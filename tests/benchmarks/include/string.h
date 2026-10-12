#ifndef BENCH_STRING_H
#define BENCH_STRING_H
#include <stddef.h>
void *memcpy(void *, const void *, size_t);
void *memset(void *, int, size_t);
size_t strlen(const char *);
size_t strnlen(const char *, size_t);
int strcmp(const char *, const char *);
char *strcpy(char *, const char *);
#endif
