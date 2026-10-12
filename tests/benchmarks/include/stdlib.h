#ifndef BENCH_STDLIB_H
#define BENCH_STDLIB_H
#include <stddef.h>
void exit(int) __attribute__((noreturn));
void abort(void) __attribute__((noreturn));
long atol(const char *);
#endif
