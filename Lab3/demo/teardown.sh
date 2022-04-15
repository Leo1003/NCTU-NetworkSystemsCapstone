#!/usr/bin/bash
NETNS_PREFIX="nsc-lab3-"

podman rm -f R1 &
podman rm -f R2 &
podman rm -f R3 &
podman rm -f R4 &
podman rm -f h1 &
podman rm -f h2 &
podman rm -f h3 &
podman rm -f h4 &

wait

ip netns delete "${NETNS_PREFIX}R1" &
ip netns delete "${NETNS_PREFIX}R2" &
ip netns delete "${NETNS_PREFIX}R3" &
ip netns delete "${NETNS_PREFIX}R4" &
ip netns delete "${NETNS_PREFIX}h1" &
ip netns delete "${NETNS_PREFIX}h2" &
ip netns delete "${NETNS_PREFIX}h3" &
ip netns delete "${NETNS_PREFIX}h4" &

wait

