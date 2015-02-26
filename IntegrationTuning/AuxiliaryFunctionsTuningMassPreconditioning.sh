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
		echo "  --walltime                         ->    default value = 06:00:00 (6h)"
		echo "  --measurements                     ->    default value = 100"
		echo "  --nsave                            ->    default value = 300"
		echo "  --intsteps0                        ->    default value = 2"
		echo "  --intsteps1                        ->    default value = 2"
		echo "  --intsteps2                        ->    default value = 6:7:1"
		echo "  --kmp                              ->    default value = 1525:1600:25"
		echo "  --partition                        ->    default value = parallel"
		echo "  --constraint                       ->    default value = gpu"
		echo "  --node                             ->    default value = automatically assigned"
		echo "  --evonly                           ->    if given, just evaluate how many tuning would be done with the provided parameters!"
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
	    --intsteps1=* )		 INTSTEPS1=${1#*=}; shift ;;
	    --intsteps2=* )		 INTSTEPS2=${1#*=}; shift ;;
	    --kmp=* ) 		         KAPPA_MP=${1#*=}; shift ;;
	    --partition=* )		 LOEWE_PARTITION=${1#*=}; shift ;;
	    --constraint=* )		 LOEWE_CONSTRAINT=${1#*=}; shift ;;
	    --node=* )		         LOEWE_NODE=${1#*=}; shift ;;
	    --evonly )		         EVALUATEONLY=1; shift ;;
	    * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
	esac
    done
}

function ParseIntegratorSteps(){

    if [[ ! $INTSTEPS0 =~ ^[0-9]+$ ]]; then
	printf "\n\e[0;31m Integrator0 steps not valid, see --help for more info! Aborting...\n\n\e[0m"
	exit -1
    fi

    if [[ ! $INTSTEPS1 =~ ^[0-9]+$ ]]; then
	printf "\n\e[0;31m Integrator1 steps not valid, see --help for more info! Aborting...\n\n\e[0m"
	exit -1
    fi

    if [[ ! $INTSTEPS2 =~ ^([0-9]+[:]){2}[0-9]+$ ]]; then
	printf "\n\e[0;31m Integrator2 steps have been specified in the wrong way, see --help for more info! Aborting...\n\n\e[0m"
	exit -1
    fi
        
    local INTSTEPS2_MIN=$(echo "$INTSTEPS2" | awk 'BEGIN{ FS=":" }{print $1}')
    local INTSTEPS2_MAX=$(echo "$INTSTEPS2" | awk 'BEGIN{ FS=":" }{print $2}')
    local INTSTEPS2_RES=$(echo "$INTSTEPS2" | awk 'BEGIN{ FS=":" }{print $3}')

    if [ $INTSTEPS2_MIN -eq $INTSTEPS2_MAX ]; then INTSTEPS2_RES=1; fi

    if [ $INTSTEPS2_RES -eq 0 ]; then
        printf "\n\e[0;31m Integrator2 steps resolution equal to 0 cannot be used to scan the given region!! Aborting...\n\n\e[0m"
        exit -1
    fi
    
    if [ $INTSTEPS2_MIN -gt $INTSTEPS2_MAX ]; then
	INTSTEPS2_MIN=`expr $INTSTEPS2_MIN + $INTSTEPS2_MAX`
	INTSTEPS2_MAX=`expr $INTSTEPS2_MIN - $INTSTEPS2_MAX`
	INTSTEPS2_MIN=`expr $INTSTEPS2_MIN - $INTSTEPS2_MAX`
    fi

    if [[ ! $KAPPA_MP =~ ^([0-9]+[:]){2}[0-9]+$ ]]; then
	printf "\n\e[0;31m Kappa_mp range and resolution have been specified in the wrong way, see --help for more info! Aborting...\n\n\e[0m"
	exit -1
    fi

    local KAPPA_MP_MIN=$(echo "$KAPPA_MP" | awk 'BEGIN{ FS=":" }{print $1}')
    local KAPPA_MP_MAX=$(echo "$KAPPA_MP" | awk 'BEGIN{ FS=":" }{print $2}')
    local KAPPA_MP_RES=$(echo "$KAPPA_MP" | awk 'BEGIN{ FS=":" }{print $3}')
    
    if [ $KAPPA_MP_MIN -eq $KAPPA_MP_MAX ]; then KAPPA_MP_RES=1; fi
    
    if [ $KAPPA_MP_RES -eq 0 ]; then
        printf "\n\e[0;31m Kappa_mp resolution equal to 0 cannot be used to scan the given region!! Aborting...\n\n\e[0m"
        exit -1
    fi
    
    if [ $KAPPA_MP_MIN -gt $KAPPA_MP_MAX ]; then
	KAPPA_MP_MIN=`expr $KAPPA_MP_MIN + $KAPPA_MP_MAX`
	KAPPA_MP_MAX=`expr $KAPPA_MP_MIN - $KAPPA_MP_MAX`
	KAPPA_MP_MIN=`expr $KAPPA_MP_MIN - $KAPPA_MP_MAX`
    fi
    
    INTSTEPS2=("$INTSTEPS2_MIN" "$INTSTEPS2_MAX" "$INTSTEPS2_RES")
    KAPPA_MP=("$KAPPA_MP_MIN" "$KAPPA_MP_MAX" "$KAPPA_MP_RES")
}


function ProduceJobScriptFile(){

    #-----------------------------------------------------------------#
    if [ $# -lt 1 ] || [ $# -gt $((2*$GPU_PER_NODE)) ] || [ $(echo $# | awk '{print $1 % 2}') -ne 0 ]; then
	printf "\n\e[0;31m  Wrong number of parameters given to \"ProduceJobScriptFile\" function. Aborting...\n\n\e[0m"
	exit -1	
    fi
    local INT2_TO_BE_USED=()
    local KMP_TO_BE_USED=()
    while [ "$1" != "" ]; do
	INT2_TO_BE_USED+=( "$1" )
	KMP_TO_BE_USED+=( "$2" )
	shift 2
    done
    #-----------------------------------------------------------------#

    echo "#!/bin/sh" > $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --job-name=${JOBSCRIPT_NAME#${JOBSCRIPT_PREFIX}_*}_Tuning" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --mail-type=FAIL" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --mail-user=$USER_MAIL" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --time=$WALLTIME" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --output=${HMC_FILENAME}.%j.out" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --error=${HMC_FILENAME}.%j.err" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --partition=$LOEWE_PARTITION" >> $JOBSCRIPT_GLOBALPATH
    if [[ "$LOEWE_PARTITION" == "parallel" ]]; then
	echo "#SBATCH --constraint=$LOEWE_CONSTRAINT" >> $JOBSCRIPT_GLOBALPATH
    fi
    echo "#SBATCH --tasks=$GPU_PER_NODE" >> $JOBSCRIPT_GLOBALPATH
    if [[ "$LOEWE_NODE" != "unset" ]]; then
	echo "#SBATCH -w $LOEWE_NODE" >> $JOBSCRIPT_GLOBALPATH
    fi
    echo "" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!INT2_TO_BE_USED[@]}"; do
	echo "dir$INDEX=${WORK_BETADIRECTORY}/${INTSTEPS0}_${INTSTEPS1}_${INT2_TO_BE_USED[$INDEX]}_kmp${KMP_TO_BE_USED[$INDEX]}" >> $JOBSCRIPT_GLOBALPATH
    done
    echo "" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!INT2_TO_BE_USED[@]}"; do
	echo "workdir$INDEX=${WORK_BETADIRECTORY}/${INTSTEPS0}_${INTSTEPS1}_${INT2_TO_BE_USED[$INDEX]}_kmp${KMP_TO_BE_USED[$INDEX]}" >> $JOBSCRIPT_GLOBALPATH
    done
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "outFile=hmc.\$SLURM_JOB_ID.out" >> $JOBSCRIPT_GLOBALPATH
    echo "errFile=hmc.\$SLURM_JOB_ID.err" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "# Check if directories exist" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!INT2_TO_BE_USED[@]}"; do
        echo "if [ ! -d \$dir$INDEX ]; then" >> $JOBSCRIPT_GLOBALPATH
        echo "echo \"Could not find directory \\\"\$dir$INDEX\\\" for runs. Aborting...\""  >> $JOBSCRIPT_GLOBALPATH
        echo "exit -1"  >> $JOBSCRIPT_GLOBALPATH
	echo "fi"  >> $JOBSCRIPT_GLOBALPATH
	echo "" >> $JOBSCRIPT_GLOBALPATH
    done

    echo "# Print some information" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!INT2_TO_BE_USED[@]}"; do
	echo "echo \"${INT2_TO_BE_USED[$INDEX]} ${KMP_TO_BE_USED[$INDEX]}\"" >> $JOBSCRIPT_GLOBALPATH
    done
    echo "echo \"\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"Host: \$(hostname)\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"GPU:  \$GPU_DEVICE_ORDINAL\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"Date and time: \$(date)\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \$SLURM_JOB_NODELIST > hmc.${STEPS_STRING:1}.\$SLURM_JOB_ID.nodelist" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "# TODO: this is necessary because the log file is produced in the directoy" >> $JOBSCRIPT_GLOBALPATH
    echo "#       of the exec. Copying it later does not guarantee that it is still the same..." >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"Copy executable to beta directories in ${WORK_BETADIRECTORY}/xx_yy...\"" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!INT2_TO_BE_USED[@]}"; do
	echo "cp -a $HMC_GLOBALPATH \$dir$INDEX" >> $JOBSCRIPT_GLOBALPATH
    done
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"---------------------------\"" >> $JOBSCRIPT_GLOBALPATH
    echo "export DISPLAY=:0" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"\\\"export DISPLAY=:0\\\" done!\"" >> $JOBSCRIPT_GLOBALPATH
    #echo "export GPU_MAX_HEAP_SIZE=75" >> $JOBSCRIPT_GLOBALPATH             #Max amount of total memory of GPU allowed to be used, we do not set it for the moment
    echo "echo \"---------------------------\"" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "# Run jobs from different directories" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!INT2_TO_BE_USED[@]}"; do
	echo "cd \$workdir$INDEX" >> $JOBSCRIPT_GLOBALPATH
	echo "pwd &" >> $JOBSCRIPT_GLOBALPATH
	echo "time srun -n 1 \$dir$INDEX/$HMC_FILENAME --input-file=\$dir$INDEX/$INPUTFILE_NAME --device=$INDEX --integrationsteps2=${INT2_TO_BE_USED[$INDEX]} --kappa_mp=0.${KMP_TO_BE_USED[$INDEX]} > \$outFile 2>\$errFile &" >> $JOBSCRIPT_GLOBALPATH
	echo "" >> $JOBSCRIPT_GLOBALPATH
    done
    echo "wait" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "err=\`echo \$?\`" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"---------------------------\"" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"Date and time: \$(date)\"" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH

}


function ProduceInputFile() {

    echo "use_cpu=false" > $INPUTFILE_GLOBALPATH
    echo "theta_fermion_spatial=0" >> $INPUTFILE_GLOBALPATH
    echo "theta_fermion_temporal=1" >> $INPUTFILE_GLOBALPATH
    echo "use_chem_pot_im=1" >> $INPUTFILE_GLOBALPATH
    echo "chem_pot_im=0.523598775598299" >> $INPUTFILE_GLOBALPATH
    echo "use_eo=1" >> $INPUTFILE_GLOBALPATH
    echo "solver=cg" >> $INPUTFILE_GLOBALPATH
    echo "cgmax=5000" >> $INPUTFILE_GLOBALPATH
    echo "measure_correlators=0" >> $INPUTFILE_GLOBALPATH
    echo "measure_pbp=0" >> $INPUTFILE_GLOBALPATH
    echo "tau=1" >> $INPUTFILE_GLOBALPATH
    echo "savefrequency=$NSAVE" >> $INPUTFILE_GLOBALPATH
    echo "startcondition=continue" >> $INPUTFILE_GLOBALPATH
    echo "sourcefile=conf.start" >> $INPUTFILE_GLOBALPATH
    echo "kappa=0.$KAPPA" >> $INPUTFILE_GLOBALPATH
    echo "nspace=$NSPACE" >> $INPUTFILE_GLOBALPATH
    echo "ntime=$NTIME" >> $INPUTFILE_GLOBALPATH
    echo "beta=$BETA" >> $INPUTFILE_GLOBALPATH
    echo "cg_iteration_block_size=10" >> $INPUTFILE_GLOBALPATH
    echo "iter_refresh=2500" >> $INPUTFILE_GLOBALPATH
    echo "use_merge_kernels_fermion=1" >> $INPUTFILE_GLOBALPATH
    echo "hmcsteps=$MEASUREMENTS" >> $INPUTFILE_GLOBALPATH
    echo "num_timescales=3" >> $INPUTFILE_GLOBALPATH
    echo "integrator0=twomn" >> $INPUTFILE_GLOBALPATH
    echo "integrator1=twomn" >> $INPUTFILE_GLOBALPATH
    echo "integrator2=twomn" >> $INPUTFILE_GLOBALPATH
    echo "use_mp=1" >> $INPUTFILE_GLOBALPATH
    echo "solver_mp=cg" >> $INPUTFILE_GLOBALPATH
    echo "integrationsteps0=$INTSTEPS0" >> $INPUTFILE_GLOBALPATH
    echo "integrationsteps1=$INTSTEPS1" >> $INPUTFILE_GLOBALPATH

}