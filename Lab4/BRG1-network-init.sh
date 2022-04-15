#!/usr/bin/bash
set -e

# Rename interfaces
ip link set BRG1h1veth down
ip link set BRG1h1veth name eth0
ip link set eth0 up
ip link set BRG1R1veth down
ip link set BRG1R1veth name eth1
ip link set eth1 up

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

