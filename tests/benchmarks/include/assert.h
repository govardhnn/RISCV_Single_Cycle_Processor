#ifndef BENCH_ASSERT_H
#define BENCH_ASSERT_H
#include <stdlib.h>
/* Keep assertions enabled: upstream abort() reports a failing exit code. */
#define assert(expr) ((expr) ? (void)0 : abort())
#endif
