function ParseCommandLineOption(){
#
#  Copyright (c) 2014 Alessandro Sciarra
#  Copyright (c) 2015 Christopher Czaban
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
		echo "  --jobscript_prefix                 ->    default value = job.cl2qcd.Thermalize"
		echo "  --chempot_prefix                   ->    default value = mu"
		echo "  --kappa_prefix                     ->    default value = k"
		echo "  --ntime_prefix                     ->    default value = nt"
		echo "  --nspace_prefix                    ->    default value = ns"
		echo "  --beta_prefix                      ->    default value = b"
		echo "  --walltime                         ->    default value = 06:00:00 (1h)"
		echo "  --measurements                     ->    default value = 1000"
		echo "  --nsave                            ->    default value = 200"
		echo "  --startcondition                   ->    default value = hot"
		echo "  --intsteps0                        ->    default value = 7"
		echo "  --intsteps1                        ->    default value = 5"
		echo "  --partition                        ->    default value = parallel"
		echo "  --constraint                       ->    default value = gpu"
		echo "  --node                             ->    default value = automatically assigned"
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
	    --partition=* )		 LOEWE_PARTITION=${1#*=}; shift ;;
	    --constraint=* )		 LOEWE_CONSTRAINT=${1#*=}; shift ;;
	    --node=* )		         LOEWE_NODE=${1#*=}; shift ;;
	    --startcondition=* )         STARTCONDITION=${1#*=};
                                         if [[ "$STARTCONDITION" != "hot" && "$STARTCONDITION" != "cold" ]]; then
					     printf "\n\e[0;31mInvalid startcondition (only \"hot\" and \"cold\" accepted)! Aborting...\n\n\e[0m"
					     exit -1
					 fi; shift ;;
	    * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
	esac
    done
}

function ReadBetaValuesFromFile(){

    if [ ! -e $BETASFILE ]; then
        printf "\n\e[0;31m  File \"$BETASFILE\" not found in $(pwd). Aborting...\n\n\e[0m"
        exit -1
    fi
    #Write beta values from BETASFILE into BETAVALUES array
    BETAVALUES=( $(grep -o "^[[:blank:]]*[[:digit:]]\.[[:digit:]]\{4\}" $BETASFILE) )
    if [ ${#BETAVALUES[@]} -gt "0" ]; then
        printf "\n\e[0;36m====================\n\e[0m"
        printf "\e[0;34m Read beta values:\n\e[0m"
        for i in ${BETAVALUES[@]}; do
            echo "  - $i"
        done
        printf "\e[0;36m====================\n\e[0m"
    else
        printf "\n\e[0;31m  No beta values in betas file. Aborting...\n\n\e[0m"
        exit -1
    fi
}


function ProduceJobScriptFile(){

    #-----------------------------------------------------------------#
    if [ $# -lt 1 ] || [ $# -gt $GPU_PER_NODE ]; then
	printf "\n\e[0;31m  Wrong number of parameters given to \"ProduceJobScriptFile\" function. Aborting...\n\n\e[0m"
	exit -1
    fi
    local BETAS_TO_BE_USED=("$@")
    #-----------------------------------------------------------------#

    echo "#!/bin/sh" > $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --job-name=${JOBSCRIPT_NAME#${JOBSCRIPT_PREFIX}_*}_Thermalize" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --mail-type=FAIL" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --mail-user=$USER_MAIL" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --time=$WALLTIME" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --output=${HMC_FILENAME}.%j.out" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --error=${HMC_FILENAME}.%j.err" >> $JOBSCRIPT_GLOBALPATH
    echo "#SBATCH --partition=$LOEWE_PARTITION" >> $JOBSCRIPT_GLOBALPATH  #In case of the cluster being LCSC the variable LOEWE_PARTITION is set to "lcsc"
    if [[ "$LOEWE_PARTITION" == "parallel" ]]; then
		echo "#SBATCH --constraint=$LOEWE_CONSTRAINT" >> $JOBSCRIPT_GLOBALPATH
    fi
	if [ $CLUSTER_NAME = "LCSC" ]
	then
    	echo "#SBATCH --ntasks=$GPU_PER_NODE" >> $JOBSCRIPT_GLOBALPATH
    	echo "#SBATCH --gres=gpu:$GPU_PER_NODE" >> $JOBSCRIPT_GLOBALPATH
    	echo "#SBATCH --mem=64000" >> $JOBSCRIPT_GLOBALPATH
	else
    	echo "#SBATCH --tasks=$GPU_PER_NODE" >> $JOBSCRIPT_GLOBALPATH
	fi
    if [[ "$LOEWE_NODE" != "unset" ]]; then
	echo "#SBATCH -w $LOEWE_NODE" >> $JOBSCRIPT_GLOBALPATH
    fi
    echo "" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!BETAS_TO_BE_USED[@]}"; do
	echo "dir$INDEX=${WORK_DIR_WITH_BETAFOLDERS}/$BETA_PREFIX${BETAS_TO_BE_USED[$INDEX]}/getConf" >> $JOBSCRIPT_GLOBALPATH
    done
    echo "" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!BETAS_TO_BE_USED[@]}"; do
	echo "workdir$INDEX=${WORK_DIR_WITH_BETAFOLDERS}/$BETA_PREFIX${BETAS_TO_BE_USED[$INDEX]}/getConf" >> $JOBSCRIPT_GLOBALPATH
    done
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "outFile=hmc.\$SLURM_JOB_ID.out" >> $JOBSCRIPT_GLOBALPATH
    echo "errFile=hmc.\$SLURM_JOB_ID.err" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "# Check if directories exist" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!BETAS_TO_BE_USED[@]}"; do
        echo "if [ ! -d \$dir$INDEX ]; then" >> $JOBSCRIPT_GLOBALPATH
        echo "echo \"Could not find directory \\\"\$dir$INDEX\\\" for runs. Aborting...\""  >> $JOBSCRIPT_GLOBALPATH
        echo "exit -1"  >> $JOBSCRIPT_GLOBALPATH
	echo "fi"  >> $JOBSCRIPT_GLOBALPATH
	echo "" >> $JOBSCRIPT_GLOBALPATH
    done

    echo "# Print some information" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"${BETAS_TO_BE_USED[@]}\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"Host: \$(hostname)\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"GPU:  \$GPU_DEVICE_ORDINAL\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"Date and time: \$(date)\"" >> $JOBSCRIPT_GLOBALPATH
    echo "echo \$SLURM_JOB_NODELIST > hmc.${BETAS_STRING:1}.\$SLURM_JOB_ID.nodelist" >> $JOBSCRIPT_GLOBALPATH
    echo "" >> $JOBSCRIPT_GLOBALPATH
    echo "# TODO: this is necessary because the log file is produced in the directoy" >> $JOBSCRIPT_GLOBALPATH
    echo "#       of the exec. Copying it later does not guarantee that it is still the same..." >> $JOBSCRIPT_GLOBALPATH
    echo "echo \"Copy executable to beta directories in ${WORK_DIR_WITH_BETAFOLDERS}/${BETA_PREFIX}x.xxxx...\"" >> $JOBSCRIPT_GLOBALPATH
    for INDEX in "${!BETAS_TO_BE_USED[@]}"; do
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
    for INDEX in "${!BETAS_TO_BE_USED[@]}"; do
	echo "cd \$workdir$INDEX" >> $JOBSCRIPT_GLOBALPATH
	echo "pwd &" >> $JOBSCRIPT_GLOBALPATH
	echo "time srun -n 1 \$dir$INDEX/$HMC_FILENAME --input-file=\$dir$INDEX/$INPUTFILE_NAME --device=$INDEX --kappa=0.$KAPPA --ns=$NSPACE --nt=$NTIME --integrationsteps0=$INTSTEPS0 --integrationsteps1=$INTSTEPS1 --beta=${BETAS_TO_BE_USED[$INDEX]} > \$outFile 2>\$errFile &" >> $JOBSCRIPT_GLOBALPATH
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
    echo "cgmax=8000" >> $INPUTFILE_GLOBALPATH
    echo "measure_pbp=0" >> $INPUTFILE_GLOBALPATH
    echo "tau=1" >> $INPUTFILE_GLOBALPATH
    echo "savefrequency=$NSAVE" >> $INPUTFILE_GLOBALPATH
    echo "startcondition=$STARTCONDITION" >> $INPUTFILE_GLOBALPATH
    echo "hmcsteps=$MEASUREMENTS" >> $INPUTFILE_GLOBALPATH
    echo "num_timescales=2" >> $INPUTFILE_GLOBALPATH
    echo "integrator0=twomn" >> $INPUTFILE_GLOBALPATH
    echo "integrator1=twomn" >> $INPUTFILE_GLOBALPATH

}
