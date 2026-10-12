#ifndef _RISCV_TEST_H
#define _RISCV_TEST_H

/* Minimal test environment for a single-cycle RV32I processor.
 * No CSR instructions, no privileged setup — just bare-metal pass/fail
 * signalling via a memory-mapped tohost word at 0x1000.
 */

#define TESTNUM gp

#define RVTEST_RV32U
#define RVTEST_RV64U RVTEST_RV32U

/* _start: initialise TESTNUM to 0, then fall into test body */
#define RVTEST_CODE_BEGIN       \
    .section .text.init;        \
    .align 2;                   \
    .globl _start;              \
_start:                         \
    li TESTNUM, 0;

#define RVTEST_CODE_END

/* Write 1 to tohost → simulator detects PASS */
#define RVTEST_PASS             \
    li   a0, 1;                 \
    la   t5, tohost;            \
    sw   a0, 0(t5);             \
1:  j    1b;

/* Write (TESTNUM<<1)|1 to tohost → simulator detects FAIL + failing test# */
#define RVTEST_FAIL             \
    la   t5, tohost;            \
    slli a0, TESTNUM, 1;        \
    ori  a0, a0, 1;             \
    sw   a0, 0(t5);             \
1:  j    1b;

/* Place the 4-byte tohost word in .tohost (linked at 0x1000), then
 * return to .data so any TEST_DATA that follows lands in .data.       */
#define RVTEST_DATA_BEGIN                       \
    .section .tohost, "aw", @progbits;          \
    .align 2;                                   \
    .globl tohost;                              \
tohost: .word 0;                                \
    .section .data;                             \
    .align 2;

#define RVTEST_DATA_END

#endif /* _RISCV_TEST_H */
