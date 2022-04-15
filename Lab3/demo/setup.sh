#!/usr/bin/bash
set -e;

NETNS_PREFIX="nsc-lab3-"
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

veth_connect() {
    if [ $# -lt 2 ]; then
        return 1
    fi

    local link1="$1$2veth"
    local link2="$2$1veth"

    ip link add "$link1" type veth peer name "$link2"
    veth_bind_and_up "$link1" "$1"
    veth_bind_and_up "$link2" "$2"
}

create_router_container() {
    if [ $# -lt 1 ]; then
        return 1
    fi

    podman run --network none \
        --cap-add NET_ADMIN \
        --cap-add NET_RAW \
        --cap-add SYS_ADMIN \
        -d \
        --name "$1" \
        --mount type=bind,src="$1-bgpd.conf",dst=/etc/quagga/bgpd.conf,ro=true \
        --mount type=bind,src="$1-zebra.conf",dst=/etc/quagga/zebra.conf,ro=true \
        --mount type=bind,src="$1-network-init.sh",dst=/usr/bin/nsc-network-init,ro=true \
        localhost/nsc-lab3-router
}

create_host_container() {
    if [ $# -lt 1 ]; then
        return 1
    fi

    podman run --network none \
        --cap-add NET_ADMIN \
        -d \
        --name "$1" \
        --mount type=bind,src="$1-network-init.sh",dst=/usr/bin/nsc-network-init,ro=true \
        localhost/nsc-lab-host
}

echo >&2 "[1/5] Starting router containers..."
create_router_container R1 &
create_router_container R2 &
create_router_container R3 &
create_router_container R4 &

wait

echo >&2 "[2/5] Starting host containers..."
create_host_container h1
create_host_container h2
create_host_container h3
create_host_container h4

wait

echo >&2 "[3/5] Attaching network namespace..."
nsattach R1 &
nsattach R2 &
nsattach R3 &
nsattach R4 &
nsattach h1 &
nsattach h2 &
nsattach h3 &
nsattach h4 &

wait

echo >&2 "[4/5] Create veth links..."
veth_connect "R1" "h1" &
veth_connect "R2" "h2" &
veth_connect "R3" "h3" &
veth_connect "R4" "h4" &
veth_connect "R1" "R2" &
veth_connect "R2" "R4" &
veth_connect "R4" "R3" &
veth_connect "R3" "R1" &

wait

echo >&2 "[5/5] Send signal to run network initialize script..."
podman kill -s USR1 R1 &
podman kill -s USR1 R2 &
podman kill -s USR1 R3 &
podman kill -s USR1 R4 &
podman kill -s USR1 h1 &
podman kill -s USR1 h2 &
podman kill -s USR1 h3 &
podman kill -s USR1 h4 &

wait

