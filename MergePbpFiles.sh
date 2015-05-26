#!/bin/bash

# Script to merge several pbp files into one. It has to be run in the folder
# where the pbp files are. The name of the files is by defaut conf.XXXXX_pbp.dat
# but it can be changed.
#
# The output file is called hmc_output_pbp.dat and it will contain in each line
# the trajectory number XXXXX and then all the pbp estimate.

PREFIX="conf."
POSTFIX="_pbp.dat"
DIGITS=5
OUTPUT_FILENAME="hmc_output_pbp.dat"
SKIP_BROKEN_FILES="TRUE"
MOVE_PBP_FILES="TRUE"
FOLDER_TO_MOVE_SINGLE_FILES_TO="PbpSingleFiles"
BROKEN_FILES_FOLDER="BrokenPbpSingleFiles"
EMPTY_FILES_FOLDER="EmptyFiles"

while [ "$1" != "" ]; do
    case $1 in
	-h | --help )
            printf "\n\e[0;32m"
            echo "Call the script $0 with the following optional arguments:"
            echo "  -h | --help"
            echo "  -q | --doNotLookForBrokenFiles        ->    merge all files, without checks"
	    echo "  -o | --outputFilename                 ->    default value = $OUTPUT_FILENAME"
	    echo "  -d | --digitsInConfName               ->    default value = $DIGITS"
	    echo "  --doNotMovePbpFiles                   ->    leave pbp files where they are"
	    echo "  --folderWhereToMoveMergedPbpFiles     ->    default value = $FOLDER_TO_MOVE_SINGLE_FILES_TO"
	    echo "  --folderWhereToMoveBrokenPbpFiles     ->    default value = $BROKEN_FILES_FOLDER"
	    echo "  --prefixInConfName                    ->    default value = $PREFIX"
	    echo "  --postfixInConfName                   ->    default value = $POSTFIX"
            printf "\n\e[0m"
            exit
            shift;;
	-q | --doNotLookForBrokenFiles )        SKIP_BROKEN_FILES="FALSE"; shift ;;
	-o=* | --outputFilename=* )             OUTPUT_FILENAME=${1#*=}; shift ;;
	-d=* | --digitsInConfName=* )           DIGITS=${1#*=}; shift ;;
	--doNotMovePbpFiles )                   MOVE_PBP_FILES="FALSE"; shift ;;
	--folderWhereToMoveMergedPbpFiles=* )   FOLDER_TO_MOVE_SINGLE_FILES_TO=${1#*=}; shift ;;
	--folderWhereToMoveBrokenPbpFiles=* )   BROKEN_FILES_FOLDER=${1#*=}; shift ;;
	--prefixInConfName=* )                  PREFIX=${1#*=}; shift ;;
	--postfixInConfName=* )                 POSTFIX=${1#*=}; shift ;;
	* ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
done

#=================================================================================================================================

function __static__getAnswer() {
    local CONFIRM="";
    while read CONFIRM; do
        if [ "$CONFIRM" = "Y" ]; then
            break;
        elif [ "$CONFIRM" = "N" ]; then
            exit 0
        else
            printf "\n\e[38;5;196m            Please enter Y (yes) or N (no): \e[0m"
        fi
    done
}

function __static__drawProgressBar() {
    STEPS_DONE="$1"
    TOTAL_STEPS="$2"
    #Progress bar for the user
    # NOTE: The default behavior for printf if you give it more arguments than there are specified in the format string is to loop back to the beginning of the format string and run it again.
    #       In printf %0.s is a string of zero char (%0s) and the period tells printf to truncate the string if it's longer than the specified length (otherwise it prints everything) [BASH specific]
    PERCENTAGE_DONE=$(($STEPS_DONE*100/$TOTAL_STEPS))
    if [ $PERCENTAGE_DONE -eq 0 ]; then
	PROGRESS_BAR="\e[38;5;14m Merging: \e[0m [$(printf '%0.s.' {1..100})] ($STEPS_DONE/$TOTAL_STEPS)\e[K\r"
    elif [ $PERCENTAGE_DONE -ne 100 ]; then
	TIME_TO_END=$(bc -l <<< "($(date +%s) - $START_TIME)/$PERCENTAGE_DONE*(100-$PERCENTAGE_DONE)" | awk '{printf "%5d", $1}')
	PROGRESS_BAR="\e[38;5;14m Merging: \e[0m [$(printf '%0.s=' $(seq 1 $PERCENTAGE_DONE))$(printf '%0.s.' $(seq 1 $((100-$PERCENTAGE_DONE))))] ($STEPS_DONE/$TOTAL_STEPS)   $TIME_TO_END sec. to end\e[K\r"
    fi
    printf "$PROGRESS_BAR"
}


function __static__isFileBroken(){
    local FILE="$1"
    #Check if file is not empty, in the sense of zero bytes
    if [ ! -s $FILE ]; then
	return 1
    fi
    #Check on first column (trajectory number)
    local FILE_PROCESS_RESULT=$(awk -v trNum="$TRAJECTORY_IN_PBP_FILE" 'BEGIN{errorCode=0; pbpMerged=""}\
                                  {if(NF!=2){errorCode=2; exit}
                                   if($1 !~ /^[[:digit:]]+$/){errorCode=3; exit}
                                   if($2 !~ /^[+-]?[[:digit:]]{1}[.][[:digit:]]+[e][+-]?[[:digit:]]+$/){errorCode=4; exit}
                                   pbpMerged = pbpMerged "   " $2 
                                  }END{print errorCode"|"$1"|"pbpMerged}' $FILE)
    if [ ${FILE_PROCESS_RESULT%%|*} -ne 0 ]; then
	return ${FILE_PROCESS_RESULT%%|*}
    else
	PBP_MERGED_VALUES=$(sed -e 's/^[[:space:]]*//' <<< "${FILE_PROCESS_RESULT##*|}")
    fi
    #Compare trajectory number of filename with real one
    local TRAJECTORY_FROM_PBP_FILENAME=$(sed 's/'$PREFIX'\(.*\)'$POSTFIX'/\1/g' <<< "$FILE")
    local TRAJECTORY_FROM_PBP_FILE=$(sed 's/.*|\(.*\)|.*/\1/g' <<< "$FILE_PROCESS_RESULT")
    if [ "$TRAJECTORY_FROM_PBP_FILENAME" -ne "$TRAJECTORY_FROM_PBP_FILE" ]; then
	return 5
    fi
    #File is not broken
    PBP_MERGED_VALUES="$TRAJECTORY_FROM_PBP_FILE\t\t$PBP_MERGED_VALUES\n"
    return 0
}

#=================================================================================================================================
printf "\n\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)/2)) ))\n\e[0m"

#Look for pbp files
PBP_FILENAMES=()
for FILE in *; do
    if [[ $FILE =~ ^$PREFIX[[:digit:]]{$DIGITS}$POSTFIX$ ]]; then
	PBP_FILENAMES+=( "$FILE" )
    fi
done
if [ ${#PBP_FILENAMES[@]} -eq 0 ]; then printf "\e[38;5;9m"; else printf "\e[38;5;10m"; fi
printf "\n Found ${#PBP_FILENAMES[@]} pbp files!\n\e[0m"
if [ ${#PBP_FILENAMES[@]} -eq 0 ]; then printf "\n\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)/2)) ))\n\n\e[0m"; exit -1; fi

#Some checks on files and directories
if [ -f $OUTPUT_FILENAME ]; then
    printf "\n\e[38;5;11m WARNING: Found \"$OUTPUT_FILENAME\" existing file, new pbp values will be appended to it!\n\e[0m"
    OUTPUT_FILENAME_BACKUP=${OUTPUT_FILENAME}_$(date +'%F_%H%M')
    cp $OUTPUT_FILENAME $OUTPUT_FILENAME_BACKUP || exit -2
fi

if [ $MOVE_PBP_FILES == "TRUE" ]; then
    if [ -d $FOLDER_TO_MOVE_SINGLE_FILES_TO ]; then
	printf "\n\e[38;5;11m WARNING: Found \"$FOLDER_TO_MOVE_SINGLE_FILES_TO\" existing folder, files will be added there!\n\e[0m"
    else
	mkdir $FOLDER_TO_MOVE_SINGLE_FILES_TO || exit -2
    fi
    if [ -d $BROKEN_FILES_FOLDER ]; then
	printf "\n\e[38;5;196m ATTENTION: Found \"$BROKEN_FILES_FOLDER\" existing folder, files will be moved there: risk of overwriting existing files, continue (Y/N)? \e[0m"
	__static__getAnswer
    else
	mkdir $BROKEN_FILES_FOLDER || exit -2
    fi
    if [ -d $BROKEN_FILES_FOLDER/$EMPTY_FILES_FOLDER ]; then
	printf "\e[38;5;196m ATTENTION: Found \"$EMPTY_FILES_FOLDER\" existing folder, files will be moved there: risk of overwriting existing files, continue (Y/N)? \e[0m"
	__static__getAnswer
    else
	mkdir -p $BROKEN_FILES_FOLDER/$EMPTY_FILES_FOLDER || exit -2
    fi
fi



#MAIN part of the script
if [[ "$SKIP_BROKEN_FILES" == "TRUE" ]]; then
    BROKEN_FILENAMES=()	
    EMPTY_FILENAMES=()	
    COUNTER=0
    PROGRESS_BAR_LAST_UPDATE=0
    START_TIME=`date +%s`
    printf "\n\e[38;5;14m Merging: \r\e[0m"
    for FILE in ${PBP_FILENAMES[@]}; do
	if __static__isFileBroken $FILE; then
	    PERCENTAGE_DONE=$(($COUNTER*100/${#PBP_FILENAMES[@]}))
	    if [ $PERCENTAGE_DONE -ge $PROGRESS_BAR_LAST_UPDATE ]; then
		(( PROGRESS_BAR_LAST_UPDATE+=1 ))
		__static__drawProgressBar $COUNTER ${#PBP_FILENAMES[@]}
	    fi
	    COUNTER=$(($COUNTER+1))
	    #Merge
	    printf "$PBP_MERGED_VALUES" >> $OUTPUT_FILENAME
	    #Move pbp single file to folder
	    if [ $MOVE_PBP_FILES == "TRUE" ]; then
		if [ -f $FOLDER_TO_MOVE_SINGLE_FILES_TO/$FILE ]; then
		    printf "\e[38;5;9m ATTENTION: In folder \"$FOLDER_TO_MOVE_SINGLE_FILES_TO\", file \"$FILE\" already exists! It will be not moved!!\e[0m\e[K\n$PROGRESS_BAR"
		else
		    mv $FILE $FOLDER_TO_MOVE_SINGLE_FILES_TO || exit -2
		fi
	    fi
	else
	    case $? in
		1 ) printf "\e[38;5;9m File \"$FILE\" is broken: empty file!\e[0m"; EMPTY_FILENAMES+=( $FILE ) ;;
		2 ) printf "\e[38;5;9m File \"$FILE\" is broken: found NOT 2 columns on at least one line\e[0m"; BROKEN_FILENAMES+=( $FILE ) ;;
		3 ) printf "\e[38;5;9m File \"$FILE\" is broken: at least one traj. does not match the required format\e[0m"; BROKEN_FILENAMES+=( $FILE ) ;;
		4 ) printf "\e[38;5;9m File \"$FILE\" is broken: at least one value does not match the required format\e[0m"; BROKEN_FILENAMES+=( $FILE ) ;;
		5 ) printf "\e[38;5;9m File \"$FILE\" is broken: trajectory number different from those in the name\e[0m"; BROKEN_FILENAMES+=( $FILE ) ;;
	    esac
	    COUNTER=$(($COUNTER+1))
	    printf "\e[K\n$PROGRESS_BAR"
	fi
    done
    printf "\e[38;5;14m Merging: \e[0m [$(printf '%0.s=' {1..100})] ($COUNTER/${#PBP_FILENAMES[@]})\e[K\n"
    #Report to user and move broken files to own folder
    if [ ${#BROKEN_FILENAMES[@]} -eq 0 ] && [ ${#EMPTY_FILENAMES[@]} -eq 0 ]; then
	printf "\n\e[38;5;10m No pbp file has been detected as broken!\n\e[0m"
    else
	printf "\n\e[38;5;9m Found ${#BROKEN_FILENAMES[@]} broken pbp file(s) and ${#EMPTY_FILENAMES[@]} pbp file(s):\n\e[0m"
    fi
    for FILE in "${BROKEN_FILENAMES[@]}"; do
	printf "\e[38;5;202m  - $FILE\n\e[0m"
	if [ $MOVE_PBP_FILES == "TRUE" ]; then
	    mv $FILE $BROKEN_FILES_FOLDER || exit -2
	fi
    done
    for FILE in "${EMPTY_FILENAMES[@]}"; do
	printf "\e[38;5;226m  - $FILE\n\e[0m"
	if [ $MOVE_PBP_FILES == "TRUE" ]; then
	    mv $FILE $BROKEN_FILES_FOLDER/$EMPTY_FILES_FOLDER || exit -2
	fi
    done

#=================================================================================================================================
else

    printf "\n\e[38;5;14m Merging: \r\e[0m"
    COUNTER=0
    PROGRESS_BAR_LAST_UPDATE=0
    START_TIME=`date +%s`
    for FILE in ${PBP_FILENAMES[@]}; do
	PERCENTAGE_DONE=$(($COUNTER*100/${#PBP_FILENAMES[@]}))
	if [ $PERCENTAGE_DONE -ge $PROGRESS_BAR_LAST_UPDATE ]; then
	    (( PROGRESS_BAR_LAST_UPDATE+=1 ))
	    __static__drawProgressBar $COUNTER ${#PBP_FILENAMES[@]}
	fi
	#Merge
	TRAJECTORY_IN_PBP_FILE=$(head -n1 $FILE | cut -f1)
	if [ "$TRAJECTORY_IN_PBP_FILE" = "" ]; then
	    TRAJECTORY_IN_PBP_FILE=$(grep -o "[[:digit:]]\{$DIGITS\}" <<< "$FILE")
	fi
	printf "%s\t\t" "$TRAJECTORY_IN_PBP_FILE" >> $OUTPUT_FILENAME
	awk '{printf "%s   ", $2}END{printf "\n"}' $FILE >> $OUTPUT_FILENAME
	COUNTER=$(($COUNTER+1))
	#Move
	if [ $MOVE_PBP_FILES == "TRUE" ]; then
	    if [ -f $FOLDER_TO_MOVE_SINGLE_FILES_TO/$FILE ]; then
		printf "\e[38;5;9m ATTENTION: In folder \"$FOLDER_TO_MOVE_SINGLE_FILES_TO\", file \"$FILE\" already exists! It will be not moved!!\e[0m\e[K\n\e[0m$PROGRESS_BAR"
	    else
		mv $FILE $FOLDER_TO_MOVE_SINGLE_FILES_TO || exit -2
	    fi
	fi
    done
    printf "\e[38;5;14m Merging: \e[0m [$(printf '%0.s=' {1..100})] ($COUNTER/${#PBP_FILENAMES[@]})\e[K\n"
fi

#=================================================================================================================================
printf "\n\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)/2)) ))\n\n\e[0m"
