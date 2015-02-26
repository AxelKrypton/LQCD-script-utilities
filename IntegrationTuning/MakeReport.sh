#!/bin/bash

# Just a short script to read out the situation from
# the folders present where the script is run.
SHOW_ONLY_MP="FALSE"

function ParseCommandLineOption(){
    while [ "$1" != "" ]; do
	case $1 in
	    -h | --help )
		printf "\n\e[0;32m"
		echo "Call the script $0 with the following optional arguments:"
		echo ""
		echo "  -h | --help"
		echo "  -a | --orderAcceptance      ->    Print report with increasing Acceptance Rate"
		echo "  -t | --orderTime            ->    Print report with increasing Simulation Time"
		echo "  -f | --orderFolder          ->    Print report with increasing Folder Name"
		echo "  -m | --showOnlyMP           ->    Print report of only mass preconditioning tuning"
		echo ""
		echo "NOTE: If more than one of the options -a, -t and -f are given, the last is used! By default -a is used."
		printf "\n\e[0m"
		exit
		shift;;
	    -a | --orderAcceptance )  ORDER_PARAMETER="ACCEPTANCE"; shift ;;
	    -t | --orderTime )        ORDER_PARAMETER="DURATION"; shift ;;
	    -f | --orderFolder )      ORDER_PARAMETER="FOLDERS"; shift ;;
	    -m | --showOnlyMP )       SHOW_ONLY_MP="TRUE"; shift ;;
	    * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
	esac
    done
}


#-----------------------------------------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source $HOME/Script/UtilityFunctions.sh || exit -2
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
ORDER_PARAMETER="ACCEPTANCE"
ParseCommandLineOption $@
FOLDERS=( $(ls) )
for INDEX in "${!FOLDERS[@]}"; do
    NAME=${FOLDERS[$INDEX]}
    if [ ! -d $NAME ] || [[ ! $NAME =~ ^[0-9]{1,2}_[0-9]{1,2}.*$ ]]; then
	unset FOLDERS[$INDEX]
    fi
    if [[ $SHOW_ONLY_MP == "TRUE" ]] && [[ ! $NAME =~ ^[0-9]{1,2}_[0-9]{1,2}_[0-9]{1,2}_kmp[0-9]{3,4}$ ]]; then
	unset FOLDERS[$INDEX]
    fi
done
FOLDERS=( "${FOLDERS[@]}" ) #Make FOLDERS not sparse for the following!!!
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
ACCEPTED=()
TRAJECTORIES=()
DURATION=()
MAX_DELTAS=()
ALLRUNFINISHED=1
for NAME in ${FOLDERS[@]}; do
    if [ -f $NAME/hmc_output ]; then
	ACCEPTED+=( $(awk '{ sum+=$11} END {print sum}' $NAME/hmc_output) )
	TRAJECTORIES+=( $(wc -l $NAME/hmc_output | awk '{print $1}') )
	MAX_DELTAS+=( $(awk 'BEGIN {max=0} {if(sqrt($8^2)>max){max=sqrt($8^2)}} END {printf "%6g", max}' $NAME/hmc_output) )
    else
	ACCEPTED+=( "--" )
	TRAJECTORIES+=( "--")
	MAX_DELTAS+=( "--" )
	ALLRUNFINISHED=0
    fi
    if [ -f $NAME/hmc*.out ]; then
	START_TIME=( $(grep "Start generation of configurations..." $NAME/hmc*.out | grep -o "[[:digit:]]\{2\}:[[:digit:]]\{2\}:[[:digit:]]\{2\}" ) )
	END_TIME=( $(grep "...generation done" $NAME/hmc*.out | grep -o "[[:digit:]]\{2\}:[[:digit:]]\{2\}:[[:digit:]]\{2\}") )
	START_TIME_SEC=$(TimeToSeconds $START_TIME)
	END_TIME_SEC=$(TimeToSeconds $END_TIME)
	if [ $START_TIME_SEC -gt $END_TIME_SEC ]; then
            END_TIME_SEC=$(( $END_TIME_SEC + 24*3600 ))
	fi
	DURATION+=( $(( $END_TIME_SEC - $START_TIME_SEC )) )
    else
	DURATION+=( 0 )
	ALLRUNFINISHED=0
    fi
done
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
printf "\n\e[0;36m=======================================================================\e[0m\n"
printf "\e[0;35m\t\tkappa=0.$KAPPA  ns=$NSPACE  beta=$BETA\e[0m"
TABLE_FORMAT="%-$(LengthOfLongestEntryInArray "${FOLDERS[@]}")s%-5s%+17s%-5s%17s%-5s%-8s"
printf "\n\e[0;36m=======================================================================\e[0m\n"
printf "\e[0;36m$TABLE_FORMAT\e[0m\n"   "SETUP:" ""   "AV. TIME PER TR.:" ""   "ACCEPTANCE RATE:" "" "MAX_DS:"

#


if [ $ALLRUNFINISHED -eq 0 ]; then
    for ((i=0; i<${#FOLDERS[@]}; i++)); do
	printf "$TABLE_FORMAT\e[0m\n"   "${FOLDERS[$i]}" ""\
                                        "$(echo "${DURATION[$i]} ${TRAJECTORIES[$i]}" | awk '{if($2=="--"){print "------------   "}else{sec_tr=(int($1/$2)+1); printf "%d min %2d sec   ", int(sec_tr/60.0),  int(sec_tr%60)}}' )" ""\
                                        "$(echo "${ACCEPTED[$i]} ${TRAJECTORIES[$i]}" | awk '{if($2=="--"){print " ----- %  ( 0/0 )"}else{printf "%5.2f %%  (%d/%d)", 100*$1/$2, $1, $2}}')" ""\
                                        "${MAX_DELTAS[$i]}"
    done
else
    while [ ${#FOLDERS[@]} -gt 0 ]; do
	if [[ $ORDER_PARAMETER = "ACCEPTANCE" ]]; then
	    i=$(FindPositionOfFirstMinimumOfArray "${ACCEPTED[@]}")
	elif [[ $ORDER_PARAMETER = "DURATION" ]]; then
	    i=$(FindPositionOfFirstMinimumOfArray "${DURATION[@]}")
	else
	    i=$(FindPositionOfFirstMinimumOfArray "${FOLDERS[@]}")
	fi

	printf "$TABLE_FORMAT\e[0m\n"   "${FOLDERS[$i]}" ""\
                                        "$(echo "${DURATION[$i]} ${TRAJECTORIES[$i]}" | awk '{if($2==0){print "------------"}else{sec_tr=(int($1/$2)+1); printf "%d min %2d sec   ", int(sec_tr/60.0),  int(sec_tr%60)}}' )" ""\
                                        "$(echo "${ACCEPTED[$i]} ${TRAJECTORIES[$i]}" | awk '{if($2==0){print " ----- %   (0/0)"}else{printf "%5.2f %%  (%d/%d)", 100*$1/$2, $1, $2}}')" ""\
                                        "${MAX_DELTAS[$i]}"

	unset FOLDERS[$i]; FOLDERS=( "${FOLDERS[@]}" )
	unset DURATION[$i]; DURATION=( "${DURATION[@]}" )
	unset ACCEPTED[$i]; ACCEPTED=( "${ACCEPTED[@]}" )
	unset TRAJECTORIES[$i]; TRAJECTORIES=( "${TRAJECTORIES[@]}" )
	unset MAX_DELTAS[$i]; MAX_DELTAS=( "${MAX_DELTAS[@]}" )

    done    
fi
printf "\e[0;36m=======================================================================\e[0m\n\n"

