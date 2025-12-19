#!/bin/bash
#
#  Copyright (c) 2014,2015 Alessandro Sciarra
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


# Just a short script to save as text files the reports
# of the integrator for the beta present in the folder
# from which it is run.

SAVE_ONLY_MP="FALSE"
SAVE_ONLY_ST="FALSE"

function ParseCommandLineOption(){
    while [ "$1" != "" ]; do
        case $1 in
            -h | --help )
                printf "\n\e[0;32m"
                echo "Call the script $0 with the following optional arguments:"
                echo ""
                echo "  -h | --help"
                echo "  -p | --prefixOutput      ->    Prefix for the output file (default=\"Wilson_\")"
		        echo "  -m | --doMP              ->    Make reports of tuning with mass preconditioning (default=FALSE)"
		        echo "  -s | --doStandard        ->    Make reports of tuning without mass preconditioning (default=FALSE)"
                echo ""
                printf "\n\e[0m"
                exit
                shift;;
            -p=* | --prefixOutput=* )  PREFIX=${1#*=}; shift ;;
            -m | --doOnlyMP )  SAVE_ONLY_MP="TRUE"; shift ;;
            -s | --doOnlyStandard )  SAVE_ONLY_ST="TRUE"; shift ;;
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
if [ $SAVE_ONLY_MP = "FALSE" ] && [ $SAVE_ONLY_ST = "FALSE" ]; then
    printf "\n\e[0;31m No report asked to be done (see --help for further info)! Aborting...\n\n\e[0m"
    exit -1
fi
#-----------------------------------------------------------------------------------------------------------------#

mkdir -p Reports || exit 2

printf "\n\e[0;36m========================================\e[0m\n"
for BETA in b[[:digit:]]*; do

    BETA=$(echo $BETA | grep -o "[[:digit:]].[[:digit:]]\{4\}")
    if [[ ! $BETA =~ [[:digit:]].[[:digit:]]{4} ]]; then continue; fi

    OUTPUT_FILENAME="${PREFIX}${PARAMETERS_STRING}_b${BETA}"
    printf "\e[0;32m  $OUTPUT_FILENAME\e[0m\n"
    cd "b$BETA" || exit 2
    if [ $SAVE_ONLY_ST = "TRUE" ]; then
	    if [ $(ls | grep "^[0-9]\{1,2\}_[0-9]\{1,2\}$" | wc -l) -ne 0 ]; then
	        $HOME/Script/IntegrationTuning/MakeReport.sh -s -t > ${OUTPUT_FILENAME}_ST
	        mv ${OUTPUT_FILENAME}_ST ../Reports || exit 2
        fi
    elif [ $SAVE_ONLY_MP = "TRUE" ]; then
	    if [ $(ls | grep ".*kmp.*" | wc -l) -ne 0 ]; then
	        $HOME/Script/IntegrationTuning/MakeReport.sh -f -m > ${OUTPUT_FILENAME}_MP
	        mv ${OUTPUT_FILENAME}_MP ../Reports || exit 2
	    fi
    else
	    $HOME/Script/IntegrationTuning/MakeReport.sh > $OUTPUT_FILENAME
	    $HOME/Script/IntegrationTuning/MakeReport.sh -t > ${OUTPUT_FILENAME}_time
	    mv $OUTPUT_FILENAME ../Reports || exit 2
	    mv ${OUTPUT_FILENAME}_time ../Reports || exit 2
    fi
    cd .. || exit 2

done
printf "\e[0;36m========================================\e[0m\n\n"
