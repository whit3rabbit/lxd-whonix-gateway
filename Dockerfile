FROM debian:buster-slim

MAINTAINER whiterabbit@protonmail.com

ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND noninteractive

# Get packages
RUN apt-get -yq update && \
    apt-get -yq upgrade && \
    apt-get -yq --no-install-recommends install \
		dirmngr \
		build-essential \
		ca-certificates \
		golang-go \
		rsync \
		gpg \
		squashfs-tools \
		tor \
		git \
		debootstrap && \
	apt-get clean && \
	rm -rf /tmp/* /var/tmp/* /var/lib/apt/archive/* /var/lib/apt/lists/*

# Get Distrobuilder for LXC
RUN go get -d -v github.com/lxc/distrobuilder/distrobuilder && \
	cd /root/go/src/github.com/lxc/distrobuilder && \
	make

# Expose TOR port for apt building
RUN echo "SOCKSPort 9050" >> /etc/tor/torrc &&\ 
	echo "RunAsDaemon 1" >> /etc/tor/torrc

# Set working folder
RUN git clone https://github.com/whit3rabbit/lxd-whonix-gateway.git /distrobuilder
WORKDIR /distrobuilder

COPY helper/docker-build.sh build.sh
RUN chmod 755 build.sh

CMD ["/distrobuilder/build.sh"]
