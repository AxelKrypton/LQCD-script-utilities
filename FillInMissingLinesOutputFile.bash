#!/bin/bash
#
#  Copyright (c) 2016 Christopher Czaban
#  Copyright (c) 2021 Alessandro Sciarra
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


if [[ $# -ne 2 ]]; then
    echo "Usage: $0 (output|pbp) <filename>"
    exit
elif [[ ! $1 =~ ^(output|pbp)$ ]]; then
    echo "First argument to the script must be either 'output' or 'pbp'."
    echo "Usage: $0 (output|pbp) <filename>"
    exit
else
    TYPE_OF_FILE="$1"
    shift
fi

INPUT_FILE=$1

[ ! -f $INPUT_FILE ] && echo -e "\e[91mSpecified file does not exist. Exiting...\e[0m" && exit

NUMBER_OF_COLUMNS=$(awk 'NR==1{print NF}' $INPUT_FILE)
if [[ ${TYPE_OF_FILE} = 'output' ]]; then
    if [[ ${NUMBER_OF_COLUMNS} -ne 10 && ${NUMBER_OF_COLUMNS} -ne 13 ]]; then
        echo -e "\e[91mSpecified file does not seem to be a CL2QCD output file with 10 or 13 columns. Exiting...\e[0m"
        exit
    fi
    REPLACEMENT_FOR_ACCEPTANCE_COLUMN='a[9]=0;'
else
    REPLACEMENT_FOR_ACCEPTANCE_COLUMN=''
fi

TOTAL_NUMBER_OF_MISSING_LINES=( $(awk 'NR==1{tr=$1}END{missing=$1-tr+1-NR; percent=missing/($1-tr); if(percent > 0.01){error=1}; print missing" "100*percent" "error}' ${INPUT_FILE}) )
if [[ ${TOTAL_NUMBER_OF_MISSING_LINES[0]} -eq 0 ]]; then
    echo -e "\n\e[92m No missing lines in \"${INPUT_FILE}\" file.\e[0m\n"
    exit
else
    echo -e "\n\e[93m Found ${TOTAL_NUMBER_OF_MISSING_LINES[0]} missing lines, ${TOTAL_NUMBER_OF_MISSING_LINES[1]}% of expected lines.\e[0m\n"
fi

if [[ ${TOTAL_NUMBER_OF_MISSING_LINES[2]} -eq 1 ]]; then
	echo -en "\e[91m More than 1% missing line. Fill in file anyway? [Y/N] \e[0m"
	CONFIRM="";
	while read CONFIRM; do
		if [ "$CONFIRM" = "Y" ]; then
			break
		elif [ "$CONFIRM" = "N" ]; then
			echo; exit
		fi
	done
fi

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
        #Note that the split function with four arguments is supported only by GNU awk.
        sed -n $LINE_NR'p' $INPUT_FILE | awk -v increment=$i -v space="$IDENTATION_SPACE" '{split($0, a, FS, seps); a[1]+=increment;'"${REPLACEMENT_FOR_ACCEPTANCE_COLUMN}"' printf "%s", space; for (i=1;i<=NF;i++) printf("%s%s", a[i], seps[i]); print ""}'  >> $TMP_FILE
	done
	NR_LINES_FROM_BOTTOM=$(($(wc -l < $INPUT_FILE)-$LINE_NR))
	tail -n$(($NR_LINES_FROM_BOTTOM)) $INPUT_FILE >> $TMP_FILE
	cat $TMP_FILE > $INPUT_FILE
done

rm -f $TMP_FILE

echo ''
