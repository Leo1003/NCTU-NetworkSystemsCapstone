#!/usr/bin/bash
set -e

ip addr add 172.19.0.3/24 dev h1R1veth
ip route add default via 172.19.0.2

