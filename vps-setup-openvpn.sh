#!/bin/bash
#
# For debian based system (tested on Debian buster)
#
# Script to set up LXC virtualized Whonix Gateway on VPS
# Creates LXC Debian VPN server that uses Whonix Gateway for all traffic 
# Copy the client.ovpn file to your local computer and you can connect to VPN to have all traffic routed through 

# Check for root...this could possibly be removed
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# For OPENVPN configuration
PUBLIC_IP=`curl ipinfo.io/ip`

#################################################################
# Install/Setup lxd
#################################################################
# Add contrib for zfsutils-linux
echo 'deb http://deb.debian.org/debian/ buster contrib' >> '/etc/apt/sources.list'
sudo apt update && 

# Install zfs utils for zfs pool used by LXC
sudo apt-get -y install linux-headers-$(uname -r)
sudo apt-get -y install zfs-dkms zfsutils-linux spl-dkms
sudo modprobe zfs
sudo echo "zfs" >> /etc/modules

# Install snap
sudo apt-get -y install git wget snapd
sudo systemctl restart snapd
snap refresh
snap install core &&
snap install lxd &&
sudo adduser $USER lxd

# Set up path
PATH=/snap/bin:$PATH
echo 'PATH=/snap/bin:$PATH' >> ~/.bashrc

# Set up lxd
lxd init --auto --storage-backend zfs

#################################################################
# Download/ Setup Whonix image/metadata
#################################################################
wget https://github.com/whit3rabbit/lxd-whonix-gateway/releases/download/v15.0/47d6dc01aac13b047214574190ad135df72f486f512dba0e0c598c90fdd2dd2a.squashfs -O /tmp/rootfs.squashfs
wget https://github.com/whit3rabbit/lxd-whonix-gateway/releases/download/v15.0/meta-47d6dc01aac13b047214574190ad135df72f486f512dba0e0c598c90fdd2dd2a.tar.xz -O /tmp/metadata.tar.xz

# Import Whonix Image
lxc image import /tmp/metadata.tar.xz /tmp/rootfs.squashfs --alias whonix-gateway-cli

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
lxc launch whonix-gateway-cli whgw1 && 
lxc stop whgw1 && 
lxc profile assign whgw1 whonix-profile-gateway

# Start container:
lxc start whgw1 &&

# Start connection to TOR ( this has to be done manually/interactively) until I can figure something out.. 
# https://github.com/Whonix/whonixsetup/blob/master/usr/bin/whonixsetup
lxc exec whgw1 -- whonixsetup

# Update whonix
lxc exec whgw1 -- apt-get-update-plus -y dist-upgrade &&

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
lxc exec --env AUTO_INSTALL=y --env ENDPOINT=${PUBLIC_IP} debian-vpn -- ./openvpn-install.sh

# Copy client.openvpn file
lxc exec debian-vpn -- cat /root/client.ovpn > client.ovpn

# Enable openvpn at startup and start openvpn
lxc exec debian-vpn -- systemctl enable openvpn
lxc exec debian-vpn -- systemctl start openvpn

# Because we use TOR, cloudflare doesn't like that we look for IP
echo "Modify client.ovpn file with your public IP: ${PUBLIC_IP}"

# Get Debian-VPN IP
DEBIAN-VPN-IP=`lxc list debian-vpn --format csv | grep eth0 | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"`

# Get VPN port for VPS
echo "What port should VPS listen on for VPN server (1 through 65535): "
read VPNPORT

# IPTABLES to forward public VPN IP to LXC container
iptables -t nat -A PREROUTING -p udp --dport ${VPNPORT} -j DNAT --to-destination ${DEBIAN-VPN-IP}:1194
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables-save > lxc-who-vpn.fw

# To survive reboot
apt-get -y install iptables-persistent

echo "All finished!"
echo "Modify remote/port line in client.ovpn with: remote ${PUBLIC_IP} ${VPNPORT}"
echo "You may need to allow VPN port ${VPNPORT} on VPS firewall rule"
echo "To stop/start LXC containers:"
echo "Whonix Gateway: lxc stop whgw1 && lxc start whgw1"
echo "Debian VPN container: lxc stop debian-vpn && lxc start debian-vpn"

#################################################################
# Cleanup
#################################################################
rm -f /tmp/metadata.tar.xz
rm -f /tmp/rootfs.squashfs
rm -f ~/whonix-profile-client.yml 
rm -f ~/whonix-profile-gateway.yml
