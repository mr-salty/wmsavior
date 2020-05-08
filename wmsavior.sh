#!/bin/bash
###############################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You can receive a copy of the GNU General Public License
# at <http://www.gnu.org/licenses/>.
###############################################################################

# Simple script that save your window arrangement when external display
# connected. The windows are rearranged on display disconnect to
# the remaining display. When the external display is reconnected
# you can use the script to restore windows arrangement.
# Created by dosmanak.

# store files in this directory; try to create it if necessary
readonly DIR="${HOME}/.wmsavior";
if ! cd "${DIR}"; then
  mkdir -p ${DIR}
  if ! cd "${DIR}"; then
    echo "Can't chdir to ${DIR}"
    exit 1;
  fi
fi

readonly STORFILE="saved.wmctrl"
readonly TMPFILE="${STORFILE}.$(date +%s)"
readonly DEFAULT_NUM_TO_KEEP="5"

if [[ "$1" == "save" ]]; then
  wmctrl -l -G | \
    while read window_id desktop_id x_offset y_offset width height junk; do
    offset=($(xwininfo -id $window_id |grep Relative | awk '{print $NF}'|xargs))
    # Although I tried to get precise position using xwininfo, I had to subtract
    # 15px from y position (Mint Cinnamon). May differ on your window manager.
    echo $window_id $desktop_id $((${x_offset}-${offset[0]})) \
      $((${y_offset}-15-${offset[1]}-${offset[0]})) $width $height $junk >> \
          ${TMPFILE}
  done
  if [[ -f "${TMPFILE}" ]]; then
    # ignore the window title when comparing, and any ordering differences.
    if diff <(cut -d\  -f1-6 "${STORFILE}" | sort) \
            <(cut -d\  -f1-6 "${TMPFILE}" | sort) >& /dev/null; then
      rm "${TMPFILE}"
    else
      ln -s -f "${TMPFILE}" "${STORFILE}"
    fi
  fi
elif [[ "$1" == "restore" ]]; then
  readonly storfile="${2-${STORFILE}}"
  while read window_id desktop_id x_offset y_offset width height junk; do 
    wmctrl -v -i -r $window_id -e 0,$x_offset,$y_offset,$width,$height \
      2>/dev/null
  done < "${storfile}"
elif [[ "$1" == "cleanup" ]]; then
  # cleanup all but the most recent N (default 5) files
  skip_count=${2-5}
  while read -r file; do
    ((--skip_count))
    if [[ "${skip_count}" -lt 0 ]]; then
      rm -v ${file}
    fi
  done <<< "$(ls -1t . --hide "${STORFILE}")"
elif [[ "$1" == "show" ]]; then
  ls -lt
elif [[ "$1" == "diff" ]]; then
  last_file="saved.wmctrl"
  while read -r file; do
    echo -n "${file} "
    diff -y --suppress-common-lines <(cut -d\  -f1-6 "${last_file}" | sort) \
      <(cut -d\  -f1-6 "${file}" | sort) | wc -l
    last_file=${file}
  done <<< "$(ls -1t . --hide "${STORFILE}")"
else
  readonly prog="$(basename $0)"
  cat <<EOM
Usage: ${prog} <save|show|diff>
       ${prog} restore [filename (default "${STORFILE}"]
       ${prog} cleanup [number-of-backups-to-keep (default ${DEFAULT_NUM_TO_KEEP})]
EOM
  exit 127
fi
