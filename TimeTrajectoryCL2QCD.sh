#!/bin/bash

# This script is just an Handy tool to get the average time
# per trajectory calculated using the standard output of the
# CL2QCD code. Use it as
#
#    <script_name> <std_output_file>
#

#-----------------------------------------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used. 
source $HOME/Script/UtilityFunctions.sh || exit -2
#-----------------------------------------------------------------------------------------------------------------#

if [ $# -le 2 ]; then
    if [ ! -f $1 ]; then
	    printf "\n\e[0;31m  File \"$1\" not found! Aborting...\e[0m\n\n"
	    exit -1
    fi
    STRING_TO_GREP_FOR="finished trajectory"
    if [ $# -eq 2 ]; then
        STRING_TO_GREP_FOR="$2"
    fi

    TIMES=( `grep "$STRING_TO_GREP_FOR" $1 | awk '{print substr($1,2,8)}'` )
    NUMBER_DONE_TR_STDOUTPUT=`grep "$STRING_TO_GREP_FOR" $1 | wc -l`
    #The array TIMES is not sparse, then the following code work
    TOTAL_TIME_SEC=0
    for((INDEX=1; INDEX<${#TIMES[@]}; INDEX++)); do
	START_TIME_SEC=$(TimeToSeconds ${TIMES[$(($INDEX-1))]})
	END_TIME_SEC=$(TimeToSeconds ${TIMES[$INDEX]})
	if [ $START_TIME_SEC -gt $END_TIME_SEC ]; then
            END_TIME_SEC=$(( $END_TIME_SEC + 24*3600 ))
	fi
	TOTAL_TIME_SEC=$(( $TOTAL_TIME_SEC + ($END_TIME_SEC - $START_TIME_SEC) ))
    done
    AVERAGE_TIME=$(bc -l <<< "$TOTAL_TIME_SEC / ($NUMBER_DONE_TR_STDOUTPUT - 1)" | awk '{printf "%f", $0}')

    if [ $# -eq 2 ]; then
        printf "\n\e[0;32m Operation done $(($NUMBER_DONE_TR_STDOUTPUT-1)) times in $(SecondsToTimeStringWithDays $TOTAL_TIME_SEC)  --->  $AVERAGE_TIME sec. per operation.\e[0m\n\n"
    else
        printf "\n\e[0;32m Done $(($NUMBER_DONE_TR_STDOUTPUT-1)) trajectories in $(SecondsToTimeStringWithDays $TOTAL_TIME_SEC)  --->  $AVERAGE_TIME sec. per trajectory.\e[0m\n\n"
    fi
    
else
    printf "\n\e[0;34mPlease use the following syntax:\n"
    printf "\t\e[0;32m $0 <file with CL2QCD standard output>\e[0m\n\n"
    exit -1
fi
