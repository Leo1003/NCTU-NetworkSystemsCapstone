#!/usr/bin/bash
set -e

ip link set h1BRG1veth down
ip link set h1BRG1veth name eth0
ip link set eth0 up

ip addr add 10.0.1.1/24 dev eth0
ip route add default via 10.0.1.254

