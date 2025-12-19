#!/bin/bash

# This script is to automatize the Integrator tuning in hmc simulation.
# It is not really well written as script, but it is just ad hoc with
# not so general cases treated.
#
# It creates a folder with a name XX_YY from where it is run. XX is the
# number of integration steps on the gauge part, YY on the fermionic part.
# 0_YY means that only one timescale is used. The integrator is always
# 2MN integrator.
#
# Since on LOEWE now one should group GPU_PER_NODE srun in order not to waste 
# computing time, in this script the user will have to specify
# the number of integration steps for each scale in the following
# way: 
#                      Smin:Smax:delta
# where Smin is the minimum number of steps that will be used on
# that scale, Smax is the maximum, and delta is the resolution
# with which to scan. All the possibility will be then done. For example:
#  --intsteps0=4:6:1
#  --intsteps1=24:30:2
# will make the following 12 simulations start:
#  (4,24) - (4,26) - (4,28) - (4,30)  
#  (5,24) - (5,26) - (5,28) - (5,30)  
#  (6,24) - (6,26) - (6,28) - (6,30)  
#
#
# From the path some parameters like kappa, ns, nt, mu are deduced.

#-----------------------------------------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source $HOME/Script/PathManagement.sh || exit -2
source $HOME/Script/IntegrationTuning/AuxiliaryFunctionsTuning.sh || exit -2
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
NUMTIMESCALES=1
INTSTEPS0="4:7:1"
INTSTEPS1=""
LOEWE_PARTITION="parallel"
LOEWE_CONSTRAINT="gpu"
LOEWE_NODE="unset"
EVALUATEONLY=0

#-----------------------------------------------------------------------------------------------------------------#
# Paths on LOEWE using CL2QCD
#USER_MAIL="sciarra@th.physik.uni-frankfurt.de"
#HMC_BUILD_PATH="clhmc/build/RefExec"
#SIMULATION_PATH="IntegratorTest"
#HOME_DIR="/home/hfftheo/sciarra" 
#WORK_DIR="/scratch/hfftheo/sciarra" 
#HMC_FILENAME="hmc_ref"
#HMC_GLOBALPATH="$HOME_DIR/$HMC_BUILD_PATH/$HMC_FILENAME"
#INPUTFILE_NAME="hmc.input"
#JOBSCRIPT_PREFIX="job.cl2qcd.IntTest"
#JOBSCRIPT_LOCALFOLDER="JobScripts"
#GPU_PER_NODE=4 #If you change this number to a crazy value like 0, do not complain for what you get...
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
ParseIntegratorSteps #here INTSTEPS(0,1) become array with (min max delta)
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Check that the thermalized configuration is in the folder WORK_BETADIRECTORY
if [ $(ls $WORK_BETADIRECTORY | grep "conf.*" | wc -l) -ne 1 ]; then
    printf "\n\e[0;31m Thermalized configuration not present in $WORK_BETADIRECTORY folder! Aborting...\n\n\e[0m"
    exit -1
fi
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Create the folder XX_YY and inside the Input file
TOTAL_NUMBER_OF_SRUN=0
for((i=${INTSTEPS0[0]}; i<=${INTSTEPS0[1]}; i+=${INTSTEPS0[2]})); do
    for((j=${INTSTEPS1[0]}; j<=${INTSTEPS1[1]}; j+=${INTSTEPS1[2]})); do
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

for((i=${INTSTEPS0[0]}; i<=${INTSTEPS0[1]}; i+=${INTSTEPS0[2]})); do
    for((j=${INTSTEPS1[0]}; j<=${INTSTEPS1[1]}; j+=${INTSTEPS1[2]})); do
	if [ -d "${i}_${j}" ]; then
	    printf "\n\e[0;31m Directory \"${i}_${j}\" already existing! Aborting...\n\n\e[0m"
	    exit -1
	fi
    done
done
#If the previous for loop went through, we create the folders to thermalize (just to avoid to create some folders and then abort)
printf "\n\e[0;36m***************************************\n\e[0m"
for((i=${INTSTEPS0[0]}; i<=${INTSTEPS0[1]}; i+=${INTSTEPS0[2]})); do
    for((j=${INTSTEPS1[0]}; j<=${INTSTEPS1[1]}; j+=${INTSTEPS1[2]})); do
	mkdir "${i}_${j}" || exit -2
	printf " \e[0;35m Folder \e[0;32m\"${i}_${j}\"\e[0;35m successfully created! \e[0;36m\n"
    done
done
printf "\e[0;36m***************************************\n\e[0m"
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Create the input files inside each XX_YY folder and copy there the thermalized configuration
for((i=${INTSTEPS0[0]}; i<=${INTSTEPS0[1]}; i+=${INTSTEPS0[2]})); do
    for((j=${INTSTEPS1[0]}; j<=${INTSTEPS1[1]}; j+=${INTSTEPS1[2]})); do
	LOCALPATH_TO_INPUTFILE="${i}_${j}/$INPUTFILE_NAME"
	INPUTFILE_GLOBALPATH="${WORK_BETADIRECTORY}/$LOCALPATH_TO_INPUTFILE"
	ProduceInputFile
	cp conf.* ${i}_${j}/conf.start
    done
done
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Collect GPU_PER_NODE pairs of integrator steps values and create the JobScript files inside the JOBSCRIPT_FOLDER
mkdir -p ${WORK_BETADIRECTORY}/$JOBSCRIPT_LOCALFOLDER || exit -2
JOBS_TO_BE_SUBMITTED=()
INTSTEPS_TOGETHER=()
for((i=${INTSTEPS0[0]}; i<=${INTSTEPS0[1]}; i+=${INTSTEPS0[2]})); do
    for((j=${INTSTEPS1[0]}; j<=${INTSTEPS1[1]}; j+=${INTSTEPS1[2]})); do
	INTSTEPS_TOGETHER+=( "$i" "$j")
    done
done

while [[ "${!INTSTEPS_TOGETHER[@]}" != "" ]]; do # ${!array[@]} gives the list of the valid indeces in the array
    INTSTEPS_FOR_JOBSCRIPT=(${INTSTEPS_TOGETHER[@]:0:$((2*$GPU_PER_NODE))})
    INTSTEPS_TOGETHER=(${INTSTEPS_TOGETHER[@]:$((2*$GPU_PER_NODE))})
    INTSTEPS_STRING=""
    printf "\n\e[0;36m======================================================\n\e[0m"
    printf "\e[0;36m  The following Int. steps values have been grouped:\e[0m\n       "
    for((i=0; i<${#INTSTEPS_FOR_JOBSCRIPT[@]}; i+=2)); do
	printf "${INTSTEPS_FOR_JOBSCRIPT[$i]}-${INTSTEPS_FOR_JOBSCRIPT[$(($i+1))]}        "
	INTSTEPS_STRING="${INTSTEPS_STRING}_${INTSTEPS_FOR_JOBSCRIPT[$i]}-${INTSTEPS_FOR_JOBSCRIPT[$(($i+1))]}"
    done
    printf "\n\e[0;36m======================================================\n\e[0m"
    JOBSCRIPT_NAME="${JOBSCRIPT_PREFIX}_${PARAMETERS_STRING}_${INTSTEPS_STRING:1}"
    JOBSCRIPT_GLOBALPATH="${WORK_BETADIRECTORY}/$JOBSCRIPT_LOCALFOLDER/$JOBSCRIPT_NAME"
    if [ -e $JOBSCRIPT_GLOBALPATH ]; then
	mv $JOBSCRIPT_GLOBALPATH ${JOBSCRIPT_GLOBALPATH}_$(date +'%F_%H%M') || exit -2
    fi
    ProduceJobScriptFile "${INTSTEPS_FOR_JOBSCRIPT[@]}"
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



