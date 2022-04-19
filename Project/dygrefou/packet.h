#ifndef PACKET_H
#define PACKET_H

#include <arpa/inet.h>

int parse_packet(const unsigned char *pkt, size_t pktlen, struct in_addr *saddr, struct in_addr *daddr);

#endif

