#!/bin/bash

# This script is intended to gather the binder data from phil-configs
# and to put them in the relative folders here. The path to phil-configs
# is hard coded just because it should not change.

PATH_TO_DATA="/home/phil-configs/Staggered/Nf3/mui0"
EXTRACTED_DATA_FILENAME="PbpBinderCumulantAtBetaC.dat"

function ExtractAvailableMassValues(){
    MASS_VALUES=( $(ls $PATH_TO_DATA | grep -o "mass[[:digit:]]\{4\}") )
}

function ExtractAvailableVolumes(){
    #ls $PATH_TO_DATA/$1
    VOLUMES_VALUES=( $(ls $PATH_TO_DATA/$1/nt4 | grep -o "ns[[:digit:]]\{1\}$") )
    VOLUMES_VALUES+=( $(ls $PATH_TO_DATA/$1/nt4 | grep -o "ns[[:digit:]]\{2\}$") )
}

function GetBetaCFolderName(){
    echo "$PATH_TO_DATA/${1}/nt4/${2}/mui0_${1}_nt4_${2}_betacEstimates"
}

function GetBetaCFileName(){
    echo "mui0_${1}_nt4_${2}_betaC_pbp_from_skew_reweightedData.dat"
}

#------------------------------------------------------------------------------------------------#
if [ -f $EXTRACTED_DATA_FILENAME ]; then
    mkdir -p Trash
    mv $EXTRACTED_DATA_FILENAME Trash/${EXTRACTED_DATA_FILENAME}_$(date +'%F_%H%M%S')
fi
#Extract data
printf "%-12s%-10s%-25s%-25s%-25s%-25s%-25s\n" "#mass" "ns" "betaC" "skew" "errorSkew" "binder" "errorBinder" > $EXTRACTED_DATA_FILENAME
ExtractAvailableMassValues
for MASS in ${MASS_VALUES[@]}; do
    ExtractAvailableVolumes $MASS
    for VOL in ${VOLUMES_VALUES[@]}; do
        FOLDER=$(GetBetaCFolderName $MASS $VOL)
        FILENAME=$(GetBetaCFileName $MASS $VOL)
        if [ -d $FOLDER ]; then
            if [ -f $FOLDER/$FILENAME ]; then
                printf "%-12s%-10s" "0.${MASS#mass}" "${VOL#ns}" >> $EXTRACTED_DATA_FILENAME
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

