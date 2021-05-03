#!/bin/bash

[ $# -eq 0 ] && echo "Usage: $0 <filename>" && exit

INPUT_FILE=$1

[ ! -f $INPUT_FILE ] && echo -e "\e[91mSpecified file does not exist. Exiting...\e[0m" && exit

BACKUP_FILE="${INPUT_FILE}_$(date +'%F_%H%M')"

cp $INPUT_FILE $BACKUP_FILE

TMP_FILE="temporaryFile"
PROMPT_AT_MISSING_NR_LINES="1"

START_TRAJ_NR=($(awk '$1 != (last+1) && NR > 1 {print last}{last=$1}' $INPUT_FILE))
NR_MISSING_LINES=($(awk '$1 != (last+1) && NR > 1 {print $1-last-1}{last=$1}' $INPUT_FILE))

for((i=0; i<${#NR_MISSING_LINES[@]};i++))
do
	if [ ${NR_MISSING_LINES[$i]} -lt 0 ]
	then
		echo -e "\e[1m\e[91m WARNING: Computed negative number of missing lines for trajectory number ${START_TRAJ_NR[$i]}\e[0m"
		NEGATIVE_NUMBER_DETECTED="TRUE"
	fi
done

[ "$NEGATIVE_NUMBER_DETECTED" = "TRUE" ] && exit

#echo ${START_TRAJ_NR[@]}
#echo ${NR_MISSING_LINES[@]}
echo ''

NR_ENTRIES=${#START_TRAJ_NR[@]}

if [[ ${NR_ENTRIES} -eq 0 ]]; then
    echo -e "\e[92m No missing lines in \"${INPUT_FILE}\" file.\e[0m"
fi

for((INDEX=0; INDEX < $NR_ENTRIES; INDEX++)); do

	if [ ${NR_MISSING_LINES[$INDEX]} -ge $PROMPT_AT_MISSING_NR_LINES ]; then
		echo -en "\e[91m Warning: Found bunch of ${NR_MISSING_LINES[$INDEX]} missing lines. Fill in lines? [Y/N] \e[0m"
		CONFIRM="";
		while read CONFIRM; do
			if [ "$CONFIRM" = "Y" ]; then
				break	
			elif [ "$CONFIRM" = "N" ]; then
				continue 2
			fi
		done
	fi
	
	LINE_NR=$(grep -n "^[[:space:]]*${START_TRAJ_NR[$INDEX]}" $INPUT_FILE | cut -f1 -d":")
	head -n$LINE_NR $INPUT_FILE > $TMP_FILE
	for((i=1; i<=${NR_MISSING_LINES[$INDEX]}; i++)); do
        IDENTATION_SPACE="$(sed -n $LINE_NR'p' $INPUT_FILE | grep -o "^[[:space:]]*")"
        #Note that the split function with forth argument is supported only by GNU awk.
        sed -n $LINE_NR'p' $INPUT_FILE | awk -v increment=$i -v space="$IDENTATION_SPACE" '{split($0, a, FS, seps); a[1]+=increment; a[9]=0; printf "%s", space; for (i=1;i<=NF;i++) printf("%s%s", a[i], seps[i]); print ""}'  >> $TMP_FILE
	done
	NR_LINES_FROM_BOTTOM=$(($(wc -l < $INPUT_FILE)-$LINE_NR))
	tail -n$(($NR_LINES_FROM_BOTTOM)) $INPUT_FILE >> $TMP_FILE
	cat $TMP_FILE > $INPUT_FILE
done	

rm -f $TMP_FILE

echo ''
