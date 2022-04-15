#!/usr/bin/bash
set -e

ip link set h2BRG2veth down
ip link set h2BRG2veth name eth0
ip link set eth0 up

ip addr add 10.0.1.2/24 dev eth0
ip route add default via 10.0.1.254

