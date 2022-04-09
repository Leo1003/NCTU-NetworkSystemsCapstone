#include "packet.h"

#include "hexdump.h"
#include "ip-gre.h"
#include <arpa/inet.h>
#include <ctype.h>
#include <errno.h>
#include <linux/if.h>
#include <net/ethernet.h>
#include <netinet/ip.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FMT_MACADDR "%02x:%02x:%02x:%02x:%02x:%02x"

static void print_macaddr(FILE *fp, const uint8_t a[ETH_ALEN])
{
    fprintf(fp, FMT_MACADDR, a[0], a[1], a[2], a[3], a[4], a[5]);
}

const char *str_ipproto(uint8_t ipproto)
{
    switch (ipproto) {
    case IPPROTO_TCP:
        return "TCP";
    case IPPROTO_UDP:
        return "UDP";
    case IPPROTO_GRE:
        return "GRE";
    case IPPROTO_ICMP:
        return "ICMP";
    default:
        return "Unknown";
    }
}

const char *str_ethtype(uint16_t ethtype)
{
    switch (ethtype) {
    case ETHERTYPE_IP:
        return "IPv4";
    case ETHERTYPE_ARP:
        return "ARP";
    case ETHERTYPE_REVARP:
        return "RARP";
    case ETHERTYPE_IPV6:
        return "IPv6";
    case ETHERTYPE_ETHERNET:
        return "Transparent Ethernet Bridging";
    default:
        return "Unknown";
    }
}

const struct ether_header *read_ethhdr(const uint8_t **buf, size_t *buflen)
{
    if (*buflen < sizeof(struct ether_header)) {
        return NULL;
    }
    const struct ether_header *ethhdr = (const struct ether_header *)*buf;
    *buf += sizeof(struct ether_header);
    *buflen -= sizeof(struct ether_header);

    return ethhdr;
}

const struct iphdr *read_iphdr(const uint8_t **buf, size_t *buflen)
{
    if (*buflen < sizeof(struct iphdr)) {
        return NULL;
    }
    const struct iphdr *iphdr = (const struct iphdr *)*buf;
    *buf += iphdr->ihl * 4;
    *buflen -= iphdr->ihl * 4;

    return iphdr;
}

const struct grehdr *read_grehdr(const uint8_t **buf, size_t *buflen)
{
    if (*buflen < sizeof(struct grehdr)) {
        return NULL;
    }
    const struct grehdr *grehdr = (const struct grehdr *)*buf;
    size_t hdrlen = sizeof(struct grehdr);
    if (grehdr->c) {
        hdrlen += 4;
    }
    if (grehdr->k) {
        hdrlen += 4;
    }
    if (grehdr->s) {
        hdrlen += 4;
    }

    if (*buflen < hdrlen) {
        return NULL;
    }
    *buf += hdrlen;
    *buflen -= hdrlen;

    return grehdr;
}

int parse_packet(const uint8_t *pkt, size_t pktlen, struct in_addr *saddr, struct in_addr *daddr)
{
    char ipaddr_buf[INET_ADDRSTRLEN];

    const uint8_t *buf = pkt;
    size_t buflen = pktlen;

    printf("-------- [Packet Dump] --------\n");
    hexdump(stdout, pkt, pktlen);
    printf("-------- [    End    ] --------\n");

    /**
     * Ethernet header
     **/
    const struct ether_header *ethhdr = read_ethhdr(&buf, &buflen);
    if (ethhdr == NULL) {
        return -1;
    }

    printf("Source MAC: ");
    print_macaddr(stdout, ethhdr->ether_shost);
    printf("\n");
    printf("Destination MAC: ");
    print_macaddr(stdout, ethhdr->ether_dhost);
    printf("\n");
    uint16_t ethtype = ntohs(ethhdr->ether_type);
    printf("Ethernet Type: 0x%04hx %s\n", ethtype, str_ethtype(ethtype));

    /**
     * IP header
     **/
    if (ntohs(ethhdr->ether_type) != ETHERTYPE_IP) {
        return -1;
    }
    const struct iphdr *iphdr = read_iphdr(&buf, &buflen);
    if (iphdr == NULL) {
        return -1;
    }

    inet_ntop(AF_INET, &iphdr->saddr, ipaddr_buf, INET_ADDRSTRLEN);
    printf("Source IP: %s\n", ipaddr_buf);
    inet_ntop(AF_INET, &iphdr->daddr, ipaddr_buf, INET_ADDRSTRLEN);
    printf("Destination IP: %s\n", ipaddr_buf);
    printf("Protocol: 0x%02hhx %s\n", iphdr->protocol, str_ipproto(iphdr->protocol));

    /**
     * GRE header
     **/
    if (iphdr->protocol != IPPROTO_GRE) {
        return -1;
    }
    const struct grehdr *grehdr = read_grehdr(&buf, &buflen);
    if (grehdr == NULL) {
        return -1;
    }
    uint16_t greproto = ntohs(grehdr->protocol);
    printf("GRE Protocol Type: 0x%04hx %s\n", greproto, str_ethtype(greproto));


    /**
     * Inner Ethernet header
     **/
    if (ntohs(grehdr->protocol) != ETHERTYPE_ETHERNET) {
        return -1;
    }
    const struct ether_header *iethhdr = read_ethhdr(&buf, &buflen);
    if (iethhdr == NULL) {
        return -1;
    }

    printf("Inner Source MAC: ");
    print_macaddr(stdout, iethhdr->ether_shost);
    printf("\n");
    printf("Inner Destination MAC: ");
    print_macaddr(stdout, iethhdr->ether_dhost);
    printf("\n");
    uint16_t iethtype = ntohs(iethhdr->ether_type);
    printf("Inner Ethernet Type: 0x%04hx %s\n", iethtype, str_ethtype(iethtype));

    /**
     * Copy remote & local address
     **/
    memcpy(saddr, &iphdr->saddr, sizeof(struct in_addr));
    memcpy(daddr, &iphdr->daddr, sizeof(struct in_addr));

    /**
     * Inner IP header
     **/
    if (ntohs(iethhdr->ether_type) != ETHERTYPE_IP) {
        return 0;
    }
    const struct iphdr *iiphdr = read_iphdr(&buf, &buflen);
    if (iiphdr == NULL) {
        return 0;
    }

    inet_ntop(AF_INET, &iiphdr->saddr, ipaddr_buf, INET_ADDRSTRLEN);
    printf("Inner Source IP: %s\n", ipaddr_buf);
    inet_ntop(AF_INET, &iiphdr->daddr, ipaddr_buf, INET_ADDRSTRLEN);
    printf("Inner Destination IP: %s\n", ipaddr_buf);
    printf("Inner Protocol: 0x%02hhx %s\n", iiphdr->protocol, str_ipproto(iiphdr->protocol));

    return 0;
}

