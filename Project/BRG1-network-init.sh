#!/usr/bin/bash
set -e
#IPV4_REGEX='[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*'

# Configure IP & route
dhclient -4 -v eth1
#ipaddr="$(ip -o addr show dev eth1 | grep -o "inet $IPV4_REGEX" | grep -o "$IPV4_REGEX")"

# Setup GRETAP
ip link add gretap1 type gretap \
    remote 140.113.0.2 \
    local any \
    key 20.255.1.1 \
    encap fou \
    encap-sport 50056 \
    encap-dport 5555
ip link set gretap1 up
ip fou add port 50056 ipproto 47

# Start ovs server
ovsdb-server --detach --remote=punix:/var/run/openvswitch/db.sock
ovs-vswitchd --detach

# Add links to bridge
ovs-vsctl add-br br0
ovs-vsctl set bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,
ip link set br0 up
ovs-vsctl add-port br0 eth0
ovs-vsctl add-port br0 gretap1
ovs-vsctl set-fail-mode br0 standalone
ovs-ofctl -O OpenFlow14 add-meter br0 meter=1,kbps,band=type=drop,rate=1000
ovs-ofctl -O OpenFlow14 add-flow br0 actions=meter:1,normal

## Original Linux bridge
#ip link add br0 type bridge
#ip link set br0 up
#ip link set eth0 master br0
#ip link set gretap1 master br0

