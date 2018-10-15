#!/bin/bash -e


if [[ -e ~/devstack/openrc ]]; then
    echo "Sourcing devstack admin credentials"
    source ~/devstack/openrc admin admin
else
    echo "Could not find any credentials file"
    exit 1
fi

curl -o /tmp/ubuntu.img "http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-uefi1.img"
openstack image create "ubuntu" --file /tmp/ubuntu.img --disk-format qcow2 --container-format bare --public
