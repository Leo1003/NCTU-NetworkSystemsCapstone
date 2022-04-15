#!/usr/bin/bash
set -e

ip addr add 172.22.0.3/24 dev h4R4veth
ip route add default via 172.22.0.2

