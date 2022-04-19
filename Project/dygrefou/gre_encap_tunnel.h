#ifndef GRETAP_ENCAP_TUNNEL_H
#define GRETAP_ENCAP_TUNNEL_H

#include <arpa/inet.h>
#include <inttypes.h>
#include <linux/if.h>
#include <linux/if_tunnel.h>
#include <netlink/netlink.h>

struct gretap_opt {
    char ifname[IFNAMSIZ];
    int master;
    struct in_addr local;
    struct in_addr remote;
    uint32_t key;
    enum tunnel_encap_types encap_type;
    uint16_t encap_sport;
    uint16_t encap_dport;
};

int create_tunnel(struct nl_sock *nl, const struct gretap_opt *opt);
int destory_tunnel(struct nl_sock *nl, const char *ifname);
int destory_tunnel_index(struct nl_sock *nl, int ifindex);

#endif
