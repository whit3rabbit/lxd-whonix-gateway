# LXD/LXC Whonix Gateway CLI image for x64

Test repository for LXD/LXC for Whonix distro

* This has not been tested for security/leaks.
* Use with caution / development!

## Prerequistes

Tested on latest Debian release but could probably be built on any Linux distro.

Requires installation of:

* LXD/LXC
* Docker (optional for image build)

## Easy build LXC image for Whonix Gateway CLI with Docker

Clone this repository and run as root.

** You will need to change Docker to "devicemapper" in order to build images **
** This may break functionality with other docker images/containers **
```
systemctl stop docker
print "{\n   "storage-driver": "devicemapper"\n}" > /etc/docker/daemon.json
systemctl start docker
```
Build rootfs for LXC
```
cd ~
git clone https://github.com/whit3rabbit/lxd-whonix-gateway.git
cd lxd-whonix-gateway
docker build . -t whonix-distrobuilder1
docker run --privileged -v output:/output -it whonix-distrobuilder1
```
Copy files out of container
```
docker ps -a # Get container name
docker cp [container-name]:/distrobuilder/lxd.tar.xz
docker cp [container-name]:/distrobuilder/rootfs.squashfs
```

## Import rootfs files to create LXC image

Create Whonix LXC image named "whonix-gateway-cli":
```
#lxd init  # If first time running LXD
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