#!/usr/bin/bash
set -e

ip address add 140.113.0.1/24 dev R2BRGrveth
ip address add 140.114.0.2/24 dev R2R1veth

