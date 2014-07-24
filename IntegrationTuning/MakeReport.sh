#!/bin/bash

# Just a short script to read out the situation from
# the folders present where the script is run.

function TimeToSeconds(){
    local T=$1; shift
    echo $((10#${T:0:2} * 3600 + 10#${T:3:2} * 60 + 10#${T:6:2})) 
}

function MinimumOfArray(){
    local MIN=$1; shift
    while [ "$1" != "" ]; do
	if [ $(echo "$1 $MIN" | awk '{if($1<$2){print 1}else{print 0}}') -eq 1 ]; then
	    MIN=$1
	fi
	shift
    done
    echo "$MIN"
}

function FindPositionOfFirstMinimumOfArray(){
    local ARRAY_TMP=("$@")
    local ARRAY=("$@")
    local MIN=$(MinimumOfArray "${ARRAY_TMP[@]}")
    for (( i=0; i<${#ARRAY[@]}; i++ )); do
	if [ "${ARRAY[$i]}" = "${MIN}" ]; then
	    echo $i;
	    break
	fi
    done
}


#-----------------------------------------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source $HOME/Script/PathManagement.sh || exit -2
CheckSingleOccurrenceInPath "scratch" "hfftheo" "$(whoami)" "mui" "k[[:digit:]]\+" "nt[[:digit:]]\+" "ns[[:digit:]]\+"
ReadParametersFromPath $(pwd)
BETA=$(echo "$(pwd)" | awk '{if(index($0, "/b") != 0){print substr($0, index($0, "/b") + 2, 6)}else{print 0}}')
if [[ ! $BETA =~ ^[0-9]+([.][0-9]+)?$ || $BETA = "0" ]]; then
    echo "Unable to recover beta from the path \"$(pwd)\". Aborting..."
    exit -1
fi
#-----------------------------------------------------------------------------------------------------------------#

#-----------------------------------------------------------------------------------------------------------------#
# Global variables declared in other scripts
#   CHEMPOT_PREFIX="mui"
#   NTIME_PREFIX="nt"
#   NSPACE_PREFIX="ns"
#   KAPPA_PREFIX="k"
#   CHEMPOT_POSITION=0
#   KAPPA_POSITION=1
#   NTIME_POSITION=2
#   NSPACE_POSITION=3
#   CHEMPOT
#   KAPPA
#   NSPACE
#   NTIME
#   PARAMETERS_PATH    <---This is the string in the path with the 4 parameters with slash in front, e.g. /muiPiT/k1550/nt6/ns12
#   PARAMETERS_STRING  <---This is the string in the path with the 4 parameters with underscores, e.g. muiPiT_k1550_nt6_ns12
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
FOLDERS=( $(ls) )
index=0
for NAME in ${FOLDERS[@]}; do
    if [ ! -d $NAME ] || [[ ! $NAME =~ ^[0-9]{1,2}_[0-9]{1,2}$ ]]; then
	unset FOLDERS[$index]
    fi
    index=$(($index+1))
done
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
ACCEPTANCE=()
TRAJECTORIES=()
DURATION=()
ALLRUNFINISHED=1
for NAME in ${FOLDERS[@]}; do
    if [ -f $NAME/hmc_output ]; then
	ACCEPTANCE+=( $(awk '{ sum+=$11} END {print 100*sum/(NR)}' $NAME/hmc_output) )
	TRAJECTORIES+=( $(wc -l $NAME/hmc_output | awk '{print $1}') )
    else
	ACCEPTANCE+=( "--" )
	TRAJECTORIES+=( "--")
	ALLRUNFINISHED=0
    fi
    if [ -f $NAME/hmc*.out ]; then
	START_TIME=( $(grep "\[[[:digit:]]\{2\}:[[:digit:]]\{2\}:[[:digit:]]\{2\}\] INFO:" $NAME/hmc*.out | head -n1 | grep -o "[[:digit:]]\{2\}:[[:digit:]]\{2\}:[[:digit:]]\{2\}" ) )
	END_TIME=( $(grep "\[[[:digit:]]\{2\}:[[:digit:]]\{2\}:[[:digit:]]\{2\}\] INFO:" $NAME/hmc*.out | tail -n1 | grep -o "[[:digit:]]\{2\}:[[:digit:]]\{2\}:[[:digit:]]\{2\}") )
	DURATION+=( $(( $(TimeToSeconds $END_TIME) - $(TimeToSeconds $START_TIME) )) )
    else
	DURATION+=( 0 )
	ALLRUNFINISHED=0
    fi
done
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
printf "\n\e[0;36m=======================================================\e[0m\n"
printf "\e[0;35m\e[2m  kappa=0.$KAPPA  ns=$NSPACE  beta=$BETA\e[0m"
TABLE_FORMAT="%-8s%-5s%-9s%-5s%-8s"
printf "\n\e[0;36m=======================================================\e[0m\n"
printf "\e[0;34m\e[2m$TABLE_FORMAT\e[0m\n"   "SETUP:" ""   "DURATION:" ""   "ACC-RATE:"

if [ $ALLRUNFINISHED -eq 0 ]; then
    for ((i=0; i<${#FOLDERS[@]}; i++)); do
	printf "$TABLE_FORMAT\e[0m\n"   "${FOLDERS[$i]}" ""   " $(( (${DURATION[$i]}-${DURATION[$i]}%60)/60 ))m $(( ${DURATION[$i]}%60 ))s" ""   "${ACCEPTANCE[$i]}%"
    done
else
    while [ ${#FOLDERS[@]} -gt 0 ]; do
	i=$(FindPositionOfFirstMinimumOfArray "${ACCEPTANCE[@]}")
	printf "$TABLE_FORMAT%3s%-15s\e[0m\n"   "${FOLDERS[$i]}" ""   " $(( (${DURATION[$i]}-${DURATION[$i]}%60)/60 ))m $(( ${DURATION[$i]}%60 ))s" ""   "${ACCEPTANCE[$i]}%" "" "(out of ${TRAJECTORIES[$i]})"
	unset FOLDERS[$i]; FOLDERS=( "${FOLDERS[@]}" )
	unset DURATION[$i]; DURATION=( "${DURATION[@]}" )
	unset ACCEPTANCE[$i]; ACCEPTANCE=( "${ACCEPTANCE[@]}" )
	unset TRAJECTORIES[$i]; TRAJECTORIES=( "${TRAJECTORIES[@]}" )
    done    
fi
printf "\e[0;36m=======================================================\e[0m\n\n"

