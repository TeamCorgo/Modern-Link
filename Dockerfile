# Builds the Steam Link Debian disk image from scratch. Use ./build.sh, which
# runs: docker build --output out .
# The result is out/steamlink-debian.img.xz.

# Kernel version; kernel/<version>.config must exist
ARG KERNEL_VERSION=7.2.10

# --- Kernel: cross-compiled with the Steam Link SDK toolchain (x86-64 only) ---
# Docker's build cache keeps the result, so it only recompiles when kernel/ changes
FROM --platform=linux/amd64 docker.io/library/ubuntu:24.04 AS kernel

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends bc bison ca-certificates curl flex gcc git \
        kmod libc6-dev libelf-dev libssl-dev make perl xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 --filter=blob:none --sparse https://github.com/ValveSoftware/steamlink-sdk.git /sdk \
 && git -C /sdk sparse-checkout set toolchain

ARG KERNEL_VERSION
# Defaults to the kernel.org tarball for KERNEL_VERSION
ARG KERNEL_URL
RUN url=${KERNEL_URL:-https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-$KERNEL_VERSION.tar.xz} \
 && curl -fsSL --retry 3 -o /linux.tar "$url" \
 && mkdir /linux \
 && tar -xf /linux.tar --strip-components=1 -C /linux \
 && rm /linux.tar

COPY kernel/ /kernel/
RUN /kernel/build.sh /linux /sdk /out

# --- Root filesystem: a Debian 13 server install for armhf (runs under QEMU) ---
FROM --platform=linux/arm/v7 docker.io/arm32v7/debian:trixie AS rootfs

ARG KERNEL_VERSION
ARG DEBIAN_FRONTEND=noninteractive

# Undo the Docker image's apt/dpkg tweaks so the system behaves like a normal install
RUN rm -f /etc/apt/apt.conf.d/docker-* /etc/dpkg/dpkg.cfg.d/docker-*

COPY --from=kernel /out/kernel-${KERNEL_VERSION}/ /boot/
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

# --- Disk image: partitioned ext3 USB image, built without loop devices ---
FROM --platform=$BUILDPLATFORM docker.io/library/ubuntu:24.04 AS image

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends e2fsprogs fdisk xz-utils \
 && rm -rf /var/lib/apt/lists/*

COPY --from=rootfs / /rootfs/
COPY rootfs/build.sh /usr/local/bin/build-image
RUN build-image /rootfs /out

# --- Output: what docker build --output exports ---
FROM scratch
COPY --from=image /out/steamlink-debian.img.xz /
