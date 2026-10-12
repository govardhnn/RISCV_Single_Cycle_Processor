#ifndef CORE_PORTME_H
#define CORE_PORTME_H
#include <stddef.h>
#include <stdint.h>
#define HAS_FLOAT 0
#define HAS_TIME_H 0
#define HAS_STDIO 1
#define HAS_PRINTF 1
#define COMPILER_VERSION "GCC " __VERSION__
#define COMPILER_FLAGS FLAGS_STR
#define MEM_LOCATION "512 KiB unified RAM; static data; RV32I software arithmetic"
typedef int16_t ee_s16;
typedef uint16_t ee_u16;
typedef int32_t ee_s32;
typedef uint8_t ee_u8;
typedef uint32_t ee_u32;
typedef uintptr_t ee_ptr_int;
typedef size_t ee_size_t;
typedef uint32_t CORE_TICKS;
#define CORETIMETYPE uint32_t
#define align_mem(x) ((void *)(((uintptr_t)(x) + 3) & ~(uintptr_t)3))
#define SEED_METHOD SEED_VOLATILE
#define MEM_METHOD MEM_STATIC
#define MULTITHREAD 1
#define MAIN_HAS_NOARGC 1
#define MAIN_HAS_NORETURN 0
extern ee_u32 default_num_contexts;
typedef struct { ee_u8 portable_id; } core_portable;
void portable_init(core_portable *, int *, char *[]);
void portable_fini(core_portable *);
#endif
