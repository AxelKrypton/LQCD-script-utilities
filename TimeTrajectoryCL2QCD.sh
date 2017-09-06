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

if [ $# -eq 0 ] || [ $# -gt 3 ]; then
    printf "\n\e[0;34mPlease use the following syntax:\n"
    printf "\t\e[0;32m $0 <file with CL2QCD standard output> [ <Start string to grep for> [ <End string to grep for> ] ]\e[0m\n\n"
    exit -1
else
    if [ ! -f "$1" ]; then
	    printf "\n\e[0;31m  File \"$1\" not found! Aborting...\e[0m\n\n"
	    exit -1
    fi
    START_STRING_TO_GREP_FOR="finished trajectory"
    END_STRING_TO_GREP_FOR=''
    STRATEGY='START-START'
    if [ $# -eq 2 ]; then
        if [ "$2" = '--pbp' ]; then
            STRATEGY='START-END'
            START_STRING_TO_GREP_FOR='   Write chiral condensate'
            END_STRING_TO_GREP_FOR='   \.\.\.done\!'
        else
            START_STRING_TO_GREP_FOR="$2"
        fi
    elif [ $# -eq 3 ]; then
        STRATEGY='START-END'
        START_STRING_TO_GREP_FOR="$2"
        END_STRING_TO_GREP_FOR="$3"
    fi

    if [ $STRATEGY = 'START-START' ]; then
        TIMES=( `grep "$START_STRING_TO_GREP_FOR" $1 | awk '{print substr($1,2,8)}'` )
        NUMBER_DONE_TR_STDOUTPUT=`grep "$START_STRING_TO_GREP_FOR" $1 | wc -l`
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
    fi

    if [ $STRATEGY = 'START-END' ]; then
        TIMES=( `grep -E "(${START_STRING_TO_GREP_FOR}|${END_STRING_TO_GREP_FOR})" $1 | awk '{print substr($1,2,8)}'` )
        NUMBER_OF_BLOCKS=$(( ${#TIMES[@]}/2 ))
        #The array TIMES is not sparse, then the following code work
        TOTAL_TIME_SEC=0
        for((INDEX=1; INDEX<${#TIMES[@]}; INDEX+=2)); do
	        START_TIME_SEC=$(TimeToSeconds ${TIMES[$(($INDEX-1))]})
	        END_TIME_SEC=$(TimeToSeconds ${TIMES[$INDEX]})
	        if [ $START_TIME_SEC -gt $END_TIME_SEC ]; then
                END_TIME_SEC=$(( $END_TIME_SEC + 24*3600 ))
	        fi
	        TOTAL_TIME_SEC=$(( $TOTAL_TIME_SEC + ($END_TIME_SEC - $START_TIME_SEC) ))
        done
        AVERAGE_TIME=$(bc -l <<< "$TOTAL_TIME_SEC / $NUMBER_OF_BLOCKS" | awk '{printf "%f", $0}')
        if [ "$2" = '--pbp' ]; then
            printf "\n\e[0;32m Measurement of the pbp done $NUMBER_OF_BLOCKS times in $(SecondsToTimeStringWithDays $TOTAL_TIME_SEC)  --->  $AVERAGE_TIME sec. per measurement.\e[0m\n\n"
        else
            printf "\n\e[0;32m Block of operations done $NUMBER_OF_BLOCKS times in $(SecondsToTimeStringWithDays $TOTAL_TIME_SEC)  --->  $AVERAGE_TIME sec. per block.\e[0m\n\n"
        fi
    fi
 
    

fi
