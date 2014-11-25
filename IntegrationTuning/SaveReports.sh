#!/bin/bash

# Just a short script to save as text files the reports
# of the integrator for the beta present in the folder
# from which it is run.

function ParseCommandLineOption(){
    while [ "$1" != "" ]; do
        case $1 in
            -h | --help )
                printf "\n\e[0;32m"
                echo "Call the script $0 with the following optional arguments:"
                echo ""
                echo "  -h | --help"
                echo "  -p | --prefixOutput      ->    Prefix for the output file (default=\"Nf3_\")"
                echo ""
                printf "\n\e[0m"
                exit
                shift;;
            -p=* | --prefixOutput=* )  PREFIX=${1#*=}; shift ;;
            * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
        esac
    done
}

#-----------------------------------------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source $HOME/Script/UtilityFunctions.sh || exit -2
source $HOME/Script/PathManagement.sh || exit -2
CheckSingleOccurrenceInPath "scratch" "hfftheo" "$(whoami)" "$CHEMPOT_PREFIX" "${KAPPA_PREFIX}[[:digit:]]\+" "${NTIME_PREFIX}[[:digit:]]\+" "${NSPACE_PREFIX}[[:digit:]]\+"
ReadParametersFromPath $(pwd)
PREFIX="Wilson_"
ParseCommandLineOption $@
#-----------------------------------------------------------------------------------------------------------------#

mkdir -p Reports || exit 2

printf "\n\e[0;36m========================================\e[0m\n"
for BETA in b[[:digit:]]*; do

    BETA=$(echo $BETA | grep -o "[[:digit:]].[[:digit:]]\{4\}")
    if [[ ! $BETA =~ [[:digit:]].[[:digit:]]{4} ]]; then continue; fi
    
    OUTPUT_FILENAME="${PREFIX}${PARAMETERS_STRING}_b${BETA}"
    printf "\e[0;32m  $OUTPUT_FILENAME\e[0m\n"
    cd "b$BETA" || exit 2
    $HOME/Script/IntegrationTuning/MakeReport.sh > $OUTPUT_FILENAME
    $HOME/Script/IntegrationTuning/MakeReport.sh -t > ${OUTPUT_FILENAME}_time
    mv $OUTPUT_FILENAME ../Reports || exit 2
    mv ${OUTPUT_FILENAME}_time ../Reports || exit 2
    cd .. || exit 2

done
printf "\e[0;36m========================================\e[0m\n\n"
