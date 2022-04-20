#!/usr/bin/bash
set -e

ip link add br0 type bridge
ip link set R1BRG1veth master br0
ip link set R1BRG2veth master br0
ip link set br0 up

ip address add 172.27.0.1/24 dev br0
ip address add 140.114.0.1/24 dev R1R2veth

ip route add default via 140.114.0.2

## iptables rules
iptables -t nat -A POSTROUTING -s 172.27.0.0/24 -o R1R2veth -j MASQUERADE

iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 172.27.0.0/24 -j ACCEPT

echo "" > /run/dhcpd.leases

