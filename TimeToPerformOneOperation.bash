#!/bin/bash
#
#  Copyright (c) 2015,2016 Alessandro Sciarra
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


# This script is just a tool to get the time that the hmc executable
# took to perform a specific operation. It is based on the standard output of the
# CL2QCD code. Use it as
#
#    <script_name> <CL2QCD_std_output> <operation_to_grep_for>
#

#-----------------------------------------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source $HOME/Script/UtilityFunctions.sh || exit -2
#-----------------------------------------------------------------------------------------------------------------#

if [ $# -ne 2 ]; then
    printf "\n\e[0;34mPlease use the following syntax:\n"
    printf "\t\e[0;32m $0 <file with CL2QCD standard output> <operation_to_grep_for>\e[0m\n\n"
    exit -1
else
    if [ ! -f $1 ]; then
	    printf "\n\e[0;31m  File \"$1\" not found! Aborting...\e[0m\n\n"
	    exit -1
    fi

    TIMES=( "-" `grep -A1 "$2" $1 | awk '{print substr($1,2,8)}'` )

    #echo "${TIMES[@]}"

    TOTAL_TIME_SEC=()
    for((INDEX=1; INDEX<${#TIMES[@]}; INDEX++)); do
	    if [ ${TIMES[$INDEX]} == "-" ]; then
	        START_TIME_SEC=$(TimeToSeconds ${TIMES[$(($INDEX+1))]})
	        END_TIME_SEC=$(TimeToSeconds ${TIMES[$(($INDEX+2))]})
	        if [ $START_TIME_SEC -gt $END_TIME_SEC ]; then
		        END_TIME_SEC=$(( $END_TIME_SEC + 24*3600 ))
	        fi
	        TOTAL_TIME_SEC+=( "$(( $TOTAL_TIME_SEC + ($END_TIME_SEC - $START_TIME_SEC) ))" )
	    fi
    done

    #printf "\n\e[0;32m ${TOTAL_TIME_SEC[*]} \e[0m\n\n"
    AV_TIME=$(echo ${TOTAL_TIME_SEC[@]} | awk 'BEGIN{RS=" "}{sum+=$1}END{print sum/NR}')

    printf "\n\e[0;32m Operation executed ${#TOTAL_TIME_SEC[@]} times with an average time of $AV_TIME seconds. \e[0m\n\n"

fi
