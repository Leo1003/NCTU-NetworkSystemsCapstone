#!/usr/bin/bash
set -e;

NETNS_PREFIX="nsc-lab4-"
nsattach() {
    if [ $# -lt 1 ]; then
        return 1
    fi
    ip netns attach $NETNS_PREFIX$1 $(podman inspect $1 -f '{{.State.Pid}}')
}

veth_bind_and_up() {
    if [ $# -lt 2 ]; then
        return 1
    fi

    ip link set "$1" netns "${NETNS_PREFIX}$2" &&
    ip netns exec "${NETNS_PREFIX}$2" ip link set "$1" up
}

echo >&2 "[1/9] Starting router containers..."
podman run --network none \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SYS_ADMIN \
    -d \
    --name R1 \
    localhost/nsc-lab4-router &

podman run --network none \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SYS_ADMIN \
    -d \
    --name R2 \
    localhost/nsc-lab4-router &

podman run --network none \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SYS_ADMIN \
    -d \
    --name BRG1 \
    localhost/nsc-lab4-bridge &

podman run --network none \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SYS_ADMIN \
    -d \
    --name BRG2 \
    localhost/nsc-lab4-bridge &

podman run --network none \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SYS_ADMIN \
    -d \
    --name BRGr \
    localhost/nsc-lab4-bridge &

wait

echo >&2 "[2/9] Starting host containers..."
podman run --network none \
    -d \
    --name h1 \
    localhost/nsc-lab-host &

podman run --network none \
    -d \
    --name h2 \
    localhost/nsc-lab-host &

podman run --network none \
    -d \
    --name GWr \
    localhost/nsc-lab-host &

wait

echo >&2 "[3/9] Attaching network namespace..."
nsattach R1 &
nsattach R2 &
nsattach BRG1 &
nsattach BRG2 &
nsattach BRGr &
nsattach h1 &
nsattach h2 &
nsattach GWr &

wait

echo >&2 "[4/9] Adding virtual links..."
ip link add R1R2veth type veth peer name R2R1veth &
ip link add BRG1-eth1 type veth peer name R1BRG1 &
ip link add BRG2-eth1 type veth peer name R1BRG2 &
ip link add BRGr-eth1 type veth peer name R2BRGr &
ip link add h1-eth type veth peer name BRG1-eth0 &
ip link add h2-eth type veth peer name BRG2-eth0 &
ip link add GWr-eth type veth peer name BRGr-eth0 &

wait

echo >&2 "[5/9] Bind virtual links and set to up..."
veth_bind_and_up R1R2veth  "R1" &
veth_bind_and_up R2R1veth  "R2" &
veth_bind_and_up BRG1-eth0 "BRG1" &
veth_bind_and_up BRG1-eth1 "BRG1" &
veth_bind_and_up BRG2-eth0 "BRG2" &
veth_bind_and_up BRG2-eth1 "BRG2" &
veth_bind_and_up BRGr-eth0 "BRGr" &
veth_bind_and_up BRGr-eth1 "BRGr" &
veth_bind_and_up R1BRG1    "R1" &
veth_bind_and_up R1BRG2    "R1" &
veth_bind_and_up R2BRGr    "R2" &
veth_bind_and_up h1-eth    "h1" &
veth_bind_and_up h2-eth    "h2" &
veth_bind_and_up GWr-eth   "GWr" &

wait

echo >&2 "[6/9] Applying static IPs..."
ip netns exec "${NETNS_PREFIX}R1" ip addr add 140.114.0.254/24 dev R1BRG1 &
ip netns exec "${NETNS_PREFIX}R1" ip addr add 140.115.0.254/24 dev R1BRG2 &
ip netns exec "${NETNS_PREFIX}R1" ip addr add 172.16.0.1/30 dev R1R2veth &
ip netns exec "${NETNS_PREFIX}R2" ip addr add 140.113.0.254/24 dev R2BRGr &
ip netns exec "${NETNS_PREFIX}R2" ip addr add 172.16.0.2/30 dev R2R1veth &

ip netns exec "${NETNS_PREFIX}BRG1" ip addr add 140.114.0.1/24 dev BRG1-eth1 &
ip netns exec "${NETNS_PREFIX}BRG2" ip addr add 140.115.0.1/24 dev BRG2-eth1 &
ip netns exec "${NETNS_PREFIX}BRGr" ip addr add 140.113.0.1/24 dev BRGr-eth1 &

ip netns exec "${NETNS_PREFIX}h1" ip addr add 10.0.1.1/24 dev h1-eth &
ip netns exec "${NETNS_PREFIX}h2" ip addr add 10.0.1.2/24 dev h2-eth &
ip netns exec "${NETNS_PREFIX}GWr" ip addr add 10.0.1.254/24 dev GWr-eth &

wait

echo >&2 "[7/9] Configuring routing tables..."
ip netns exec "${NETNS_PREFIX}R1" ip route add 140.113.0.0/24 via 172.16.0.2 &
ip netns exec "${NETNS_PREFIX}R2" ip route add 140.114.0.0/24 via 172.16.0.1 &
ip netns exec "${NETNS_PREFIX}R2" ip route add 140.115.0.0/24 via 172.16.0.1 &
ip netns exec "${NETNS_PREFIX}BRG1" ip route add default via 140.114.0.254 &
ip netns exec "${NETNS_PREFIX}BRG2" ip route add default via 140.115.0.254 &
ip netns exec "${NETNS_PREFIX}BRGr" ip route add default via 140.113.0.254 &

ip netns exec "${NETNS_PREFIX}h1" ip route add default via 10.0.1.254 &
ip netns exec "${NETNS_PREFIX}h2" ip route add default via 10.0.1.254 &

wait

echo >&2 "[8/9] Setup GRE tunnels..."
ip netns exec "${NETNS_PREFIX}BRG1" ip link add GRETAP type gretap remote 140.113.0.1 local 140.114.0.1
ip netns exec "${NETNS_PREFIX}BRG2" ip link add GRETAP type gretap remote 140.113.0.1 local 140.115.0.1

wait

ip netns exec "${NETNS_PREFIX}BRG1" ip link set GRETAP up &
ip netns exec "${NETNS_PREFIX}BRG2" ip link set GRETAP up &

wait

echo >&2 "[9/9] Setup bridges and GRE tunnels..."
ip netns exec "${NETNS_PREFIX}BRG1" ip link add br0 type bridge &
ip netns exec "${NETNS_PREFIX}BRG2" ip link add br0 type bridge &
ip netns exec "${NETNS_PREFIX}BRGr" ip link add br0 type bridge &

wait

ip netns exec "${NETNS_PREFIX}BRG1" ip link set br0 up &
ip netns exec "${NETNS_PREFIX}BRG2" ip link set br0 up &
ip netns exec "${NETNS_PREFIX}BRGr" ip link set br0 up &

wait

ip netns exec "${NETNS_PREFIX}BRG1" ip link set BRG1-eth0 master br0 &
ip netns exec "${NETNS_PREFIX}BRG1" ip link set GRETAP master br0 &
ip netns exec "${NETNS_PREFIX}BRG2" ip link set BRG2-eth0 master br0 &
ip netns exec "${NETNS_PREFIX}BRG2" ip link set GRETAP master br0 &
ip netns exec "${NETNS_PREFIX}BRGr" ip link set BRGr-eth0 master br0 &

wait

