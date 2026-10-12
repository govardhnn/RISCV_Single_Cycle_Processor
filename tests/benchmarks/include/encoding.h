#ifndef BENCH_ENCODING_H
#define BENCH_ENCODING_H
/* CSR definitions used by upstream common/crt.S and common/util.h.
 * Keep this adapter independent of riscv-tests' nested riscv-test-env submodule.
 */
#define MSTATUS_VS  0x00000600
#define MSTATUS_MPP 0x00001800
#define MSTATUS_FS  0x00006000
#define MSTATUS_XS  0x00018000
#ifndef __ASSEMBLER__
#define read_csr(reg) ({ unsigned long value; \
  __asm__ volatile ("csrr %0, " #reg : "=r" (value)); value; })
#endif
#endif
