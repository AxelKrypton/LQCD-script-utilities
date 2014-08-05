#!/bin/bash

# This script is just supposed to run the Python script to backup simulation
# data automatically for a bunch of simulations.
#
# The idea is that one gives as command-line parameters a set
# of strings like "muiPiT/k1650/nt6/ns16" and this script will
# syncronize data using the betas file for such parameters

function PrintSituationDataFolder(){
    for d in $@; do 
	if [ -d $d ]; then
	    printf " \e[0;32mNumber of files in directory $d: \e[0;34m\e[2m"
	    ls $d | wc -l
	    printf " \e[0;33mNumber of files \"*_pbp.dat\" in directory $d: \e[0;34m\e[2m"
	    ls $d/*_pbp.dat | wc -l 
	    if [ -e $d/hmc_output ]; then
		printf " \e[0;35m\e[2mNumber of data in \"hmc_output\" in directory $d: \e[0;34m\e[2m"
		wc -l $d/hmc_output | awk '{print $1}'
	    fi
	    printf " \e[0m---------------------------------------------------\n"
	fi
    done
    printf " \e[0m"
}


STARTING_POSITION="$(pwd)"
printf "\n\n\e[1mScript \"$0\" run from $STARTING_POSITION...\n\e[0m"

DATA_GLOBALPATH="/home/phil-configs/wilson_nf2_muipi4/ImagMu/"
RUN_PARAMETERS=()
SKIPPED_DIRECTORIES=()

while [ "$1" != "" ]; do
    RUN_PARAMETERS+=( $1 )
    shift
done

printf "\n \e[0;32m\e[4mStarting time: $(date +'%Hh%M on %d.%m.%y')\n\e[0m"
for RUN in ${RUN_PARAMETERS[@]}; do
    if [ ! -d $DATA_GLOBALPATH$RUN ]; then
	printf "\n\e[0;31m The directory \"$DATA_GLOBALPATH$RUN\" has not been found! It will be skipped!\n\n\e[0m"
	SKIPPED_DIRECTORIES+=( "$DATA_GLOBALPATH$RUN" )
	continue
    fi
    cd $DATA_GLOBALPATH$RUN || exit -2
    printf "\n\e[0;36m=======================================================================\e[0m\n"
    printf "\e[0;35m\e[2m  $(pwd)\e[0m"
    printf "\n\e[0;36m=======================================================================\e[0m\n"
    # Before syncronize just give an overview of the status of the folder
    if [ -e betasSync ]; then
	BETASFILE="betasSync"
    else
	BETASFILE="betas"
    fi
    BETAVALUES=( $(grep -o "^[[:blank:]]*[[:digit:]]\.[[:digit:]]\{4\}" $BETASFILE) )
    for((i=0; i<${#BETAVALUES[@]}; i++)); do
	BETAVALUES[$i]="b${BETAVALUES[$i]}"
    done
    PrintSituationDataFolder ${BETAVALUES[@]}
    printf "\n\e[0;32m--------------------------------------------------------------\e[0m\n"
    # Then syncronize
    python ${HOME}/Documents/PhD_project/Data_Elaboration_tools/LQCD_SimulationManagementUtilities/ImagMu/ImagMuTools.py -s --syncConfs -f=$BETASFILE
    # Then give an other overview of the status of the folder
    printf "\n\e[0;32m--------------------------------------------------------------\e[0m\n"
    PrintSituationDataFolder ${BETAVALUES[@]}
    printf "\n\e[0;36m=======================================================================\e[0m\n\n"
done

# Print report on skipped folder
if [ ${#SKIPPED_DIRECTORIES[@]} -gt "0" ]; then	
    printf "\n\e[0;31m===================================================================================\n\e[0m"
    printf "\e[0;31m For the following given folders something went wrong and hence\n\e[0m"
    printf "\e[0;31m they were left out during the syncronization process:\n"
    for DIR in ${SKIPPED_DIRECTORIES[@]}; do
	printf "  - \e[1m$DIR\e[0;31m\n"
    done
    printf "\e[0;31m===================================================================================\n\n\e[0m"
fi
printf " \e[0;32m\e[4mEnding time: $(date +'%Hh%M on %d.%m.%y')\n\n\e[0m\n"
exit 0
