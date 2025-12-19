function ParseCommandLineOption(){
#
#  Copyright (c) 2014 Alessandro Sciarra
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
		echo "  --intsteps0                        ->    default value = 4:7:1"
		echo "  --intsteps1                        ->    default value = not used, specify it to use 2 timescale!"
		echo "  --partition                        ->    default value = parallel"
		echo "  --constraint                       ->    default value = gpu"
		echo "  --node                             ->    default value = automatically assigned"
		echo "  --evonly                           ->    if given, just evaluate how many tuning would be done with the provided parameters!"
		printf "\n\e[0m"
		exit
		shift;;
	    -H | --helpInt )
		printf "\n\e[0;32m"
		echo "# Since on LOEWE now one should group $GPU_PER_NODE srun in order not to waste"
		echo "# computing time, in this script the user will have to specify"
		echo "# the number of integration steps for each scale in the following"
		echo "# way: "
		echo "#                      Smin:Smax:delta"
		echo "#"
		echo "# where Smin is the minimum number of steps that will be used on"
		echo "# that scale, Smax is the maximum, and delta is the resolution"
		echo "# with which to scan. All the possibility will be then done. For example:"
		echo "#  --intsteps0=4:6:1"
		echo "#  --intsteps1=24:30:2"
		echo "# will make the following 12 simulations start:"
		echo "#  (4,24) - (4,26) - (4,28) - (4,30)  "
		echo "#  (5,24) - (5,26) - (5,28) - (5,30)  "
		echo "#  (6,24) - (6,26) - (6,28) - (6,30)  "
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
	    --constraint=* )		 LOEWE_CONSTRAINT=${1#*=}; shift ;;
	    --node=* )		         LOEWE_NODE=${1#*=}; shift ;;
	    --evonly )		         EVALUATEONLY=1; shift ;;
	    * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
	esac
    done
}

function ParseIntegratorSteps(){

    if [ $NUMTIMESCALES -ne 1 ] && [ $NUMTIMESCALES -ne 2 ]; then
	printf "\n\e[0;31m NUMTIMESCALES=$NUMTIMESCALES not valid! Aborting...\n\n\e[0m"
	exit -1
    fi

    if [[ ! $INTSTEPS0 =~ ^([0-9]+[:]){2}[0-9]+$ ]]; then
	printf "\n\e[0;31m Integrator0 steps have been specified in the wrong way, see --help for more info! Aborting...\n\n\e[0m"
	exit -1
    fi

    local INTSTEPS0MIN=$(echo "$INTSTEPS0" | awk 'BEGIN{ FS=":" }{print $1}')
    local INTSTEPS0MAX=$(echo "$INTSTEPS0" | awk 'BEGIN{ FS=":" }{print $2}')
    local INTSTEPS0RES=$(echo "$INTSTEPS0" | awk 'BEGIN{ FS=":" }{print $3}')

    if [ $INTSTEPS0MIN -eq $INTSTEPS0MAX ]; then INTSTEPS0RES=1; fi

    if [ $INTSTEPS0RES -eq 0 ]; then
        printf "\n\e[0;31m Integrator0 steps resolution equal to 0 cannot be used to scan the given region!! Aborting...\n\n\e[0m"
        exit -1
    fi

    if [ $INTSTEPS0MIN -gt $INTSTEPS0MAX ]; then
	INTSTEPS0MIN=`expr $INTSTEPS0MIN + $INTSTEPS0MAX`
	INTSTEPS0MAX=`expr $INTSTEPS0MIN - $INTSTEPS0MAX`
	INTSTEPS0MIN=`expr $INTSTEPS0MIN - $INTSTEPS0MAX`
    fi

    if [ $NUMTIMESCALES -eq 1 ]; then

	local INTSTEPS1MIN=0
        local INTSTEPS1MAX=0
        local INTSTEPS1RES=1

    elif [ $NUMTIMESCALES -eq 2 ]; then
	if [[ ! $INTSTEPS1 =~ ^([0-9]+[:]){2}[0-9]+$ ]]; then
	    printf "\n\e[0;31m Integrator1 steps have been specified in the wrong way, see --help for more info! Aborting...\n\n\e[0m"
	    exit -1
	fi

	local INTSTEPS1MIN=$(echo "$INTSTEPS1" | awk 'BEGIN{ FS=":" }{print $1}')
	local INTSTEPS1MAX=$(echo "$INTSTEPS1" | awk 'BEGIN{ FS=":" }{print $2}')
	local INTSTEPS1RES=$(echo "$INTSTEPS1" | awk 'BEGIN{ FS=":" }{print $3}')

	if [ $INTSTEPS0MIN -eq $INTSTEPS0MAX ]; then INTSTEPS0RES=1; fi

	if [ $INTSTEPS0RES -eq 0 ]; then
            printf "\n\e[0;31m Integrator1 steps resolution equal to 0 cannot be used to scan the given region!! Aborting...\n\n\e[0m"
            exit -1
	fi

	if [ $INTSTEPS1MIN -gt $INTSTEPS1MAX ]; then
	    INTSTEPS1MIN=`expr $INTSTEPS1MIN + $INTSTEPS1MAX`
	    INTSTEPS1MAX=`expr $INTSTEPS1MIN - $INTSTEPS1MAX`
	    INTSTEPS1MIN=`expr $INTSTEPS1MIN - $INTSTEPS1MAX`
	fi
    fi

    INTSTEPS0=("$INTSTEPS0MIN" "$INTSTEPS0MAX" "$INTSTEPS0RES")
    INTSTEPS1=("$INTSTEPS1MIN" "$INTSTEPS1MAX" "$INTSTEPS1RES")
}


function ProduceJobScriptFile(){

    #-----------------------------------------------------------------#
    if [ $# -lt 1 ] || [ $# -gt $((2*$GPU_PER_NODE)) ] || [ $(echo $# | awk '{print $1 % 2}') -ne 0 ]; then
	printf "\n\e[0;31m  Wrong number of parameters given to \"ProduceJobScriptFile\" function. Aborting...\n\n\e[0m"
	exit -1
    fi
    local INT0_TO_BE_USED=()
    local INT1_TO_BE_USED=()
    while [ "$1" != "" ]; do
	INT0_TO_BE_USED+=( "$1" )
	INT1_TO_BE_USED+=( "$2" )
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
    for INDEX in "${!INT0_TO_BE_USED[@]}"; do
	echo "dir$INDEX=${WORK_BETADIRECTORY}/${INT0_TO_BE_USED[$INDEX]}_${INT1_TO_BE_USED[$INDEX]}" >> $JOBSCRIPT_GLOBALPATH
    done
    echo "" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!INT0_TO_BE_USED[@]}"; do
	echo "workdir$INDEX=${WORK_BETADIRECTORY}/${INT0_TO_BE_USED[$INDEX]}_${INT1_TO_BE_USED[$INDEX]}" >> $JOBSCRIPT_GLOBALPATH
    done
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "outFile=hmc.\$SLURM_JOB_ID.out" >> $JOBSCRIPT_GLOBALPATH
    echo "errFile=hmc.\$SLURM_JOB_ID.err" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "# Check if directories exist" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!INT0_TO_BE_USED[@]}"; do
        echo "if [ ! -d \$dir$INDEX ]; then" >> $JOBSCRIPT_GLOBALPATH
        echo "echo \"Could not find directory \\\"\$dir$INDEX\\\" for runs. Aborting...\""  >> $JOBSCRIPT_GLOBALPATH
        echo "exit -1"  >> $JOBSCRIPT_GLOBALPATH
	echo "fi"  >> $JOBSCRIPT_GLOBALPATH
	echo "" >> $JOBSCRIPT_GLOBALPATH
    done

    echo "# Print some information" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!INT0_TO_BE_USED[@]}"; do
	echo "echo \"${INT0_TO_BE_USED[$INDEX]} ${INT1_TO_BE_USED[$INDEX]}\"" >> $JOBSCRIPT_GLOBALPATH
    done
    echo "echo \"\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"Host: \$(hostname)\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"GPU:  \$GPU_DEVICE_ORDINAL\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"Date and time: \$(date)\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \$SLURM_JOB_NODELIST > hmc.${INTSTEPS_STRING:1}.\$SLURM_JOB_ID.nodelist" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "# TODO: this is necessary because the log file is produced in the directoy" >> $JOBSCRIPT_GLOBALPATH
    echo "#       of the exec. Copying it later does not guarantee that it is still the same..." >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"Copy executable to beta directories in ${WORK_BETADIRECTORY}/xx_yy...\"" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!INT0_TO_BE_USED[@]}"; do
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
    for INDEX in "${!INT0_TO_BE_USED[@]}"; do
	echo "cd \$workdir$INDEX" >> $JOBSCRIPT_GLOBALPATH
	echo "pwd &" >> $JOBSCRIPT_GLOBALPATH
	if [ $NUMTIMESCALES -eq 1 ]; then
	    echo "time srun -n 1 \$dir$INDEX/$HMC_FILENAME --input-file=\$dir$INDEX/$INPUTFILE_NAME --device=$INDEX --kappa=0.$KAPPA --ns=$NSPACE --nt=$NTIME --integrationsteps0=${INT0_TO_BE_USED[$INDEX]} > \$outFile 2>\$errFile &" >> $JOBSCRIPT_GLOBALPATH
	elif [ $NUMTIMESCALES -eq 2 ]; then
	    echo "time srun -n 1 \$dir$INDEX/$HMC_FILENAME --input-file=\$dir$INDEX/$INPUTFILE_NAME --device=$INDEX --kappa=0.$KAPPA --ns=$NSPACE --nt=$NTIME --integrationsteps0=${INT0_TO_BE_USED[$INDEX]} --integrationsteps1=${INT1_TO_BE_USED[$INDEX]} > \$outFile 2>\$errFile &" >> $JOBSCRIPT_GLOBALPATH
	fi
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
