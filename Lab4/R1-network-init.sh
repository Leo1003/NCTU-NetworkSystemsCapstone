#!/usr/bin/bash
set -e

ip addr add 140.114.0.254/24 dev R1BRG1veth
ip addr add 140.115.0.254/24 dev R1BRG2veth
ip addr add 172.16.0.1/30 dev R1R2veth

ip route add 140.113.0.0/24 via 172.16.0.2

