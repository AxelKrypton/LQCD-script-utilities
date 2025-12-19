#!/bin/bash
#
#  Copyright (c) 2016 Christopher Czaban
#  Copyright (c) 2017,2018,2021 Alessandro Sciarra
#  Copyright (c) 2017,2021 Francesca Cuteri
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


source $HOME/Script/PathManagement.sh   || exit -2

CheckWilsonStaggeredVariables

if [ $WILSON = "TRUE" ]; then
    PATH_TO_DATA="/home/phil-configs/wilson_nf2_muipi4/ImagMu"
elif [ $STAGGERED = "TRUE" ]; then
    PATH_TO_DATA="/home/phil-configs/Staggered"
fi

#Other variables for the script
MASS_PARAMETER_ARRAY=()
AVAILABLE_OBSERVABLES=('plaq' 'poly_re' 'poly_im' 'poly_im_abs' 'poly_sq' 'poly_ph' 'poly_im_withZeroMean' 'pbp')
OBSERVABLE=""
EXTRACT_BETAC_FROM_BINDER='FALSE'

while [ "$#" -gt 0 ]
do
    case $1 in
        --nf)
            NFLAVOUR=$2
            shift
            ;;
        --mui)
            CHEMPOT=$2
            shift
            ;;
        --nt)
            NTIME=$2
            shift
            ;;
        --mass)
            while [[ $2 =~ [[:digit:]]{4} ]]
            do
                MASS_PARAMETER_ARRAY+=( $2 )
                shift
            done
            ;;
        --obs)
            OBSERVABLE=$2
            shift
            ;;
        --useKurtosis)
            EXTRACT_BETAC_FROM_BINDER="TRUE"
            ;;
        -h)
            printf '\n  \e[1;4;95mAvailble options\e[24m:\n'
            printf '\n\e[22;96m'
            printf "    --nf            ->  the number of flavours   [default: extracted from path, prefix \"${NFLAVOUR_PREFIX}\"]\n"
            printf "    --mui           ->  chemical potential value [default: extracted from path, prefix \"${CHEMPOT_PREFIX}\"]\n"
            printf "    --nt            ->  temporal lattice extent  [default: extracted from path, prefix \"${NTIME_PREFIX}\"]\n"
            printf "    --mass          ->  list of mass values      [default: all existing ones,   prefix \"${MASS_PREFIX}\"]\n"
            printf '                        Use spaces to separate mass values and use format as they appear in folder names.\n'
            printf "    --obs           ->  observable to be used, e.g. poly_sq, poly_im --> \e[1;93mMandatory option\e[22;96m\n"
            printf "    --useKurtosis   ->  extract beta_c from reweighted kurtosis instead of from the reweighted skewness\n"
            printf '\n\e[0m'
            exit
            ;;
        *)
            echo "$0: $1: unrecognized option...exiting"
            exit
            ;;
        -*)
            echo "$0: $1: unrecognized option...exiting"
            exit
            ;;
    esac
    shift
done

function ElementInArray() {
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

if [ "$OBSERVABLE" = "" ] || ! ElementInArray $OBSERVABLE ${AVAILABLE_OBSERVABLES[@]}; then
    printf "\n\e[1;93mWARNING:\e[21m No valid observable specified! Here the available ones:\n\e[96m"
    PS3="$(printf "\e[93mChoose one: \e[96m")"
    select OBSERVABLE in ${AVAILABLE_OBSERVABLES[@]}; do
        if ElementInArray ${OBSERVABLE} ${AVAILABLE_OBSERVABLES[@]}; then
            break
        fi
    done
    printf "\e[0m"
fi

function TryToExtractValueOfParameterFromPwd()
{
    local prefix regex result
    prefix="$1"
    regex="$2"
    if ! ( ReadSingleParameterFromPath ${PWD} ${prefix} &> /dev/null); then
        result=( $(grep -o "${prefix}${regex}" <<< "${PWD}") )
        if [[ ${#result[@]} -ne 1 ]]; then
            printf "\n\e[0;91m Unable to recover \"${prefix}\" from the path \"${PWD}\". Aborting...\n\n\e[0m"
            exit 1
        fi
        result=${result[0]/#${prefix}/}
    fi
    declare -gr ${PARAMETER_VARIABLE_NAMES[${prefix}]}="${result}"
}

[ "$NFLAVOUR" = "" ] && TryToExtractValueOfParameterFromPwd "${NFLAVOUR_PREFIX}" "${NFLAVOUR_REGEX}"
[ "$NTIME" = "" ]    && TryToExtractValueOfParameterFromPwd "${NTIME_PREFIX}"    "${NTIME_REGEX}"
[ "$CHEMPOT" = "" ]  && TryToExtractValueOfParameterFromPwd "${CHEMPOT_PREFIX}"  "${CHEMPOT_REGEX}"
CheckParametersExtractedFromPath $NFLAVOUR_PREFIX $CHEMPOT_PREFIX $NTIME_PREFIX

PATH_TO_DATA=$PATH_TO_DATA$(GetParametersPath $NFLAVOUR_PREFIX $CHEMPOT_PREFIX)
EXTRACTED_DATA_FILENAME="${OBSERVABLE}_KurtosisAtBetaC.dat"

if [ ${#MASS_PARAMETER_ARRAY[@]} -eq 0 ]; then
    MASS_PARAMETER_ARRAY=( $(ls -d ${PATH_TO_DATA}/${MASS_PREFIX}*/${NTIME_PREFIX}${NTIME}/ | grep -o "/$MASS_PREFIX$MASS_REGEX/" | grep -o "$MASS_REGEX") )
    for INDEX in ${!MASS_PARAMETER_ARRAY[@]}; do
        if [ ${MASS_PARAMETER_ARRAY[$INDEX]} = '0000' ]; then
            unset -v 'MASS_PARAMETER_ARRAY[$INDEX]'
        fi
    done
    MASS_PARAMETER_ARRAY=( ${MASS_PARAMETER_ARRAY[@]} ) #Make array not sparse
    if [ ${#MASS_PARAMETER_ARRAY[@]} -eq 0 ]; then
        printf "\n\e[91m No mass folder was found!\e[0m\n\n"
        exit -1
    fi
fi

printf '\n \e[1;4;95mScript setup\e[24m:\e[22;96m\n\n'
printf "%+16s: %s\n" 'Path to data' $PATH_TO_DATA
printf "%+16s: %s\n" ${NFLAVOUR_PREFIX} $NFLAVOUR
printf "%+16s: %s\n" ${NTIME_PREFIX}  $NTIME
printf "%+16s: %s\n" ${CHEMPOT_PREFIX} $CHEMPOT
printf "%+16s: %s\n" "$MASS_PREFIX array" "${MASS_PARAMETER_ARRAY[*]}"
printf "%+16s: %s\n" 'Observable' $OBSERVABLE
printf '\n\e[0m'

function ExtractAvailableVolumes(){
    #The reason for the following implementation is to have the volumes in the array sorted.
    VOLUMES_VALUES=( $(ls -1 $PATH_TO_DATA/$MASS_PREFIX$1/$NTIME_PREFIX$NTIME | grep -o "^$NSPACE_PREFIX${NSPACE_REGEX%?}$" | grep -o "${NSPACE_REGEX%?}") )
}

function GetBetaCFolderName(){
    echo "$PATH_TO_DATA/$MASS_PREFIX${1}/$NTIME_PREFIX$NTIME/$NSPACE_PREFIX${2}/$NFLAVOUR_PREFIX${NFLAVOUR}_$CHEMPOT_PREFIX${CHEMPOT}_$MASS_PREFIX${1}_$NTIME_PREFIX${NTIME}_$NSPACE_PREFIX${2}_betacEstimates"
}

function GetBetaCFileName(){
    if [ $EXTRACT_BETAC_FROM_BINDER = "TRUE" ]; then
        echo "$NFLAVOUR_PREFIX${NFLAVOUR}_$CHEMPOT_PREFIX${CHEMPOT}_$MASS_PREFIX${1}_$NTIME_PREFIX${NTIME}_$NSPACE_PREFIX${2}_betaC_${OBSERVABLE}_from_kurtosis_reweightedData.dat"
    else
        echo "$NFLAVOUR_PREFIX${NFLAVOUR}_$CHEMPOT_PREFIX${CHEMPOT}_$MASS_PREFIX${1}_$NTIME_PREFIX${NTIME}_$NSPACE_PREFIX${2}_betaC_${OBSERVABLE}_from_skewness_reweightedData.dat"
    fi
}

if [ -f $EXTRACTED_DATA_FILENAME ]; then
    mkdir -p Trash
    mv $EXTRACTED_DATA_FILENAME Trash/${EXTRACTED_DATA_FILENAME}_$(date +'%F_%H%M%S')
fi

#Extract data
printf "%-12s%-10s%-25s%-25s%-25s%-25s%-25s%-25s%-25s\n" "#$MASS_PREFIX" "ns" "betaC" "skew" "errorSkew" "Kurtosis" "errorKurtosis" "deltaBetaLow" "deltaBetaHigh" > $EXTRACTED_DATA_FILENAME

[ ${#MASS_PARAMETER_ARRAY[@]} -eq 0 ] && ExtractAvailableMassParameterValues

for MASS in ${MASS_PARAMETER_ARRAY[@]}; do
    ExtractAvailableVolumes $MASS
    for VOL in ${VOLUMES_VALUES[@]}; do
        FOLDER=$(GetBetaCFolderName $MASS $VOL)
        FILENAME=$(GetBetaCFileName $MASS $VOL)
        if [ -d $FOLDER ]; then
            if [ -f $FOLDER/$FILENAME ]; then
                if [[ $MASS =~ [.] ]]; then
                    MASS_VALUE=${MASS}
                else
                    MASS_VALUE="0.${MASS}"
                fi
                printf "%-12s%-10s" "${MASS_VALUE}" "${VOL}" >> $EXTRACTED_DATA_FILENAME
                awk 'END{printf "%-25s%-25s%-25s%-25s%-25s%-25s%-25s\n", $1, $6, $7, $8, $9, $10, $11}' $FOLDER/$FILENAME >> $EXTRACTED_DATA_FILENAME
                printf "\e[96m Extracted data from \"$FOLDER/$FILENAME\" file!\e[0m\n"
            else
                printf "\e[93m File \"$FILENAME\" not found, skipping it!\e[0m\n"
            fi
        else
            printf "\e[93m Folder \"$FOLDER\" not found, skipping it!\e[0m\n"
        fi
    done
done

if [ $(wc -l < ${EXTRACTED_DATA_FILENAME}) -eq 1 ]; then
    printf "\n\e[91m No data was extracted!\e[0m\n\n"
    exit -1
else
    printf "\n\e[92m Extraction of data successfully completed!\e[0m\n"
    #Resort the file according to ns
    sort -k2n $EXTRACTED_DATA_FILENAME | awk 'BEGIN{ns=1000}NR==1{print $0} NR>1{if($2>ns){printf "\n\n"}; ns=$2; print $0}' >> fileThatHopefullyDoesNotExist
    mv fileThatHopefullyDoesNotExist $EXTRACTED_DATA_FILENAME
    printf "\n\e[92m Data successfully sorted!\e[0m\n\n"
fi

#Check for nan in the data file produced and warn the user in case
if [ $(grep -ci "nan" $EXTRACTED_DATA_FILENAME) -ne 0 ]; then
    printf "\n\e[38;5;11m \e[1m\e[4mWARNING\e[24m:\e[21m The produced file \"$EXTRACTED_DATA_FILENAME\" seems to contain not a numbers! Please check it! \n"
fi
