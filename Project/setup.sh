#!/usr/bin/bash
set -e;

NETNS_PREFIX="nsc-proj-"
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
    local ifname="$1"
    if [ "$2" != "_" ]; then
        # netns is not set to host
        local netns="${NETNS_PREFIX}$2"
    fi
    local newifname="$3"

    if [ -n "$netns" ]; then
        ip link set "$ifname" netns "$netns"
        if [ -n "$newifname" ]; then
            ip -netns "$netns" link set "$ifname" name "$newifname"
            local ifname="$newifname"
        fi
        ip -netns "$netns" link set "$ifname" up
    else
        if [ -n "$newifname" ]; then
            ip link set "$ifname" name "$newifname"
            local ifname="$newifname"
        fi
        ip link set "$ifname" up
    fi
}

veth_connect() {
    if [ $# -lt 2 ]; then
        return 1
    fi

    local h1="${1#*@}"
    local h1ifname="${1%"$h1"}"
    local h1ifname="${h1ifname%@*}"
    local h2="${2#*@}"
    local h2ifname="${2%"$h2"}"
    local h2ifname="${h2ifname%@*}"

    local veth1="${h1}${h2}veth"
    local veth2="${h2}${h1}veth"

    ip link add "$veth1" type veth peer name "$veth2"
    veth_bind_and_up "$veth1" "$h1" "$h1ifname"
    veth_bind_and_up "$veth2" "$h2" "$h2ifname"
}

create_router_container() {
    if [ $# -lt 1 ]; then
        return 1
    fi
    local name="$1"
    shift

    podman run --network none \
        --cap-add NET_ADMIN \
        --cap-add NET_RAW \
        --cap-add SYS_ADMIN \
        -d \
        --name "$name" \
        --mount type=bind,src="$name-network-init.sh",dst=/usr/bin/nsc-network-init,ro=true \
        localhost/nsc-proj-router \
        "$@"
}

create_edge_router_container() {
    if [ $# -lt 1 ]; then
        return 1
    fi
    local name="$1"
    shift

    podman run --network none \
        --cap-add NET_ADMIN \
        --cap-add NET_RAW \
        --cap-add SYS_ADMIN \
        -d \
        --name "$name" \
        --mount type=bind,src="$name-network-init.sh",dst=/usr/bin/nsc-network-init,ro=true \
        --mount type=bind,src="$name-dhcpd.conf",dst=/etc/dhcpd.conf,ro=true \
        localhost/nsc-proj-router \
        "$@"
}

create_bridge_container() {
    if [ $# -lt 1 ]; then
        return 1
    fi
    local name="$1"
    shift

    podman run --network none \
        --cap-add NET_ADMIN \
        --cap-add NET_RAW \
        --cap-add SYS_ADMIN \
        -d \
        --name "$name" \
        --mount type=bind,src="$name-network-init.sh",dst=/usr/bin/nsc-network-init,ro=true \
        localhost/nsc-proj-bridge \
        "$@"
}

create_host_container() {
    if [ $# -lt 1 ]; then
        return 1
    fi
    local name="$1"
    shift

    podman run --network none \
        --cap-add NET_ADMIN \
        --cap-add NET_RAW \
        -d \
        --name "$name" \
        --mount type=bind,src="$name-network-init.sh",dst=/usr/bin/nsc-network-init,ro=true \
        localhost/nsc-lab-host \
        "$@"
}

echo >&2 "[1/6] Starting router containers..."
create_edge_router_container R1 dhcpd -4 -cf /etc/dhcpd.conf -pf /run/dhcpd.pid -lf /run/dhcpd.leases -f -d br0 &
create_router_container R2 &
create_bridge_container BRG1 &
create_bridge_container BRG2 &
create_bridge_container BRGr valgrind --leak-check=full dygrefou eth1 br0 &

wait

echo >&2 "[2/6] Starting host containers..."
create_host_container h1 &
create_host_container h2 &

wait

echo >&2 "[3/6] Attaching network namespace..."
nsattach R1 &
nsattach R2 &
nsattach BRG1 &
nsattach BRG2 &
nsattach BRGr &
nsattach h1 &
nsattach h2 &

wait

echo >&2 "[4/6] Create veth links..."
veth_connect "R1" "R2" &
veth_connect "R1" "eth1@BRG1" &
veth_connect "R1" "eth1@BRG2" &
veth_connect "R2" "eth1@BRGr" &
veth_connect "eth0@BRG1" "eth0@h1" &
veth_connect "eth0@BRG2" "eth0@h2" &
veth_connect "eth0@BRGr" "GWveth@_" &

wait

echo >&2 "[5/6] Send signal to run network initialize script..."
podman kill -s USR1 R1 &
podman kill -s USR1 R2 &
podman kill -s USR1 BRG1 &
podman kill -s USR1 BRG2 &
podman kill -s USR1 BRGr &
podman kill -s USR1 h1 &
podman kill -s USR1 h2 &

wait

echo >&2 "[6/6] Setup host network interfaces..."

ip address add 20.0.1.254/24 dev GWveth
touch /run/nsc-proj-dhcpd.leases
dhcpd -4 -cf Host-dhcpd.conf -pf /run/nsc-proj-dhcpd.pid -lf /run/nsc-proj-dhcpd.leases GWveth

iptables -t nat -A POSTROUTING -s 20.0.1.0/24 -o ens192 -j MASQUERADE
iptables -A FORWARD -s 20.0.1.0/24 -j ACCEPT

