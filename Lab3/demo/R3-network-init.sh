#!/usr/bin/bash
set -e

ip addr add 172.21.0.2/24 dev R3h3veth
ip addr add 172.16.0.10/30 dev R3R4veth
ip addr add 172.16.0.13/30 dev R3R1veth

