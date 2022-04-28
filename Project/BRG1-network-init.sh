#!/usr/bin/bash
set -e
IPV4_REGEX='[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*'

# Configure IP & route
dhclient -4 -v eth1
dhclient -4 -v eth2
eth1_ip="$(ip -o addr show dev eth1 | grep -o "inet $IPV4_REGEX" | grep -o "$IPV4_REGEX")"
eth2_ip="$(ip -o addr show dev eth2 | grep -o "inet $IPV4_REGEX" | grep -o "$IPV4_REGEX")"

# Setup GRETAP
ip link add gretap1 type gretap \
    remote 140.113.0.2 \
    local $eth1_ip \
    key 20.255.1.1 \
    encap fou \
    encap-sport 50056 \
    encap-dport 5555
ip link set gretap1 up
ip link add gretap2 type gretap \
    remote 140.113.0.3 \
    local $eth2_ip \
    key 20.255.2.1 \
    encap fou \
    encap-sport 50057 \
    encap-dport 5555
ip link set gretap2 up
ip fou add port 50056 ipproto 47
ip fou add port 50057 ipproto 47

# Start ovs server
ovsdb-server --detach --remote=punix:/var/run/openvswitch/db.sock
ovs-vswitchd --detach

# Add links to bridge
ovs-vsctl add-br br0
ovs-vsctl set bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14
ip link set br0 up
ovs-vsctl add-port br0 eth0
ovs-vsctl add-port br0 gretap1
ovs-vsctl add-port br0 gretap2
ovs-vsctl set-fail-mode br0 standalone

# OpenFlow setup
ovs-ofctl add-group br0 group_id=1,type=fast_failover,bucket=watch_port:gretap1,output:gretap1,bucket=watch_port:gretap2,output:gretap2
ovs-ofctl -O OpenFlow14 add-meter br0 meter=1,kbps,band=type=drop,rate=1000

ovs-ofctl -O OpenFlow14 add-flow br0 in_port=eth0,actions=meter:1,group:1
ovs-ofctl -O OpenFlow14 add-flow br0 in_port=gretap1,actions=meter:1,output:eth0
ovs-ofctl -O OpenFlow14 add-flow br0 in_port=gretap2,actions=meter:1,output:eth0

## Original Linux bridge
#ip link add br0 type bridge
#ip link set br0 up
#ip link set eth0 master br0
#ip link set gretap1 master br0

