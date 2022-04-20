#ifndef PACKET_H
#define PACKET_H

#include <arpa/inet.h>
#include "gre_encap_tunnel.h"

int parse_packet(const uint8_t *pkt, size_t pktlen, struct gretap_opt *opt);

#endif

