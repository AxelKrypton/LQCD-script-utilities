#!/bin/bash

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

#Variables to be changed, hardcoded for the moment
USERS_LIST=( "czaban" "cuteri" "sciarra" )
CLUSTER_NAME='LOEWE'
PARTITION='gpu'
REMOTE_NAME='uni'
REMOTE_PATH='/home/phil-shared/clustersInformation'
SYNC_NOW='FALSE'
PRINT_ONLY_TO_SHELL='FALSE'
if [ "$(hostname)" = "lxlcsc0001" ]; then
    CLUSTER_NAME='LCSC'
    PARTITION='lcsc'
    USERS_LIST=( "cczaban" "fcuteri" "asciarra" )
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
            echo "   --now                        ->    run it now, not at 2 a.m."
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
                printf "\n\e[38;5;202m Value \e[1m${2}\e[21m not valid for option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1
            fi
            shift ;;
        -p | --partition )
            if [[ ! $2 =~ ^- ]]; then
                PARTITION="$2"
                shift
            else
                printf "\n\e[38;5;202m Value \e[1m${2}\e[21m not valid for option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1
            fi
            shift ;;
        -r | --remote )
            if [[ ! $2 =~ ^- ]]; then
                REMOTE_NAME="$2"
                shift
            else
                printf "\n\e[38;5;202m Value \e[1m${2}\e[21m not valid for option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1
            fi
            shift ;;
        -x | --remotePath )
            if [[ ! $2 =~ ^- ]]; then
                REMOTE_PATH="$2"
                shift
            else
                printf "\n\e[38;5;202m Value \e[1m${2}\e[21m not valid for option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1
            fi
            shift ;;
        -o | --outputFile )
            if [[ ! $2 =~ ^- ]]; then
                OUTPUT_FILE="$2"
                shift
            else
                printf "\n\e[38;5;202m Value \e[1m${2}\e[21m not valid for option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1
            fi
            shift ;;
        -e | --excludedNodeFilename )
            if [[ ! $2 =~ ^- ]]; then
                EXCLUDED_NODES_FILENAME="$2"
                shift
            else
                printf "\n\e[38;5;202m Value \e[1m${2}\e[21m not valid for option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1
            fi
            shift ;;
        --now )
            SYNC_NOW="TRUE"
            shift ;;
        --doNotUpdateFiles )
            PRINT_ONLY_TO_SHELL='TRUE'
            SYNC_NOW="TRUE"
            shift ;;
        * ) printf "\n\e[0;31m Unknouwn option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1 ;;
    esac
done

RSYNC_PATH="${REMOTE_NAME}:${REMOTE_PATH}"
declare -a USERS_USAGE

while :
do
    if [ $SYNC_NOW = 'FALSE' ]; then
        #Just to wait 2 a.m.
        CURRENT_EPOCH=$(date +%s)
        TARGET_EPOCH=$(date -d '02 + 1 days' +%s)
        SLEEP_SECONDS=$(( $TARGET_EPOCH - $CURRENT_EPOCH ))
        sleep $SLEEP_SECONDS
    fi
    
    USED_BY_USERS=0
    STRING_DESCRIPTOR_FOR_USERS=''

    DATE="$(date +'%d.%m.%Y_%H:%M')"
    ALLOCATED_IDLE_OTHER_TOTAL_NODES=( $(sinfo --noheader -p $PARTITION -o '%F' | sed 's@/@ @g') ) # --format '%F'    Number of nodes by state in the format "allocated/idle/other/total"
    ALLOCATED_NODES=${ALLOCATED_IDLE_OTHER_TOTAL_NODES[0]}
    IDLE_NODES=${ALLOCATED_IDLE_OTHER_TOTAL_NODES[1]}
    NOT_AVAILABLE=${ALLOCATED_IDLE_OTHER_TOTAL_NODES[2]}
    TOTAL_NUMBER_OF_NODES=${ALLOCATED_IDLE_OTHER_TOTAL_NODES[3]}
    for INDEX in ${!USERS_LIST[@]}; do
        USERS_USAGE[$INDEX]=$(squeue --noheader -u ${USERS_LIST[$INDEX]} -p $PARTITION -o '%T' | grep -c 'RUNNING')
        (( USED_BY_USERS += ${USERS_USAGE[$INDEX]} ))
        STRING_DESCRIPTOR_FOR_USERS="${STRING_DESCRIPTOR_FOR_USERS}%-13s"
    done
    #Get excluded nodes from remote file and then parse information into list of numbers
    OTHERS_USAGE=$(( $ALLOCATED_NODES - $USED_BY_USERS ))
    EXCLUDED_NODES=$(ssh $REMOTE_NAME 'bash -s' << EOF
grep -oE "\-\-exclude=.*\[.*\]" ${REMOTE_PATH}/${EXCLUDED_NODES_FILENAME} 2>/dev/null
EOF
                  )
    if [ "$EXCLUDED_NODES" == "" ]; then
       BROKEN_BUT_AVAILABLE=''
       BROKEN_BUT_AVAILABLE_LIST='----------------'
    else
        PREFIX_NODES=$(sed -n 's/.*=\(.*\)\[.*/\1/p' <<< "$EXCLUDED_NODES")
        ARRAY_OF_EXCLUDED_NODES=( $(sed -n 's/.*\[\(.*\)\]/\1/p' <<< "$EXCLUDED_NODES" | sed 's/,/ /g') )
        for INDEX in ${!ARRAY_OF_EXCLUDED_NODES[@]}; do
            if [[ ${ARRAY_OF_EXCLUDED_NODES[$INDEX]} =~ - ]]; then
                ARRAY_OF_EXCLUDED_NODES[$INDEX]=$(awk 'BEGIN{FS="-"}{num=length($1); for(i=$1; i<=$2; i++){printf "%0"num"d ", i}}' <<< "${ARRAY_OF_EXCLUDED_NODES[$INDEX]}")
            fi
        done
        ARRAY_OF_EXCLUDED_NODES=( ${ARRAY_OF_EXCLUDED_NODES[@]} ) #To separate all entries in single ones
        #Get idling nodes and parse into list of numbers
        ARRAY_OF_IDLING_NODES=( $(sinfo -h -p lcsc -t IDLE -o "%N" | sed -n 's/.*\[\(.*\)\]/\1/p' | sed 's/,/ /g') )
        for INDEX in ${!ARRAY_OF_IDLING_NODES[@]}; do
            if [[ ${ARRAY_OF_IDLING_NODES[$INDEX]} =~ - ]]; then
                ARRAY_OF_IDLING_NODES[$INDEX]=$(awk 'BEGIN{FS="-"}{num=length($1); for(i=$1; i<=$2; i++){printf "%0"num"d ", i}}' <<< "${ARRAY_OF_IDLING_NODES[$INDEX]}")
            fi
        done
        ARRAY_OF_IDLING_NODES=( ${ARRAY_OF_IDLING_NODES[@]} ) #To separate all entries in single ones
        #Now build up BROKEN_BUT_AVAILABLE comparing arrays excluded vs idling nodes
        BROKEN_BUT_AVAILABLE=0
        BROKEN_BUT_AVAILABLE_LIST=''
        LAST_ELEM='-17' #Starting value such that at the first iteration nothing can happen
        for ELEM in ${ARRAY_OF_EXCLUDED_NODES[@]}; do
            if ElementInArray "$ELEM" ${ARRAY_OF_IDLING_NODES[@]}; then
                (( BROKEN_BUT_AVAILABLE++ ))
                BROKEN_BUT_AVAILABLE_LIST="${BROKEN_BUT_AVAILABLE_LIST} $ELEM"
            fi
        done
        BROKEN_BUT_AVAILABLE_LIST=($(awk '{printf $1"|"; for(i=2; i<NF; i++){if( ($i==1+$(i-1)) && ($i==-1+$(i+1)) ){printf "-"}else{printf "|"$i}}; printf "|"$NF}' <<< "$BROKEN_BUT_AVAILABLE_LIST" | sed 's/|[-]\+|/-/g' | sed 's/[|]\+/,/g') )
        BROKEN_BUT_AVAILABLE_LIST="${PREFIX_NODES}["$(sed 's/ /,/g' <<< "${BROKEN_BUT_AVAILABLE_LIST[@]}")"]"
    fi

    if [ $PRINT_ONLY_TO_SHELL = 'TRUE' ]; then
        echo ''
        printf "%-21s%-15s%-14s${STRING_DESCRIPTOR_FOR_USERS}%-11s%-11s%-17s%-23s\n" "Date" "Partition" "TotalNodes" "${USERS_LIST[@]}" "Others" "Idling" "NotAvailable" "BrokenButAvailable"                
        printf "%-21s%-15s%-14s${STRING_DESCRIPTOR_FOR_USERS}%-11s%-11s%-17s%-s\n" $DATE $PARTITION $TOTAL_NUMBER_OF_NODES ${USERS_USAGE[@]} $OTHERS_USAGE $IDLE_NODES $NOT_AVAILABLE "$BROKEN_BUT_AVAILABLE $BROKEN_BUT_AVAILABLE_LIST"
        echo ''
    else
        #Printing to file
        if [ -s $OUTPUT_FILE ]; then
            printf "%-21s%-15s%-14s${STRING_DESCRIPTOR_FOR_USERS}%-11s%-11s%-17s%-23s\n" $DATE $PARTITION $TOTAL_NUMBER_OF_NODES ${USERS_USAGE[@]} $OTHERS_USAGE $IDLE_NODES $NOT_AVAILABLE "$BROKEN_BUT_AVAILABLE $BROKEN_BUT_AVAILABLE_LIST" >> $OUTPUT_FILE
        else
            printf "%-21s%-15s%-14s${STRING_DESCRIPTOR_FOR_USERS}%-11s%-11s%-17s%-23s\n" "Date" "Partition" "TotalNodes" "${USERS_LIST[@]}" "Others" "Idling" "NotAvailable" "BrokenButAvailable"                  > $OUTPUT_FILE
            printf "%-21s%-15s%-14s${STRING_DESCRIPTOR_FOR_USERS}%-11s%-11s%-17s%-23s\n" $DATE $PARTITION $TOTAL_NUMBER_OF_NODES ${USERS_USAGE[@]} $OTHERS_USAGE $IDLE_NODES $NOT_AVAILABLE "$BROKEN_BUT_AVAILABLE $BROKEN_BUT_AVAILABLE_LIST" >> $OUTPUT_FILE
        fi

        #Rsync removing writing permissions to everybody
        rsync -qluz --no-p --no-g --chmod=ugo=rX $OUTPUT_FILE $RSYNC_PATH/$OUTPUT_FILE
    fi

    [ $SYNC_NOW = "TRUE" ] && break

done

exit 0
