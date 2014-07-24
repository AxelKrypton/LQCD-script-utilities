function ParseCommandLineOption(){
    while [ "$1" != "" ]; do
	case $1 in
	    -h | --help )
		printf "\n\e[0;32m"
		echo "Call the script $0 with the following optional arguments:"
		echo ""
		echo "  -h | --help"
		echo "  --jobscript_prefix                 ->    default value = job.cl2qcd.IntTest"
		echo "  --chempot_prefix                   ->    default value = mu"
		echo "  --kappa_prefix                     ->    default value = k"
		echo "  --ntime_prefix                     ->    default value = nt"
		echo "  --nspace_prefix                    ->    default value = ns"
		echo "  --beta_prefix                      ->    default value = b"
		echo "  --walltime                         ->    default value = 01:00:00 (1h)"
		echo "  --measurements                     ->    default value = 100"
		echo "  --nsave                            ->    default value = 300"
		echo "  --intsteps0                        ->    default value = 7"
		echo "  --intsteps1                        ->    default value = 5"
		echo "  --partition                        ->    default value = test"
		printf "\n\e[0m"
		exit
		shift;;
	    --jobscript_prefix=* )       JOBSCRIPT_PREFIX=${1#*=}; shift ;;
            --chempot_prefix=* )    	 CHEMPOT_PREFIX=${1#*=}; shift ;;
	    --kappa_prefix=* )           KAPPA_PREFIX=${1#*=}; shift ;;
	    --ntime_prefix=* )           NTIME_PREFIX=${1#*=}; shift ;;
	    --nspace_prefix=* )          NSPACE_PREFIX=${1#*=}; shift ;;
	    --beta_prefix=* )          	 BETA_PREFIX=${1#*=}; shift ;;
	    --walltime=* )               WALLTIME=${1#*=}; shift ;;
	    --measurements=* )		 MEASUREMENTS=${1#*=}; shift ;;
	    --nsave=* )		 	 NSAVE=${1#*=}; shift ;;
	    --intsteps0=* )		 INTSTEPS0=${1#*=}; shift ;;
	    --intsteps1=* )		 INTSTEPS1=${1#*=}; NUMTIMESCALES=2; shift ;;
	    --partition=* )		 LOEWE_PARTITION=${1#*=}; shift ;;
	    * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
	esac
    done
}


function ProduceJobScriptFile(){

    #-----------------------------------------------------------------------------------#
    local JOBSCRIPT_NAME="${JOBSCRIPT_PREFIX}_${PARAMETERS_STRING}_$BETA_PREFIX$BETA"
    local JOBSCRIPT_GLOBALPATH="${WORK_BETADIRECTORY}/$RUN_DIR/$JOBSCRIPT_NAME"
    #-----------------------------------------------------------------------------------#

    echo "#!/bin/sh" > $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --tasks=1" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --cpus-per-task=1" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --job-name=${JOBSCRIPT_NAME#${JOBSCRIPT_PREFIX}_*}_${RUN_DIR}" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --mail-type=FAIL" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --mail-user=$USER_MAIL" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --output=${HMC_FILENAME}.%j.out" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --error=${HMC_FILENAME}.%j.err" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --time=$WALLTIME" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --gres=gpu:1" >> $JOBSCRIPT_GLOBALPATH
    if [[ "$LOEWE_PARTITION" = "gpu" ]]; then
	echo "#SBATCH -w gpu021" >> $JOBSCRIPT_GLOBALPATH
    fi
    echo "#SBATCH --partition=$LOEWE_PARTITION" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "WORKDIR=$(pwd)" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"Host: \$(hostname)\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"GPU:  \$GPU_DEVICE_ORDINAL\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"Date and time: \$(date)\"" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "# prepare" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \$SLURM_JOB_NODELIST > hmc.\$SLURM_JOB_ID.nodelist" >> $JOBSCRIPT_GLOBALPATH
    echo "mkdir -p \$WORKDIR || exit 2" >> $JOBSCRIPT_GLOBALPATH
    echo "cd \$WORKDIR || exit 2" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"---------------------------\"" >> $JOBSCRIPT_GLOBALPATH
    echo "export DISPLAY=:0" >> $JOBSCRIPT_GLOBALPATH
    echo "export GPU_MAX_HEAP_SIZE=75" >> $JOBSCRIPT_GLOBALPATH
    echo "# report where we are" >> $JOBSCRIPT_GLOBALPATH
    echo "srun hostname" >> $JOBSCRIPT_GLOBALPATH
    echo "# check gpu" >> $JOBSCRIPT_GLOBALPATH
    echo "srun aticonfig --odgc --odgt --adapter=all" >> $JOBSCRIPT_GLOBALPATH
    echo "# blablabla" >> $JOBSCRIPT_GLOBALPATH
    echo "srun aticonfig --od-enable" >> $JOBSCRIPT_GLOBALPATH
    echo "# modify gpu clock to factory defaults" >> $JOBSCRIPT_GLOBALPATH
    echo "srun aticonfig --odsc 850,1200" >> $JOBSCRIPT_GLOBALPATH
    echo "# check gpu again" >> $JOBSCRIPT_GLOBALPATH
    echo "srun aticonfig --odgc --odgt --adapter=all" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"---------------------------\"" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "# run hmc" >> $JOBSCRIPT_GLOBALPATH
    if [ $NUMTIMESCALES -eq 1 ]; then
	echo "srun --gres=gpu:1 $HMC_GLOBALPATH --input-file=\$SLURM_SUBMIT_DIR/$INPUTFILE_NAME --kappa=0.$KAPPA --ns=$NSPACE --nt=$NTIME --integrationsteps0=$INTSTEPS0 || exit 1" >> $JOBSCRIPT_GLOBALPATH
    elif [ $NUMTIMESCALES -eq 2 ]; then
	echo "srun --gres=gpu:1 $HMC_GLOBALPATH --input-file=\$SLURM_SUBMIT_DIR/$INPUTFILE_NAME --kappa=0.$KAPPA --ns=$NSPACE --nt=$NTIME --integrationsteps0=$INTSTEPS0 --integrationsteps1=$INTSTEPS1 || exit 1" >> $JOBSCRIPT_GLOBALPATH
    fi
    echo "err=\`echo \$?\`" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"---------------------------\"" >> $JOBSCRIPT_GLOBALPATH
    echo "# Reset clocks to default" >> $JOBSCRIPT_GLOBALPATH
    echo "srun aticonfig --odsc 750,1100" >> $JOBSCRIPT_GLOBALPATH
    echo "# done messing with clocks" >> $JOBSCRIPT_GLOBALPATH
    echo "srun aticonfig --od-disable" >> $JOBSCRIPT_GLOBALPATH
    echo "# check gpu again" >> $JOBSCRIPT_GLOBALPATH
    echo "srun aticonfig --odgc --odgt --adapter=all" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"---------------------------\"" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH

}


function ProduceInputFile() {

    #-----------------------------------------------------------------------------------#
    local INPUTFILE_GLOBALPATH="${WORK_BETADIRECTORY}/$RUN_DIR/$INPUTFILE_NAME"
    #-----------------------------------------------------------------------------------#

    echo "use_cpu=false" > $INPUTFILE_GLOBALPATH
    echo "device=0" >> $INPUTFILE_GLOBALPATH
    echo "theta_fermion_spatial=0" >> $INPUTFILE_GLOBALPATH
    echo "theta_fermion_temporal=1" >> $INPUTFILE_GLOBALPATH
    echo "use_chem_pot_im=1" >> $INPUTFILE_GLOBALPATH
    echo "chem_pot_im=0.523598775598299" >> $INPUTFILE_GLOBALPATH
    echo "use_eo=1" >> $INPUTFILE_GLOBALPATH
    echo "solver=cg" >> $INPUTFILE_GLOBALPATH
    echo "cgmax=5000" >> $INPUTFILE_GLOBALPATH
    echo "measure_pbp=0" >> $INPUTFILE_GLOBALPATH
    echo "tau=1" >> $INPUTFILE_GLOBALPATH
    echo "savefrequency=$NSAVE" >> $INPUTFILE_GLOBALPATH
    echo "startcondition=continue" >> $INPUTFILE_GLOBALPATH
    echo "sourcefile=conf.start" >> $INPUTFILE_GLOBALPATH
    echo "beta=$BETA" >> $INPUTFILE_GLOBALPATH
    echo "hmcsteps=$MEASUREMENTS" >> $INPUTFILE_GLOBALPATH
    if [ $NUMTIMESCALES -eq 1 ]; then
	echo "num_timescales=1" >> $INPUTFILE_GLOBALPATH
	echo "integrator0=twomn" >> $INPUTFILE_GLOBALPATH
    elif [ $NUMTIMESCALES -eq 2 ]; then
	echo "num_timescales=2" >> $INPUTFILE_GLOBALPATH
	echo "integrator0=twomn" >> $INPUTFILE_GLOBALPATH
	echo "integrator1=twomn" >> $INPUTFILE_GLOBALPATH
    fi

}