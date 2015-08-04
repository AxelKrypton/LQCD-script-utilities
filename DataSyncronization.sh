#!/bin/bash

# This script is just supposed to run the Python script to backup simulation
# data automatically for a bunch of simulations.
#
# The idea is that one gives as command-line parameters a set
# of strings like
# "muiPiT/k1650/nt6/ns16"
# and this script will syncronize data using the betas(Sync) file for
# such parameters
#
# This script works also for Staggered simulations, since the python
# script can manage also that case.
#
# IMPORTANT: Add here below your globalpath to the python executable 
#            using a variable whose name is $(whoami).

sciarra="${HOME}/Documents/PhD_project/Data_Elaboration_tools/LQCD_SimulationManagementUtilities/ImagMu/ImagMuSync.py"
czaban="${HOME}/LQCD_SimulationManagementUtilities/ImagMu/ImagMuSync.py"

identity=$(whoami)

#-----------------------------------------------------------------------------------------------------------------------------#

function PrintSituationVolume(){
    [ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ] && DATA_FILENAME="rhmc_output"
    [ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ] && DATA_FILENAME="hmc_output"
	printf "\n\e[38;5;14m----------------------------------------------------------------------------------------------------------------------------\e[0m\n"
    printf "  \e[38;5;202m%-40s%-20s%-20s%-20s%-20s\n\e[0m" "BetaFolder" "NumFiles" "NumPbpFiles" "$DATA_FILENAME" "${DATA_FILENAME}_pbp.dat"
    for FOLDER in b[0-9].????_s*; do
        local NUMBER_OF_FILES=$(ls $FOLDER 2>/dev/null | wc -l)
        local NUMBER_OF_PBP_FILES=$(ls $FOLDER/conf.*_pbp.dat 2>/dev/null | wc -l)
        local NUMBER_OF_LINES_DATA=$(wc -l 2>/dev/null < $FOLDER/$DATA_FILENAME)
        local NUMBER_OF_LINES_PBP=$(wc -l 2>/dev/null < $FOLDER/${DATA_FILENAME}_pbp.dat)
        [ "$NUMBER_OF_LINES_DATA" == "" ] && NUMBER_OF_LINES_DATA=0
        [ "$NUMBER_OF_LINES_PBP" == "" ] && NUMBER_OF_LINES_PBP=0
        printf "  \e[38;5;14m%-40s%-20s%-20s%-20s%-20s\n\e[0m" "$FOLDER" "$NUMBER_OF_FILES" "$NUMBER_OF_PBP_FILES" "$NUMBER_OF_LINES_DATA lines" "$NUMBER_OF_LINES_PBP lines"
    done
	printf "\e[38;5;14m----------------------------------------------------------------------------------------------------------------------------\e[0m\n"
    unset -v 'FOLDER'
}

function CleanDataFiles(){
	printf "\n\e[0;34m Cleaning:\n\e[38;5;45m"
    for FOLDER in b[0-9].????_s*; do
        printf " - $FOLDER\n"
	    if [ -e $FOLDER/hmc_output ]; then
	        rm -f $FOLDER/hmc_output_raw
	        ${HOME}/Script/tmLQCD_Juqueen/CleanOutputData.sh $FOLDER/hmc_output >/dev/null
	    fi
	    if [ -e $FOLDER/hmc_output_pbp.dat ]; then
	        rm -f $FOLDER/hmc_output_pbp.dat_raw
	        ${HOME}/Script/tmLQCD_Juqueen/CleanOutputData.sh $FOLDER/hmc_output_pbp.dat >/dev/null
	    fi
	    if [ -e $FOLDER/rhmc_output ]; then
	        rm -f $FOLDER/rhmc_output_raw
	        ${HOME}/Script/tmLQCD_Juqueen/CleanOutputData.sh $FOLDER/rhmc_output >/dev/null
	    fi
	    if [ -e $FOLDER/rhmc_output_pbp.dat ]; then
	        rm -f $FOLDER/rhmc_output_pbp.dat_raw
	        ${HOME}/Script/tmLQCD_Juqueen/CleanOutputData.sh $FOLDER/rhmc_output_pbp.dat >/dev/null
	    fi
	done
    printf "\e[0m"
}


function UnmergeAndCheck(){
    for d in $@; do
	cd $d
        if [ -e rhmc_output ]; then
	    ${HOME}/ScriptStaggered/UnmergePbpFile.sh
	    if [ $? -ne 0 ]; then
		>&2 echo "$(date +"%d-%m-%Y at %T --->") Error occurred in script \"UnmergePbpFile.sh\" from \"$(pwd)\""
	    fi
	    ${HOME}/ScriptStaggered/CheckPbpFilesVSMergedFile.sh
	    if [ $? -ne 0 ]; then
		>&2 echo "$(date +"%d-%m-%Y at %T --->") Error occurred in script \"CheckPbpFilesVSMergedFile.sh\" from \"$(pwd)\""
	    fi
        fi
	cd ..
    done
}

#-----------------------------------------------------------------------------------------------------------------------------#

STARTING_POSITION="$(pwd)"
printf "\n\n\e[1mScript \"$0\" run from $STARTING_POSITION...\n\e[0m"

DATA_GLOBALPATHS=()
SKIPPED_DIRECTORIES=()
REMOTE="loewe"

while [ "$1" != "" ]; do
    case $1 in
        -h | --help )
            printf "\n\e[0;32m"
            echo "Call the script $0 with the following optional arguments:"
            echo -e "  -r | --remote           ->    default value = $REMOTE"
            echo -e "  -p | --globalPaths      ->    to specify the folders to syncronize"
            printf "\n\e[0m"
            exit
            shift ;;
        
        -r | --remote )
            while [[ ! "$2" =~ ^- ]] && [ "$2" != "" ]; do
                echo $2
                REMOTE=$2
                shift
            done
            shift ;;

        -p | --globalPaths )
            while [[ ! "$2" =~ ^- ]] && [ "$2" != "" ]; do
                DATA_GLOBALPATHS+=( $2 )
                shift
            done
            shift ;;
            
        * ) printf "\n\e[0;31m Invalid option \e[1m$1\e[0;31m (see help for further information)! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
done

printf "\n \e[0;32m\e[4mStarting time: $(date +'%Hh%M on %d.%m.%y') (from $REMOTE)\n\e[0m"
for RUN in ${DATA_GLOBALPATHS[@]}; do
    if [ ! -d $RUN ]; then
	printf "\n\e[0;31m The directory \"$RUN\" has not been found! It will be skipped!\n\n\e[0m"
	SKIPPED_DIRECTORIES+=( "$RUN" )
	continue
    fi
    cd $RUN || exit -2
    printf "\n\e[0;36m=======================================================================\e[0m\n"
    printf "\e[38;5;13m\e[2m  $(pwd)\e[0m"
    printf "\n\e[0;36m=======================================================================\e[0m\n"
    # Before syncronize just give an overview of the status of the folder
    if [ -e betasSync ]; then
	    BETASFILE="betasSync"
    else
	    BETASFILE="betas"
    fi
    BETAVALUES=( $(grep -o "^[[:blank:]]*[[:digit:]]\.[[:digit:]]\{4\}" $BETASFILE) )
    for((i=0; i<${#BETAVALUES[@]}; i++)); do
	    BETAVALUES[$i]="b${BETAVALUES[$i]}*"
    done
    PrintSituationVolume
    #printf "\n\e[0;32m--------------------------------------------------------------\e[0m\n"
    # Then syncronize
    printf "\n\e[38;5;10m Syncronizing..."
    python ${!identity} -f=$BETASFILE --remote=$REMOTE >/dev/null
    printf " done!\e[0m\n" 
    # Then clean data files
    CleanDataFiles ${BETAVALUES[@]}
    # For Staggered runs unmerge pbp file and check if it was ok
    #UnmergeAndCheck ${BETAVALUES[@]}
    # Then give an other overview of the status of the folder
    #printf "\n\e[0;32m--------------------------------------------------------------\e[0m\n"
    PrintSituationVolume
    printf "\n\e[0;36m=======================================================================\e[0m\n\n"
done

# Print report on skipped folder
if [ ${#SKIPPED_DIRECTORIES[@]} -gt "0" ]; then	
    printf "\n\e[0;31m===================================================================================\n\e[0m"
    printf "\e[0;31m For the following given folders something went wrong and hence\n\e[0m"
    printf "\e[0;31m they were left out during the syncronization process:\n"
    for DIR in ${SKIPPED_DIRECTORIES[@]}; do
	printf "  - \e[1m$DIR\e[0;31m\n"
    done
    printf "\e[0;31m===================================================================================\n\n\e[0m"
fi
printf " \e[0;32m\e[4mEnding time: $(date +'%Hh%M on %d.%m.%y')\n\n\e[0m\n"
exit 0
