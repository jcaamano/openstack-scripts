#!/bin/bash -e
# Creates some instances for networking-sfc demo/development:
# a web server, another instance to use as client
# three "service VMs" with two interface that will just route the packets to/from each interface

. $(dirname "${BASH_SOURCE}")/custom.sh
. $(dirname "${BASH_SOURCE}")/tools.sh

# Disable port security (else packets would be rejected when exiting the service VMs)
openstack network set --disable-port-security "${PRIV_NETWORK}"

# Create network ports for all VMs
for port in p1in p1out p2in p2out p3in p3out source_vm_port dest_vm_port
do
    openstack port create --network "${PRIV_NETWORK}" "${port}"
done

SF_IMAGE="sfc_nsh"

# SFC VMs
openstack server create --image "${SF_IMAGE}" --flavor "${FLAVOR}" \
    --nic port-id="$(openstack port show -f value -c id p1in)" \
    --nic port-id="$(openstack port show -f value -c id p1out)" \
    --key-name "${SSH_KEYNAME}" vm1
openstack server create --image "${SF_IMAGE}" --flavor "${FLAVOR}" \
    --nic port-id="$(openstack port show -f value -c id p2in)" \
    --nic port-id="$(openstack port show -f value -c id p2out)" \
    --key-name "${SSH_KEYNAME}" vm2
openstack server create --image "${SF_IMAGE}" --flavor "${FLAVOR}" \
    --nic port-id="$(openstack port show -f value -c id p3in)" \
    --nic port-id="$(openstack port show -f value -c id p3out)" \
    --key-name "${SSH_KEYNAME}" vm3

# Demo VMs
openstack server create --image "${IMAGE}" --flavor "${FLAVOR}" \
    --nic port-id="$(openstack port show -f value -c id source_vm_port)" \
    --key-name "${SSH_KEYNAME}" source_vm
openstack server create --image "${IMAGE}" --flavor "${FLAVOR}" \
    --nic port-id="$(openstack port show -f value -c id dest_vm_port)" \
    --key-name "${SSH_KEYNAME}" dest_vm

# Floating IPs
SOURCE_FLOATING=$(openstack floating ip create "${PUB_NETWORK}" -f value -c floating_ip_address)
openstack server add floating ip source_vm ${SOURCE_FLOATING}
DEST_FLOATING=$(openstack floating ip create "${PUB_NETWORK}" -f value -c floating_ip_address)
openstack server add floating ip dest_vm ${DEST_FLOATING}
for i in 1 2 3; do
    floating_ip=$(openstack floating ip create --port p${i}in "${PUB_NETWORK}" -f value -c floating_ip_address)
    declare VM${i}_FLOATING=${floating_ip}
done

# HTTP Flow classifier (catch the web traffic from source_vm to dest_vm)
SOURCE_IP=$(openstack port show source_vm_port -f value -c fixed_ips | grep "ip_address='[0-9]*\." | cut -d"'" -f2)
DEST_IP=$(openstack port show dest_vm_port -f value -c fixed_ips | grep "ip_address='[0-9]*\." | cut -d"'" -f2)
openstack sfc flow classifier create \
    --ethertype IPv4 \
    --source-ip-prefix ${SOURCE_IP}/32 \
    --destination-ip-prefix ${DEST_IP}/32 \
    --protocol tcp \
    --destination-port 80:80 \
    --logical-source-port source_vm_port \
    FC_http

# UDP flow classifier (catch all UDP traffic from source_vm to dest_vm, like traceroute)
openstack sfc flow classifier create \
    --ethertype IPv4 \
    --source-ip-prefix ${SOURCE_IP}/32 \
    --destination-ip-prefix ${DEST_IP}/32 \
    --protocol udp \
    --logical-source-port source_vm_port \
    FC_udp

# Create the port pairs for all 3 VMs
openstack sfc port pair create --ingress=p1in --egress=p1out PP1
openstack sfc port pair create --ingress=p2in --egress=p2out PP2
openstack sfc port pair create --ingress=p3in --egress=p3out PP3

# And the port pair groups
openstack sfc port pair group create --port-pair PP1 PG1
openstack sfc port pair group create --port-pair PP2 PG2
openstack sfc port pair group create --port-pair PP3 PG3

# The complete chain
openstack sfc port chain create --port-pair-group PG1 --port-pair-group PG2 --flow-classifier FC_udp --flow-classifier FC_http PC1

# Start a basic demo web server
ssh cirros@${DEST_FLOATING} 'while true; do echo -e "HTTP/1.0 200 OK\r\n\r\nWelcome to $(hostname)" | sudo nc -l -p 80 ; done&'

# Get vxlan_tool from ODL SFC project
VT_URL="https://raw.githubusercontent.com/opendaylight/sfc/master/sfc-test/nsh-tools/vxlan_tool.py"
curl --silent "${VT_URL}" --output vxlan_tool.py

# On service VMs, enable eth1 interface and start vxlan tool
for i in 1 2 3
do
    ip_name=VM${i}_FLOATING
    sshpass -p opnfv ssh -T root@${!ip_name} <<EOF
python /root/vxlan_tool.py --do forward --interface eth0 --output eth1 --verbose off &
python /root/vxlan_tool.py --do forward --interface eth1 --output eth0 --verbose off &

EOF
done
