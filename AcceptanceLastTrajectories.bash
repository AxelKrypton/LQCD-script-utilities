#!/bin/bash
#
#  Copyright (c) 2015,2016,2021 Alessandro Sciarra
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


#Script to get quickly the Acceptance of the last trajectories

# Load auxiliary bash files that will be used.
source $HOME/Script/PathManagement.sh || exit -2

BETA=""
NUM_FIRST_TR=()
NUM_LAST_TR=()

# extract options and their arguments into variables.
while [ "$1" != "" ]; do
    case $1 in
      -h | --help )
          printf "\n\e[0;32m"
          echo "Call the script $0 with the following optional arguments:"
          echo "  -h | --help"
          echo "  -b   ->    the beta to be considered (the other parameters are taken from pwd)"
          echo "  -t   ->    how many trajectory from the   end of the run to calculate the acceptance on"
          echo "  -T   ->    how many trajectory from the begin of the run to calculate the acceptance on"
          echo "  -p   ->    global path to the place where the beta folder is"
	      echo ""
          echo "NOTE: Use spaces and not equal signs to give values after the options (-t and -T can accept multiple values)."
          echo "      If the options -t and -T are combined then data ARE CUT at the beginning AND at the end of the history."
          echo "      Hence, the same amount of values has to be specified for both options. The acceptance is calculated on"
          echo "      the data in the middle of the run."
	      echo ""
          echo "HINT: Try to run the script without the -p option. If the script tells you, then use it."
          printf "\n\e[0m"
          exit
          shift ;;
      -b )
          if [[ $2 =~ ^- ]]; then
              printf "\n\e[0;31m No value specified for the -b option! Aborting...\n\n\e[0m"
              exit -1
          else
              BETA=$2
              if [[ ! $BETA =~ ^${BETA_FOLDER_REGEX//\\/}$ ]] && [[ ! $BETA =~ ^${BETA_FOLDER_SHORT_REGEX//\\/}$ ]]; then
                  printf "\n\e[0;31m Wrong format for beta value! Aborting...\n\n\e[0m"
                  exit -1
              fi
          fi
          shift 2 ;;
      -t )
          while [[ $2 =~ ^[[:digit:]]+$ ]]; do
              NUM_LAST_TR+=( $2 )
              shift
          done
          shift ;;
      -T )
          while [[ $2 =~ ^[[:digit:]]+$ ]]; do
              NUM_FIRST_TR+=( $2 )
              shift
          done
          shift ;;
      -p )
          GLOBALPATH_TO_BETAFOLDER_PLACE=$2
          shift 2 ;;
      * ) printf "\n\e[0;31m Option \e[1m$1\e[21m not recognized! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
done

if [ ${#NUM_FIRST_TR[@]} -ne 0 ] && [ ${#NUM_LAST_TR[@]} -ne 0 ] && [ ${#NUM_FIRST_TR[@]} -ne ${#NUM_LAST_TR[@]} ]; then
    printf "\n\e[0;31m Options \e[1m-t\e[21m and \e[1m-T\e[21m given with different amount of values! Aborting...\n\n\e[0m"
    exit -1
fi

ReadParametersFromPath $(pwd)

#Treat in the right way the suffixes
if [[ $BETA =~ ^${BETA_FOLDER_SHORT_REGEX//\\/}$ ]]; then
    if [ "${BETA##*_}" = "NC" ]; then
        BETA="$BETA_PREFIX${BETA%_*}_continueWithNewChain"
    elif [ "${BETA##*_}" = "fC" ]; then
        BETA="$BETA_PREFIX${BETA%_*}_thermalizeFromConf"
    elif [ "${BETA##*_}" = "fH" ]; then
        BETA="$BETA_PREFIX${BETA%_*}_thermalizeFromHot"
    fi
fi

# Build the path with the output file
if [[ $STAGGERED == "TRUE" ]]; then #STAGGERED initialized in PathManagement.sh
    OUTPUT_FILE="rhmc_output"
else
    OUTPUT_FILE="hmc_output"
fi

if [ ! -z ${GLOBALPATH_TO_BETAFOLDER_PLACE:+x} ]; then
    SCRATCH_PATH=$GLOBALPATH_TO_BETAFOLDER_PLACE/$BETA/$OUTPUT_FILE
    if [ ! -f $SCRATCH_PATH ]; then
        printf "\n\e[0;31m Output file should be in $SCRATCH_PATH but it was not found! Aborting...\n\n\e[0m"
        exit -1
    fi
else
    for TRIAL_PATH in ${PWD/\/*\//home} ${PWD/\/*\//data01} ${PWD/\/*\//data02} ${PWD/\/*\//scratch}; do #LOEWE specific
        if [ -f $TRIAL_PATH/$BETA/$OUTPUT_FILE ]; then
            SCRATCH_PATH=$TRIAL_PATH/$BETA/$OUTPUT_FILE
            break
        fi
    done
    if [ -z ${SCRATCH_PATH:+x} ]; then
        SCRATCH_PATH=$PWD/$BETA/$OUTPUT_FILE
        if [ ! -f $SCRATCH_PATH ]; then
            printf "\n\e[38;5;202m Unable to find output file, please use \e[1m-p\e[21m option! Exiting...\n\n\e[0m" ; exit -1
        fi
    fi
fi

#Just do and print acceptances
TOO_LOW_ACCEPTANCE_LISTSTATUS_COLOR="\033[38;5;9m"
LOW_ACCEPTANCE_LISTSTATUS_COLOR="\033[38;5;208m"
OPTIMAL_ACCEPTANCE_LISTSTATUS_COLOR="\033[38;5;10m"
HIGH_ACCEPTANCE_LISTSTATUS_COLOR="\e[38;5;11m"
TOO_HIGH_ACCEPTANCE_LISTSTATUS_COLOR="\033[38;5;202m"
TOO_LOW_ACCEPTANCE_THRESHOLD=68
LOW_ACCEPTANCE_THRESHOLD=70
HIGH_ACCEPTANCE_THRESHOLD=78
TOO_HIGH_ACCEPTANCE_THRESHOLD=90
function GoodAcc(){
    echo "$1" | awk -v tl="${TOO_LOW_ACCEPTANCE_LISTSTATUS_COLOR/\\/\\\\}" \
                    -v l="${LOW_ACCEPTANCE_LISTSTATUS_COLOR/\\/\\\\}" \
                    -v op="${OPTIMAL_ACCEPTANCE_LISTSTATUS_COLOR/\\/\\\\}" \
                    -v h="${HIGH_ACCEPTANCE_LISTSTATUS_COLOR/\\/\\\\}" \
                    -v th="${TOO_HIGH_ACCEPTANCE_LISTSTATUS_COLOR/\\/\\\\}" \
                    -v tlt="$TOO_LOW_ACCEPTANCE_THRESHOLD" \
                    -v lt="$LOW_ACCEPTANCE_THRESHOLD" \
                    -v ht="$HIGH_ACCEPTANCE_THRESHOLD" \
                    -v tht="$TOO_HIGH_ACCEPTANCE_THRESHOLD" '{if($1<tlt){print tl}else if($1<lt){print l}else if($1>tht){print th}else if($1>ht){print h}else{print op}}'
}

function SetLengthToBeUsedInPrinting(){
    LENGTH=0
    if [ ${#NUM_FIRST_TR[@]} -ne 0 ] && [ ${#NUM_LAST_TR[@]} -ne 0 ]; then
        for INDEX in ${!NUM_FIRST_TR[@]}; do
            NUMBER_OF_LINES_IN_CUT_FILE=$(( $(wc -l < $SCRATCH_PATH) - ${NUM_FIRST_TR[$INDEX]} - ${NUM_LAST_TR[$INDEX]} ))
            [ ${#NUMBER_OF_LINES_IN_CUT_FILE} -gt $LENGTH ] && LENGTH=${#NUMBER_OF_LINES_IN_CUT_FILE}
        done
    else
        for TMP in ${NUM_FIRST_TR[@]} ${NUM_LAST_TR[@]}; do
            [ ${#TMP} -gt $LENGTH ] && LENGTH=${#TMP}
        done
    fi
}

IFS='@' #In order to make printf preserve contigous whitespaces
if [ ${#NUM_FIRST_TR[@]} -eq 0 ] && [ ${#NUM_LAST_TR[@]} -eq 0 ]; then
    printf "\n\e[0;36m==================================\e[0m\n"
    for TR in 100 200 300 400 500 600 700 800 900; do
        eval $(tail -n${TR} $SCRATCH_PATH | awk '{sum+=$9} END {print 100*sum/(NR), sum, NR, 100*sum/(NR)}' | xargs printf 'printf "$(GoodAcc %f)  Accepted %%3d over %%3d (%%.2f%%%%) \\e[0m\\n" "%d" "%d" "%f"')
    done
    printf "\e[0;36m==================================\e[0m\n\n"
elif [ ${#NUM_FIRST_TR[@]} -ne 0 ] && [ ${#NUM_LAST_TR[@]} -ne 0 ]; then
    SetLengthToBeUsedInPrinting
    printf -v LINE_OF_EQUAL '%*s' $((34 + 2 * $LENGTH)) ''
    printf "\n\e[0;36m${LINE_OF_EQUAL// /=}\e[0m\n"
    for INDEX in ${!NUM_FIRST_TR[@]}; do
        TR_FOR_HEAD_COMMAND=$(( $(wc -l < $SCRATCH_PATH) - ${NUM_LAST_TR[$INDEX]} )) #Keeping this amount of lines from the beginning wil cut ${NUM_LAST_TR[$INDEX]} from the end
        TR_FOR_TAIL_COMMAND=$(( ${NUM_FIRST_TR[$INDEX]} + 1 )) #Here I use "tail -n+x" to cut from the beginning x-1 lines
        eval $(head -n${TR_FOR_HEAD_COMMAND}  $SCRATCH_PATH | tail -n+${TR_FOR_TAIL_COMMAND} |
                      awk '{sum+=$9} END {print 100*sum/(NR), sum, NR, 100*sum/(NR)}' | xargs printf 'printf "$(GoodAcc %f)  Accepted %%${LENGTH}d over first %%${LENGTH}d (%%.2f%%%%) \\e[0m\\n" "%d" "%d" "%f"')
    done
    printf "\e[0;36m${LINE_OF_EQUAL// /=}\e[0m\n\n"
else
    SetLengthToBeUsedInPrinting
    printf -v LINE_OF_EQUAL '%*s' $((34 + 2 * $LENGTH)) ''
    printf "\n\e[0;36m${LINE_OF_EQUAL// /=}\e[0m\n"
    for TR in ${NUM_FIRST_TR[@]}; do
        eval $(head -n${TR} $SCRATCH_PATH | awk '{sum+=$9} END {print 100*sum/(NR), sum, NR, 100*sum/(NR)}' | xargs printf 'printf "$(GoodAcc %f)  Accepted %%${LENGTH}d over first %%${LENGTH}d (%%.2f%%%%) \\e[0m\\n" "%d" "%d" "%f"')
    done
    for TR in ${NUM_LAST_TR[@]}; do
        eval $(tail -n${TR} $SCRATCH_PATH | awk '{sum+=$9} END {print 100*sum/(NR), sum, NR, 100*sum/(NR)}' | xargs printf 'printf "$(GoodAcc %f)  Accepted %%${LENGTH}d over  last %%${LENGTH}d (%%.2f%%%%) \\e[0m\\n" "%d" "%d" "%f"')
    done
    printf "\e[0;36m${LINE_OF_EQUAL// /=}\e[0m\n\n"
fi

