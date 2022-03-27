#!/usr/bin/bash
set -e;

NETNS_PREFIX="nsc-lab3-"
nsattach() {
    if [ $# -lt 1 ]; then
        return 1
    fi
    ip netns attach $NETNS_PREFIX$1 $(podman inspect $1 -f '{{.State.Pid}}')
}

echo >&2 "[1/8] Starting router containers..."
podman run --network none \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SYS_ADMIN \
    -d \
    --name R1 \
    --mount type=bind,src=R1-bgpd.conf,dst=/etc/quagga/bgpd.conf,ro=true \
    --mount type=bind,src=R1-zebra.conf,dst=/etc/quagga/zebra.conf,ro=true \
    --mount type=bind,src=R1-iptables.rules,dst=/etc/iptables/rules.v4,ro=true \
    localhost/nsc-lab3-router &

podman run --network none \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SYS_ADMIN \
    -d \
    --name R2 \
    --mount type=bind,src=R2-bgpd.conf,dst=/etc/quagga/bgpd.conf,ro=true \
    --mount type=bind,src=R2-zebra.conf,dst=/etc/quagga/zebra.conf,ro=true \
    --mount type=bind,src=R2-iptables.rules,dst=/etc/iptables/rules.v4,ro=true \
    localhost/nsc-lab3-router &

wait

echo >&2 "[2/8] Starting host containers..."
podman run --network none \
    -d \
    --name h1 \
    localhost/nsc-lab3 &

podman run --network none \
    -d \
    --name h2 \
    localhost/nsc-lab3 &

podman run --network none \
    -d \
    --name hR \
    localhost/nsc-lab3 &

wait

echo >&2 "[3/8] Attaching network namespace..."
nsattach R1 &
nsattach R2 &
nsattach h1 &
nsattach h2 &
nsattach hR &

wait

echo >&2 "[4/8] Adding virtual links..."
ip link add R1h1veth type veth peer name h1R1veth &
ip link add R1h2veth type veth peer name h2R1veth &
ip link add R1R2veth type veth peer name R2R1veth &
ip link add R2hRveth type veth peer name hRR2veth &

wait

echo >&2 "[5/8] Connecting networks..."
ip link set R1R2veth netns "${NETNS_PREFIX}R1" &
ip link set R2R1veth netns "${NETNS_PREFIX}R2" &
ip link set R1h1veth netns "${NETNS_PREFIX}R1" &
ip link set h1R1veth netns "${NETNS_PREFIX}h1" &
ip link set R1h2veth netns "${NETNS_PREFIX}R1" &
ip link set h2R1veth netns "${NETNS_PREFIX}h2" &
ip link set R2hRveth netns "${NETNS_PREFIX}R2" &
ip link set hRR2veth netns "${NETNS_PREFIX}hR" &

wait

echo >&2 "[6/8] Bring up virtual links"
ip netns exec "${NETNS_PREFIX}R1" ip link set R1h1veth up &
ip netns exec "${NETNS_PREFIX}R1" ip link set R1h2veth up &
ip netns exec "${NETNS_PREFIX}R1" ip link set R1R2veth up &
ip netns exec "${NETNS_PREFIX}R2" ip link set R2R1veth up &
ip netns exec "${NETNS_PREFIX}R2" ip link set R2hRveth up &

ip netns exec "${NETNS_PREFIX}h1" ip link set h1R1veth up &
ip netns exec "${NETNS_PREFIX}h2" ip link set h2R1veth up &
ip netns exec "${NETNS_PREFIX}hR" ip link set hRR2veth up &

wait

echo >&2 "[7/8] Applying static IPs..."
ip netns exec "${NETNS_PREFIX}R1" ip addr add 192.168.1.254/24 dev R1h1veth &
ip netns exec "${NETNS_PREFIX}R1" ip addr add 192.168.2.254/24 dev R1h2veth &
ip netns exec "${NETNS_PREFIX}R1" ip addr add 140.113.2.1/24 dev R1R2veth &
#ip netns exec "${NETNS_PREFIX}R1" ip addr add 140.113.2.30/24 dev R1R2veth &
#ip netns exec "${NETNS_PREFIX}R1" ip addr add 140.113.2.40/24 dev R1R2veth &
ip netns exec "${NETNS_PREFIX}R2" ip addr add 140.113.1.1/24 dev R2hRveth &
ip netns exec "${NETNS_PREFIX}R2" ip addr add 140.113.2.254/24 dev R2R1veth &

ip netns exec "${NETNS_PREFIX}h1" ip addr add 192.168.1.1/24 dev h1R1veth &
ip netns exec "${NETNS_PREFIX}h2" ip addr add 192.168.2.1/24 dev h2R1veth &
ip netns exec "${NETNS_PREFIX}hR" ip addr add 140.113.1.2/24 dev hRR2veth &

wait

echo >&2 "[8/8] Reconfiguring gateway..."
ip netns exec "${NETNS_PREFIX}h1" ip route add default via 192.168.1.254 &
ip netns exec "${NETNS_PREFIX}h2" ip route add default via 192.168.2.254 &
ip netns exec "${NETNS_PREFIX}hR" ip route add default via 140.113.1.1 &

wait

