#include "riscv_test.h"

.macro check reg, value
  addi TESTNUM, TESTNUM, 1
  li t6, \value
  bne \reg, t6, fail
.endm

.macro trap_setup cause
  li s0, \cause
  la s1, 991f
  li s3, 0
.endm

.macro trapped
  check s3, 1
.endm

RVTEST_CODE_BEGIN
  la t0, handler
  csrw mtvec, t0
  li t0, 8
  csrs mstatus, t0

  # All six CSR forms: old value in rd, new value in CSR.
  li t0, 0x55
  csrrw t1, mscratch, t0
  check t1, 0
  csrr t1, mscratch
  check t1, 0x55
  li t0, 0x0a
  csrrs t1, mscratch, t0
  check t1, 0x55
  csrr t1, mscratch
  check t1, 0x5f
  li t0, 0x0f
  csrrc t1, mscratch, t0
  check t1, 0x5f
  csrr t1, mscratch
  check t1, 0x50
  csrrwi t1, mscratch, 31
  check t1, 0x50
  csrrci t1, mscratch, 3
  check t1, 31
  csrrsi t1, mscratch, 1
  check t1, 28
  csrr t1, mscratch
  check t1, 29
  csrrs t1, mscratch, x0
  csrrc t1, mscratch, x0
  csrrsi t1, mscratch, 0
  csrrci t1, mscratch, 0
  check t1, 29
  csrrw x0, mscratch, x0
  csrr t1, mscratch
  check t1, 0
  csrrwi x0, mscratch, 7
  csrrwi t1, mscratch, 0
  check t1, 7
  csrr t1, mscratch
  check t1, 0

  # All read-only CSR read forms must work, including immediate mask zero.
  csrrs t1, mhartid, x0
  check t1, 0
  csrrc t1, mhartid, x0
  check t1, 0
  csrrsi t1, mhartid, 0
  check t1, 0
  csrrci t1, mhartid, 0
  check t1, 0

  # A nonzero register index requests a write even if its value is zero.
  li t0, 0
  li a0, 123
  trap_setup 2
  lw s2, 991f
991: csrrs a0, mhartid, t0
  trapped
  check a0, 123
  trap_setup 2
  lw s2, 991f
991: csrrw a0, mhartid, x0
  trapped
  trap_setup 2
  lw s2, 991f
991: csrrsi a0, mhartid, 1
  trapped
  trap_setup 2
  lw s2, 991f
991: csrr a0, 0x777
  trapped
  check a0, 123

  # ECALL and EBREAK save precise PC/cause/value and return through MRET.
  li s2, 0
  trap_setup 11
991: ecall
  trapped
  trap_setup 3
  mv s2, s1
991: ebreak
  trapped
  csrr t1, mstatus
  check t1, 0x1888

  # Illegal encodings cannot silently execute an ALU/store/CSR operation.
  trap_setup 2
  li s2, 0x02000533 # mul a0,x0,x0 (M is not implemented)
991: .word 0x02000533
  trapped
  check a0, 123
  trap_setup 2
  li s2, 0x00004073 # reserved SYSTEM funct3
991: .word 0x00004073
  trapped
  trap_setup 2
  li s2, 0x02001513 # reserved SLLI upper bits
991: .word 0x02001513
  trapped
  check a0, 123

  # Misaligned loads/stores leave the destination and memory unchanged.
  la a1, data_word
  li a2, 0x12345678
  sw a2, 0(a1)
  addi s2, a1, 1
  trap_setup 4
991: lh a0, 1(a1)
  trapped
  check a0, 123
  addi s2, a1, 2
  trap_setup 4
991: lw a0, 2(a1)
  trapped
  addi s2, a1, 1
  trap_setup 4
991: lhu a0, 1(a1)
  trapped
  trap_setup 6
991: sh a0, 1(a1)
  trapped
  addi s2, a1, 2
  trap_setup 6
991: sw a0, 2(a1)
  trapped
  lw t1, 0(a1)
  check t1, 0x12345678

  # Taken jump/branch misalignment traps; an untaken branch does not.
  trap_setup 0
  addi s2, s1, 2
991: .word 0x0020056f # jal a0,+2
  trapped
  check a0, 123
  trap_setup 0
  addi s2, s1, 2
991: .word 0x00000163 # beq x0,x0,+2
  trapped
  .word 0x00001163 # bne x0,x0,+2 (not taken)
  trap_setup 0
  addi s2, s1, 2
  ori a1, s2, 1
991: jalr a0, 0(a1)
  trapped
  check a0, 123

  # JALR clears bit zero and supports rd == rs1, with PC+4 as the link.
  la a0, odd_target
  ori a0, a0, 1
  jalr a0, 0(a0)
return_link:
  j fail
odd_target:
  la t1, return_link
  bne a0, t1, fail
  addi x0, x0, 9
  check x0, 0
  fence rw, rw
  fence.i

  # Freeze counters and check machine writes, high halves and aliases.
  li t0, 5
  csrw mcountinhibit, t0
  li t0, 0x89abcdef
  csrw mcycle, t0
  li t0, 0x12345678
  csrw mcycleh, t0
  csrr t1, cycle
  check t1, 0x89abcdef
  csrr t1, cycleh
  check t1, 0x12345678
  li t0, 42
  csrw minstret, t0
  li t0, 7
  csrw minstreth, t0
  csrr t1, instret
  check t1, 42
  csrr t1, instreth
  check t1, 7
  li t0, 1
  csrw mcountinhibit, t0 # following instructions retire; cycle stays frozen
  addi t0, t0, 1
  csrr t1, instret
  check t1, 43
  csrr t1, cycle
  check t1, 0x89abcdef
  RVTEST_PASS

.balign 4
handler:
  csrr t4, mcause
  bne t4, s0, fail
  csrr t4, mepc
  bne t4, s1, fail
  csrr t5, mtval
  bne t5, s2, fail
  csrr t5, mstatus
  li t6, 0x1880
  bne t5, t6, fail
  addi t4, t4, 4
  csrw mepc, t4
  addi s3, s3, 1
  mret
fail:
  RVTEST_FAIL
RVTEST_CODE_END
RVTEST_DATA_BEGIN
.balign 4
data_word: .word 0
RVTEST_DATA_END
