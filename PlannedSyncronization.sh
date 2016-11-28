#!/bin/bash

# Script to syncronize data and write the report in a file
# (Launching this script in crontab to get it run regularly does not work
# and I do not know why. rsync fails and then, since it fails only in crontab
# I decided to workaround using sleep and endless loop)
#
# Since it uses the script DataSyncronization.sh, a file with the
# global path to the folder to be syncronized is needed. For example
#
# /user-dependent-path/muiPiT/k1550/nt6/ns16    loewe
# /user-dependent-path/muiPiT/k1550/nt6/ns20    loewe
# /user-dependent-path/muiPiT/k1550/nt6/ns24    loewe
# /user-dependent-path/muiPiT/k1625/nt6/ns18    lcsc
# /user-dependent-path/muiPiT/k1625/nt6/ns24    lcsc
#
# (where user-dependent-path e.g. can be /home/phil-configs/wilson_nf2_muipi4/ImagMu/)
#
# the second column is needed to specify which remote to use. Please
# use here the name of the host as it is given to the python script.
#
# ATTENTION: In order to get it work constantly, you have to:
#             1) Do an ssh to go to kampala (server that is 24h a day on)
#                 ---> ssh un
#             2) Invoke the ssh-agent in order to let it use the ssh key
#                 ---> eval `ssh-agent`
#                 ---> ssh-add
#             3) Make a screen session, e.g.
#                 ---> screen -S LQCD_sync
#             4) Launch the following script (better in background)
#             5) Check that it is running via "jobs" and detach the screen
#                session via CTRL+a CTRL+d and exit from kampala.            
#
# IMPORTANT: Add here below your globalpath using a variable whose name is whoami.

sciarra="/home/sciarra/Documents/PhD_project/Data_Elaboration_tools/AutomaticSyncronizationData"
czaban="/home/czaban/Promotion/Physics/AutomaticSyncImagMuDataReports"

#Move to the correct sync folder
identity=$(whoami)
cd ${!identity} || exit 2 

# extract options and their arguments into variables.
if [ $# -eq 0 ]; then
    printf "\n\e[0;31m  A file containing the syncronization directives must be provided as first argument! Aborting...\e[0m\n"
    printf "\n\e[0;34m  Please use the following syntax:\n"
    printf "\t\e[0;32m  $0 <file with parameters strings> [--now]\e[0m\n\n"
    exit -1
fi

SYNC_NOW="FALSE"
FILE_WITH_DIRECTIONS="$1"
CUSTOM_SLEEP_TIME="FALSE"
while [ "$2" != "" ]; do
    case $2 in
      --now )   SYNC_NOW="TRUE"; shift ;;
      --sleepTime )  
            if [[ "$3" =~ [[:digit:]]+(s|m|h|d) ]]; then 
                SLEEP_TIME=$3; 
                CUSTOM_SLEEP_TIME="TRUE"; 
            fi 
            shift 2
            ;;
      * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
done

#Check file given in $FILE_WITH_DIRECTIONS exists
if [ ! -f $FILE_WITH_DIRECTIONS ]; then
	printf "\n \e[0;31m File \"$FILE_WITH_DIRECTIONS\" not found! Aborting...\e[0m\n\n"
	exit -1
fi

#Actual syncronization
while :
do
#<<<<<<< Updated upstream
#    if [ $SYNC_NOW = "FALSE" ]; then
#        #Just to wait time for backup
#        TIME_FOR_BACKUP='22'
#        CURRENT_EPOCH=$(date +%s)
#        TARGET_EPOCH=$(date -d $TIME_FOR_BACKUP +%s)
#        SLEEP_SECONDS=$(awk 'BEGIN{secInDay=3600*24}{print (($1-$2)+secInDay)%(secInDay)}' <<< "$TARGET_EPOCH $CURRENT_EPOCH" )
#        printf "\n\t\e[38;5;147mEntering sleeping mode. Performing next backup on \e[38;5;86m$(date -d @$(( $CURRENT_EPOCH + $SLEEP_SECONDS)) +"%d.%m.%Y \e[38;5;147mat\e[38;5;86m %H:%M")\e[0m\n\n"
#        sleep $SLEEP_SECONDS
#======= The following code should be the to be used, right?
    if [ $SYNC_NOW = "FALSE" ] && [ $CUSTOM_SLEEP_TIME = "FALSE" ]; then
        #Just to wait time for backup
        TIME_FOR_BACKUP='22'
        CURRENT_EPOCH=$(date +%s)
        TARGET_EPOCH=$(date -d $TIME_FOR_BACKUP +%s)
        SLEEP_SECONDS=$(awk 'BEGIN{secInDay=3600*24}{print (($1-$2)+secInDay)%(secInDay)}' <<< "$TARGET_EPOCH $CURRENT_EPOCH" )
        printf "\n\t\e[38;5;147mEntering sleeping mode. Performing next backup on \e[38;5;86m$(date -d @$(( $CURRENT_EPOCH + $SLEEP_SECONDS)) +"%d.%m.%Y \e[38;5;147mat\e[38;5;86m %H:%M")\e[0m\n\n"
        sleep $SLEEP_SECONDS
    elif [ $SYNC_NOW = "FALSE" ] && [ $CUSTOM_SLEEP_TIME = "TRUE" ]; then	
        sleep $SLEEP_TIME
#>>>>>>> Stashed changes
    fi
    
    declare -A RUN_NAMES
    while read SYNC_FOLDER_GLOBAL_PATH REMOTE_NAME; do
        RUN_NAMES[$REMOTE_NAME]="${RUN_NAMES[$REMOTE_NAME]} $SYNC_FOLDER_GLOBAL_PATH"
    done <<< "$(awk '/^($|[#]+)/{next} {print $0}' $FILE_WITH_DIRECTIONS )"
    
    OUTPUT_FILENAME="syncronization_$(date +'%d.%m.%y-%Hh%M')"
    ERROR_FILENAME="errors_$(date +'%d.%m.%y-%Hh%M')"
    for REMOTE in "${!RUN_NAMES[@]}"; do
	    ${HOME}/Script/DataSyncronization.sh -r $REMOTE -p ${RUN_NAMES[$REMOTE]} 1>> $OUTPUT_FILENAME 2>> $ERROR_FILENAME
    done
	
    unset -v 'RUN_NAMES'
    [ $SYNC_NOW = "TRUE" ] && break
done
    
cd ${HOME}
