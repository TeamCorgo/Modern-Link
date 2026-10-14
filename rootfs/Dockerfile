FROM docker.io/arm32v7/debian:trixie

ARG KERNEL_VERSION=7.2.10
ARG DEBIAN_FRONTEND=noninteractive

# Undo the Docker image's apt/dpkg tweaks so the system behaves like a normal install
RUN rm -f /etc/apt/apt.conf.d/docker-* /etc/dpkg/dpkg.cfg.d/docker-*

# Prebuilt kernel from GitHub Releases: run kernel/fetch.sh first
COPY ./kernel-${KERNEL_VERSION}/ /boot/
RUN mkdir -p /lib/modules && mv /boot/${KERNEL_VERSION}-steam /lib/modules/${KERNEL_VERSION}-steam

COPY ./rootfs/boot/* /boot/
COPY ./rootfs/usr/bin/* /usr/bin/
COPY ./rootfs/steamlink/ /steamlink/
COPY ./rootfs/etc/ /etc/

# Match a Debian server install: everything debootstrap installs (required and
# important), "standard system utilities" (standard) and "SSH server"
RUN apt-get update \
 && apt-get install -y $(awk '/^Package:/ {p = $2} /^Priority: (required|important|standard)$/ {print p}' \
        /var/lib/apt/lists/*_main_binary-armhf_Packages | sort -u) \
 && apt-get install -y task-ssh-server

# Steam Link specifics: networking, firmware, nftables-based iptables, initramfs
RUN apt-get install -y systemd-timesyncd dbus ca-certificates dhcpcd-base ifupdown sudo \
    nftables iptables net-tools wget unzip binutils libatomic1 dosfstools e2fsprogs parted \
    initramfs-tools firmware-libertas wireless-regdb dialog tasksel vim

RUN sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen \
 && update-locale LANG=en_US.UTF-8

RUN useradd -s /bin/bash -m corgo
RUN echo "corgo:steamlink" | chpasswd

# Same groups the installer gives the first user, plus sudo
RUN for g in sudo cdrom floppy audio dip video plugdev users netdev; do \
        if getent group "$g" > /dev/null; then usermod -a -G "$g" corgo; fi; \
    done

# Enable basic services
RUN systemctl enable ssh
RUN systemctl enable dbus
RUN systemctl enable networking
RUN systemctl enable systemd-timesyncd

# /etc/network/interfaces setup
RUN printf '%s\n' \
    'source /etc/network/interfaces.d/*' \
    '' \
    'auto lo' \
    'iface lo inet loopback' \
    '' \
    'auto eth0' \
    'allow-hotplug eth0' \
    'iface eth0 inet dhcp' > /etc/network/interfaces

# Create initramfs once all packages and their hooks are in place
RUN mkinitramfs -o /boot/initramfs-linux-steam.img ${KERNEL_VERSION}-steam

# Let package upgrades on the device start and restart services again
RUN rm -f /usr/sbin/policy-rc.d

RUN apt-get --yes clean
