#!/bin/sh

/usr/bin/tor
/root/go/bin/distrobuilder build-lxd whonix-gateway-distrobuilder.yml
cp lxd.tar.xz /output
cp rootfs.squashfs /output