#!/usr/bin/bash
set -e

# Configure IP & route
ip addr add 140.113.0.1/24 dev eth1
ip route add default via 140.113.0.254

# Add links to bridge
ip link add br0 type bridge
ip link set br0 up
ip link set eth0 master br0

