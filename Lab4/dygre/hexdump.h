#ifndef HEXDUMP_H
#define HEXDUMP_H

#include <stdio.h>
#include <stdint.h>

void hexdump(FILE *fp, const unsigned char *mem, size_t len);

#endif

