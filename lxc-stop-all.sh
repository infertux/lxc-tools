#!/bin/bash -eu

# LXC tools
# Copyright (C) 2012-2016 Infertux <infertux@infertux.com>
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

# Especially useful to shutdown properly all containers before rebooting the LXC host.

RUNNING_CONTAINERS="$(lxc list -c ns | grep 'RUNNING' | awk -F '|' '{print $2}' | awk '{$1=$1;print}')"

for container in $RUNNING_CONTAINERS; do
echo "Stopping $container..."
lxc stop $container
done
