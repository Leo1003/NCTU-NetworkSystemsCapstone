#include "hexdump.h"

#include <ctype.h>
#include <stdio.h>
#define HEXDUMP_COLS 8

void hexdump(FILE *fp, const unsigned char *mem, size_t len)
{
    size_t i, j;

    for (i = 0; i < len + ((len % HEXDUMP_COLS) ? (HEXDUMP_COLS - len % HEXDUMP_COLS) : 0); i++) {
        /* print offset */
        if (i % HEXDUMP_COLS == 0) {
            fprintf(fp, "0x%06zx: ", i);
        }

        /* print hex data */
        if (i < len) {
            fprintf(fp, "%02x ", 0xFF & ((char *)mem)[i]);
        } else /* end of block, just aligning for ASCII dump */ {
            fprintf(fp, "   ");
        }

        /* print ASCII dump */
        if (i % HEXDUMP_COLS == (HEXDUMP_COLS - 1)) {
            for (j = i - (HEXDUMP_COLS - 1); j <= i; j++) {
                if (j >= len) {
                    /* end of block, not really printing */
                    fputc(' ', fp);
                } else if (isprint(((char *)mem)[j])) {
                    /* printable char */
                    fputc(0xFF & ((char *)mem)[j], fp);
                } else {
                    /* other char */
                    fputc('.', fp);
                }
            }
            fputc('\n', fp);
        }
    }
}

