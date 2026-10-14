FROM docker.io/arm32v7/debian:bookworm
COPY ./kernel-7.2.10/ /boot/
RUN mkdir -p /lib/modules && mv /boot/7.2.10-steam /lib/modules/7.2.10-steam

COPY ./rootfs/boot/* /boot/
COPY ./rootfs/usr/bin/* /usr/bin/
COPY ./rootfs/steamlink/ /steamlink/

# Add repositories
RUN rm -rf /etc/apt/sources.list.d/* || true
RUN echo "deb http://deb.debian.org/debian bookworm main non-free non-free-firmware" > /etc/apt/sources.list
RUN echo "deb http://security.debian.org/debian-security bookworm-security main non-free non-free-firmware" >> /etc/apt/sources.list
RUN echo "deb http://deb.debian.org/debian bookworm-updates main non-free non-free-firmware" >> /etc/apt/sources.list

# Install basic system components
RUN apt-get update && apt-get install -y --no-install-recommends systemd systemd-timesyncd dbus ca-certificates dhcpcd5 nano vim openssh-server sudo ifupdown net-tools udev iputils-ping wget dosfstools unzip binutils libatomic1 initramfs-tools e2fsprogs parted firmware-libertas wireless-regdb dialog tasksel

# Create initramfs
RUN mkinitramfs -o /boot/initramfs-linux-steam.img 7.2.10-steam

RUN useradd -s /bin/bash -m corgo
RUN echo "corgo:steamlink" | chpasswd

# Add corgo user to sudoers
RUN usermod -a -G sudo corgo

# Enable basic services
RUN systemctl enable ssh
RUN systemctl enable dbus
RUN systemctl enable networking
RUN systemctl enable systemd-timesyncd

# /etc/network/interfaces setup
RUN echo "allow-hotplug eth0" > /etc/network/interfaces
RUN echo "auto eth0" >> /etc/network/interfaces
RUN echo "iface eth0 inet dhcp" >> /etc/network/interfaces

RUN apt-get --yes clean

# Update to Trixie 13
RUN sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
RUN sed -i 's/main non-free/main contrib non-free/g' /etc/apt/sources.list
RUN apt-get update
RUN apt dist-upgrade -y
RUN apt-get update
RUN apt-get upgrade

RUN apt-get --yes clean
