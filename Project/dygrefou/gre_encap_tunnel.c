#include "gre_encap_tunnel.h"

#include <linux/if.h>
#include <linux/if_tunnel.h>
#include <linux/if_link.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <netlink/attr.h>
#include <netlink/msg.h>
#include <netlink/netlink.h>

int create_tunnel(struct nl_sock *nl, const struct gretap_opt *opt)
{
    int ret = -1;

    struct nl_msg *msg = nlmsg_alloc_simple(RTM_NEWLINK, NLM_F_CREATE);
    if (msg == NULL) {
        return -1;
    }

    struct ifinfomsg ifmsg = {
        .ifi_flags = IFF_UP,
        .ifi_change = IFF_UP,
    };

    if (nlmsg_append(msg, &ifmsg, sizeof(ifmsg), NLMSG_ALIGNTO) < 0) {
        goto err_msg;
    }
    NLA_PUT_STRING(msg, IFLA_IFNAME, opt->ifname);
    if (opt->master) {
        NLA_PUT_U32(msg, IFLA_MASTER, opt->master);
    }

    struct nlattr *info = nla_nest_start(msg, IFLA_LINKINFO);
    if (info == NULL) {
        goto err_msg;
    }
    NLA_PUT_STRING(msg, IFLA_INFO_KIND, "gretap");
    
    struct nlattr *info_data = nla_nest_start(msg, IFLA_INFO_DATA);
    if (info_data == NULL) {
        goto err_msg;
    }
    if (opt->local.s_addr) {
        NLA_PUT_U32(msg, IFLA_GRE_LOCAL, opt->local.s_addr);
    }
    if (opt->remote.s_addr) {
        NLA_PUT_U32(msg, IFLA_GRE_REMOTE, opt->remote.s_addr);
    }
    if (opt->key) {
        NLA_PUT_U32(msg, IFLA_GRE_IKEY, opt->key);
        NLA_PUT_U32(msg, IFLA_GRE_OKEY, opt->key);
    }
    if (opt->encap_type != TUNNEL_ENCAP_NONE) {
        NLA_PUT_U16(msg, IFLA_GRE_ENCAP_TYPE, opt->encap_type);
        if (opt->encap_sport) {
            NLA_PUT_U16(msg, IFLA_GRE_ENCAP_SPORT, opt->encap_sport);
        }
        if (opt->encap_dport) {
            NLA_PUT_U16(msg, IFLA_GRE_ENCAP_DPORT, opt->encap_dport);
        }
    }
    nla_nest_end(msg, info_data);

    nla_nest_end(msg, info);

    if (nl_send_sync(nl, msg) < 0) {
        goto err_msg;
    }
    ret = 0;

nla_put_failure:
err_msg:
    nlmsg_free(msg);
    return ret;
}

int destory_tunnel(struct nl_sock *nl, const char *ifname)
{
    int ret = -1;
    struct nl_cache *links = NULL;
    if (rtnl_link_alloc_cache(nl, AF_UNSPEC, &links) < 0) {
        return ret;
    }

    struct rtnl_link* link = rtnl_link_get_by_name(links, ifname);
    if (link == NULL) {
        goto err:
    }

    ret = rtnl_link_delete(nl, link);

err_msg:
    nl_cache_free(links);
    return ret;
}

int destory_tunnel_index(struct nl_sock *nl, int ifindex)
{
    int ret = -1;
    struct nl_cache *links = NULL;
    if (rtnl_link_alloc_cache(nl, AF_UNSPEC, &links) < 0) {
        return ret;
    }

    struct rtnl_link* link = rtnl_link_get(links, ifindex);
    if (link == NULL) {
        goto err:
    }

    ret = rtnl_link_delete(nl, link);

err_msg:
    nl_cache_free(links);
    return ret;
}

