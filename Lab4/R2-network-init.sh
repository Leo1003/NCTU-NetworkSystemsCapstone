#!/usr/bin/bash
set -e

ip addr add 140.113.0.254/24 dev R2BRGrveth
ip addr add 172.16.0.2/30 dev R2R1veth

ip route add 140.114.0.0/24 via 172.16.0.1
ip route add 140.115.0.0/24 via 172.16.0.1

