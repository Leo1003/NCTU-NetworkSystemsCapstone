#!/usr/bin/bash
set -e

# Rename interfaces
ip link set BRGrGWrveth down
ip link set BRGrGWrveth name eth0
ip link set eth0 up
ip link set BRGrR2veth down
ip link set BRGrR2veth name eth1
ip link set eth1 up

# Configure IP & route
ip addr add 140.113.0.1/24 dev eth1
ip route add default via 140.113.0.254

# Add links to bridge
ip link add br0 type bridge
ip link set br0 up
ip link set eth0 master br0

