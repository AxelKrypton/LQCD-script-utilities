#!/bin/bash

# This script is intended to calculate the Chiral Condensate on a set of configurations
# placed in the folder from which it is invoked.
# Basically the "inverter" executable of CL2QCD is called per each configuration. 
# Such an executable, by default should be in the folder, otherwise it has to be specified.
# Since several options that could be given to such an executable are here fixed,
# we parse only those that are realistically sometimes changed. In any case all have
# some default value (see below).
#
# NOTE: To right this script quickly, everything starting with "conf" is considered
#       as configuration, i.e. as lime file. This means that if there is something that
#       is not such a file, it will produce some error.
#       This should not be the case but however is up to the user to manage it.
#

# Source the common global script supposed to be in $(HOME)/Script
source $HOME/Script/PathManagement.sh || exit -2

# set an initial value for the options
EXECUTABLE="./inverter"
NTIME=6
NSPACE=12
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
HOST=""
JOBWALLTIME="06:00:00"

# extract options and their arguments into variables.
while [ "$1" != "" ]; do
    case $1 in
      -h | --help )
	  printf "\n\e[0;32m"
	  echo "Call the script $0 with the following optional arguments:"
	  echo "  -h | --help"
	  echo "  --ntime                 ->    default value = 6"
	  echo "  --nspace                ->    default value = 12"
	  echo "  --executable            ->    default value = ./inverter"
	  echo "  --measure_correlators   ->    default value = false"
	  echo "  --solver                ->    default value = cg"
          echo "  --cgmax                 ->    default value = 1000"
	  echo "  --sourcetype            ->    default value = volume"
	  echo "  --sourcecontent         ->    default value = gaussian"
	  echo "  --ferm_obs_corr_postfix ->    defualt value = _pbp"
          echo "  --num_sources           ->    default value = 96"
          echo "  --use_cpu               ->    default value = false"
          echo "  --use_gpu               ->    default value = true"
          echo "  --host                  ->    default value = \"\""
          echo "  --walltime              ->    default value = 06:00:00 (6h)"
	  printf "\n\e[0m"
	  exit
	  shift;;
      --executable=* )             EXECUTABLE=${1#*=}; shift ;;
      --ntime=* )                  NTIME=${1#*=}; shift ;;
      --nspace=* )                 NSPACE=${1#*=}; shift ;;
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
      --walltime=* )               JOBWALLTIME=${1#*=}; shift ;;
      * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
done

# If the host is LOEWE we will assume the user want to run a job where to make the calculation of pbp
shopt -s nocasematch
if [[ "$HOST" = "loewe" ]]; then
    HOST="loewe"
fi
shopt -u nocasematch

if [ "$HOST" == "loewe" ]; then 
    # Let us read from pwd some parameters
    ReadParametersFromPath $(pwd)
    BETA=$(echo "$(pwd)" | awk '{if(index($0, "/b") != 0){print substr($0, index($0, "/b") + 2, 6)}else{print 0}}')
    if [[ ! $BETA =~ ^[0-9]+([.][0-9]+)?$ || $BETA = "0" ]]; then
	echo "Unable to recover beta from the path \"$(pwd)\". Aborting..."
	exit -1
    fi
   
    # Build string that will be used later
    PROGRAM_OPTIONS="--use_cpu=$USE_CPU --use_gpu=$USE_GPU --start=continue --ntime=$NTIME --nspace=$NSPACE --measure_pbp=$MEASURE_PBP --measure_correlators=$MEASURE_CORRELATORS --solver=$SOLVER --cgmax=$SOLVER_ITER --sourcetype=$SOURCETYPE --sourcecontent=$SOURCECONTENT --ferm_obs_corr_postfix=$FERM_OBS_CORR_POSTFIX --num_sources=$NUM_SOURCES"

    # First of all we have to wrte the job script, whose name is "job.calculate.pbp"
    JOBFILENAME="job.calculate.pbp"
    if [ -e $JOBFILENAME ]; then
	echo "File \"$JOBFILENAME\" already existing. Aborting..." 
	exit -1
    fi
    echo "#!/bin/sh" > $JOBFILENAME
    echo "#SBATCH --tasks=1" >> $JOBFILENAME
    echo "#SBATCH --cpus-per-task=1" >> $JOBFILENAME
    echo "#SBATCH --job-name=CalculatePbp_${PARAMETERS_STRING}_b$BETA" >> $JOBFILENAME
    echo "#SBATCH --mail-type=FAIL" >> $JOBFILENAME
    echo "#SBATCH --mail-user=sciarra@th.physik.uni-frankfurt.de" >> $JOBFILENAME
    echo "#SBATCH --output=pbp.%j.out" >> $JOBFILENAME
    echo "#SBATCH --error=pbp.%j.err" >> $JOBFILENAME
    echo "#SBATCH --time=${JOBWALLTIME}" >> $JOBFILENAME
    echo "#SBATCH --gres=gpu" >> $JOBFILENAME
    echo "#SBATCH --partition=parallel" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "WORKDIR=/scratch/hfftheo/sciarra/WilsonProject$PARAMETERS_PATH/b${BETA}" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "cd \$WORKDIR || exit 2" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "echo \"Date and time: \$(date)\"" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "printf \"\n=============================================================================================================\n\"" >> $JOBFILENAME
    echo "mkdir StdOutput/ || exit 2" >> $JOBFILENAME
    echo "mkdir Pbp/ || exit 2" >> $JOBFILENAME
    echo "NUMBER_OF_CONFIGURATIONS=\$(ls conf* | wc -l) " >> $JOBFILENAME
    echo "CONFIGURATIONS_DONE=0" >> $JOBFILENAME
    echo "for CONF in conf* ; do" >> $JOBFILENAME
    echo "    CONFIGURATIONS_DONE=\$(( \$CONFIGURATIONS_DONE+1 ))" >> $JOBFILENAME
    echo "    printf \"  -  Calculating chiral condensate (\$CONFIGURATIONS_DONE of \$NUMBER_OF_CONFIGURATIONS)\"" >> $JOBFILENAME
    echo "    printf \" on \$CONF using $NUM_SOURCES $SOURCETYPE-sources on a lattice ${NTIME}x${NSPACE}^3...\"" >> $JOBFILENAME
    echo "    srun $EXECUTABLE --sourcefile=\$CONF $PROGRAM_OPTIONS >> \${CONF}$FERM_OBS_CORR_POSTFIX.out" >> $JOBFILENAME
    echo "    if [ \$? -ne 0 ]; then" >> $JOBFILENAME
    echo "        printf \"\n  Error occurred executing \\\"$EXECUTABLE\\\". Aborting...\n\n\"" >> $JOBFILENAME
    echo "        exit -1" >> $JOBFILENAME
    echo "    fi" >> $JOBFILENAME
    echo "    mv \${CONF}$FERM_OBS_CORR_POSTFIX.out StdOutput/" >> $JOBFILENAME
    echo "    mv \${CONF}$FERM_OBS_CORR_POSTFIX.dat Pbp/" >> $JOBFILENAME
    echo "    rm -f general_time_output" >> $JOBFILENAME
    echo "    rm -f prng.save" >> $JOBFILENAME
    echo "    printf \" done!\n\"" >> $JOBFILENAME
    echo "done" >> $JOBFILENAME
    echo "printf \"===================================================================================================================\n\n\"" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "echo \"Date and time: \$(date)\"" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "echo \"---------------------------\"" >> $JOBFILENAME
    echo "# backup core results" >> $JOBFILENAME
    echo "cp -ar Pbp/ \$SLURM_SUBMIT_DIR/ || exit 2" >> $JOBFILENAME
    echo "echo \"---------------------------\"" >> $JOBFILENAME
    echo "# go back to the submitting directory" >> $JOBFILENAME
    echo "cd \$SLURM_SUBMIT_DIR" >> $JOBFILENAME

    # Now that the job script is ready we can submit it
    sbatch $JOBFILENAME

else # Assume user want to do it from where he is without job
    printf "\n\e[0;31m Interactive pbp-calculation TEMPORARILY not available! Modify the script \"$0\" to switch it on! Aborting...\n\n\e[0m"
    exit -1
    # Build string that will be used later
    PROGRAM_OPTIONS="--use_cpu=$USE_CPU --use_gpu=$USE_GPU --start=continue --ntime=$NTIME --nspace=$NSPACE --measure_pbp=$MEASURE_PBP --measure_correlators=$MEASURE_CORRELATORS --solver=$SOLVER --cgmax=$SOLVER_ITER --sourcetype=$SOURCETYPE --sourcecontent=$SOURCECONTENT --ferm_obs_corr_postfix=$FERM_OBS_CORR_POSTFIX --num_sources=$NUM_SOURCES"
    # Loop over all the configurations in the folder invoking the inverter executable.
    printf "\n\e[0;34m===================================================================================================================\e[0;36m\n"
    mkdir StdOutput/ || exit 2
    mkdir Pbp/ || exit 2
    NUMBER_OF_CONFIGURATIONS=$(ls conf* | wc -l)
    CONFIGURATIONS_DONE=0
    for CONF in conf* ; do
	CONFIGURATIONS_DONE=$(( $CONFIGURATIONS_DONE+1 ))
	printf "  -  Calculating chiral condensate ($CONFIGURATIONS_DONE of $NUMBER_OF_CONFIGURATIONS)"
	printf " on $CONF using $NUM_SOURCES $SOURCETYPE-sources on a lattice $NTIMEx$NSPACE^3..."
	$EXECUTABLE --sourcefile=$CONF $PROGRAM_OPTIONS >> $CONF$FERM_OBS_CORR_POSTFIX.out
	if [ $? -ne 0 ]; then
            printf "\n\e[0;31m  Error occurred executing $EXECUTABLE. Aborting...\n\n\e[0m"
            exit -1
	fi
	mv $CONF$FERM_OBS_CORR_POSTFIX.out StdOutput/
	mv $CONF$FERM_OBS_CORR_POSTFIX.dat Pbp/
	rm -f general_time_output
	rm -f prng.save
	printf "\e[0;36m done!\n"
    done
    printf "\e[0;34m===================================================================================================================\e[0m\n\n"
fi

exit 0
