#define _GNU_SOURCE
#include <arpa/inet.h>
#include <ctype.h>
#include <errno.h>
#include <linux/if.h>
#include <net/ethernet.h>
#include <netinet/ip.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#include "ip-gre.h"
#include "packet.h"

#include <netlink/cache.h>
#include <netlink/errno.h>
#include <netlink/netlink.h>
#include <netlink/route/link.h>
#include <netlink/route/route.h>
#include <netlink/route/link/bridge.h>
#include <netlink/route/link/ipgre.h>
#include <netlink/socket.h>
#include <pcap/pcap.h>

#define TUNNEL_PREFIX "dygre-"

#define errf(fmt, ...) fprintf(stderr, fmt, ##__VA_ARGS__)
char errbuf[PCAP_ERRBUF_SIZE];

int search_interface(char selected_if[IFNAMSIZ], const char *arg_if)
{
    pcap_if_t *if_dev = NULL;
    pcap_findalldevs(&if_dev, errbuf);
    if (if_dev == NULL) {
        errf("No interface found!\n");
        return -1;
    }

    memset(selected_if, 0, sizeof(char) * IFNAMSIZ);
    errf("Found following network interfaces:\n");
    pcap_if_t *cur = if_dev;
    size_t index = 0;
    while (cur) {
        errf("  [%zu] %s\n", index++, cur->name);
        if (arg_if && strcmp(arg_if, cur->name) == 0) {
            strncpy(selected_if, cur->name, IFNAMSIZ - 1);
            selected_if[IFNAMSIZ - 1] = '\0';
        }
        cur = cur->next;
    }

    if (arg_if != NULL && selected_if[0] == '\0') {
        errf("Selected interface is invalid!\n");
        goto err;
    }

    // No interface selected
    while (selected_if[0] == '\0') {
        errf("Select interface to listen by specifying number or name: ");
        char buf[64];
        char *endptr = buf;

        if (scanf("%15s", buf) == EOF) {
            errf("Unexpected end of input!\n");
            goto err;
        }
        unsigned id = strtoul(buf, &endptr, 10);
        if (*buf != '\0' && *endptr == '\0') {
            // input is an valid number
            cur = if_dev;
            for (size_t i = 0; i < id && cur != NULL; i++) {
                cur = cur->next;
            }

            if (cur == NULL) {
                errf("Index out of bound!\n");
                continue;
            } else {
                strncpy(selected_if, cur->name, IFNAMSIZ - 1);
                selected_if[IFNAMSIZ - 1] = '\0';
            }
        } else {
            // treat as interface name
            cur = if_dev;
            while (cur) {
                if (strcmp(buf, cur->name) == 0) {
                    strncpy(selected_if, cur->name, IFNAMSIZ - 1);
                    selected_if[IFNAMSIZ - 1] = '\0';
                    break;
                }
                cur = cur->next;
            }
        }
    }

    pcap_freealldevs(if_dev);
    return 0;
err:
    pcap_freealldevs(if_dev);
    return -1;
}

int search_bridge(struct nl_sock *nl, const char *hint)
{
    int ret = 0;
    struct nl_cache *links = NULL;
    if (rtnl_link_alloc_cache(nl, AF_UNSPEC, &links) < 0){
        errf("Error: Failed to acquire links!\n");
        return -1;
    }

    errf("Found following bridge:\n");
    for (struct rtnl_link *cur = (struct rtnl_link *)nl_cache_get_first(links);
            cur != NULL;
            cur = (struct rtnl_link *)nl_cache_get_next((struct nl_object *)cur)) {
        if (!rtnl_link_is_bridge(cur)) {
            continue;
        }

        const char *linkname = rtnl_link_get_name(cur);
        if (linkname == NULL) {
            continue;
        }
        errf("  [%d] %s\n", rtnl_link_get_ifindex(cur), linkname);

        if (hint) {
            if (strcmp(linkname, hint) == 0) {
                ret = rtnl_link_get_ifindex(cur);
            }
        }
    }

    if (hint && ret == 0) {
        errf("Selected bridge is invalid!\n");
        ret = -1;
        goto out;
    }

    while (ret == 0) {
        errf("Select interface to connect by specifying number or name: ");
        char buf[64];
        char *endptr = buf;

        if (scanf("%15s", buf) == EOF) {
            errf("Unexpected end of input!\n");
            ret = -1;
            goto out;
        }
        unsigned id = strtoul(buf, &endptr, 10);
        if (*buf != '\0' && *endptr == '\0') {
            // input is an valid number
            for (struct rtnl_link *cur = (struct rtnl_link *)nl_cache_get_first(links);
                    cur != NULL;
                    cur = (struct rtnl_link *)nl_cache_get_next((struct nl_object *)cur)) {
                if (!rtnl_link_is_bridge(cur)) {
                    continue;
                }

                if (rtnl_link_get_ifindex(cur) == id) {
                    ret = id;
                }
            }
        } else {
            // treat as interface name
            for (struct rtnl_link *cur = (struct rtnl_link *)nl_cache_get_first(links);
                    cur != NULL;
                    cur = (struct rtnl_link *)nl_cache_get_next((struct nl_object *)cur)) {
                if (!rtnl_link_is_bridge(cur)) {
                    continue;
                }

                const char *linkname = rtnl_link_get_name(cur);
                if (linkname == NULL) {
                    continue;
                }

                if (strcmp(linkname, buf) == 0) {
                    ret = rtnl_link_get_ifindex(cur);
                }
            }
        }
    }

out:
    nl_cache_free(links);
    return ret;
}

int build_filter(pcap_t *pcap, struct nl_sock *nl)
{
    char *exprbuf = NULL;
    size_t exprbuf_len = 0;
    FILE *ss = open_memstream(&exprbuf, &exprbuf_len);
    if (ss == NULL) {
        abort();
    }

    errf("Building filter expression...\n");

    fprintf(ss, "inbound and ip proto gre");

    struct nl_cache *links = NULL;
    if (rtnl_link_alloc_cache(nl, AF_UNSPEC, &links) < 0){
        errf("Error: Failed to acquire links!\n");
        goto skip_links;
    }

    for (struct rtnl_link *cur = (struct rtnl_link *)nl_cache_get_first(links);
            cur != NULL;
            cur = (struct rtnl_link *)nl_cache_get_next((struct nl_object *)cur)) {
        char buf[INET_ADDRSTRLEN];

        if (!rtnl_link_is_ipgretap(cur)) {
            continue;
        }
        // Check link prefix
        const char *linkname = rtnl_link_get_name(cur);
        if (linkname == NULL || strncmp(linkname, TUNNEL_PREFIX, strlen(TUNNEL_PREFIX)) != 0) {
            continue;
        }

        struct in_addr remote = {
            .s_addr = rtnl_link_ipgre_get_remote(cur)
        };
        fprintf(ss, " and not src host %s", inet_ntop(AF_INET, &remote, buf, INET_ADDRSTRLEN));
    }
    nl_cache_free(links);

skip_links:
    fflush(ss);
    fclose(ss);

    errf("Expression: %s\n", exprbuf);

    struct bpf_program bpf;
    if (pcap_compile(pcap, &bpf, exprbuf, 0, PCAP_NETMASK_UNKNOWN) == PCAP_ERROR) {
        errf("Failed to compile the filter into BPF program: %s\n", pcap_geterr(pcap));
        goto err;
    }

    if (pcap_setfilter(pcap, &bpf) == PCAP_ERROR) {
        errf("Failed to load the BPF program: %s\n", pcap_geterr(pcap));
        goto err_bpf;
    }

    pcap_freecode(&bpf);
    free(exprbuf);
    return 0;

err_bpf:
    pcap_freecode(&bpf);
err:
    free(exprbuf);
    return -1;
}

int create_tunnel(struct nl_sock *nl, int master, struct in_addr *remote, struct in_addr *local)
{
    struct rtnl_link *grelink = rtnl_link_ipgretap_alloc();
    if (grelink == NULL) {
        errf("Failed to allocate rtnl_link!\n");
        return -1;
    }

    char linkname[IFNAMSIZ];
    snprintf(linkname, IFNAMSIZ - 1, TUNNEL_PREFIX"%08x", remote->s_addr);
    linkname[IFNAMSIZ - 1] = '\0';

    rtnl_link_set_name(grelink, linkname);
    rtnl_link_ipgre_set_local(grelink, local->s_addr);
    rtnl_link_ipgre_set_remote(grelink, remote->s_addr);
    if (master > 0) {
        rtnl_link_set_master(grelink, master);
    }
    rtnl_link_set_flags(grelink, IFF_UP);

    int ret = rtnl_link_add(nl, grelink, NLM_F_CREATE);
    rtnl_link_put(grelink);

    if (ret == -NLE_EXIST) {
        errf("Warning: Link exists\n");
        return 0;
    } else if (ret < 0) {
        errf("Error: Failed to add link: %s\n", nl_geterror(ret));
        return -1;
    }

    return 0;
}

static volatile sig_atomic_t running = 1;
pcap_t *pcap = NULL;

void term_handler(int sig)
{
    running = 0;
    if (pcap) {
        pcap_breakloop(pcap);
    }
}

int main(int argc, char *argv[])
{
    const char *arg_if = NULL;
    const char *arg_bridge = NULL;
    char selected_if[IFNAMSIZ];
    int master = 0;

    if (argc > 1) {
        arg_if = argv[1];
    }
    if (argc > 2) {
        arg_bridge = argv[2];
    }

    struct nl_sock *nl = nl_socket_alloc();
    if (nl == NULL) {
        errf("Failed to allocate netlink socket!\n");
        exit(1);
    }
    if (nl_connect(nl, NETLINK_ROUTE) < 0) {
        errf("Failed to connect to netlink route!\n");
        exit(1);
    }

    if (search_interface(selected_if, arg_if) < 0) {
        exit(1);
    }
    master = search_bridge(nl, arg_bridge);
    if (master < 0) {
        exit(1);
    }

    signal(SIGINT, term_handler);
    signal(SIGTERM, term_handler);

    pcap = pcap_open_live(selected_if, 65535, true, 1000, errbuf);
    if (pcap == NULL) {
        errf("Failed to open device \"%s\": %s\n", selected_if, errbuf);
        exit(1);
    }
    errf("Start listening on %s...\n", selected_if);

    if (build_filter(pcap, nl) < 0) {
        exit(1);
    }

    errf("Fetching packet...\n");
    while (running) {
        struct pcap_pkthdr pkt_hdr;

        const u_char *pkt = pcap_next(pcap, &pkt_hdr);
        if (pkt == NULL) {
            continue;
        }

        struct in_addr saddr, daddr;
        if (parse_packet(pkt, pkt_hdr.caplen, &saddr, &daddr) < 0) {
            errf("Warning: Got invalid GRE packet!\n");
            continue;
        }

        if (create_tunnel(nl, master, &saddr, &daddr) < 0) {
            errf("Error: Failed to create tunnel!\n");
            continue;
        }

        if (build_filter(pcap, nl) < 0) {
            errf("Error: Failed to rebuild filter!\n");
        }
    }

    pcap_close(pcap);
    pcap = NULL;
    nl_close(nl);
    nl_socket_free(nl);

    return 0;
}

