#!/bin/bash -e
# Common functions

function route_to_subnetpool {
    # Neutron no longer sets route to the created net:
    # https://github.com/openstack-dev/devstack/commit/1493bdeba24674f6634160d51b8081c571df4017
    # Add/replace it here for ease of use
    local ROUTER=$(openstack router list -f value -c ID)
    # No router
    if [ -z "${ROUTER}" ]; then
        return
    fi
    # No namespace (different node?)
    if ! sudo ip netns list | grep -q qrouter-"${ROUTER}"; then
        return
    fi

    local NET_GATEWAY=$(sudo ip netns exec qrouter-"${ROUTER}" ip -4 route get 8.8.8.8 | head -n1 | awk '{print $7}')
    # Filter IPv6 pool out
    local SUBNET_POOL=$(openstack subnet pool list -f value -c Prefixes | grep -v :)

    sudo ip route replace "${SUBNET_POOL}" via "${NET_GATEWAY}"
}

function nsh_sf_image_setup {
    SF_IMAGE="sfc_nsh"
    (
        if [[ -e ~/devstack/openrc ]]; then
           echo "Sourcing devstack admin credentials"
           source ~/devstack/openrc admin admin
        else
           echo "Could not find any credentials file"
           exit 1
        fi

        curl -o /tmp/sfc_nsh_fraser.qcow2 "http://artifacts.opnfv.org/sfc/images/sfc_nsh_fraser.qcow2"
        openstack image create $SF_IMAGE --file /tmp/sfc_nsh_fraser.qcow2 --disk-format qcow2 --container-format bare --public
    )
}
