#!/usr/bin/bash
set -e

ip addr add 172.21.0.3/24 dev h3R3veth
ip route add default via 172.21.0.2

