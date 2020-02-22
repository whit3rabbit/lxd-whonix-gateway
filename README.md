# LXD/LXC Whonix Gateway CLI image for x64

Test repository for LXD/LXC for Whonix distro

* This has not been tested for security/leaks.
* Use with caution / development!

## Prerequiste

Tested on latest Debian release but could probably be built on any Linux distro.

Requires installation of:

* LXD/LXC
* Distrobuilder https://distrobuilder.readthedocs.io/en/latest/
* TOR

## Instructions 

Clone this repository

```
git clone https://github.com/whit3rabbit/lxd-whonix-gateway.git
cd lxd-whonix-gateway
```

Build the image (only need to be done once):

```
# Make sure TOR is running for whonix apt packages
sudo systemctl start tor
sudo $HOME/go/bin/distrobuilder build-lxd whonix-gateway-distrobuilder.yml
```

Create Whonix LXC image named "whonix-gateway-cli":
```
sudo lxc image import lxd.tar.xz rootfs.squashfs --alias whonix-gateway-cli
```

Create bridge network with Whonix IP space/gateway (eth0):
```
sudo lxc network create whonixbr0 ipv4.address=10.0.2.2/24 ipv4.nat=true ipv6.address=none
```

Create a bridge network for client IP space (eth1):
```
sudo lxc network create whonixveth0 ipv4.address=10.152.152.0/18 ipv4.nat=true ipv4.dhcp.gateway=10.152.152.10 ipv6.address=none
```

Create a network profile to use the bridge (whonixbr0):
```
sudo lxc profile create whonix-profile-gateway
cat whonix-profile-gateway.yml | sudo lxc profile edit whonix-profile-gateway
```

Create your first container named whgw1 from image and assign the network profile "whonix-gateway":
```
sudo lxc launch whonix-gateway-cli whgw1
sudo lxc stop whgw1 # Stop to assign network profile
sudo lxc profile assign whgw1 whonix-profile-gateway
```
Start container
```
sudo lxc start whgw1
```
First time commands inside whonix gateway:
```
sudo lxc exec whgw1 -- whonixsetup
sudo lxc exec whgw1 -- apt-get-update-plus dist-upgrade
```
Troubleshooting
```
sudo lxc exec whgw1 bash
```

## WIP: Connecting to other containers

I will use the Kali Linux distro as an example but others could be used:

Here the IP address of the Kali box is set to 10.152.152.12 and can be changed if needed, but not to same IP as gateway (.10).

Set up network profile (do once):
```
sudo lxc profile create whonix-profile-client
cat whonix-profile-client.yml | sudo lxc profile edit whonix-profile-client
lxc network attach-profile whonix-profile-client default eth0
```

Create kali box
```
sudo lxc launch images:kali/current/amd64 kali-whonix
sudo lxc exec kali-whonix -- printf "auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet static\naddress 10.152.152.12\nnetmask 255.255.192.0\ngateway 10.152.152.10\n" > /etc/network/interfaces
sudo lxc exec kali-whonix -- echo nameserver 10.152.152.10 > /etc/resolv.conf
sudo lxc stop kali-whonix # Restart box
sudo lxc profile assign kali-whonix whonix-profile-client
sudo lxc start kali-whonix
sudo lxc exec kali-whonix -- bash
```

## Stats

* Running idle about 150-350mb of memory usage.
* 1% of CPU usage
* 446.74MB Image size


## Cleanup/Removal

To stop container
```
sudo lxc stop whgw1
```
To delete container
```
sudo lxc delete whgw1
```
To delete image
```
sudo lxc image delete whonix-gateway-cli
```

## Monitoring

* Sysdig

Install sysdig 
```
curl -s https://s3.amazonaws.com/download.draios.com/stable/install-sysdig | sudo bash
```
Monitor containers CPU/memory/process uage
```
sudo csysdig -vcontainers # View all containers
```
Monitor all commands inside container from host
```
sudo sysdig -pc -c spy_users container.name=whgw1
```