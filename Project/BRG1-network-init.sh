#!/usr/bin/bash
set -e
#IPV4_REGEX='[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*'

# Configure IP & route
dhclient -4 -v eth1
#ipaddr="$(ip -o addr show dev eth1 | grep -o "inet $IPV4_REGEX" | grep -o "$IPV4_REGEX")"

# Setup GRETAP
ip link add gretap1 type gretap \
    remote 140.113.0.2 \
    local any \
    encap fou \
    encap-sport 50056 \
    encap-dport 5555
ip link set gretap1 up
ip fou add port 50056 ipproto 47

# Add links to bridge
ip link add br0 type bridge
ip link set br0 up
ip link set eth0 master br0
ip link set gretap1 master br0

