#include "gre_encap_tunnel.h"

#include <linux/if.h>
#include <linux/if_tunnel.h>
#include <linux/if_link.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <netlink/msg.h>
#include <netlink/netlink.h>
#include <netlink/route/link.h>

static int tunnel_parser(struct nl_msg *msg, void *arg)
{
    int ret = -1;
    struct nlmsghdr *hdr = nlmsg_hdr(msg);
    struct gretap_opt result;
    memset(&result, 0, sizeof(struct gretap_opt));
    
    struct ifinfomsg *ifi = NULL;
    if (!nlmsg_valid_hdr(hdr, sizeof(struct ifinfomsg))) {
        return -1;
    }
    ifi = nlmsg_data(hdr);

    struct nlattr *nla = NULL, *gretap_data = NULL;
    struct nlattr *nlas = nlmsg_attrdata(hdr, sizeof(struct ifinfomsg));
    int len = nlmsg_attrlen(hdr, sizeof(struct ifinfomsg));
    int rem;
    nla_for_each_attr(nla, nlas, len, rem) {
        switch (nla_type(nla)) {
        case IFLA_MASTER:
            result.master = nla_get_u32(nla);
            break;
        case IFLA_IFNAME:
            nla_strlcpy(result.ifname, nla, IFNAMSIZ);
            break;
        case IFLA_LINKINFO: {
            struct nlattr *li_nla = NULL;
            int li_rem;
            nla_for_each_nested(li_nla, nla, li_rem) {
                switch (nla_type(li_nla)) {
                case IFLA_INFO_KIND:
                    if (nla_strcmp(li_nla, "gretap") != 0) {
                        goto err;
                    }
                    break;
                case IFLA_INFO_DATA:
                    gretap_data = li_nla;
                    break;
                default:
                    break;
                }
            }
            ;
        }
            break;
        default:
            break;
        }
    }

    if (gretap_data == NULL) {
        goto err;
    }
    nla_for_each_nested(nla, gretap_data, rem) {
        switch (nla_type(nla)) {
        case IFLA_GRE_LOCAL:
            result.local.s_addr = nla_get_u32(nla);
            break;
        case IFLA_GRE_REMOTE:
            result.remote.s_addr = nla_get_u32(nla);
            break;
        case IFLA_GRE_IKEY:
        case IFLA_GRE_OKEY:
            result.key = nla_get_u32(nla);
            break;
        case IFLA_GRE_ENCAP_TYPE:
            result.encap_type = nla_get_u16(nla);
            break;
        case IFLA_GRE_ENCAP_SPORT:
            result.encap_sport = nla_get_u16(nla);
            break;
        case IFLA_GRE_ENCAP_DPORT:
            result.encap_dport = nla_get_u16(nla);
            break;
        default:
            break;
        }
    }

    memcpy((struct gretap_opt *)arg, &result, sizeof(struct gretap_opt));
err:
    return ret;
}

int get_tunnel(struct nl_sock *nl, const char *ifname, struct gretap_opt *opt)
{
    struct nl_msg *msg = NULL;

    int ret = -1;
    if (rtnl_link_build_get_request(0, ifname, &msg) < 0) {
        goto err;
    }
    if (nl_send_auto(nl, msg) < 0) {
        goto err_msg;
    }

    struct nl_cb *cb = nl_cb_alloc(NL_CB_CUSTOM);
    if (cb == NULL) {
        goto err_msg;
    }
    nl_cb_set(cb, NL_CB_VALID, NL_CB_CUSTOM, tunnel_parser, (void *)opt);

    if (nl_recvmsgs(nl, cb) < 0) {
        goto err_cb;
    }
    nl_wait_for_ack(nl);

err_cb:
    nl_cb_put(cb);
err_msg:
    nlmsg_free(msg);
err:
    return ret;
}

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
        goto err;
    }

    ret = rtnl_link_delete(nl, link);

err:
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
        goto err;
    }

    ret = rtnl_link_delete(nl, link);

err:
    nl_cache_free(links);
    return ret;
}

