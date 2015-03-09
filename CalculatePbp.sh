#!/bin/bash

# This script is intended to calculate the Chiral Condensate on a set of configurations
# placed in the folder from which it is invoked.
# Basically the "inverter" executable of CL2QCD is called per each configuration. 
# Such an executable, by default should be in the folder given in the --help,
# otherwise it has to be specified.
# Since several options that could be given to such an executable are here fixed,
# we parse only those that are realistically sometimes changed. In any case all have
# some default value (see below).
#
# NOTE: To write this script quickly, everything starting with "conf" is considered
#       as configuration, i.e. as lime file. This means that if there is something that
#       is not such a file, it will produce some error.
#       This should not be the case but however is up to the user to manage it.
#

# Source the common global script supposed to be in $(HOME)/Script
source $HOME/Script/PathManagement.sh || exit -2

# set an initial value for the options
EXECUTABLE="${HOME}/clhmc/build/RefExec/inverter_ref"
MEASURE_PBP="true"
MEASURE_CORRELATORS="false"
SOLVER="cg"
SOLVER_ITER=5000
SOURCETYPE="volume"
SOURCECONTENT="gaussian"
FERM_OBS_CORR_POSTFIX="_pbp"
NUM_SOURCES=16
USE_CPU="false"
USE_GPU="true"
HOST="loewe"
JOBWALLTIME="24:00:00"

# extract options and their arguments into variables.
while [ "$1" != "" ]; do
    case $1 in
      -h | --help )
	  printf "\n\e[0;32m"
	  echo "Call the script $0 with the following optional arguments:"
	  echo "  -h | --help"
	  echo "  --executable            ->    default value = $EXECUTABLE"
	  echo "  --measure_correlators   ->    default value = $MEASURE_CORRELATORS"
	  echo "  --solver                ->    default value = $SOLVER"
          echo "  --cgmax                 ->    default value = $SOLVER_ITER"
	  echo "  --sourcetype            ->    default value = $SOURCETYPE"
	  echo "  --sourcecontent         ->    default value = $SOURCECONTENT"
	  echo "  --ferm_obs_corr_postfix ->    defualt value = $FERM_OBS_CORR_POSTFIX"
          echo "  --num_sources           ->    default value = $NUM_SOURCES"
          echo "  --use_cpu               ->    default value = $USE_CPU"
          echo "  --use_gpu               ->    default value = $USE_GPU"
          echo "  --host                  ->    default value = $HOST"
          echo "  --walltime              ->    default value = $JOBWALLTIME"
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
    PROGRAM_OPTIONS="--use_cpu=$USE_CPU --use_gpu=$USE_GPU --use_eo=1 --start=continue --ntime=$NTIME --nspace=$NSPACE --kappa=0.$KAPPA --measure_pbp=$MEASURE_PBP --measure_correlators=$MEASURE_CORRELATORS --solver=$SOLVER --cgmax=$SOLVER_ITER --sourcetype=$SOURCETYPE --sourcecontent=$SOURCECONTENT --ferm_obs_corr_postfix=$FERM_OBS_CORR_POSTFIX --num_sources=$NUM_SOURCES --beta=$BETA --theta_fermion_temporal=1 --theta_fermion_spatial=0 --use_chem_pot_im=1 --chem_pot_im=0.523598775598299"

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
    echo "#SBATCH --partition=parallel" >> $JOBFILENAME
    echo "#SBATCH --constraint=gpu" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "WORKDIR=/scratch/hfftheo/sciarra/WilsonProject$PARAMETERS_PATH/b${BETA}/CalculatePbp" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "cd \$WORKDIR || exit 2" >> $JOBFILENAME
    echo "cp $EXECUTABLE inverter || exit 2" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "echo \"Date and time: \$(date)\"" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "printf \"\n=============================================================================================================\n\"" >> $JOBFILENAME
    echo "mkdir StdOutput/ || exit 2" >> $JOBFILENAME
    echo "mkdir Pbp/ || exit 2" >> $JOBFILENAME
    echo "GPU_PER_NODE=4" >> $JOBFILENAME
    echo "SRUN_NUMBER=0" >> $JOBFILENAME
    echo "PID_SRUN=()" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "if [ ! -f sourcefiles ]; then" >> $JOBFILENAME
    echo "    echo \" File sourcefile not existing in \$WORKDIR folder! Aborting...\"" >> $JOBFILENAME
    echo "    exit -1" >> $JOBFILENAME
    echo "fi" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "echo \"\nStarting calculation from \$(pwd)\n\n\"" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "for CONF in \$(cat sourcefiles) ; do" >> $JOBFILENAME
    echo "    cp ../\$CONF . || exit -2" >> $JOBFILENAME
    echo "    [ \$SRUN_NUMBER -eq 0 ] && printf \"  -  Calculating chiral condensate on configurations \"" >> $JOBFILENAME
    echo "    if [ \$SRUN_NUMBER -lt \$GPU_PER_NODE ]; then" >> $JOBFILENAME
    echo "        srun -n 1 inverter --device=\$SRUN_NUMBER --sourcefile=\$CONF $PROGRAM_OPTIONS > \${CONF}.out 2> \${CONF}.err & PID_SRUN+=( \"\$!\" )" >> $JOBFILENAME
    echo "        printf \"\${CONF} \"" >> $JOBFILENAME
    echo "        SRUN_NUMBER=\$(( \$SRUN_NUMBER+1 ))" >> $JOBFILENAME
    echo "        continue" >> $JOBFILENAME
    echo "    else" >> $JOBFILENAME
    echo "        #Execute wait \$PID job after job" >> $JOBFILENAME
    echo "        for PID in \"\${PID_SRUN[@]}\"; do" >> $JOBFILENAME
    echo "            wait \$PID || printf \"       Error occurred calculating pbp on \"\$CONF\". Please check...\n\"" >> $JOBFILENAME
    echo "        done" >> $JOBFILENAME
    echo "        printf \"...done!\n\"" >> $JOBFILENAME
    echo "        SRUN_NUMBER=0" >> $JOBFILENAME
    echo "        PID_SRUN=()" >> $JOBFILENAME
    echo "        mv conf*.out StdOutput/" >> $JOBFILENAME
    echo "        mv conf*.err StdOutput/" >> $JOBFILENAME
    echo "        mv *$FERM_OBS_CORR_POSTFIX.dat Pbp/" >> $JOBFILENAME
    echo "    fi" >> $JOBFILENAME
    echo "    rm -f general_time_output" >> $JOBFILENAME
    echo "    rm -f prng.save" >> $JOBFILENAME
    echo "    rm \$(ls conf.* | grep -v pbp) || exit -2" >> $JOBFILENAME
    echo "done" >> $JOBFILENAME
    echo "printf \"===================================================================================================================\n\n\"" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "echo \"Date and time: \$(date)\"" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "" >> $JOBFILENAME
    echo "echo \"---------------------------\"" >> $JOBFILENAME
    #echo "# backup core results" >> $JOBFILENAME
    #echo "cp -ar Pbp/ \$SLURM_SUBMIT_DIR/ || exit 2" >> $JOBFILENAME
    #echo "echo \"---------------------------\"" >> $JOBFILENAME
    echo "# go back to the submitting directory" >> $JOBFILENAME
    echo "cd \$SLURM_SUBMIT_DIR" >> $JOBFILENAME

    # Now that the job script is ready we can submit it
    sbatch $JOBFILENAME

else # Assume user want to do it from where he is without job

    echo "Script has to be adjusted (e.g. so far it doesn't read parameters from path as for the job)! Not usable yet! Exiting..."
    exit

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
