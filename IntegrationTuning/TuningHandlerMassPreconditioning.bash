#!/bin/bash
#
#  Copyright (c) 2015 Alessandro Sciarra
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


# This script is to automatize the Integrator tuning in hmc simulation with
# mass preconditioning.
# It is not really well written as script, but it is just ad hoc with
# not so general cases treated.
#
# It creates a folder with a name XX_YY_ZZ_kmpTTTT from where it is run.
#  - XX is the number of integration steps on the innermost scale
#  - YY on the middle scale
#  - ZZ on the outermost scale
#  - TTTT is the value of the kappa_mp
#
# 3 timescales are mandatory! The integrator is always 2MN integrator per each timescale.
# The tuning is meant to be on the outermost scale as well as on the kappa_mp, while
# the innermost scales are kept fixed.
#
# Since on LOEWE now one should group GPU_PER_NODE srun in order not to waste
# computing time, in this script the user will have to specify
# the number of the outermost scale and the value of kappa_mp in the following
# way:
#                      Xmin:Xmax:delta
# where Xmin is the minimum value that will be used, Xmax is the maximum, and delta is
# the resolution with which to scan. All the possibility will be then done. For example:
#  --intsteps2=4:6:1
#  --kmp=1525:1600:25
# will make the following 12 simulations start:
#  (4,1525) - (4,1550) - (4,1575) - (4,1600)
#  (5,1525) - (5,1550) - (5,1575) - (5,1600)
#  (6,1525) - (6,1550) - (6,1575) - (6,1600)
#
#
# From the path some parameters like kxappa, ns, nt, mu are deduced.

#-----------------------------------------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source $HOME/Script/PathManagement.sh || exit -2
source $HOME/Script/IntegrationTuning/AuxiliaryFunctionsTuningMassPreconditioning.sh || exit -2
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
# Set default values for the command line parameters

BETA_PREFIX="b"
WALLTIME="06:00:00"
MEASUREMENTS="100"
NSAVE="300"
NUMTIMESCALES=3
INTSTEPS0="2"
INTSTEPS1="2"
INTSTEPS2="6:7:1"
KAPPA_MP="1525:1600:25"
LOEWE_PARTITION="parallel"
LOEWE_CONSTRAINT="gpu"
LOEWE_NODE="unset"
EVALUATEONLY=0

#-----------------------------------------------------------------------------------------------------------------#
# Set default values for the non-modifyable variables ---> Modify this file to change them!
source $HOME/Script/IntegrationTuning/UserSpecificVariables_$(whoami).sh || exit -2
#-----------------------------------------------------------------------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Extract options and their arguments into variables.
ParseCommandLineOption $@
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Perform all the checks on the path, reading out some variables
CheckSingleOccurrenceInPath "scratch" "hfftheo" "$(whoami)" "mui" "k[[:digit:]]\+" "nt[[:digit:]]\+" "ns[[:digit:]]\+"

ReadParametersFromPath $(pwd)
BETA=$(echo "$(pwd)" | awk '{if(index($0, "/b") != 0){print substr($0, index($0, "/b") + 2, 6)}else{print 0}}')
if [[ ! $BETA =~ ^[0-9]+([.][0-9]+)?$ || $BETA = "0" ]]; then
    echo "Unable to recover beta from the path \"$(pwd)\". Aborting..."
    exit -1
fi
WORK_BETADIRECTORY="$WORK_DIR/$SIMULATION_PATH$PARAMETERS_PATH/$BETA_PREFIX$BETA"
if [ ! -d $WORK_BETADIRECTORY ]; then
    printf "\n\e[0;31m \"$WORK_BETADIRECTORY\" directory not found! Aborting...\n\n\e[0m"
    exit -1
fi
if [ "$WORK_BETADIRECTORY" != "$(pwd)" ]; then
    printf "\n\e[0;31m Constructed path to local directory does not match the actual position! Aborting...\n\n\e[0m"
    exit -1
fi
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Parse the integrator steps ranges from what has been given from command line
ParseIntegratorSteps #here INTSTEPS2 and KAPPA_MP become array with (min max delta)
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Check that the thermalized configuration is in the folder WORK_BETADIRECTORY
if [ $(ls $WORK_BETADIRECTORY | grep "^conf.*" | wc -l) -ne 1 ]; then
    printf "\n\e[0;31m Thermalized configuration not present in $WORK_BETADIRECTORY folder (or more than one)! Aborting...\n\n\e[0m"
    exit -1
fi
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Create the folder XX_YY and inside the Input file
TOTAL_NUMBER_OF_SRUN=0
for((i=${INTSTEPS2[0]}; i<=${INTSTEPS2[1]}; i+=${INTSTEPS2[2]})); do
    for((j=${KAPPA_MP[0]}; j<=${KAPPA_MP[1]}; j+=${KAPPA_MP[2]})); do
	TOTAL_NUMBER_OF_SRUN=$(($TOTAL_NUMBER_OF_SRUN + 1))
    done
done
if [ $(echo "$TOTAL_NUMBER_OF_SRUN" | awk '{print $1 % '"$GPU_PER_NODE"'}') -ne 0 ]; then
    printf "\n\e[0;33m \e[1m\e[4mWARNING\e[24m:\e[0;33m Asked to run $TOTAL_NUMBER_OF_SRUN tunings (not multiple of $GPU_PER_NODE). WASTING computing time...\n\e[0m"
fi

if [ $EVALUATEONLY -eq 1 ]; then
    if [ $(echo "$TOTAL_NUMBER_OF_SRUN" | awk '{print $1 % '"$GPU_PER_NODE"'}') -eq 0 ]; then
	printf "\n\e[0;32m \e[1m\e[4mCONGRATULATION\e[24m:\e[0;32m Asked to run $TOTAL_NUMBER_OF_SRUN tunings,"
	printf " multiple of $GPU_PER_NODE  ===>  $(($TOTAL_NUMBER_OF_SRUN/$GPU_PER_NODE)) jobs!\n\n\e[0m"
    else
	echo ""
    fi
    exit 0
fi

for((i=${INTSTEPS2[0]}; i<=${INTSTEPS2[1]}; i+=${INTSTEPS2[2]})); do
    for((j=${KAPPA_MP[0]}; j<=${KAPPA_MP[1]}; j+=${KAPPA_MP[2]})); do
	if [ -d "${INTSTEPS0}_${INTSTEPS1}_${i}_kmp${j}" ]; then
	    printf "\n\e[0;31m Directory \"${INTSTEPS0}_${INTSTEPS1}_${i}_kmp${j}\" already existing! Aborting...\n\n\e[0m"
	    exit -1
	fi
    done
done
#If the previous for loop went through, we create the folders to tune (just to avoid to create some folders and then abort)
printf "\n\e[0;36m*************************************************\n\e[0;36m"
for((i=${INTSTEPS2[0]}; i<=${INTSTEPS2[1]}; i+=${INTSTEPS2[2]})); do
    for((j=${KAPPA_MP[0]}; j<=${KAPPA_MP[1]}; j+=${KAPPA_MP[2]})); do
	mkdir "${INTSTEPS0}_${INTSTEPS1}_${i}_kmp${j}" || exit -2
	printf "* \e[0;35m Folder \e[0;32m\"${INTSTEPS0}_${INTSTEPS1}_${i}_kmp${j}\"\e[0;35m successfully created! \e[0;36m*\n"
    done
done
printf "\e[0;36m*************************************************\n\e[0m"
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Create the input files inside each XX_YY_ZZ_kmpTTTT folder and copy there the thermalized configuration
for((i=${INTSTEPS2[0]}; i<=${INTSTEPS2[1]}; i+=${INTSTEPS2[2]})); do
    for((j=${KAPPA_MP[0]}; j<=${KAPPA_MP[1]}; j+=${KAPPA_MP[2]})); do
	LOCALPATH_TO_INPUTFILE="${INTSTEPS0}_${INTSTEPS1}_${i}_kmp${j}/$INPUTFILE_NAME"
	INPUTFILE_GLOBALPATH="${WORK_BETADIRECTORY}/$LOCALPATH_TO_INPUTFILE"
	ProduceInputFile
	cp conf.* ${INTSTEPS0}_${INTSTEPS1}_${i}_kmp${j}/conf.start || exit -2
    done
done
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Collect GPU_PER_NODE pairs of integrator2 steps and kappa_mp values and create the JobScript files inside the JOBSCRIPT_FOLDER
mkdir -p ${WORK_BETADIRECTORY}/$JOBSCRIPT_LOCALFOLDER || exit -2
JOBS_TO_BE_SUBMITTED=()
STEPS_TOGETHER=()
for((i=${INTSTEPS2[0]}; i<=${INTSTEPS2[1]}; i+=${INTSTEPS2[2]})); do
    for((j=${KAPPA_MP[0]}; j<=${KAPPA_MP[1]}; j+=${KAPPA_MP[2]})); do
	STEPS_TOGETHER+=( "$i" "$j")
    done
done

while [[ "${!STEPS_TOGETHER[@]}" != "" ]]; do # ${!array[@]} gives the list of the valid indeces in the array
    STEPS_FOR_JOBSCRIPT=(${STEPS_TOGETHER[@]:0:$((2*$GPU_PER_NODE))})
    STEPS_TOGETHER=(${STEPS_TOGETHER[@]:$((2*$GPU_PER_NODE))})
    STEPS_STRING=""
    printf "\n\e[0;36m======================================================\n\e[0m"
    printf "\e[0;36m  The following Int. steps values have been grouped:\e[0m\n       "
    for((i=0; i<${#STEPS_FOR_JOBSCRIPT[@]}; i+=2)); do
	printf "${STEPS_FOR_JOBSCRIPT[$i]}-${STEPS_FOR_JOBSCRIPT[$(($i+1))]}     "
	STEPS_STRING="${STEPS_STRING}_${STEPS_FOR_JOBSCRIPT[$i]}-${STEPS_FOR_JOBSCRIPT[$(($i+1))]}"
    done
    printf "\n\e[0;36m======================================================\n\e[0m"
    JOBSCRIPT_NAME="${JOBSCRIPT_PREFIX}_${PARAMETERS_STRING}_${BETA_PREFIX}${BETA}_${STEPS_STRING:1}"
    JOBSCRIPT_GLOBALPATH="${WORK_BETADIRECTORY}/$JOBSCRIPT_LOCALFOLDER/$JOBSCRIPT_NAME"
    if [ -e $JOBSCRIPT_GLOBALPATH ]; then
	mv $JOBSCRIPT_GLOBALPATH ${JOBSCRIPT_GLOBALPATH}_$(date +'%F_%H%M') || exit -2
    fi
    ProduceJobScriptFile "${STEPS_FOR_JOBSCRIPT[@]}"
    if [ -e $JOBSCRIPT_GLOBALPATH ]; then
	JOBS_TO_BE_SUBMITTED+=( "$JOBSCRIPT_NAME" )
    else
	printf "\n\e[0;31m Jobscript \"$JOBSCRIPT_NAME\" failed to be created! It will be not submitted!!!\n\e[0m"
    fi
done

#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Submit valid jobs
for JOB in "${JOBS_TO_BE_SUBMITTED[@]}"; do
    cd "${WORK_BETADIRECTORY}/$JOBSCRIPT_LOCALFOLDER"
    printf "\n\e[0;34m Actual location: \e[0;35m$(pwd) \n\e[0m"
    printf "\e[0;34m      Submitting:\e[0m"
    printf "\e[0;32m \e[4msbatch $JOBSCRIPT_NAME\n\e[0m"
    sbatch $JOB
done

printf "\e[1;36m___________________________________________________________________________________________________\n\n\e[0m"



