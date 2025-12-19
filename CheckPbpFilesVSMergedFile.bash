#!/bin/bash

# Script to check that in the files conf.XXXXX_pbp.dat the values
# of the pbp is the same of that contained in the merged file. It has
# to be run in the folder where the pbp files are.

PREFIX="conf."
POSTFIX="_pbp.dat"
DIGITS=5
MERGED_FILENAME="pbp.dat"
FOLDER_WITH_PBP_FILES="."
CREATE_ARCHIVE_AND_DELETE_PBP_FOLDER="TRUE"
[ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ] && MERGED_FILENAME="rhmc_output_pbp.dat"
[ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ] && MERGED_FILENAME="hmc_output_pbp.dat"

while [ "$1" != "" ]; do
    case $1 in
	-h | --help )
            printf "\n\e[0;32m"
            echo "Call the script $0 with the following optional arguments:"
            echo "  -h | --help"
            echo "  -f | --mergedFilename          ->    default value = $MERGED_FILENAME"
	    echo "  -d | --digitsInConfName        ->    default value = $DIGITS"
	    echo "  --folderWithPbpFiles           ->    default value = $FOLDER_WITH_PBP_FILES"
	    echo "  --prefixInConfName             ->    default value = $PREFIX"
	    echo "  --postfixInConfName            ->    default value = $POSTFIX"
	    echo "  --doNotMakeTarAndDoNotDelete   ->    if given, the .tar is not created and pbp files are not deleted"
            printf "\n\e[0m"
            exit
            shift;;
	-f=* | --mergedFilename=* )      MERGED_FILENAME=${1#*=}; shift ;;
	-d=* | --digitsInConfName=* )    DIGITS=${1#*=}; shift ;;
	--folderWithPbpFiles=* )         FOLDER_WITH_PBP_FILES=${1#*=}; shift ;;
	--prefixInConfName=* )           PREFIX=${1#*=}; shift ;;
	--postfixInConfName=* )          POSTFIX=${1#*=}; shift ;;
	--doNotMakeTarAndDoNotDelete )   CREATE_ARCHIVE_AND_DELETE_PBP_FOLDER="FALSE"; shift ;;
	* ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
done

#=================================================================================================================================

function __static__drawProgressBar() {
    STEPS_DONE="$1"
    TOTAL_STEPS="$2"
    #Progress bar for the user
    # NOTE: The default behavior for printf if you give it more arguments than there are specified in the format string is to loop back to the beginning of the format string and run it again.
    #       In printf %0.s is a string of zero char (%0s) and the period tells printf to truncate the string if it's longer than the specified length (otherwise it prints everything) [BASH specific]
    PERCENTAGE_DONE=$(($STEPS_DONE*100/$TOTAL_STEPS))
    if [ $PERCENTAGE_DONE -eq 0 ]; then
	PROGRESS_BAR="\e[38;5;14m Checking pbp values: \e[0m [$(printf '%0.s.' {1..100})] ($STEPS_DONE/$TOTAL_STEPS)\e[K\r"
    elif [ $PERCENTAGE_DONE -ne 100 ]; then
	TIME_TO_END=$(bc -l <<< "($(date +%s) - $START_TIME)/$PERCENTAGE_DONE*(100-$PERCENTAGE_DONE)" | awk '{printf "%5d", $1}')
	PROGRESS_BAR="\e[38;5;14m Checking pbp values: \e[0m [$(printf '%0.s=' $(seq 1 $PERCENTAGE_DONE))$(printf '%0.s.' $(seq 1 $((100-$PERCENTAGE_DONE))))] ($STEPS_DONE/$TOTAL_STEPS)   $TIME_TO_END sec. to end\e[K\r"
    fi
    printf "$PROGRESS_BAR"
}

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
else
    if [ "${FOLDER_WITH_PBP_FILES: -1}" = "/" ]; then
	FOLDER_WITH_PBP_FILES="${FOLDER_WITH_PBP_FILES%?}"
    fi
    if [ $(grep -o "/" <<< "$FOLDER_WITH_PBP_FILES" | wc -l) -eq 0 ]; then
	FOLDER_WITH_PBP_FILES="./$FOLDER_WITH_PBP_FILES"
    fi
fi

#Gather information
START_TIME=`date +%s`
printf "\n\e[38;5;69m Extracting trajectories numbers... \e[0m"
PBP_FILENAMES=( $(find ${FOLDER_WITH_PBP_FILES} -name "${PREFIX}*${POSTFIX}" -type f 2>/dev/null) )
NUMBER_PBP_FILES=${#PBP_FILENAMES[@]}
LINES_MERGED_FILE=$(wc -l < ${MERGED_FILENAME})
TRAJECTORY_IN_PBP_FILES=( $(grep -o "[[:digit:]]*" <<< "${PBP_FILENAMES[@]}" | awk '{printf "%d ", $1}') ) #Awk will strip leading zeros
TRAJECTORY_IN_MERGED_FILE=( $(awk '{print $1}' $MERGED_FILENAME | sort | uniq) )
printf "\e[38;5;69m done in $(( $(date +%s) - $START_TIME )) seconds!\n\e[0m"
#Check repeated lines
if [ ${#TRAJECTORY_IN_MERGED_FILE[@]} -ne $LINES_MERGED_FILE ]; then
    printf "\n\e[38;5;11m WARNING: Merged pbp file has repeated lines!\n\e[0m"
fi
#Check on number of files
START_TIME=`date +%s`
printf "\n\e[38;5;69m Crosschecking trajectories... \e[0m"
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
printf "\e[38;5;69m done in $(( $(date +%s) - $START_TIME )) seconds!\n\e[0m"

#Check that pbp values are present in the merged files
COUNTER=0
PROGRESS_BAR_LAST_UPDATE=0
START_TIME=`date +%s`
printf "\n\e[38;5;14m Checking pbp values: \r\e[0m"
for FILE in ${PBP_FILENAMES[@]}; do
    PERCENTAGE_DONE=$(($COUNTER*100/${#PBP_FILENAMES[@]}))
    if [ $PERCENTAGE_DONE -ge $PROGRESS_BAR_LAST_UPDATE ]; then
	(( PROGRESS_BAR_LAST_UPDATE+=1 ))
	__static__drawProgressBar $COUNTER ${#PBP_FILENAMES[@]}
    fi
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
    COUNTER=$(($COUNTER+1))
done
printf "\e[38;5;14m Checking pbp values: \e[0m [$(printf '%0.s=' {1..100})] ($COUNTER/${#PBP_FILENAMES[@]})\e[K\n"

#If everything fine create the .tar archive and delete folder with pbp files
printf "\n\e[1;32m Merged file and unmerged files match!\n\e[0m"
if [ $CREATE_ARCHIVE_AND_DELETE_PBP_FOLDER = "TRUE" ]; then
    FOLDER_WITH_PBP_FILES_BASENAME=${FOLDER_WITH_PBP_FILES##*/}
    PATH_TO_FOLDER_WITH_PBP_FILES=${FOLDER_WITH_PBP_FILES%/*}
    ARCHIVE_NAME="${FOLDER_WITH_PBP_FILES_BASENAME}.tar.gz"
    if [ -f $ARCHIVE_NAME ]; then
	ARCHIVE_NAME_BACKUP="${ARCHIVE_NAME/.tar.gz/}_$(date +'%F_%H%M').tar.gz"
	printf "\n\e[38;5;11m WARNING: Found \"$ARCHIVE_NAME\" existing archive, renaming it to \"$ARCHIVE_NAME_BACKUP\"!\n\e[0m"
	mv $ARCHIVE_NAME $ARCHIVE_NAME_BACKUP || exit -2
    fi
    cd $PATH_TO_FOLDER_WITH_PBP_FILES
    printf "\n\e[38;5;69m Creating archive \"$ARCHIVE_NAME\" in $PWD folder... \e[0m"
    tar czf ${ARCHIVE_NAME} ${FOLDER_WITH_PBP_FILES_BASENAME}
    printf "\e[38;5;69m done!\n\e[0m"
    printf "\n\e[38;5;69m Removing folder \"$FOLDER_WITH_PBP_FILES_BASENAME\" from $PWD folder... \e[0m"
    rm -r ${FOLDER_WITH_PBP_FILES_BASENAME}
    printf "\e[38;5;69m done!\n\e[0m"
    cd - >> /dev/null
fi

printf "\n\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)/2)) ))\n\n\e[0m"

exit 0

