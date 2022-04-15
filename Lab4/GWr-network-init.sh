#!/usr/bin/bash
set -e

ip link set GWrBRGrveth down
ip link set GWrBRGrveth name eth0
ip link set eth0 up

ip addr add 10.0.1.254/24 dev eth0

