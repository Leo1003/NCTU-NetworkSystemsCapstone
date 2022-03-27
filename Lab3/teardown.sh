#!/usr/bin/bash
NETNS_PREFIX="nsc-lab3-"

podman rm -f R1 &
podman rm -f R2 &
podman rm -f h1 &
podman rm -f h2 &
podman rm -f hR &

wait 

ip netns delete "${NETNS_PREFIX}R1" &
ip netns delete "${NETNS_PREFIX}R2" &
ip netns delete "${NETNS_PREFIX}h1" &
ip netns delete "${NETNS_PREFIX}h2" &
ip netns delete "${NETNS_PREFIX}hR" &

wait

