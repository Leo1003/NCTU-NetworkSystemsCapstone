#!/usr/bin/bash
set -e

ip addr add 172.19.0.2/24 dev R1h1veth
ip addr add 172.16.0.1/30 dev R1R2veth
ip addr add 172.16.0.14/30 dev R1R3veth

