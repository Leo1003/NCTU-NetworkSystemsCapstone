#!/usr/bin/bash
set -e

ip addr add 10.0.1.2/24 dev eth0
ip route add default via 10.0.1.254

