#!/bin/bash

source $HOME/Script/PathManagement.sh || exit -2

CheckWilsonStaggeredVariables

if [ $WILSON = "TRUE" ]; then
    PATH_TO_DATA="/home/phil-configs/wilson_nf2_muipi4/ImagMu"   
elif [ $STAGGERED = "TRUE" ]; then
    PATH_TO_DATA="/home/phil-configs/Staggered"
fi

#Other variables for the script
MASS_PARAMETER_ARRAY=()
OBSERVABLE=""

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
        --mp | --massParameter)
            while [[ $2 =~ [[:digit:]]{4} ]] 
            do
                MASS_PARAMETER_ARRAY+=( $2 )
                shift
            done
            ;;
        --obs | --observable)
            OBSERVABLE=$2
            shift
            ;;
        --betaCFromBinder)
            EXTRACT_BETAC_FROM_BINDER="TRUE"
            ;;
        -h)
            echo "availble options:"
            echo "--nf (specify the number of flavours)"
            echo "--mui (specify chemical potential value, e.g. 0 or PiT )"
            echo "--nt (specify time value)"
            echo "--mp | --massParameter (specify mass parameter values - either kappa value for wilson or mass value for staggered)"
            echo "--obs | --observable (specify observable, e.g. poly_sq, poly_im, ...)"
            echo "--betaCFromBinder (extract beta_c from reweighted binder cumulant)"
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

[ "$OBSERVABLE" = "" ] && echo "No observable specified...exiting" && exit
[ "$NFLAVOUR" = "" ] && ReadSingleParameterFromPath $PWD $NFLAVOUR_PREFIX
[ "$NTIME" = "" ] && ReadSingleParameterFromPath $PWD $NTIME_PREFIX
[ "$CHEMPOT" = "" ] && ReadSingleParameterFromPath $PWD $CHEMPOT_PREFIX

CheckParametersExtractedFromPath $NFLAVOUR_PREFIX $CHEMPOT_PREFIX $NTIME_PREFIX

PATH_TO_DATA=$PATH_TO_DATA$(GetParametersPath $NFLAVOUR_PREFIX $CHEMPOT_PREFIX)

EXTRACTED_DATA_FILENAME="${OBSERVABLE}_BinderCumulantAtBetaC.dat"

echo "path to data: $PATH_TO_DATA"
echo "NFLAVOR: $NFLAVOUR"
echo "NTIME:  $NTIME"
echo "CHEMPOT: $CHEMPOT"
echo "observable: $OBSERVABLE"
echo "mass prefix: $MASS_PREFIX"

function ExtractAvailableMassParameterValues(){
    MASS_PARAMETER_ARRAY=( $(ls $PATH_TO_DATA | grep -o "$MASS_PREFIX$MASS_REGEX" | grep -o "$MASS_REGEX") )
}

function ExtractAvailableVolumes(){
    #The reason for the following implementation is to have the volumes in the array sorted.
    VOLUMES_VALUES=(  $(ls $PATH_TO_DATA/$MASS_PREFIX$1/$NTIME_PREFIX$NTIME | grep -o "$NSPACE_PREFIX$NSPACE_REGEX" | grep -o "$NSPACE_REGEX") )
    #VOLUMES_VALUES=(  $(ls $PATH_TO_DATA/$MASS_PREFIX$1/$NTIME_PREFIX$NTIME | grep -o "$NSPACE_PREFIX[[:digit:]]\{1\}" | grep -o "$NSPACE_REGEX") )
    #VOLUMES_VALUES+=( $(ls $PATH_TO_DATA/$MASS_PREFIX$1/$NTIME_PREFIX$NTIME | grep -o "$NSPACE_PREFIX[[:digit:]]\{2\}" | grep -o "$NSPACE_REGEX") )
}

function GetBetaCFolderName(){
    echo "$PATH_TO_DATA/$MASS_PREFIX${1}/$NTIME_PREFIX$NTIME/$NSPACE_PREFIX${2}/$CHEMPOT_PREFIX${CHEMPOT}_$MASS_PREFIX${1}_$NTIME_PREFIX${NTIME}_$NSPACE_PREFIX${2}_betacEstimates"
}

function GetBetaCFileName(){
    if [ "$EXTRACT_BETAC_FROM_BINDER" = "TRUE" ]; then
        echo "$CHEMPOT_PREFIX${CHEMPOT}_$MASS_PREFIX${1}_$NTIME_PREFIX${NTIME}_$NSPACE_PREFIX${2}_betaC_${OBSERVABLE}_from_binder_reweightedData.dat"
    else
        echo "$CHEMPOT_PREFIX${CHEMPOT}_$MASS_PREFIX${1}_$NTIME_PREFIX${NTIME}_$NSPACE_PREFIX${2}_betaC_${OBSERVABLE}_from_skew_reweightedData.dat"
    fi
}

if [ -f $EXTRACTED_DATA_FILENAME ]; then
    mkdir -p Trash
    mv $EXTRACTED_DATA_FILENAME Trash/${EXTRACTED_DATA_FILENAME}_$(date +'%F_%H%M%S')
fi

#Extract data
printf "%-12s%-10s%-25s%-25s%-25s%-25s%-25s\n" "#$MASS_PREFIX" "ns" "betaC" "skew" "errorSkew" "binder" "errorBinder" > $EXTRACTED_DATA_FILENAME

[ ${#MASS_PARAMETER_ARRAY[@]} -eq 0 ] && ExtractAvailableMassParameterValues

echo "mass paramter array: ${MASS_PARAMETER_ARRAY[@]}"

for MASS in ${MASS_PARAMETER_ARRAY[@]}; do
    ExtractAvailableVolumes $MASS
    for VOL in ${VOLUMES_VALUES[@]}; do
        FOLDER=$(GetBetaCFolderName $MASS $VOL)
        FILENAME=$(GetBetaCFileName $MASS $VOL)
        if [ -d $FOLDER ]; then
            if [ -f $FOLDER/$FILENAME ]; then
                printf "%-12s%-10s" "0.${MASS}" "${VOL}" >> $EXTRACTED_DATA_FILENAME
                awk 'END{printf "%-25s%-25s%-25s%-25s%-25s\n", $1, $6, $7, $8, $9}' $FOLDER/$FILENAME >> $EXTRACTED_DATA_FILENAME
            else
                printf "\n\e[38;5;9m File \"$FILENAME\" not found, skipping it!\e[0m\n"
            fi
        else
            printf "\n\e[38;5;9m Folder \"$FOLDER\" not found, skipping it!\e[0m\n"
        fi
    done
done
printf "\n\e[38;5;10m Extraction of data successfully completed!\e[0m\n"

#Resort the file according to ns
sort -k2n $EXTRACTED_DATA_FILENAME | awk 'BEGIN{ns=1000}NR==1{print $0} NR>1{if($2>ns){printf "\n\n"}; ns=$2; print $0}' >> fileThatHopefullyDoesNotExist
mv fileThatHopefullyDoesNotExist $EXTRACTED_DATA_FILENAME
printf "\n\e[38;5;10m Data successfully sorted!\e[0m\n\n"

#Check for nan in the data file produced and warn the user in case
if [ $(grep -ci "nan" $EXTRACTED_DATA_FILENAME) -ne 0 ]; then
    printf "\n\e[38;5;11m \e[1m\e[4mWARNING\e[24m:\e[21m The produced file \"$EXTRACTED_DATA_FILENAME\" seems to contain not a numbers! Please check it! \n"
fi
