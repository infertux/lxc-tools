#!/bin/bash

# LXC tools
# Copyright (C) 2011 Infertux <infertux@infertux.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

# Download a fresh Debian then install and configure it to be a LXC container.
# You may probably ajust the following constants before using this script.


NETWORK=10.1.2
GATEWAY=192.168.1.1
INTERFACE=eth0
BRIDGE=br0

ARCH=amd64
VERSION=squeeze
PACKAGES=ifupdown,netbase,net-tools
# Other useful packages: dialog, iproute

PASSWORD=ChangeMe


usage()
{
    cat <<EOF
$(basename $0) -h|--help -n|--name=<name> -i|--ip=<last-byte>
Example: $(basename $0) -n test -i 42
EOF
    exit 0
}

fail()
{
    echo "$1" >&2
    exit 1
}

options=$(getopt -o hn:i: -l help,name:,ip: -- "$@")
[ $# -eq 0 -o $? -ne 0 ] && usage

eval set -- "$options"

while true
do
    case "$1" in
    -h|--help)      usage $0 && exit 0;;
    -n|--name)      name=$2; shift 2;;
    -i|--ip)        ip=$2; shift 2;;
    --)             shift 1; break ;;
    *)              break ;;
    esac
done

type debootstrap || fail "'debootstrap' command is missing"

[ "$name" ] || fail "'name' parameter is required"
[ "$ip" ] || fail "'ip' parameter is required"

[ $UID -ne 0 ] && fail "This script should be run as 'root'"

path="/var/lib/lxc/$name"
rootfs="$path/rootfs"

[ -d $rootfs ] && fail "rootfs already exists, aborting."

# download a mini debian
mkdir -p $rootfs
debootstrap --verbose --variant=minbase --arch=$ARCH --include $PACKAGES \
  $VERSION $rootfs http://ftp.debian.org/debian || \
  fail "Failed to download the rootfs, aborting."

# configure the inittab
cat <<EOF > $rootfs/etc/inittab
id:3:initdefault:
si::sysinit:/etc/init.d/rcS
l0:0:wait:/etc/init.d/rc 0
l1:1:wait:/etc/init.d/rc 1
l2:2:wait:/etc/init.d/rc 2
l3:3:wait:/etc/init.d/rc 3
l4:4:wait:/etc/init.d/rc 4
l5:5:wait:/etc/init.d/rc 5
l6:6:wait:/etc/init.d/rc 6
# Normally not reached, but fallthrough in case of emergency.
z6:6:respawn:/sbin/sulogin
1:2345:respawn:/sbin/getty 38400 console
c1:12345:respawn:/sbin/getty 38400 tty1 linux
EOF

# disable selinux
mkdir -p $rootfs/selinux
echo 0 > $rootfs/selinux/enforce

# configure the network
cat <<EOF > $rootfs/etc/network/interfaces
auto lo
iface lo inet loopback

auto $INTERFACE
iface $INTERFACE inet static
  address $NETWORK.$ip
  netmask 255.255.255.0
  up route add -host $GATEWAY dev $INTERFACE
  up route add default gw $GATEWAY dev $INTERFACE
EOF

# set the hostname
cat <<EOF > $rootfs/etc/hostname
$name
EOF

# get rid of this bloated /dev
chroot $rootfs rm -rf /dev
chroot $rootfs mkdir /dev
# then populate it with only what we need
chroot $rootfs mknod -m 666 /dev/null c 1 3
chroot $rootfs mknod -m 666 /dev/zero c 1 5
chroot $rootfs mknod -m 666 /dev/random c 1 8
chroot $rootfs mknod -m 666 /dev/urandom c 1 9
chroot $rootfs mkdir -m 755 /dev/pts
chroot $rootfs mkdir -m 1777 /dev/shm
chroot $rootfs mknod -m 666 /dev/tty c 5 0
chroot $rootfs mknod -m 600 /dev/console c 5 1
chroot $rootfs mknod -m 666 /dev/tty0 c 4 0
chroot $rootfs mknod -m 666 /dev/tty1 c 4 1
chroot $rootfs mknod -m 666 /dev/full c 1 7
chroot $rootfs mknod -m 600 /dev/initctl p
chroot $rootfs mknod -m 666 /dev/ptmx c 5 2

# remove pointless services in a container
chroot $rootfs /usr/sbin/update-rc.d -f umountfs remove
chroot $rootfs /usr/sbin/update-rc.d -f hwclock.sh remove
chroot $rootfs /usr/sbin/update-rc.d -f hwclockfirst.sh remove

echo "root:$PASSWORD" | chroot $rootfs chpasswd

# create the LXC config file
cat <<EOF >> $path/config
lxc.tty = 2
lxc.pts = 1024
lxc.rootfs = $rootfs
lxc.cgroup.devices.deny = a
# /dev/null and zero
lxc.cgroup.devices.allow = c 1:3 rwm
lxc.cgroup.devices.allow = c 1:5 rwm
# consoles
lxc.cgroup.devices.allow = c 5:1 rwm
lxc.cgroup.devices.allow = c 5:0 rwm
lxc.cgroup.devices.allow = c 4:0 rwm
lxc.cgroup.devices.allow = c 4:1 rwm
# /dev/{,u}random
lxc.cgroup.devices.allow = c 1:9 rwm
lxc.cgroup.devices.allow = c 1:8 rwm
lxc.cgroup.devices.allow = c 136:* rwm
lxc.cgroup.devices.allow = c 5:2 rwm
# rtc
lxc.cgroup.devices.allow = c 254:0 rwm

# mounts point
lxc.mount.entry=none $rootfs/proc    proc   defaults 0 0
lxc.mount.entry=none $rootfs/dev/pts devpts defaults 0 0
lxc.mount.entry=none $rootfs/sys     sysfs  defaults 0 0
lxc.mount.entry=none $rootfs/dev/shm tmpfs  defaults 0 0

lxc.utsname = $name
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = $BRIDGE
#lxc.network.name = eth0
lxc.network.ipv4 = $NETWORK.$ip/24

EOF

echo
echo "Container ready, start it with: lxc-start -n $name."

