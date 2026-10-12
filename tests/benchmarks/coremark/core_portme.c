/* RV32 machine-mode port; upstream CoreMark workload files are unchanged. */
#include "coremark.h"
#include "encoding.h"
#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
#else
volatile ee_s32 seed1_volatile = 0;
volatile ee_s32 seed2_volatile = 0;
#endif
volatile ee_s32 seed3_volatile = 0x66;
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;
ee_u32 default_num_contexts = 1;
static CORE_TICKS start_cycles, stop_cycles;
void start_time(void) { start_cycles = read_csr(mcycle); }
void stop_time(void) { stop_cycles = read_csr(mcycle); }
CORE_TICKS get_time(void) { return stop_cycles - start_cycles; }
/* Simulation reference frequency only, not an achieved hardware clock. */
secs_ret time_in_secs(CORE_TICKS ticks) { return ticks / COREMARK_CLOCK_HZ; }
void portable_init(core_portable *p, int *argc, char *argv[]) {
    (void)argc;
    (void)argv;
    p->portable_id = 1;
    printf("Reference clock Hz: %u\n", (unsigned)COREMARK_CLOCK_HZ);
}
void portable_fini(core_portable *p) { p->portable_id = 0; }
