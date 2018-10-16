#!/bin/bash -e


if [[ -e ~/devstack/openrc ]]; then
    echo "Sourcing devstack admin credentials"
    source ~/devstack/openrc admin admin
else
    echo "Could not find any credentials file"
    exit 1
fi

curl -o /tmp/ubuntu.img "http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-uefi1.img"
curl -o /tmp/sfc_nsh_fraser.qcow2 "http://artifacts.opnfv.org/sfc/images/sfc_nsh_fraser.qcow2"
openstack image create "sfc_nsh" --file /tmp/sfc_nsh_fraser.qcow2 --disk-format qcow2 --container-format bare --public
