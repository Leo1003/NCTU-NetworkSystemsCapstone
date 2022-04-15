#!/usr/bin/bash
set -e

ip addr add 172.20.0.3/24 dev h2R2veth
ip route add default via 172.20.0.2

