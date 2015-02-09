#!/bin/bash

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