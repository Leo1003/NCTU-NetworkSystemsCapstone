#!/usr/bin/bash
set -e

# Configure IP & route
ip addr add 140.114.0.1/24 dev eth1
ip route add default via 140.114.0.254

# Setup GRETAP
ip link add GRETAP type gretap remote 140.113.0.1 local 140.114.0.1
ip link set GRETAP up

# Add links to bridge
ip link add br0 type bridge
ip link set br0 up
ip link set eth0 master br0
ip link set GRETAP master br0

