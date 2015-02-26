#!/bin/bash

# Script to syncronize data and write the report in a file
# (Launching this script in crontab to get it run regularly does not work
# and I do not know why. rsync fails and then, since it fails only in crontab
# I decided to workaround using sleep and endless loop)
#
# Since it uses the script DataSyncronization.sh, a file with the
# partial path to the folder to be syncronized is needed. Partial
# path means only the parameters string. For example a file whose content is
#
# muiPiT/k1550/nt6/ns16
# muiPiT/k1550/nt6/ns20
# muiPiT/k1550/nt6/ns24
# muiPiT/k1650/nt6/ns16
# muiPiT/k1650/nt6/ns20
# muiPiT/k1650/nt6/ns24
#
#
# ATTENTION: In order to get it work constantly, you have to:
#             1) Do an ssh to go to kampala (server that is 24h a day on)
#                 ---> ssh kampala
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
czaban="to_be_completed"

#Move to the correct sync folder
identity=$(whoami)
cd ${!identity} || exit 2 

if [ $# -eq 1 ]; then

    #Check file given in $1 exists
    if [ ! -f $1 ]; then
	printf "\n \e[0;31m File \"$1\" not found! Aborting...\e[0m\n\n"
	exit -1
    fi
    
    while :
    do

	#Just to wait 1a.m.
	CURRENT_EPOCH=$(date +%s)
	TARGET_EPOCH=$(date -d '01 + 1 days' +%s)
	SLEEP_SECONDS=$(( $TARGET_EPOCH - $CURRENT_EPOCH ))
	sleep $SLEEP_SECONDS
	
	RUNS_NAMES=($(awk 'BEGIN{ORS=" ";}{if(!($1 ~ /^#/)){print $0}}' $1))
    	OUTPUT_FILENAME="syncronization_"
    	ERROR_FILENAME="errors_"
	${HOME}/Script/DataSyncronization.sh ${RUNS_NAMES[@]} 1> $OUTPUT_FILENAME$(date +'%d.%m.%y-%Hh%M') 2> $ERROR_FILENAME$(date +'%d.%m.%y-%Hh%M')
	
    done

else
    printf "\n\e[0;34mPlease use the following syntax:\n"
    printf "\t\e[0;32m $0 <file with parameters strings>\e[0m\n\n"
    exit -1
fi

cd ${HOME}
