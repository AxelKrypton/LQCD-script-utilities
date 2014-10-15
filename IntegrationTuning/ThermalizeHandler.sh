#!/bin/bash

# This script is to thermalize a hot/cold configuration in a MC run.
# It is not really well written as script, but it is just ad hoc with
# not so general cases treated.
#
# FROM WHERE IT IS RUN, it creates a folder with the name "bX.XXXX/getConf"
# for each beta value X.XXXX inside the betas file (that of course has to exist). If
# the folder "get conf" inside the beta folder already exists, then the program aborts.
# Once the folder is created, an input file and job script are created on the basis
# of the given command line parameters and the job is submitted.
#
# ATTENTION: Multiple values of betas are used at the same time and the most
#            efficient setup is when in the betas file the number of beta values
#            is multiple of GPU_PER_NODE. If not, the first GPU_PER_NODE will be packed into one job,
#            the second GPU_PER_NODE into another, and so on; the last (1,2,...,GPU_PER_NODE-1)
#            will be then packed.
#
# From the path some parameters like kappa, ns, nt, mu are deduced.

#-----------------------------------------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source $HOME/Script/PathManagement.sh || exit -2
source $HOME/Script/IntegrationTuning/AuxiliaryFunctionsThermalize.sh || exit -2
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
BETASFILE="betas"
WALLTIME="06:00:00"
MEASUREMENTS="1000"
NSAVE="200"
STARTCONDITION="hot"
NUMTIMESCALES=2
INTSTEPS0=7
INTSTEPS1=5
LOEWE_PARTITION="parallel"
LOEWE_CONSTRAINT="gpu"
LOEWE_NODE="unset"

#-----------------------------------------------------------------------------------------------------------------#
# Paths on LOEWE using CL2QCD
USER_MAIL="sciarra@th.physik.uni-frankfurt.de"
HMC_BUILD_PATH="clhmc/build/RefExec"
SIMULATION_PATH="IntegratorTest"
HOME_DIR="/home/hfftheo/sciarra" 
WORK_DIR="/scratch/hfftheo/sciarra" 
HMC_FILENAME="hmc_ref"
HMC_GLOBALPATH="$HOME_DIR/$HMC_BUILD_PATH/$HMC_FILENAME"
INPUTFILE_NAME="hmc.input"
JOBSCRIPT_PREFIX="job.cl2qcd.Thermalize"
JOBSCRIPT_LOCALFOLDER="JobScripts"
GPU_PER_NODE=4
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Extract options and their arguments into variables.
ParseCommandLineOption $@
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Perform all the checks on the path, reading out some variables 
CheckSingleOccurrenceInPath "scratch" "hfftheo" "$(whoami)" "mui" "k[[:digit:]]\+" "nt[[:digit:]]\+" "ns[[:digit:]]\+"

ReadParametersFromPath $(pwd)

#BETA=$(echo "$(pwd)" | awk '{if(index($0, "/b") != 0){print substr($0, index($0, "/b") + 2, 6)}else{print 0}}')
#if [[ ! $BETA =~ ^[0-9]+([.][0-9]+)?$ || $BETA = "0" ]]; then
#    echo "Unable to recover beta from the path \"$(pwd)\". Aborting..."
#    exit -1
#fi

WORK_DIR_WITH_BETAFOLDERS="$WORK_DIR/$SIMULATION_PATH$PARAMETERS_PATH"
if [ ! -d $WORK_DIR_WITH_BETAFOLDERS ]; then
    printf "\n\e[0;31m \"$WORK_DIR_WITH_BETAFOLDERS=\" directory not found! Aborting...\n\n\e[0m"
    exit -1
fi
if [ "$WORK_DIR_WITH_BETAFOLDERS" != "$(pwd)" ]; then
    printf "\n\e[0;31m Constructed path to local directory does not match the actual position! Aborting...\n\n\e[0m"
    exit -1
fi
#-----------------------------------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------------------------------#
ReadBetaValuesFromFile  # Here we declare and fill the array BETAVALUES

if [ $(echo "${#BETAVALUES[@]}" | awk '{print $1 % '"$GPU_PER_NODE"'}') -ne 0 ]; then
    printf "\n\e[0;33m \e[1m\e[4mWARNING\e[24m:\e[0;33m Number of beta values provided not multiple of 4. WASTING computing time...\n\n\e[0m"
fi

for BETA in ${BETAVALUES[@]}; do
    if [ -d "$BETA_PREFIX$BETA/getConf" ]; then
	printf "\n\e[0;31m Directory \"$BETA_PREFIX$BETA/getConf\" already existing! Aborting...\n\n\e[0m"
	exit -1
    fi
done
#If the previous for loop went through, we create the folders to thermalize (just to avoid to create some folders and then abort)
printf "\n\e[0;36m**************************************************\n\e[0m"
for BETA in ${BETAVALUES[@]}; do
    mkdir -p "$BETA_PREFIX$BETA/getConf" || exit -2
    printf "*\e[0;35m Folder \e[0;32m\"$BETA_PREFIX$BETA/getConf\"\e[0;35m successfully created! \e[0;36m*\n"
done
printf "\e[0;36m**************************************************\n\e[0m"
#-----------------------------------------------------------------------------------------------------------------#


#-------------------------------------------------------------------------------------------------------------------------#
# Create the input files inside each betafolder 
for BETA in ${BETAVALUES[@]}; do
    LOCALPATH_TO_INPUTFILE="$BETA_PREFIX$BETA/getConf/$INPUTFILE_NAME"
    INPUTFILE_GLOBALPATH="${WORK_DIR_WITH_BETAFOLDERS}/$LOCALPATH_TO_INPUTFILE"
    ProduceInputFile
done
#-------------------------------------------------------------------------------------------------------------------------#


#-------------------------------------------------------------------------------------------------------------------------#
# Partition the BETAVALUES array into group of GPU_PER_NODE and create the JobScript files inside the JOBSCRIPT_FOLDER
mkdir -p ${WORK_DIR_WITH_BETAFOLDERS}/$JOBSCRIPT_LOCALFOLDER || exit -2
BETAVALUES=(${BETAVALUES[@]}) #If sparse, make it not sparse, not necessary because it has been created as not sparse
                              #but I left on purpose this line because if sparse, the following while doesn't work!!
JOBS_TO_BE_SUBMITTED=()
while [[ "${!BETAVALUES[@]}" != "" ]]; do # ${!array[@]} gives the list of the valid indeces in the array
    BETA_FOR_JOBSCRIPT=(${BETAVALUES[@]:0:$GPU_PER_NODE})
    BETAVALUES=(${BETAVALUES[@]:$GPU_PER_NODE})
    BETAS_STRING=""
    printf "\n\e[0;36m=================================================\n\e[0m"
    printf "\e[0;36m  The following beta values have been grouped:\e[0m\n    "
    for BETA in "${!BETA_FOR_JOBSCRIPT[@]}"; do
	printf "${BETA_FOR_JOBSCRIPT[BETA]}     "
	BETAS_STRING="${BETAS_STRING}_$BETA_PREFIX${BETA_FOR_JOBSCRIPT[BETA]}"
    done
    printf "\n\e[0;36m=================================================\n\e[0m"
    JOBSCRIPT_NAME="${JOBSCRIPT_PREFIX}_${PARAMETERS_STRING}_${BETAS_STRING:1}"
    JOBSCRIPT_GLOBALPATH="${WORK_DIR_WITH_BETAFOLDERS}/$JOBSCRIPT_LOCALFOLDER/$JOBSCRIPT_NAME"
    if [ -e $JOBSCRIPT_GLOBALPATH ]; then
	mv $JOBSCRIPT_GLOBALPATH ${JOBSCRIPT_GLOBALPATH}_$(date +'%F_%H%M') || exit -2
    fi
    ProduceJobScriptFile "${BETA_FOR_JOBSCRIPT[@]}"    
    if [ -e $JOBSCRIPT_GLOBALPATH ]; then
	JOBS_TO_BE_SUBMITTED+=( "$JOBSCRIPT_NAME" )
    else
	printf "\n\e[0;31m Jobscript \"$JOBSCRIPT_NAME\" failed to be created! It will be not submitted!!!\n\n\e[0m"
    fi
done


#-------------------------------------------------------------------------------------------------------------------------#
# Submit valid jobs
for JOB in "${JOBS_TO_BE_SUBMITTED[@]}"; do
    cd "${WORK_DIR_WITH_BETAFOLDERS}/$JOBSCRIPT_LOCALFOLDER"
    printf "\n\e[0;34m Actual location: \e[0;35m$(pwd) \n\e[0m"
    printf "\e[0;34m      Submitting:\e[0m"
    printf "\e[0;32m \e[4msbatch $JOBSCRIPT_NAME\n\e[0m"
    sbatch $JOB
done

printf "\e[1;36m___________________________________________________________________________________________________\n\n\e[0m"

