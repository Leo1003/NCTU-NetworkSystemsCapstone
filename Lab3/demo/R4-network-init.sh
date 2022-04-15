#!/usr/bin/bash
set -e

ip addr add 172.22.0.2/24 dev R4h4veth
ip addr add 172.16.0.6/30 dev R4R2veth
ip addr add 172.16.0.9/30 dev R4R3veth

