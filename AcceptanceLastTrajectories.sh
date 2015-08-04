#!/bin/bash

#Script to get quickly the Acceptance of the last trajectories

WILSON="true"
STAGGERED="false"
BETA=""
NUM_LAST_TR=0

# extract options and their arguments into variables.
while [ "$1" != "" ]; do
    case $1 in
      -h | --help )
          printf "\n\e[0;32m"
          echo "Call the script $0 with the following optional arguments:"
          echo "  -h | --help"
          echo "  -s   ->    for Staggered simulations"
          echo "  -b   ->    the beta to be considered (the other parameters are taken from pwd)"
          echo "  -t   ->    how many trajectory from the end of the run to calculate the acceptance on"
	  echo ""
          echo "NOTE: By default Wilson simulations are considered"
          printf "\n\e[0m"
          exit
          shift;;
      -s )             WILSON="false"; STAGGERED="true"; shift ;;
      -b=* )    BETA=${1#*=}; shift ;;
      -t=* )    NUM_LAST_TR=${1#*=}; shift ;;
      * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
done

# Load auxiliary bash files that will be used.
if [[ $STAGGERED == "true" ]]; then
    source $HOME/ScriptStaggered/PathManagement.sh || exit -2
else
    source $HOME/Script/PathManagement.sh || exit -2
fi
ReadParametersFromPath $(pwd)

#Treat in the right way some prefixes
if [ "${BETA##*_}" = "NC" ]; then
    BETA="${BETA%_*}_continueWithNewChain"
elif [ "${BETA##*_}" = "fC" ]; then
    BETA="${BETA%_*}_thermalizeFromConf"
elif [ "${BETA##*_}" = "fH" ]; then
    BETA="${BETA%_*}_thermalizeFromHot"
fi

# Build the path with the output file
SCRATCH_PATH=$(pwd)
if [ $(whoami) = "sciarra" ]; then
   SCRATCH_PATH="/scratch/hfftheo/sciarra/${SCRATCH_PATH#*sciarra/}"
fi
if [[ $STAGGERED == "true" ]]; then
    SCRATCH_PATH+="/b${BETA}/rhmc_output"
else
    SCRATCH_PATH+="/b${BETA}/hmc_output"
fi

#Check if the output file exists
if [ ! -f $SCRATCH_PATH ]; then
    printf "\n\e[0;31m SCRATCH_PATH=$SCRATCH_PATH\n"
    printf "\n\e[0;31m Constructed path to directory containing output file does not exist! Aborting...\n\n\e[0m"
    exit -1
fi

#Just do and print acceptances
printf "\n\e[0;36m======================================\e[0m\n"
if [ $NUM_LAST_TR -eq 0 ]; then
    for TR in 100 200 300 400 500 600 700 800 900; do
	tail -n${TR} $SCRATCH_PATH | awk '{sum+=$11} END {if(sum/NR>=0.7){printf "\033[38;5;10m  Accepted %3d over %d (%lf%%)\n\033[0m", sum, NR, 100*sum/(NR)}\
                                       else if(sum/NR<0.7 && sum/NR>=0.6){printf "\033[38;5;11m  Accepted %3d over %d (%lf%%)\n\033[0m", sum, NR, 100*sum/(NR)}
                                       else if(sum/NR<0.6 && sum/NR>=0.5){printf "\033[38;5;202m  Accepted %3d over %d (%lf%%)\n\033[0m", sum, NR, 100*sum/(NR)}
                                                                     else{printf "\033[38;5;9m  Accepted %3d over %d (%lf%%)\n\033[0m", sum, NR, 100*sum/(NR)}}'
    done
else
    tail -n${NUM_LAST_TR} $SCRATCH_PATH | awk '{sum+=$11} END {if(sum/NR>=0.7){printf "\033[38;5;10m  Accepted %3d over %d (%lf%%)\n\033[0m", sum, NR, 100*sum/(NR)}\
                                            else if(sum/NR<0.7 && sum/NR>=0.6){printf "\033[38;5;11m  Accepted %3d over %d (%lf%%)\n\033[0m", sum, NR, 100*sum/(NR)}
                                            else if(sum/NR<0.6 && sum/NR>=0.5){printf "\033[38;5;202m  Accepted %3d over %d (%lf%%)\n\033[0m", sum, NR, 100*sum/(NR)}
                                                                          else{printf "\033[38;5;9m  Accepted %3d over %d (%lf%%)\n\033[0m", sum, NR, 100*sum/(NR)}}'
fi    
printf "\e[0;36m======================================\e[0m\n\n"
