#!/bin/bash

# This script is intended to copy a set of configurations from remote and
# to calculate the Chiral Condensate on them. It has been developed specifically
# for LOEWE structure but can be easily generalized to other environnments.
#
# NOTE: In order to achieve our purposes, we use already existing scripts that
#       should be in the folder Script in the home directory.
#

# Source the common global script supposed to be in $(HOME)/Script
source $HOME/Script/PathManagement.sh || exit -2

# set an initial value for the options
EXECUTABLE="${HOME}/clhmc/build/inverter"
MEASURE_PBP="true"
MEASURE_CORRELATORS="false"
SOLVER="cg"
SOLVER_ITER=1000
SOURCETYPE="volume"
SOURCECONTENT="gaussian"
FERM_OBS_CORR_POSTFIX="_pbp"
NUM_SOURCES=96
USE_CPU="false"
USE_GPU="true"
HOST="loewe"
BETASFILE="betas"
COPYCONFIG="true"
CALCULATEPBP="true"
CONFIGHOST="juqueen"
JOBWALLTIME="06:00:00"

# extract options and their arguments into variables.
while [ "$1" != "" ]; do
    case $1 in
      -h | --help )
          printf "\n\e[0;32m"
          echo "Call the script $0 with the following optional arguments:"
          echo "  -h | --help"
          echo "  --executable            ->    default value = ${HOME}/clhmc/build/inverter"
          echo "  --measure_correlators   ->    default value = false"
          echo "  --solver                ->    default value = cg"
          echo "  --cgmax                 ->    default value = 1000"
          echo "  --sourcetype            ->    default value = volume"
          echo "  --sourcecontent         ->    default value = gaussian"
          echo "  --ferm_obs_corr_postfix ->    defualt value = _pbp"
          echo "  --num_sources           ->    default value = 96"
          echo "  --use_cpu               ->    default value = false"
          echo "  --use_gpu               ->    default value = true"
          echo "  --host                  ->    default value = loewe"
          echo "  --betasfile             ->    default value = betas"
          echo "  --copyconfig            ->    default value = true"
          echo "  --calculatepbp          ->    default value = true"
          echo "  --confighost            ->    default value = juqueen"
          echo "  --walltime              ->    default value = 06:00:00 (6h)"
          printf "\n\e[0m"
          exit
          shift;;
      --executable=* )             EXECUTABLE=${1#*=}; shift ;;
      --measure_correlators=* )    MEASURE_CORRELATORS=${1#*=}; shift ;;
      --solver=* )                 SOLVER=${1#*=}; shift ;;
      --cgmax=* )                  SOLVER_ITER=${1#*=}; shift ;;
      --sourcetype=* )             SOURCETYPE=${1#*=}; shift ;;
      --sourcecontent=* )          SOURCECONTENT=${1#*=}; shift ;;
      --ferm_obs_corr_postfix=* )  FERM_OBS_CORR_POSTFIX=${1#*=}; shift ;;
      --num_sources=* )            NUM_SOURCES=${1#*=}; shift ;;
      --use_cpu=* )                USE_CPU=${1#*=}; shift ;;
      --use_gpu=* )                USE_GPU=${1#*=}; shift ;;
      --host=* )                   HOST=${1#*=}; shift ;;
      --betasfile=* )              BETASFILE=${1#*=}; shift ;;
      --copyconfig=* )             COPYCONFIG=${1#*=}; shift ;;
      --calculatepbp=* )           CALCULATEPBP=${1#*=}; shift ;;
      --confighost=* )             CONFIGHOST=${1#*=}; shift ;;
      --walltime=* )               JOBWALLTIME=${1#*=}; shift ;;
      * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
done

# Options for "CalculatePbp.sh"
PBPSCRIPTOPTIONS="--executable=$EXECUTABLE --measure_correlators=$MEASURE_CORRELATORS --solver=$SOLVER\
 --cgmax=$SOLVER_ITER --sourcetype=$SOURCETYPE --sourcecontent=$SOURCECONTENT --ferm_obs_corr_postfix=$FERM_OBS_CORR_POSTFIX\
 --num_sources=$NUM_SOURCES --use_cpu=$USE_CPU --use_gpu=$USE_GPU --host=$HOST --walltime=$JOBWALLTIME"

shopt -s nocasematch
if [[ "$HOST" = "loewe" ]]; then
    HOST=$(echo $HOST | awk '{print tolower($0)}')
fi
if [[ "$CONFIGHOST" = "juqueen" || "$CONFIGHOST" = "gpu03" ]]; then
    CONFIGHOST=$(echo $CONFIGHOST | awk '{print tolower($0)}')
fi
shopt -u nocasematch

# Configurations path specific to each cluster
if [ "$CONFIGHOST" == "juqueen" ]; then
    PATHTOCONFIG_PREFIX="/work/hkf8/hkf805/WilsonProject"
elif [ "$CONFIGHOST" == "gpu03" ]; then
    PATHTOCONFIG_PREFIX="/home/sciarra/WilsonProject"
else
    printf "\n\e[0;31m  Host \"$CONFIGHOST\" from which configurations should be copied unknown! Aborting...\n\n\e[0m"
    exit -1
fi

# For the moment only the part on the loewe is implemented
if [ "$HOST" == "loewe" ]; then 
    INPUTDIR_PREFIX="/home/hfftheo/sciarra/WilsonProject"
    WORKDIR_PREFIX="/scratch/hfftheo/sciarra/WilsonProject"
    SCRIPTDIR="/home/hfftheo/sciarra/Script"
    if [ ! -d $SCRIPTDIR ]; then
	printf "\n\e[0;31m  Script directory not existing or accessible. Aborting...\n\n\e[0m"
	exit -1
    fi
    for s in CalculatePbp.sh CopyConfigs.sh RenameTMLQCDconfigs.sh; do
	if [ ! -e $SCRIPTDIR/${s} ]; then
	    printf "\n\e[0;31m  Script \"${s}\" required but non in the \"$SCRIPTDIR\" folder. Aborting...\n\n\e[0m"
	    exit -1
	fi
    done
    if [ ! -d $INPUTDIR_PREFIX ]; then
	printf "\n\e[0;31m  Input directory not existing or accessible. Aborting...\n\n\e[0m"
	exit -1
    fi
    # Let us read from pwd some parameters (we should be in the right place here)
    ReadParametersFromPath $(pwd)
    INPUTDIR="${INPUTDIR_PREFIX}${PARAMETERS_PATH}"
    WORKDIR="${WORKDIR_PREFIX}${PARAMETERS_PATH}"
    mkdir -p $WORKDIR
    if [ "$INPUTDIR" != "$(pwd)" ]; then
	printf "\n\e[0;31m Input directory for does not match the actual position! Aborting...\n\n\e[0m"
	exit -1
    fi

    # Beta has to be read from the betasfile
    if [ ! -e $BETASFILE ]; then
	printf "\n\e[0;31m  File \"$BETASFILE\" not found in $(pwd). Aborting...\n\n\e[0m"
	exit -1
    fi
    BETAVALUES=( `awk '{ if(!( $0 ~ /^(\ *#.*)/ )) print $0}' $BETASFILE` ) #Here we read all the betas from file discarding commented lines (starting by #)
    printf "\n\e[0;36m===================================================================================\n"
    printf "\e[0;34m Values of beta for which configurations will be copied and pbp will be calculated:\n"
    for (( i=0; i<${#BETAVALUES[@]}; i++ )); do
	echo "  - ${BETAVALUES[$i]}"
    done
    printf "\e[0;36m===================================================================================\n\e[0m"

    # Let us move to the working directory
    cd $WORKDIR || exit 2

    # Let us copy configurations using the script "CopyConfigs.sh" and rename them using "RenameTMLQCDconfigs.sh"
    if [ "$COPYCONFIG" == "true" ]; then
	for (( i=0; i<${#BETAVALUES[@]}; i++ )); do
	    mkdir -p b${BETAVALUES[$i]} || exit 2
	    if test -n "$(find b${BETAVALUES[$i]} -maxdepth 1 -name 'conf*' -print -quit)"; then
		printf "\n\e[0;31m  Folder $(pwd)/b${BETAVALUES[$i]} already contains some \"conf*\" file! Aborting...\n\n\e[0m"
		exit -1
            fi
	    bash $SCRIPTDIR/CopyConfigs.sh ${CONFIGHOST}\:${PATHTOCONFIG_PREFIX}${PARAMETERS_PATH}/b${BETAVALUES[$i]} $(pwd)/b${BETAVALUES[$i]}
	    if [ $? -ne 0 ]; then
		printf "\n\e[0;31m  Some error occurred copying configurations for beta=${BETAVALUES[$i]}! Aborting...\n\n\e[0m"
		exit -1
	    fi
	    bash $SCRIPTDIR/RenameTMLQCDconfigs.sh b${BETAVALUES[$i]}
	    if [ $? -ne 0 ]; then
                printf "\n\e[0;31m  Some error occurred renaming configurations for beta=${BETAVALUES[$i]}! Aborting...\n\n\e[0m"
                exit -1
            fi
	done
    fi

    # Let us move back to the input directory
    cd $INPUTDIR || exit 2

    # Let us calculate pbp using the script "CalculatePbp.sh"
    if [ "$CALCULATEPBP" == "true" ]; then
	for (( i=0; i<${#BETAVALUES[@]}; i++ )); do
	    mkdir b${BETAVALUES[$i]} || exit 2 # Here we interrupt the script if the directory already exists. Add -p option to avoid this.
	    cd b${BETAVALUES[$i]} || exit 2
	    cp $SCRIPTDIR/CalculatePbp.sh . || exit 2
	    bash $SCRIPTDIR/CalculatePbp.sh $PBPSCRIPTOPTIONS --ntime=$NTIME --nspace=$NSPACE
	    if [ $? -ne 0 ]; then
		printf "\n\e[0;31m  Some error occurred creating and submitting job to calculate pbp for for beta=${BETAVALUES[$i]}! Aborting...\n\n\e[0m"
		exit -1
	    fi
	    cd $INPUTDIR || exit 2
	done
    fi

    # Let us move back to the input directory
    cd $INPUTDIR || exit 2

else # endif [ "$HOST" == "loewe" ]
    printf "\n\e[0;31m  Host \"$HOST\" unknown! Aborting...\n\n\e[0m"
    exit -1
fi

exit 0
