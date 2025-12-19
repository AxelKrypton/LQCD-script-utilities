#!/bin/bash
#
#  Copyright (c) 2016-2020 Alessandro Sciarra
#  Copyright (c) 2021 Reinhold Kaiser
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


# Script to gather information on the cluster usage.
# Given a list of users, the sinfo and squeue commands
# are used to understand how many nodes are used by users,
# how many are not available and how many are excluded.
#
# The header of the table is fixed to be:
#   date   User1 ... UserN   Others   Idle    NotAvailable   BrokenButAvailable
#
# The script appends to the outputfile a report on the cluster usage
# and rsync it to the REMOTE_NAME at the REMOTE_PATH location.
# There, if available, the file EXCLUDED_NODES_FILENAME is used
# to know which nodes have been manually excluded and check if broken
# nodes are available to the users of the cluster.
#--------------------------------------------------------------------------------

#--------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source "$HOME/Script/UtilityFunctions.sh" || exit -2
#--------------------------------------------------------------------------------#

function ReconstructNodeListFromArrayOfNodes(){
    #Nodes as command parameters; the task is to eliminate contigous nodes with range notation
    #e.g. 0021 0022 0023 0024 0083 should become 0021-0024,0083
    local TEMPORARY_STRING=$(awk \
        '{
             printf $1"|"
             for(i=2; i<NF; i++){
                 if( ($i==1+$(i-1)) && ($i==-1+$(i+1)) ){
                     printf "|-|"
                 } else {
                     printf "|"$i"|"
                 }
             }
             printf "|"
             if(NF!=1){
                 printf $NF
             }
         }' <<< "$@" | sed 's/|\(|-|\)\+|/-/g' | sed 's/[|]\+/,/g' )

    if [[ $TEMPORARY_STRING =~ [[:digit:]]$ ]]; then
        echo $TEMPORARY_STRING
    else
        echo ${TEMPORARY_STRING%?}
    fi
}

function PrintHeader(){
    printf "$TABLE_PRINTF_FORMAT" "Date" "Partition" "TotalNodes" "${USERS_LIST[@]}" "Others" "Idling" "NotAvailable" "ExcludedButIdle/Allocated" > $1
}

function PrintClusterUsageInformation(){
    printf "$TABLE_PRINTF_FORMAT" $DATE $PARTITION $TOTAL_NUMBER_OF_NODES "${USERS_USAGE[@]}" $OTHERS_USAGE $IDLE_NODES $NOT_AVAILABLE "$EXCLUDED_BUT_IDLING $EXCLUDED_BUT_IDLING_LIST $EXCLUDED_BUT_ALLOCATED $EXCLUDED_BUT_ALLOCATED_LIST" >> $1
}

#--------------------------------------------------------------------------------#

#Variables to be changed, hardcoded for the moment
USERS_LIST=( "cuteri" "sciarra" "aschoen" "ambrosio" "kaiser")
CLUSTER_NAME='LOEWE'
PARTITION='gpu'
REMOTE_NAME='uni'
REMOTE_PATH='/home/phil-shared/clustersInformation'
SYNC_NOW='FALSE'
PRINT_ONLY_TO_SHELL='FALSE'
if [ "$(hostname)" = "lxlcsc0001" ]; then
    CLUSTER_NAME='LCSC'
    PARTITION='lcsc'
    USERS_LIST=( "fcuteri" "asciarra" "aschoen" "rekaiser" "adambros" )
fi
OUTPUT_FILE="${CLUSTER_NAME}_usage"
EXCLUDED_NODES_FILENAME="${CLUSTER_NAME}_excludedNodes"

#Command lines
while [ "$1" != "" ]; do
    case $1 in
        -h | --help )
            printf "\n\e[0;32m"
            echo " Call the script $0 with the following optional arguments:"
            echo "   -h | --help"
            echo "   -u | --users                 ->    users list (default = \"${USERS_LIST[@]}\")"
            echo "   -c | --cluster               ->    cluster name (default = $CLUSTER_NAME)"
            echo "   -p | --partition             ->    partition name (default = $PARTITION)"
            echo "   -r | --remote                ->    remote name (default = $REMOTE_NAME)"
            echo "   -x | --remotePath            ->    remote path (default = $REMOTE_PATH)"
            echo "   -o | --outputFile            ->    name of output file (default = $OUTPUT_FILE)"
            echo "   -e | --excludedNodeFilename  ->    name of file with --exclude string (default = $EXCLUDED_NODES_FILENAME)"
            echo "   --now                        ->    run it now, not at 4 a.m."
            echo "   --doNotUpdateFiles           ->    print the report only to screen and not to files (this option activates --now)"
            printf "\n\e[0m"
            exit
            shift;;
        -u | --users )
            while [[ ! $2 =~ ^- ]]; do
                USERS_LIST+=( $2 )
                shift
            done
            shift ;;
        -c | --cluster )
            if [[ ! $2 =~ ^- ]]; then
                CLUSTER_NAME="$2"
                shift
            else
                printf "\n\e[38;5;202m Value \e[1m${2}\e[22m not valid for option \e[1m${1}\e[22m! Aborting...\n\n\e[0m" 1>&2; exit -1
            fi
            shift ;;
        -p | --partition )
            if [[ ! $2 =~ ^- ]]; then
                PARTITION="$2"
                shift
            else
                printf "\n\e[38;5;202m Value \e[1m${2}\e[22m not valid for option \e[1m${1}\e[22m! Aborting...\n\n\e[0m" 1>&2; exit -1
            fi
            shift ;;
        -r | --remote )
            if [[ ! $2 =~ ^- ]]; then
                REMOTE_NAME="$2"
                shift
            else
                printf "\n\e[38;5;202m Value \e[1m${2}\e[22m not valid for option \e[1m${1}\e[22m! Aborting...\n\n\e[0m" 1>&2; exit -1
            fi
            shift ;;
        -x | --remotePath )
            if [[ ! $2 =~ ^- ]]; then
                REMOTE_PATH="$2"
                shift
            else
                printf "\n\e[38;5;202m Value \e[1m${2}\e[22m not valid for option \e[1m${1}\e[22m! Aborting...\n\n\e[0m" 1>&2; exit -1
            fi
            shift ;;
        -o | --outputFile )
            if [[ ! $2 =~ ^- ]]; then
                OUTPUT_FILE="$2"
                shift
            else
                printf "\n\e[38;5;202m Value \e[1m${2}\e[22m not valid for option \e[1m${1}\e[22m! Aborting...\n\n\e[0m" 1>&2; exit -1
            fi
            shift ;;
        -e | --excludedNodeFilename )
            if [[ ! $2 =~ ^- ]]; then
                EXCLUDED_NODES_FILENAME="$2"
                shift
            else
                printf "\n\e[38;5;202m Value \e[1m${2}\e[22m not valid for option \e[1m${1}\e[22m! Aborting...\n\n\e[0m" 1>&2; exit -1
            fi
            shift ;;
        --now )
            SYNC_NOW="TRUE"
            shift ;;
        --doNotUpdateFiles )
            PRINT_ONLY_TO_SHELL='TRUE'
            SYNC_NOW="TRUE"
            shift ;;
        * ) printf "\n\e[0;31m Unknouwn option \e[1m${1}\e[22m! Aborting...\n\n\e[0m" 1>&2; exit -1 ;;
    esac
done

RSYNC_PATH="${REMOTE_NAME}:${REMOTE_PATH}"

while :
do
    if [ $SYNC_NOW = 'FALSE' ]; then
        #Just to wait 2 a.m.
        CURRENT_EPOCH=$(date +%s)
        TARGET_EPOCH=$(date -d '04 + 1 days' +%s)
        SLEEP_SECONDS=$(( $TARGET_EPOCH - $CURRENT_EPOCH ))
        sleep $SLEEP_SECONDS || { echo "Sleep $SLEEP_SECONDS failed!"; exit -1; }
    fi

    RUNNING_BY_USERS=0
    PENDING_BY_USERS=0
    OTHER_BY_USERS=0
    STRING_DESCRIPTOR_FOR_USERS=''
    USERS_USAGE=() #Array with entries that are triplet of numbers corresponding to running/pending/other of first user, same for second, etc. (all in a row)

    DATE="$(date +'%d.%m.%Y_%H:%M')"
    ALLOCATED_IDLE_OTHER_TOTAL_NODES=( $(sinfo --noheader -p $PARTITION -o '%F' | sed 's@/@ @g') ) # --format '%F'    Number of nodes by state in the format "allocated/idle/other/total"
    ALLOCATED_NODES=${ALLOCATED_IDLE_OTHER_TOTAL_NODES[0]}
    IDLE_NODES=${ALLOCATED_IDLE_OTHER_TOTAL_NODES[1]}
    NOT_AVAILABLE=${ALLOCATED_IDLE_OTHER_TOTAL_NODES[2]}
    TOTAL_NUMBER_OF_NODES=${ALLOCATED_IDLE_OTHER_TOTAL_NODES[3]}
    for INDEX in ${!USERS_LIST[@]}; do
        declare -A USER_USAGE
        LIST_STATE_JOBS_USER="$(squeue --noheader -u ${USERS_LIST[$INDEX]} -p $PARTITION -o '%T' | uniq -c)"
        if [ "$LIST_STATE_JOBS_USER" != "" ]; then
            COMMAND_FOR_ASSOCIATIVE_ARRAY="USER_USAGE=( $(awk '{printf "[%s]=%d ", $2, $1}END{printf "\n"}' <<< "$LIST_STATE_JOBS_USER") )"
            eval $COMMAND_FOR_ASSOCIATIVE_ARRAY
            KeyInArray 'RUNNING' USER_USAGE || USER_USAGE['RUNNING']=0
            KeyInArray 'PENDING' USER_USAGE || USER_USAGE['PENDING']=0
            KeyInArray 'COMPLETING' USER_USAGE || USER_USAGE['COMPLETING']=0
            OTHER_BY_USER=$(( ( $(awk '{sum+=$1}END{print sum}' <<< "$LIST_STATE_JOBS_USER") - ${USER_USAGE['RUNNING']} - ${USER_USAGE['PENDING']}) ))
            (( RUNNING_BY_USERS += ${USER_USAGE['RUNNING']} ))
            (( PENDING_BY_USERS += ${USER_USAGE['PENDING']} ))
            (( OTHER_BY_USERS +=  $OTHER_BY_USER ))
        else
            USER_USAGE['RUNNING']=0; USER_USAGE['PENDING']=0; USER_USAGE['COMPLETING']=0; OTHER_BY_USER=0
        fi
        STRING_DESCRIPTOR_FOR_USERS+="%-13s"
        USERS_USAGE+=( "${USER_USAGE['RUNNING']} ${USER_USAGE['PENDING']} $OTHER_BY_USER" )
        unset -v 'USER_USAGE'
    done
    #Calculate information about users not in the list
    #TODO: These three lines should be moved above close to the other squeue because
    #      if a job change status between a squeue and the other, then this script
    #      gives wrong results. Remote case, but it happened...
    RUNNING_IN_TOTAL=$(squeue -h -p $PARTITION -t RUNNING -o %D | awk '{sum+=$1}END{print sum}')
    PENDING_IN_TOTAL=$(squeue -h -p $PARTITION -t PENDING -o %D | awk '{sum+=$1}END{print sum}')
    QUEUED_IN_TOTAL=$(squeue -h -p $PARTITION -o %D | awk '{sum+=$1}END{print sum}')
    [ "$RUNNING_IN_TOTAL" = '' ] && RUNNING_IN_TOTAL=0
    [ "$PENDING_IN_TOTAL" = '' ] && PENDING_IN_TOTAL=0
    [ "$QUEUED_IN_TOTAL"  = '' ] && QUEUED_IN_TOTAL=0
    RUNNING_BY_OTHERS=$(( $RUNNING_IN_TOTAL - $RUNNING_BY_USERS))
    PENDING_BY_OTHERS=$(( $PENDING_IN_TOTAL - $PENDING_BY_USERS))
    OTHER_BY_OTHERS=$(( $QUEUED_IN_TOTAL - $RUNNING_IN_TOTAL - $PENDING_IN_TOTAL - $OTHER_BY_USERS ))
    USERS_USAGE+=( "$RUNNING_BY_OTHERS $PENDING_BY_OTHERS $OTHER_BY_OTHERS" )

    #Get excluded nodes from remote file and then parse information into list of numbers
    EXCLUDED_NODES=$(ssh $REMOTE_NAME 'bash -s' << EOF
grep -oE "\-\-exclude=.*\[.*\]" ${REMOTE_PATH}/${EXCLUDED_NODES_FILENAME} 2>/dev/null
EOF
                  )
    if [ "$EXCLUDED_NODES" == "" ]; then
       EXCLUDED_BUT_IDLING='#Excluded nodes information not available'
       EXCLUDED_BUT_IDLING_LIST=''
       EXCLUDED_BUT_ALLOCATED=''
       EXCLUDED_BUT_ALLOCATED_LIST=''
    else
        PREFIX_NODES=$(sed -n 's/.*=\(.*\)\[.*/\1/p' <<< "$EXCLUDED_NODES")
        ARRAY_OF_EXCLUDED_NODES=( $(sed -n 's/.*\[\(.*\)\]/\1/p' <<< "$EXCLUDED_NODES" | sed 's/,/ /g') )
        for INDEX in ${!ARRAY_OF_EXCLUDED_NODES[@]}; do
            if [[ ${ARRAY_OF_EXCLUDED_NODES[$INDEX]} =~ - ]]; then
                ARRAY_OF_EXCLUDED_NODES[$INDEX]=$(awk 'BEGIN{FS="-"}{num=length($1); for(i=$1; i<=$2; i++){printf "%0"num"d ", i}}' <<< "${ARRAY_OF_EXCLUDED_NODES[$INDEX]}")
            fi
        done
        ARRAY_OF_EXCLUDED_NODES=( ${ARRAY_OF_EXCLUDED_NODES[@]} ) #To separate all entries in single ones
        #Get allocated and idling nodes and parse into list of numbers
        ARRAY_OF_IDLING_NODES=( $(sinfo -h -p $PARTITION -t IDLE -o "%N" | sed -n 's/.*\[\(.*\)\]/\1/p' | sed 's/,/ /g') )
        ARRAY_OF_ALLOCATED_NODES=( $(sinfo -h -p $PARTITION -t ALLOCATED -o "%N" | sed -n 's/.*\[\(.*\)\]/\1/p' | sed 's/,/ /g') )
        for INDEX in ${!ARRAY_OF_IDLING_NODES[@]}; do
            if [[ ${ARRAY_OF_IDLING_NODES[$INDEX]} =~ - ]]; then
                ARRAY_OF_IDLING_NODES[$INDEX]=$(awk 'BEGIN{FS="-"}{num=length($1); for(i=$1; i<=$2; i++){printf "%0"num"d ", i}}' <<< "${ARRAY_OF_IDLING_NODES[$INDEX]}")
            fi
        done
        for INDEX in ${!ARRAY_OF_ALLOCATED_NODES[@]}; do
            if [[ ${ARRAY_OF_ALLOCATED_NODES[$INDEX]} =~ - ]]; then
                ARRAY_OF_ALLOCATED_NODES[$INDEX]=$(awk 'BEGIN{FS="-"}{num=length($1); for(i=$1; i<=$2; i++){printf "%0"num"d ", i}}' <<< "${ARRAY_OF_ALLOCATED_NODES[$INDEX]}")
            fi
        done
        ARRAY_OF_ALLOCATED_NODES=( ${ARRAY_OF_ALLOCATED_NODES[@]} ) #To separate all entries in single ones
        #Now build up EXCLUDED_BUT_IDLING/ALLOCATED comparing arrays excluded vs idling/allocated nodes
        EXCLUDED_BUT_IDLING=0
        EXCLUDED_BUT_ALLOCATED=0
        EXCLUDED_BUT_IDLING_LIST=''
        EXCLUDED_BUT_ALLOCATED_LIST=''
        for ELEM in ${ARRAY_OF_EXCLUDED_NODES[@]}; do
            if ElementInArray "$ELEM" ${ARRAY_OF_IDLING_NODES[@]}; then
                (( EXCLUDED_BUT_IDLING++ ))
                EXCLUDED_BUT_IDLING_LIST="${EXCLUDED_BUT_IDLING_LIST} $ELEM"
            elif ElementInArray "$ELEM" ${ARRAY_OF_ALLOCATED_NODES[@]}; then
                (( EXCLUDED_BUT_ALLOCATED++ ))
                EXCLUDED_BUT_ALLOCATED_LIST="${EXCLUDED_BUT_ALLOCATED_LIST} $ELEM"
            fi
        done
        if [ $EXCLUDED_BUT_IDLING -eq 0 ]; then
            EXCLUDED_BUT_IDLING_LIST=' ---------------'
        else
        EXCLUDED_BUT_IDLING_LIST="${PREFIX_NODES}["$(ReconstructNodeListFromArrayOfNodes $EXCLUDED_BUT_IDLING_LIST)"]"
        fi
        if [ $EXCLUDED_BUT_ALLOCATED -eq 0 ]; then
            EXCLUDED_BUT_ALLOCATED_LIST=' ---------------'
        else
            EXCLUDED_BUT_ALLOCATED_LIST="${PREFIX_NODES}["$(ReconstructNodeListFromArrayOfNodes $EXCLUDED_BUT_ALLOCATED_LIST)"]"
        fi
    fi

    #Table format stored here to shorten printing lines
    TABLE_PRINTF_FORMAT="%-21s%-15s%-14s${STRING_DESCRIPTOR_FOR_USERS}%-11s%-11s%-17s%-s\n"
    if [ $PRINT_ONLY_TO_SHELL = 'TRUE' ]; then
        echo ''
        PrintHeader                  /dev/stdout
        PrintClusterUsageInformation /dev/stdout
        echo ''
    else
        #Printing to file
        if [ -s $OUTPUT_FILE ]; then
            PrintClusterUsageInformation $OUTPUT_FILE
        else
            PrintHeader                  $OUTPUT_FILE
            PrintClusterUsageInformation $OUTPUT_FILE
        fi
        #Rsync removing writing permissions to everybody
        rsync -qluz --no-p --no-g --chmod=ugo=rX $OUTPUT_FILE $RSYNC_PATH/$OUTPUT_FILE
    fi

    [ $SYNC_NOW = "TRUE" ] && break

done

exit 0
