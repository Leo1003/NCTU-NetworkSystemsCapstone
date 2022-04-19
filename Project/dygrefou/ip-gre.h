#ifndef IP_GRE_H
#define IP_GRE_H

#include <endian.h>
#include <stdint.h>

struct grehdr {
#if BYTE_ORDER == LITTLE_ENDIAN
    unsigned int __res2:4;
    unsigned int s:1;
    unsigned int k:1;
    unsigned int __res1:1;
    unsigned int c:1;
    unsigned int ver:3;
    unsigned int __res3:5;
#elif BYTE_ORDER == BIG_ENDIAN
    unsigned int c:1;
    unsigned int __res1:1;
    unsigned int k:1;
    unsigned int s:1;
    unsigned int __res2:4;
    unsigned int __res3:5;
    unsigned int ver:3;
#else
# error "Failed to get endian"
#endif
    uint16_t protocol;
} __attribute__((__packed__));

#define ETHERTYPE_ETHERNET  0x6558

#endif
