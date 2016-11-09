#!/bin/bash

# This script should be run from the folder where the BruteForceFit is
# done, namely from a path from which mass, nt and ns can be read out.
#
# Then it looks in phil-configs for the reweithed data and prints their
# resolution in beta. This is the only thing done if the option -r is given.
#
# If no option is given, then the script checks in the spatial volume folders
# whether any folder called "${DEFAULT_REWEIGHTED_FOLDER}_dBeta*" is present.
# If this is the case, then the user will be prompted for choosing one among 
# these and the chosen one will be symlinked with the default name. This is
# very handy when it comes to make fit after having reweighted the data with
# different resolutions.

#--------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source "$HOME/Script/PathManagement.sh" || exit -2
source "$HOME/Script/UtilityFunctions.sh" || exit -2
#--------------------------------------------------------------------------------#

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    printf "\e[0m\n\n"
    exit 17
}

#Having loaded PathManagement.sh we get for free all the parameters variables and functionalities
CheckWilsonStaggeredVariables

#Variables for the script
READ_ONLY='FALSE'
OBSERVABLE='poly_im_withZeroMean'
declare -A RESOLUTION
OUTPUT_FILENAME="RESOLUTIONS"
if [ $WILSON = 'TRUE' ]; then
    DATA_PATH_PREFIX='/home/phil-configs/wilson_nf2_muipi4/ImagMu'
elif [ $STAGGERED = 'TRUE' ]; then
    DATA_PATH_PREFIX='/home/phil-configs/Staggered'
fi

#Functions to handle paths (the only argument is NSPACE since the others are set from the path)
function GetNsFolderGlobalpath(){
    echo "${DATA_PATH_PREFIX}$(GetParametersPath $NFLAVOUR_PREFIX $CHEMPOT_PREFIX $MASS_PREFIX $NTIME_PREFIX)/${NSPACE_PREFIX}${1}"
}
function GetReweightingFolderGlobalpath(){
    echo "$(GetNsFolderGlobalpath $1)/$(GetParametersString $NFLAVOUR_PREFIX $CHEMPOT_PREFIX $MASS_PREFIX $NTIME_PREFIX)_${NSPACE_PREFIX}${1}_reweighting"
}
function GetDatafileGlobalpath(){
    echo "$(GetReweightingFolderGlobalpath $1)/$(GetParametersString $NFLAVOUR_PREFIX $CHEMPOT_PREFIX $MASS_PREFIX $NTIME_PREFIX)_${NSPACE_PREFIX}${1}_${OBSERVABLE}_reweighted.dat"
}

if ElementInArray "--help" $@ || ElementInArray "-h" $@; then
    printf "\n\t\e[38;5;13m\e[1m"
    printf "\e[4mPossible options to the script\e[24m:\e[21m\n\n\t\e[38;5;10m"
    printf "   -r | --readOnly          ->   Find the resolutions only, do not create any symlink!\n\t"
    printf "   -o | --observable        ->   Reweighted observable (default \"--observable $OBSERVABLE\")\n\t"
    printf "\n\e[0m"
    exit 3
fi

while [ "$1" != "" ]; do
    case $1 in
        -r | --readOnly )
            READ_ONLY='TRUE'
            shift
            ;;
        -o | --observable )
            OBSERVABLE=$2
            shift 2
            ;;
        * ) printf "\n\e[38;5;9m Option \e[1m$1\e[21m invalid! Aborting...\n\n\e[0m"; exit -1
    esac
done


#==============================================================================================================
#Read out from the path the parameters (do not check for multiple occurence!)
ReadSingleParameterFromPath $PWD $NFLAVOUR_PREFIX
ReadSingleParameterFromPath $PWD $CHEMPOT_PREFIX
ReadSingleParameterFromPath $PWD $MASS_PREFIX
ReadSingleParameterFromPath $PWD $NTIME_PREFIX
CheckParametersExtractedFromPath $NFLAVOUR_PREFIX $CHEMPOT_PREFIX $MASS_PREFIX $NTIME_PREFIX

#==============================================================================================================
#Ask for number of volumes
POSSIBLE_VOLS=( "12 18" "12 18 24" "18 24 30" "18 24 30 36" "24 30 36")
printf "\n\e[38;5;208mFor which volumes do you want to know the resolution in the reweighted data?\e[38;5;226m\n"
select VOLUMES in "${POSSIBLE_VOLS[@]}"; do
    if ! ElementInArray "$VOLUMES" "${POSSIBLE_VOLS[@]}"; then
        continue
    else
        printf "\e[0m"
        break
    fi
done
echo ''

#==============================================================================================================
#If there are several reweighted folders, choose one interactively
if [ $READ_ONLY = 'FALSE' ]; then
    for VOL in ${VOLUMES[@]}; do
        CLASSIC_REWEIGHTING_FOLDER=$(GetReweightingFolderGlobalpath $VOL)
        REWEIGHTING_FOLDERS=( $(ls -d ${CLASSIC_REWEIGHTING_FOLDER}_dBeta*/) )
        if [ ${#REWEIGHTING_FOLDERS[@]} -eq 0 ]; then
            if [ ! -d $CLASSIC_REWEIGHTING_FOLDER ]; then
                printf "\e[38;5;9m\n No reweighting folder found for m=$MASS, nt=$NTIME and ns=${VOL}!!! Aborting...\e[0m\n\n"
                exit -1
            else
                continue #It means that there is one folder with the classic name, fine.
            fi
        else
            if [ ${#REWEIGHTING_FOLDERS[@]} -gt 1 ]; then
                #Choose which reweighting data set to use if some are existing
                printf "\n\e[38;5;13mWhich reweighted dataset would you like to use?\e[38;5;6m\n"
                select FOLDER in "${REWEIGHTING_FOLDERS[@]}"; do
                    if ! ElementInArray "$FOLDER" "${REWEIGHTING_FOLDERS[@]}"; then
                        continue
                    else
                        printf "\e[0m"
                        break
                    fi
                done
            else
                FOLDER=${REWEIGHTING_FOLDERS[0]}
            fi
            #Now that we have the folder we have to exclude the scenario in which we could loose some data and then create our symbolic link.
            if [ -d $CLASSIC_REWEIGHTING_FOLDER ]; then
                if [ ! -L $CLASSIC_REWEIGHTING_FOLDER ]; then
                    printf "\e[38;5;9m\n Folder \"$CLASSIC_REWEIGHTING_FOLDER\" existing and not a symlink! Cannot overwrite it! Aborting...\e[0m\n\n"
                    exit -1
                else
                    if [ $(grep -c "$CLASSIC_REWEIGHTING_FOLDER" <<< "$(readlink $CLASSIC_REWEIGHTING_FOLDER)") -eq 0 ]; then
                        printf "\e[38;5;9m\n Folder \"$CLASSIC_REWEIGHTING_FOLDER\" seems to be a symlink, but not to a folder that is a reweighting folder!!! Please check!! Aborting...\e[0m\n\n"
                        exit -1
                    fi
                    unlink $CLASSIC_REWEIGHTING_FOLDER
                fi
            fi
            ln -s $FOLDER $CLASSIC_REWEIGHTING_FOLDER
        fi
    done
fi
#==============================================================================================================
#Get Resolution from files
printf "\nResolutions of reweighted data:\n" > $OUTPUT_FILENAME
FIT_FOLDER_NAME=""
for VOL in ${VOLUMES[@]}; do
    FILE_GLOBALPATH=$(GetDatafileGlobalpath $VOL)
    if [ -f $FILE_GLOBALPATH ]; then
        BETAS=( $(awk '/^($|[#]+)/{next}{print $0}' $FILE_GLOBALPATH | cut -f1) )
        RESOLUTIONS=( $(echo ${BETAS[@]} | awk 'BEGIN{RS=" "}{if(last){print $1-last}; last=$1}' | sort -u) )
        if [ ${#RESOLUTIONS[@]} -eq 1 ]; then
            RESOLUTION[$VOL]=${RESOLUTIONS[0]}
        else
            RESOLUTION[$VOL]="Various"
        fi
    else
        printf "\e[38;5;9m\n File \"$FILE_GLOBALPATH\" not found! Aborting...\e[0m\n\n"
        exit -1
    fi
    printf "%6s\t%6s\n" "ns$VOL" "${RESOLUTION[$VOL]}" >> $OUTPUT_FILENAME
    FIT_FOLDER_NAME="${FIT_FOLDER_NAME}_ns${VOL}_${RESOLUTION[$VOL]}"
done
printf "\nFolder name for fit results: ${FIT_FOLDER_NAME:1}\n\n" >> $OUTPUT_FILENAME

printf "\n\e[38;5;11m==============================================================================================================\n\e[38;5;86m"
cat $OUTPUT_FILENAME
printf "\e[0m"


