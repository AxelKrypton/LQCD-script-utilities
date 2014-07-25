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
# From the path some parameters like kappa, ns, nt, mu are deduced.

#-----------------------------------------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source $HOME/Script/PathManagement.sh || exit -2
source $HOME/Script/IntegrationTuning/AuxiliaryFunctions.sh || exit -2
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
WALLTIME="01:00:00"
MEASUREMENTS="100"
NSAVE="300"
NUMTIMESCALES=1
INTSTEPS0=7
INTSTEPS1=5
LOEWE_PARTITION="test"
LOEWE_NODE="unset"

#-----------------------------------------------------------------------------------------------------------------#
# Paths on LOEWE using CL2QCD
USER_MAIL="sciarra@th.physik.uni-frankfurt.de"
HMC_BUILD_PATH="clhmc/build"
SIMULATION_PATH="IntegratorTest"
HOME_DIR="/home/hfftheo/sciarra" 
WORK_DIR="/scratch/hfftheo/sciarra" 
HMC_FILENAME="hmc"
HMC_GLOBALPATH="$HOME_DIR/$HMC_BUILD_PATH/$HMC_FILENAME"
INPUTFILE_NAME="hmc.input"
JOBSCRIPT_PREFIX="job.cl2qcd.IntTest"
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


#-------------------------------------------------------------------------------------------------------------------------#
# Create the folder XX_YY and inside the Input file and the JobScript
if [ $NUMTIMESCALES -eq 1 ]; then
    RUN_DIR="0_${INTSTEPS0}"
elif [ $NUMTIMESCALES -eq 2 ]; then
    RUN_DIR="${INTSTEPS0}_${INTSTEPS1}"
else
    printf "\n\e[0;31m NUMTIMESCALES=$NUMTIMESCALES not valid! Aborting...\n\n\e[0m"
    exit -1
fi
mkdir $RUN_DIR || exit -2
cd $RUN_DIR
ProduceInputFile
ProduceJobScriptFile
cd ..
#-------------------------------------------------------------------------------------------------------------------------#


#-------------------------------------------------------------------------------------------------------------------------#
# If there is only one file whose name starts by "conf.", then copy it to the folder and submit the job
if [ $(ls | grep "conf.*" | wc -l) -eq 1 ]; then
    cp conf.* $RUN_DIR/conf.start
    cd $RUN_DIR
    sbatch ${JOBSCRIPT_PREFIX}*
    cd ..
fi



