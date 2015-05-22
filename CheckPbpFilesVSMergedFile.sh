#!/bin/bash

# Script to check that in the files conf.XXXXX_pbp.dat the values
# of the pbp is the same of that contained in the merged file. It has
# to be run in the folder where the pbp files are.

PREFIX="conf."
POSTFIX="_pbp.dat"
DIGITS=5
MERGED_FILENAME="rhmc_output_pbp.dat"
NUM_SOURCES=16
FOLDER_WITH_PBP_FILES="."

while [ "$1" != "" ]; do
    case $1 in
	-h | --help )
            printf "\n\e[0;32m"
            echo "Call the script $0 with the following optional arguments:"
            echo "  -h | --help"
            echo "  -f | --mergedFilename          ->    default value = $MERGED_FILENAME"

            echo "  -s | --numberOfSources         ->    default value = $NUM_SOURCES"
	    echo "  -d | --digitsInConfName        ->    default value = $DIGITS"

	    echo "  --folderWithPbpFiles           ->    default value = $FOLDER_WITH_PBP_FILES"
	    echo "  --prefixInConfName             ->    default value = $PREFIX"
	    echo "  --postfixInConfName            ->    default value = $POSTFIX"
            printf "\n\e[0m"
            exit
            shift;;
	-f=* | --mergedFilename=* )      MERGED_FILENAME=${1#*=}; shift ;;
	-s=* | --numberOfSources=* )     NUMBER_OF_SOURCES=${1#*=}; shift ;;
	-d=* | --digitsInConfName=* )    DIGITS=${1#*=}; shift ;;
	--folderWithPbpFiles=* )         FOLDER_WITH_PBP_FILES=${1#*=}; shift ;;
	--prefixInConfName=* )           PREFIX=${1#*=}; shift ;;
	--postfixInConfName=* )          POSTFIX=${1#*=}; shift ;;
	* ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
done

#=================================================================================================================================
printf "\n\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)/2)) ))\n\e[0m"

#Check if file exists
if [ ! -f $MERGED_FILENAME ]; then
    printf "\e[38;5;9m\n File \"$MERGED_FILENAME\" not found! Aborting...\n\e[0m"
    printf "\n\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)/2)) ))\n\n\e[0m"
    exit -1
fi

if [ ! -d $FOLDER_WITH_PBP_FILES ]; then
    printf "\n\e[38;5;9m Directory \"$FOLDER_WITH_PBP_FILES\" not found! Aborting...\n\e[0m"
    printf "\n\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)/2)) ))\n\n\e[0m"
    exit -1
fi

#Gather information
PBP_FILENAMES=( $(ls ${FOLDER_WITH_PBP_FILES}/${PREFIX}*${POSTFIX} 2>/dev/null) )
NUMBER_PBP_FILES=${#PBP_FILENAMES[@]}
LINES_MERGED_FILE=$(wc -l < ${MERGED_FILENAME})
TRAJECTORY_IN_PBP_FILES=( $(grep -o "[[:digit:]]*" <<< "${PBP_FILENAMES[@]}") )
TRAJECTORY_IN_MERGED_FILE=( $(awk '{print $1}' $MERGED_FILENAME | sort | uniq) )
#Check repeated lines
if [ ${#TRAJECTORY_IN_MERGED_FILE[@]} -ne $LINES_MERGED_FILE ]; then
    printf "\n\e[38;5;11m WARNING: Merged pbp file has repeated lines!!!\n\e[0m"
fi
#Check on number of files
if [ "$NUMBER_PBP_FILES" -ne "$LINES_MERGED_FILE" ]; then
    printf "\n\e[38;5;9m Lines of merged pbp file \e[1m$LINES_MERGED_FILE\e[21m is NOT equal to the number of pbp files \e[1m$NUMBER_PBP_FILES\e[21m\n\e[0m"
fi
#Here I am sure I have no duplicates in TRAJECTORY_IN_MERGED_FILE and TRAJECTORY_IN_PBP_FILES, so I can procede as follows
declare -A TEMP_ARRAY_ONE TEMP_ARRAY_TWO
for INDEX in "${TRAJECTORY_IN_PBP_FILES[@]}"; do ((TEMP_ARRAY_ONE[$INDEX]++)); done
for INDEX in "${TRAJECTORY_IN_MERGED_FILE[@]}"; do ((TEMP_ARRAY_TWO[$INDEX]++)); done
for INDEX in "${!TEMP_ARRAY_ONE[@]}"; do
    if [ ${TEMP_ARRAY_ONE[$INDEX]-0} -ge 1 ] && [ ${TEMP_ARRAY_TWO[$INDEX]-0} -ge 1 ]; then
        unset "TEMP_ARRAY_ONE[$INDEX]" "TEMP_ARRAY_TWO[$INDEX]"
    fi
done
if [ ${#TEMP_ARRAY_ONE[@]} -ne 0 ]; then
    printf "\n\e[38;5;129m    There are pbp single files missing in $MERGED_FILENAME:\n\e[0m"
    for TR in "${!TEMP_ARRAY_ONE[@]}"; do
	printf "\e[38;5;13m       - ${FOLDER_WITH_PBP_FILES}/${PREFIX}${TR}${POSTFIX}\n\e[0m"
    done
fi
if [ ${#TEMP_ARRAY_TWO[@]} -ne 0 ]; then
    printf "\n\e[38;5;129m    There are pbp values in $MERGED_FILENAME missing in single files:\n\e[0m"
    for TR in "${!TEMP_ARRAY_TWO[@]}"; do
	printf "\e[38;5;13m       - ${FOLDER_WITH_PBP_FILES}/${PREFIX}${TR}${POSTFIX}\n\e[0m"
    done
fi
if [ ${#TEMP_ARRAY_TWO[@]} -ne 0 ] || [ ${#TEMP_ARRAY_ONE[@]} -ne 0 ]; then
    printf "\n\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)/2)) ))\n\n\e[0m"
    exit -1
fi

#Check that pbp values are present in the merged files
for FILE in ${PBP_FILENAMES[@]}; do
    TR=$(grep -o "[[:digit:]]*" <<< "$FILE")
    VALUES_PBP_FROM_SINGLE_FILE="$(awk 'BEGIN{ORS=" "}{print $2}' $FILE)"
    VALUES_PBP_FROM_MERGED_FILE="$(awk -v tr="$TR" '$1==tr{$1=""; print $0}' $MERGED_FILENAME)"
    #Remove spaces before comparison
    VALUES_PBP_FROM_SINGLE_FILE=$(sed 's/[ ]*//g' <<< "${VALUES_PBP_FROM_SINGLE_FILE}")
    VALUES_PBP_FROM_MERGED_FILE=$(sed 's/[ ]*//g' <<< "${VALUES_PBP_FROM_MERGED_FILE}")
    if [[ ${VALUES_PBP_FROM_SINGLE_FILE} != ${VALUES_PBP_FROM_MERGED_FILE} ]]; then
	printf "\n\e[38;5;9m Content of the file \"$FILE\" differs in \"$MERGED_FILENAME\"! Aborting...\n\e[0m"
	printf "\n\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)/2)) ))\n\n\e[0m"
	exit -1
    fi
done

#If everything fine exit 0
printf "\n\e[1;32m Merged file and unmerged files match!\n\e[0m"
printf "\n\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)/2)) ))\n\n\e[0m"

exit 0

