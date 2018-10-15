#!/bin/bash -e


if [[ -e ~/devstack/openrc ]]; then
    echo "Sourcing devstack admin credentials"
    source ~/devstack/openrc admin admin
else
    echo "Could not find any credentials file"
    exit 1
fi
GATEWAY_IP=$(openstack subnet show public-subnet -c gateway_ip -f value)
EXTERNAL_IF=$(ip route get ${GATEWAY_IP} | head -n1 | awk '{print $3}')
[ "${EXTERNAL_IF}" = "br-ex" ] && return
EXTERNAL_IP=$(ip -br add show ${EXTERNAL_IF} | awk '{print $3}')
sudo ip addr del ${EXTERNAL_IP} dev ${EXTERNAL_IF}
sudo ip addr add ${EXTERNAL_IP} dev br-ex
sudo ovs-vsctl add-port br-ex ${EXTERNAL_IF}
sudo ip link set br-ex up

