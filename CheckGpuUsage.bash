#!/bin/bash
#
#  Copyright (c) 2015 Alessandro Sciarra
#
#  This file is part of "Script utilities".
#
#  "Script utilities" is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  "Script utilities" is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with "Script utilities". If not, see <http://www.gnu.org/licenses/>.
#


#Temporary version, something to be fixed!

USERS=("cuteri" "czaban" "pinke" "sciarra")
declare -A GPU_USAGE
for IDNAME in ${USERS[@]}; do
    GPU_USAGE["$IDNAME"]=0
done

GPU_NODES=()
for((i=1; i<=40; i++)); do
    GPU_NODES+=( "$(printf "gpu%03d" $i)" )
done

for((i=0; i<38; i++)); do
    for IDNAME in ${USERS[@]}; do
	echo "$i --- $IDNAME"
#	ssh -t ${GPU_NODES[$i]} bash -c "'top -n 1 | grep "$IDNAME"'" | wc -l
	if [ $(ssh -t ${GPU_NODES[$i]} bash -c "'top -n 1 | grep $IDNAME'" | wc -l) -ne 0 ]; then
	    GPU_USAGE["$IDNAME"]=$((${GPU_USAGE["$IDNAME"]} + 1))
	fi
    done
done

echo "${!GPU_USAGE[@]}"
echo "${GPU_USAGE[@]}"

exit
