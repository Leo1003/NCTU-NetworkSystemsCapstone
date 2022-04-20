#!/usr/bin/bash
NETNS_PREFIX="nsc-proj-"

remove_pod_and_ns() {
    if [ $# -lt 1 ]; then
        return 1
    fi
    ip netns delete "${NETNS_PREFIX}$1"
    podman rm -f "$1"
}

remove_pod_and_ns R1 &
remove_pod_and_ns R2 &
remove_pod_and_ns BRG1 &
remove_pod_and_ns BRG2 &
remove_pod_and_ns BRGr &
remove_pod_and_ns h1 &
remove_pod_and_ns h2 &

wait 

iptables -D FORWARD -s 20.0.1.0/24 -j ACCEPT
iptables -t nat -D POSTROUTING -s 20.0.1.0/24 -o ens192 -j MASQUERADE

kill $(cat /run/nsc-proj-dhcpd.pid) \
    && rm /run/nsc-proj-dhcpd.pid
ip link delete GWveth

