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


# List of containers you want to start at boot
CONTAINERS="web mail test"

for container in $CONTAINERS; do
  if [ "$(lxc-info -n $container)" != "'$container' is STOPPED" ]; then
    echo "'$container' is already running, skipping."
  else
    echo "Starting '$container'..."
    lxc-start -dn $container &
  fi
done

