#!/usr/bin/bash
NETNS_PREFIX="nsc-proj-"

remove_pod_and_ns() {
    if [ $# -lt 1 ]; then
        return 1
    fi
    podman rm -f "$1"
    ip netns delete "${NETNS_PREFIX}$1"
}

remove_pod_and_ns R1 &
remove_pod_and_ns R2 &
remove_pod_and_ns BRG1 &
remove_pod_and_ns BRG2 &
remove_pod_and_ns BRGr &
remove_pod_and_ns h1 &
remove_pod_and_ns h2 &

wait 

ip link delete GWveth

