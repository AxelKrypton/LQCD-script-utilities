#!/bin/bash

# Script to merge several pbp files into one. It has to be run in the folder
# where the pbp files are. The name of the files is conf.XXXXX_pbp.dat
# and it is checked that all have the same length in lines. Those with different
# lines are treated according to the option --ignoreBrokenFiles.
#
# The output file is called hmc_output_pbp.dat and it will contain in each line
# the trajectory number XXXXX and then all the pbp estimate.

PREFIX="conf."
POSTFIX="_pbp.dat"
DIGITS=5
OUTPUT_FILENAME="hmc_output_pbp.dat"
IGNORE_BROKEN_FILES="FALSE"
MERGE_FILES="TRUE"
NUMBER_OF_SOURCES=16
MOVE_PBP_FILES="TRUE"
FOLDER_TO_MOVE_SINGLE_FILES_TO="PbpSingleFiles"

while [ "$1" != "" ]; do
    case $1 in
	-h | --help )
            printf "\n\e[0;32m"
            echo "Call the script $0 with the following optional arguments:"
            echo "  -h | --help"
            echo "  -i | --ignoreBrokenFiles       ->    look for broken files and ignore them"
            echo "  -m | --doNotMergeFiles         ->    skip the merging prcedure"
            echo "  -s | --numberOfSources         ->    default value = $NUMBER_OF_SOURCES"
	    echo "  -o | --outputFilename          ->    default value = $OUTPUT_FILENAME"
	    echo "  -d | --digitsInConfName        ->    default value = $DIGITS"
	    echo "  --doNotMovePbpFiles            ->    leave pbp files where they are"
	    echo "  --folderWhereToMovePbpFiles    ->    default value = $FOLDER_TO_MOVE_SINGLE_FILES_TO"
	    echo "  --prefixInConfName             ->    default value = $PREFIX"
	    echo "  --postfixInConfName            ->    default value = $POSTFIX"
            printf "\n\e[0m"
            exit
            shift;;
	-i | --ignoreBrokenFiles )       IGNORE_BROKEN_FILES="TRUE"; shift ;;
	-m | --doNotMergeFiles )         MERGE_FILES="FALSE"; shift ;;
	-s=* | --numberOfSources=* )     NUMBER_OF_SOURCES=${1#*=}; shift ;;
	-o=* | --outputFilename=* )      OUTPUT_FILENAME=${1#*=}; shift ;;
	-d=* | --digitsInConfName=* )    DIGITS=${1#*=}; shift ;;
	--doNotMovePbpFiles )            MOVE_PBP_FILES="FALSE"; shift ;;
	--folderWhereToMovePbpFiles=* )  FOLDER_TO_MOVE_SINGLE_FILES_TO=${1#*=}; shift ;;
	--prefixInConfName=* )           PREFIX=${1#*=}; shift ;;
	--postfixInConfName=* )          POSTFIX=${1#*=}; shift ;;
	* ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
done

#=================================================================================================================================
printf "\n\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)/2)) ))\n\e[0m"

#Look for pbp files and check them
PBP_FILENAMES=()
for FILE in *; do
    if [[ $FILE =~ ^$PREFIX[[:digit:]]{$DIGITS}$POSTFIX$ ]]; then
	PBP_FILENAMES+=( "$FILE" )
    fi
done

if [ ${#PBP_FILENAMES[@]} -eq 0 ]; then printf "\e[38;5;9m"; else printf "\e[38;5;10m"; fi
printf "\n Found ${#PBP_FILENAMES[@]} pbp files!\n\e[0m"
if [ ${#PBP_FILENAMES[@]} -eq 0 ]; then exit -1; fi


if [[ "$IGNORE_BROKEN_FILES" == "TRUE" ]]; then
    BROKEN_FILENAMES=()	
    for INDEX in ${!PBP_FILENAMES[@]}; do
	if [ $(wc -l < ${PBP_FILENAMES[$INDEX]}) -ne $NUMBER_OF_SOURCES ]; then
	    BROKEN_FILENAMES+=( "${PBP_FILENAMES[$INDEX]}" )
	    unset -v 'PBP_FILENAMES[$INDEX]'
	    continue
	fi
	TRAJECTORY_IN_PBP_FILE=$(grep -o "[[:digit:]]*" <<< "${PBP_FILENAMES[$INDEX]}") 
	if [ $(awk -v trNum="$TRAJECTORY_IN_PBP_FILE" 'BEGIN{wrong=0}{if($1 != trNum){wrong=1; exit}}END{print wrong}' ${PBP_FILENAMES[$INDEX]}) -eq 1 ]; then
	    BROKEN_FILENAMES+=( "${PBP_FILENAMES[$INDEX]}" )
            unset -v 'PBP_FILENAMES[$INDEX]'
            continue
	fi
    done  
    if [ ${#BROKEN_FILENAMES[@]} -eq 0 ]; then
	printf "\n\e[38;5;10m No pbp file has been detected as broken!\n\e[0m"
    else
	printf "\n\e[38;5;9m Found ${#BROKEN_FILENAMES[@]} broken pbp files:\n\e[0m"
    fi
    for FILE in ${BROKEN_FILENAMES[@]}; do
	printf "\e[38;5;208m  - $FILE\n\e[0m"
    done
fi

if [[ "$MERGE_FILES" == "TRUE" ]]; then
    if [ $MOVE_PBP_FILES == "TRUE" ]; then
	if [ -d $FOLDER_TO_MOVE_SINGLE_FILES_TO ]; then
	    FOLDER_TO_MOVE_SINGLE_FILES_TO_BACKUP=${FOLDER_TO_MOVE_SINGLE_FILES_TO}_$(date +'%F_%H%M')
	    printf "\n\e[38;5;11m WARNING: Found \"$FOLDER_TO_MOVE_SINGLE_FILES_TO\" folder, renamed to \"$FOLDER_TO_MOVE_SINGLE_FILES_TO_BACKUP\"\n\e[0m"
	    mv $FOLDER_TO_MOVE_SINGLE_FILES_TO $FOLDER_TO_MOVE_SINGLE_FILES_TO_BACKUP || exit -2
	fi
	mkdir $FOLDER_TO_MOVE_SINGLE_FILES_TO || exit -2
    fi
    if [ -f $OUTPUT_FILENAME ]; then
	OUTPUT_FILENAME_BACKUP=${OUTPUT_FILENAME}_$(date +'%F_%H%M')
	printf "\n\e[38;5;11m WARNING: Found \"$OUTPUT_FILENAME\" file, renamed to \"$OUTPUT_FILENAME_BACKUP\"\n\e[0m"
	mv $OUTPUT_FILENAME $OUTPUT_FILENAME_BACKUP || exit -2
    fi
    printf "\n\e[38;5;14m Merging: \r\e[0m"
    COUNTER=0
    PROGRESS_BAR_LAST_UPDATE=0
    START_TIME=`date +%s`
    for FILE in ${PBP_FILENAMES[@]}; do
	#Progress bar for the user
	# NOTE: The default behavior for printf if you give it more arguments than there are specified in the format string is to loop back to the beginning of the format string and run it again.
	#       In printf %0.s is a string of zero char (%0s) and the period tells printf to truncate the string if it's longer than the specified length (otherwise it prints everything) [BASH specific]
	PERCENTAGE_DONE=$(($COUNTER*100/${#PBP_FILENAMES[@]}))
	if [ $PERCENTAGE_DONE -ge $PROGRESS_BAR_LAST_UPDATE ]; then
	    (( PROGRESS_BAR_LAST_UPDATE+=2 ))
	    if [ $PERCENTAGE_DONE -eq 0 ]; then
		PROGRESS_BAR="\e[38;5;14m Merging: \e[0m [$(printf '%0.s.' {1..100})] ($COUNTER/${#PBP_FILENAMES[@]})\e[K\r"
	    elif [ $PERCENTAGE_DONE -ne 100 ]; then
		TIME_TO_END=$(bc -l <<< "($(date +%s) - $START_TIME)/$PERCENTAGE_DONE*(100-$PERCENTAGE_DONE)" | awk '{printf "%5d", $1}')
		PROGRESS_BAR="\e[38;5;14m Merging: \e[0m [$(printf '%0.s=' $(seq 1 $PERCENTAGE_DONE))$(printf '%0.s.' $(seq 1 $((100-$PERCENTAGE_DONE))))] ($COUNTER/${#PBP_FILENAMES[@]})   $TIME_TO_END sec. to end\e[K\r"
	    fi
	    printf "$PROGRESS_BAR"
	fi
	#Merge
	TRAJECTORY_IN_PBP_FILE=$(grep -o "[[:digit:]]\{$DIGITS\}" <<< "$FILE")
	printf "%s\t\t" "$TRAJECTORY_IN_PBP_FILE" >> $OUTPUT_FILENAME
	awk '{printf "%s   ", $2}END{printf "\n"}' $FILE >> $OUTPUT_FILENAME
	COUNTER=$(($COUNTER+1))
	#Move
	if [ $MOVE_PBP_FILES == "TRUE" ]; then
	    mv $FILE $FOLDER_TO_MOVE_SINGLE_FILES_TO || exit -2
	fi
    done
    printf "\e[38;5;14m Merging: \e[0m [$(printf '%0.s=' {1..100})] ($COUNTER/${#PBP_FILENAMES[@]})\e[K\n"
fi


printf "\n\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)/2)) ))\n\n\e[0m"
