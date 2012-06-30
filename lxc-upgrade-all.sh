#!/bin/bash

# LXC tools
# Copyright (C) 2012 Infertux <infertux@infertux.com>
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

# Check for updates on Debian-based containers.
# Pass -i flag to give you the possibility to upgrade.

set -eu

LXC=/var/lib/lxc
ROOTFS=rootfs
UPGRADE_CMD="apt-get dist-upgrade"
RUNNING_CONTAINERS="$(netstat -xa | grep $LXC | sed -e 's#.*'"$LXC/"'\(.*\)/command#\1#')"
INTERACTIVE=0

usage()
{
    cat >&2 <<EOF
$(basename $0) -h|--help -i|--interactive
Example: $(basename $0) -i
EOF
    exit 0
}

options=$(getopt -o hi -l help,interactive -- "$@")
[ $# -gt 1 -o $? -ne 0 ] && usage

eval set -- "$options"

while true
do
    case "$1" in
    -h|--help)        usage $0 && exit 0;;
    -i|--interactive) INTERACTIVE=1; shift;;
    --)               shift; break ;;
    *)                break ;;
    esac
done


trap quit INT TERM

mount_special_fs() {
  mount -t proc proc $1/proc/
  mount -t sysfs sys $1/sys/
  mount -t devpts dev/pts $1/dev/pts
}

umount_special_fs() {
  umount $1/proc/
  umount $1/sys/
  umount $1/dev/pts
}

quit() {
  echo "Oops"
}

for container in $RUNNING_CONTAINERS; do
  chroot $LXC/$container/$ROOTFS apt-get update -qq
  updates="$(chroot $LXC/$container/$ROOTFS $UPGRADE_CMD -qs | grep '^ ' || true)"

  if [ "$updates" ]; then
    if [ $INTERACTIVE -eq 1 ]; then
      rootfs=$LXC/$container/$ROOTFS
      mount_special_fs $rootfs
      chroot $rootfs $UPGRADE_CMD || true
      umount_special_fs $rootfs
    else
      echo -e "Updates for $container:\n$updates"
    fi
  else
    echo "$container is up-to-date."
  fi
done

echo "Done."

