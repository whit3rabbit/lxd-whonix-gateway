#!/bin/bash
# For debian based system

# Why root...because I tested it on root?
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

#################################################################
# Install/Setup lxd
#################################################################
sudo apt update && sudo apt install lxd git wget zfsutils-linux
sudo adduser $USER lxd
newgrp lxd

#################################################################
# Download/ Setup Whonix image/metadata
#################################################################
wget https://github.com/whit3rabbit/lxd-whonix-gateway/releases/download/v15.0/47d6dc01aac13b047214574190ad135df72f486f512dba0e0c598c90fdd2dd2a.squashfs -O /tmp/rootfs.squashfs
wget https://github.com/whit3rabbit/lxd-whonix-gateway/releases/download/v15.0/meta-47d6dc01aac13b047214574190ad135df72f486f512dba0e0c598c90fdd2dd2a.tar.xz -O /tmp/metadata.tar.xz

# Import Whonix Image
lxc image import /tmp/metadta.tar.xz /tmp/rootfs.squashfs --alias whonix-gateway-cli

# Get templates
cd ~
wget https://raw.githubusercontent.com/whit3rabbit/lxd-whonix-gateway/master/whonix-profile-client.yml 
wget https://raw.githubusercontent.com/whit3rabbit/lxd-whonix-gateway/master/whonix-profile-gateway.yml

# Create bridge network with Whonix IP space/gateway (eth0):
lxc network create whonixbr0 ipv4.address=10.0.2.2/24 ipv4.nat=true ipv6.address=none

# Create a bridge network for client IP space (eth1):
lxc network create whonixbr1 ipv4.address=10.152.152.0/18 ipv4.nat=true ipv4.dhcp.gateway=10.152.152.10 ipv6.address=none

# List networks for troubleshooting
lxc network list

# Create a network profile to use the bridge (whonixbr0):

lxc profile create whonix-profile-gateway
cat whonix-profile-gateway.yml | lxc profile edit whonix-profile-gateway

# Network profile for the client bridge (whonixbr1):

lxc profile create whonix-profile-client
cat whonix-profile-client.yml | lxc profile edit whonix-profile-client

# Create your first container named whgw1 from image and assign the network profile "whonix-gateway":
lxc launch whonix-gateway-cli whgw1 && lxc stop whgw1 && lxc profile assign whgw1 whonix-profile-gateway

# Start container:
lxc start whgw1

# Start connection to TOR ( this has to be done manually/interactively) until I can figure something out.. 
# https://github.com/Whonix/whonixsetup/blob/master/usr/bin/whonixsetup
lxc exec whgw1 -- whonixsetup

# Update whonix
lxc exec whgw1 -- apt-get-update-plus -y dist-upgrade

# List lxc containers running
lxc list

#################################################################
# Setup VPN
#################################################################
lxc launch images:debian/buster debian-vpn
lxc stop debian-vpn
lxc profile assign debian-vpn whonix-profile-client
lxc start debian-vpn

# Set DNS server to Whonix gateway in ubuntu box
lxc exec debian-vpn -- echo "nameserver 10.152.152.10" > /etc/resolv.conf

# Give VPN privilege
lxc config set debian-vpn security.privileged true

# Update image and install curl
lxc exec debian-vpn -- apt-get update && apt-get upgrade -y && apt-get install -y curl

# Check if TOR is working
lxc exec debian-vpn -- curl -s https://check.torproject.org/ | cat | grep -m 1 Congratulations | xargs

# Download openvpn install script
lxc exec debian-vpn -- curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
lxc exec debian-vpn -- chmod +x openvpn-install.sh

# Install openvpn. Change auto install if you want custom ports
lxc exec --env AUTO_INSTALL=y debian-vpn -- ./openvpn-install.sh

# Copy client.openvpn file
lxc exec debian-vpn -- cat /root/client.ovpn > client.ovpn

# Because we use TOR, cloudflare doesn't like that we look for IP

PUBLIC_IP=`curl ipinfo.io/ip`
echo "Modify client.ovpn file with your public IP: ${PUBLIC_IP}"

# Get Debian-VPN IP
DEBIAN-VPN-IP=`lxc list debian-vpn --format csv | grep eth0 | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"`

# Get VPN port for VPS
echo "What port should VPS listen on for VPN server (1 through 65535): "
read VPNPORT

iptables -t nat -A PREROUTING -p udp --dport ${VPNPORT} -j DNAT --to-destination ${DEBIAN-VPN-IP}:1194
iptables -t nat -A POSTROUTING -j MASQUERADE

echo "All finished!"
echo "Modify remote/port line in client.ovpn with: remote ${PUBLIC_IP} ${VPNPORT}"
echo "To stop/start LXC containers:"
echo "Debian VPN container: lxc stop debian-vpn && lxc start debian-vpn"
echo "Whonix Gateway: lxc stop whgw1 && lxc start whgw1"

#################################################################
# Cleanup
#################################################################
rm -f /tmp/metadata.tar.xz
rm -f /tmp/rootfs.squashfs
rm -f ~/whonix-profile-client.yml 
rm -f ~/whonix-profile-gateway.yml