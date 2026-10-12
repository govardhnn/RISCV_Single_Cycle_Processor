# ============================================================================
# RISC-V Single-Cycle Processor — ISA test flow
# ============================================================================
# Requirements
#   - riscv64-unknown-elf-gcc  (or riscv32-unknown-elf-gcc)
#   - iverilog / vvp
#   - python3
#
# Targets
#   make            – build tests + testbench, then run all rv32ui tests
#   make build-tests – compile ELFs + hex files only
#   make sim         – compile testbench + run tests (implies build-tests)
#   make benchmarks  – run scalar application benchmarks; report unsupported ones
#   make coremark    – run CoreMark performance and validation configurations
#   make check       – run ISA tests and application benchmarks
#   make clean       – remove sim/ directory

# ============================================================================
# Tools
# ============================================================================
RISCV_PREFIX ?= riscv64-unknown-elf-
CC           := $(RISCV_PREFIX)gcc
OBJCOPY      := $(RISCV_PREFIX)objcopy
IVERILOG     ?= iverilog
VVP          ?= vvp
PYTHON       ?= python3

# ============================================================================
# Compiler flags — bare-metal RV32I, custom link script and env headers
# ============================================================================
MARCH  := rv32i_zicsr_zifencei
MABI   := ilp32

TESTS_ROOT  := tests/riscv-tests
ISA_DIR     := $(TESTS_ROOT)/isa/rv32ui
ENV_DIR     := tests/env
MACROS_DIR  := $(TESTS_ROOT)/isa/macros/scalar
LINK_SCRIPT := tests/link.ld
BIN2HEX     := tests/bin2hex.py
SIM_DIR     := sim

CFLAGS := \
    -march=$(MARCH) -mabi=$(MABI) \
    -static -mcmodel=medany \
    -fvisibility=hidden -nostdlib -nostartfiles \
    -I$(ENV_DIR) -I$(MACROS_DIR)

# ============================================================================
# RTL sources — complete core and production unified memory
# ============================================================================
CORE_SRCS := \
    rtl/CSR_File.v    \
    rtl/Instruction_Check.v \
    rtl/Data_Memory.v \
    rtl/ALU.v         \
    rtl/ALU_Mux.v     \
    rtl/ALU_decoder.v \
    rtl/Control_Unit.v \
    rtl/Core_Datapath.v \
    rtl/Extend.v      \
    rtl/Main_Decoder.v \
    rtl/PC.v          \
    rtl/PC_Mux.v      \
    rtl/PC_Plus_4.v   \
    rtl/PC_Target.v   \
    rtl/Register_File.v \
    rtl/Result_Mux.v  \
    rtl/Single_Cycle_Core.v \
    rtl/Single_Cycle_Top.v

TB_SRC  := tb/riscv_tests_tb.v
SIM_BIN := $(SIM_DIR)/riscv_tests_sim

# ============================================================================
# rv32ui test list
# ============================================================================
RV32UI_TESTS := \
    add addi and andi auipc \
    beq bge bgeu blt bltu bne \
    fence_i jal jalr \
    lb lbu lh lhu lui lw \
    or ori \
    sb sh simple sll slli \
    slt slti sltiu sltu \
    sra srai srl srli sub sw \
    xor xori

RV32UI_ELFS  := $(addprefix $(SIM_DIR)/rv32ui-, $(addsuffix .elf,  $(RV32UI_TESTS)))
RV32UI_HEXES := $(addprefix $(SIM_DIR)/rv32ui-, $(addsuffix .hex,  $(RV32UI_TESTS)))

# ============================================================================
# Rules
# ============================================================================
.PHONY: all build-tests sim clean

all: sim

# Create output directory
$(SIM_DIR)/.dir:
	mkdir -p $(SIM_DIR)
	touch $@

# Compile each test .S → ELF
$(SIM_DIR)/rv32ui-%.elf: $(ISA_DIR)/%.S $(LINK_SCRIPT) $(ENV_DIR)/riscv_test.h | $(SIM_DIR)/.dir
	$(CC) $(CFLAGS) -T$(LINK_SCRIPT) -o $@ $<

# ELF → flat binary → Verilog hex (word-addressed, starts at @00000000)
$(SIM_DIR)/rv32ui-%.hex: $(SIM_DIR)/rv32ui-%.elf $(BIN2HEX)
	$(OBJCOPY) -O binary $< $@.bin
	$(PYTHON) $(BIN2HEX) $@.bin $@
	@rm -f $@.bin

# Compile the iverilog testbench
$(SIM_BIN): $(CORE_SRCS) $(TB_SRC) rtl/logger.vh | $(SIM_DIR)/.dir
	$(IVERILOG) -Irtl -s riscv_tests_tb -o $@ -g2012 $(CORE_SRCS) $(TB_SRC)

build-tests: $(RV32UI_ELFS) $(RV32UI_HEXES)

# Run every test and print a summary
sim: $(SIM_BIN) $(RV32UI_HEXES) $(SIM_DIR)/directed-system.hex $(SIM_DIR)/reset_sim
	@echo ""
	@echo "=== rv32ui Test Results ==="
	@pass=0; fail=0; \
	for test in $(RV32UI_TESTS); do \
	    hexfile=$(SIM_DIR)/rv32ui-$$test.hex; \
	    if result=$$($(VVP) $(SIM_BIN) +HEXFILE=$$hexfile 2>&1) && \
	       printf '%s\n' "$$result" | grep -qx PASS; then \
	        printf "  PASS  rv32ui-%-12s\n" "$$test"; \
	        pass=$$((pass+1)); \
	    else \
	        printf "  FAIL  rv32ui-%-12s  ($$result)\n" "$$test"; \
	        fail=$$((fail+1)); \
	    fi; \
	done; \
	total=$$((pass+fail)); \
	echo ""; \
	echo "  $$pass / $$total passed,  $$fail failed"; \
	test $$fail -eq 0
	$(VVP) $(SIM_BIN) +HEXFILE=$(SIM_DIR)/directed-system.hex
	$(VVP) $(SIM_DIR)/reset_sim

clean:
	rm -rf $(SIM_DIR)

# CSR, exception, alignment, and side-effect regression.
$(SIM_DIR)/directed-%.elf: tests/directed/%.S $(LINK_SCRIPT) $(ENV_DIR)/riscv_test.h | $(SIM_DIR)/.dir
	$(CC) $(CFLAGS) -T$(LINK_SCRIPT) -o $@ $<

$(SIM_DIR)/directed-%.hex: $(SIM_DIR)/directed-%.elf $(BIN2HEX)
	$(OBJCOPY) -O binary $< $@.bin
	$(PYTHON) $(BIN2HEX) $@.bin $@
	@rm -f $@.bin

$(SIM_DIR)/reset_sim: $(CORE_SRCS) rtl/logger.vh tb/reset_tb.v | $(SIM_DIR)/.dir
	$(IVERILOG) -Irtl -s reset_tb -g2012 -o $@ $(CORE_SRCS) tb/reset_tb.v

# ============================================================================
# Application benchmarks (Verilator keeps software floating point practical).
# Upstream sources stay unchanged; local headers declare its freestanding libc.
# ============================================================================
VERILATOR ?= verilator
NM := $(RISCV_PREFIX)nm
BENCH_ROOT := $(TESTS_ROOT)/benchmarks
BENCH_ENV := tests/benchmarks
BENCH_SUPPORTED := median qsort rsort towers vvadd memcpy multiply dhrystone spmv coremark coremark-validation
BENCH_SKIPPED := mm mt-vvadd mt-matmul mt-memcpy pmp vec-memcpy vec-daxpy vec-sgemm vec-strcmp
BENCHMARKS ?= $(BENCH_SUPPORTED) $(BENCH_SKIPPED)
BENCH_RUNNABLE := $(filter $(BENCH_SUPPORTED),$(BENCHMARKS))
ifneq ($(filter-out $(BENCH_SUPPORTED) $(BENCH_SKIPPED),$(BENCHMARKS)),)
$(error Unknown benchmark name in BENCHMARKS)
endif
BENCH_MAX_CYCLES ?= 500000000
BENCH_TIMEOUT ?= 300
BENCH_SIM := $(SIM_DIR)/bench-obj/Vbenchmarks_tb
BENCH_FLAGS := -march=$(MARCH) -mabi=$(MABI) -mcmodel=medany -static \
    -std=gnu99 -O2 -ffreestanding -fno-common -fno-builtin-printf \
    -fno-tree-loop-distribute-patterns -Wno-implicit-int \
    -Wno-implicit-function-declaration -DPREALLOCATE=1 \
    -I$(BENCH_ENV)/include -I$(BENCH_ROOT)/common -I$(TESTS_ROOT)/env \
    -nostdlib -nostartfiles
BENCH_ELFS := $(addprefix $(SIM_DIR)/bench-,$(addsuffix .elf,$(BENCH_RUNNABLE)))
BENCH_HEXES := $(BENCH_ELFS:.elf=.hex)
BENCH_HEADERS := $(wildcard $(BENCH_ENV)/include/*.h $(BENCH_ENV)/include/sys/*.h)

.PHONY: benchmarks build-benchmarks check
check: sim benchmarks
build-benchmarks: $(BENCH_HEXES)
.SECONDARY: $(BENCH_ELFS)

# Generate explicit prerequisites so changing an upstream dataset rebuilds it.
define benchmark_template
$(SIM_DIR)/bench-$(1).elf: $(wildcard $(BENCH_ROOT)/$(1)/*.[chS]) \
    $(wildcard $(BENCH_ROOT)/common/*) $(BENCH_HEADERS) $(BENCH_ENV)/link.ld Makefile | $(SIM_DIR)/.dir
	$(CC) $(BENCH_FLAGS) -I$(BENCH_ROOT)/$(1) \
	    $(wildcard $(BENCH_ROOT)/$(1)/*.c $(BENCH_ROOT)/$(1)/*.S) \
	    $(BENCH_ROOT)/common/syscalls.c $(BENCH_ROOT)/common/crt.S \
	    -T$(BENCH_ENV)/link.ld -Wl,-Map,$(SIM_DIR)/bench-$(1).map -lgcc -o $$@
endef
$(foreach bench,$(filter-out coremark coremark-validation,$(BENCH_RUNNABLE)),$(eval $(call benchmark_template,$(bench))))

$(SIM_DIR)/bench-%.hex: $(SIM_DIR)/bench-%.elf $(BIN2HEX)
	$(OBJCOPY) -O binary $< $@.bin
	$(PYTHON) $(BIN2HEX) $@.bin $@
	@rm -f $@.bin

$(BENCH_SIM): $(CORE_SRCS) rtl/logger.vh tb/benchmarks_tb.sv | $(SIM_DIR)/.dir
	$(VERILATOR) --binary --timing -j 2 -Irtl --top-module benchmarks_tb \
	    --Mdir $(SIM_DIR)/bench-obj $(CORE_SRCS) tb/benchmarks_tb.sv

benchmarks: $(BENCH_SIM) $(BENCH_HEXES)
	$(PYTHON) $(BENCH_ENV)/run.py --sim $(BENCH_SIM) --nm $(NM) \
	    --dir $(SIM_DIR) --max-cycles $(BENCH_MAX_CYCLES) \
	    --timeout $(BENCH_TIMEOUT) --readme README.md $(BENCHMARKS)

# Official CoreMark submodule, with the platform port maintained outside it.
COREMARK_ROOT := tests/coremark
COREMARK_PORT := $(BENCH_ENV)/coremark
COREMARK_ITERATIONS ?= 100
COREMARK_CLOCK_HZ ?= 1000000
COREMARK_SRCS := $(addprefix $(COREMARK_ROOT)/,core_list_join.c core_main.c core_matrix.c core_state.c core_util.c)
COREMARK_FLAGS := $(BENCH_FLAGS) -I$(COREMARK_PORT) -I$(COREMARK_ROOT) \
    -DITERATIONS=$(COREMARK_ITERATIONS) -DCOREMARK_CLOCK_HZ=$(COREMARK_CLOCK_HZ) \
    -DTOTAL_DATA_SIZE=2000

.PHONY: coremark FORCE_COREMARK_CONFIG
coremark:
	$(MAKE) benchmarks BENCHMARKS="coremark coremark-validation"

# Rebuild when iteration or reference-clock parameters change, not on every run.
$(SIM_DIR)/coremark-config.h: FORCE_COREMARK_CONFIG | $(SIM_DIR)/.dir
	@printf '%s\n' '#define COREMARK_BUILD_CONFIG "$(COREMARK_FLAGS)"' > $@.tmp
	@cmp -s $@.tmp $@ || cp $@.tmp $@
	@rm -f $@.tmp

$(SIM_DIR)/bench-coremark.elf: COREMARK_MODE = -DPERFORMANCE_RUN=1
$(SIM_DIR)/bench-coremark-validation.elf: COREMARK_MODE = -DVALIDATION_RUN=1
$(SIM_DIR)/bench-coremark.elf $(SIM_DIR)/bench-coremark-validation.elf: $(COREMARK_SRCS) \
    $(COREMARK_ROOT)/coremark.h $(wildcard $(COREMARK_PORT)/*) $(BENCH_HEADERS) \
    $(wildcard $(BENCH_ROOT)/common/*) $(BENCH_ENV)/link.ld $(SIM_DIR)/coremark-config.h Makefile
	$(CC) $(COREMARK_FLAGS) $(COREMARK_MODE) \
	    '-DFLAGS_STR="$(COREMARK_FLAGS) $(COREMARK_MODE)"' \
	    $(COREMARK_SRCS) $(COREMARK_PORT)/core_portme.c \
	    $(BENCH_ROOT)/common/syscalls.c $(BENCH_ROOT)/common/crt.S \
	    -T$(BENCH_ENV)/link.ld -Wl,-Map,$(@:.elf=.map) -lgcc -o $@
