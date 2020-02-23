# LXD/LXC Whonix Gateway CLI image for x64

Test repository for LXD/LXC for Whonix distro

* This has not been tested for security/leaks.
* Use with caution / development!

## Prerequistes

Tested on latest Debian release but could probably be built on any Linux distro.

Requires installation of:

* LXD/LXC
* Distrobuilder
* TOR

```
apt update
apt install -y snapd tor git debootstrap
echo "export PATH=$PATH:/snap/bin" >> ~/.bashrc
echo "SOCKSPort 9050" >> /etc/tor/torrc
echo "RunAsDaemon 1" >> /etc/tor/torrc
. ~/.bashrc
snap install lxd
snap install distrobuilder --classic
systemctl start tor
```

## Instructions for Whonix Gateway set up

Clone this repository

```
cd ~
git clone https://github.com/whit3rabbit/lxd-whonix-gateway.git
cd lxd-whonix-gateway
```

Build the image (only need to be done once):

```
# Make sure TOR is running for whonix apt packages
# systemctl start tor
distrobuilder build-lxd whonix-gateway-distrobuilder.yml
```

Create Whonix LXC image named "whonix-gateway-cli":
```
lxd init
lxc image import lxd.tar.xz rootfs.squashfs --alias whonix-gateway-cli
```

Create bridge network with Whonix IP space/gateway (eth0):
```
lxc network create whonixbr0 ipv4.address=10.0.2.2/24 ipv4.nat=true ipv6.address=none
```

Create a bridge network for client IP space (eth1):
```
lxc network create whonixbr1 ipv4.address=10.152.152.0/18 ipv4.nat=true ipv4.dhcp.gateway=10.152.152.10 ipv6.address=none
```

Create a network profile to use the bridge (whonixbr0):
```
lxc profile create whonix-profile-gateway
cat whonix-profile-gateway.yml | lxc profile edit whonix-profile-gateway

```

Network profile for the client bridge (whonixbr1):
```
lxc profile create whonix-profile-client
cat whonix-profile-client.yml | lxc profile edit whonix-profile-client
```

Create your first container named whgw1 from image and assign the network profile "whonix-gateway":
```
lxc launch whonix-gateway-cli whgw1
lxc stop whgw1 # Stop to assign network profile
lxc profile assign whgw1 whonix-profile-gateway
```
Start container
```
lxc start whgw1
```
First time commands inside whonix gateway:
```
lxc exec whgw1 -- whonixsetup
lxc exec whgw1 -- apt-get-update-plus dist-upgrade
```
Troubleshooting
```
lxc exec whgw1 bash
```

## Connecting to other containers

Ubuntu as an example.
```
lxc launch ubuntu:18.04 bionic
lxc stop bionic
lxc profile assign bionic whonix-profile-client
lxc start bionic
lxc exec kali-whonix -- echo "nameserver 10.152.152.10" > /etc/resolv.conf
```

Kali as example:
```
lxc launch images:kali/current/amd64 kali-whonix
lxc exec kali-whonix -- printf "auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet static\naddress 10.152.152.12\nnetmask 255.255.192.0\ngateway 10.152.152.10\n" > /etc/network/interfaces
lxc exec kali-whonix -- echo "nameserver 10.152.152.10" > /etc/resolv.conf
lxc stop kali-whonix # Restart box
lxc profile assign kali-whonix whonix-profile-client
lxc start kali-whonix
lxc exec kali-whonix -- bash
```

## Stats

* Running idle about 150-350mb of memory usage.
* 1% of CPU usage
* 446.74MB Image size


## Cleanup/Removal

To stop container
```
lxc stop whgw1
```
To delete container
```
lxc delete whgw1
```
To delete image
```
lxc image delete whonix-gateway-cli
```

## Monitoring

* Sysdig

Install sysdig 
```
curl -s https://s3.amazonaws.com/download.draios.com/stable/install-sysdig | bash
```
Monitor containers CPU/memory/process uage
```
csysdig -vcontainers # View all containers
```
Monitor all commands inside container from host
```
sysdig -pc -c spy_users container.name=whgw1
```