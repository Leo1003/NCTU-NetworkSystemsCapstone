#!/usr/bin/bash
set -e

ip addr add 172.20.0.2/24 dev R2h2veth
ip addr add 172.16.0.2/30 dev R2R1veth
ip addr add 172.16.0.5/30 dev R2R4veth

