#!/bin/bash
#
#  Copyright (c) 2016 Alessandro Sciarra
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


#-----------------------------------------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source $HOME/Script/UtilityFunctions.sh || exit -2
source $HOME/Script/CollapsePlot/BashQuantitativeCollapse/ParseCommandLineOptions.sh || exit -2
source $HOME/Script/CollapsePlot/BashQuantitativeCollapse/RescaleData.sh || exit -2
source $HOME/Script/CollapsePlot/BashQuantitativeCollapse/PrepareIntegrationData.sh || exit -2
source $HOME/Script/CollapsePlot/BashQuantitativeCollapse/NumericIntegration.sh || exit -2
source $HOME/Script/CollapsePlot/BashQuantitativeCollapse/AuxiliaryPlots.sh || exit -2
#-----------------------------------------------------------------------------------------------------------------#

function DeleteAuxiliaryFiles(){
    for FILE in ${DATA_FILENAMES[@]}; do
        rm ${FILE}_betaC*_nu*${SUFFIX_RESCALED_DATA}
        rm ${FILE}_betaC*_nu*${SUFFIX_RESCALED_DATA}${SUFFIX_DATA_ON_GRID}
    done
    rm ${FILENAME_DATA_FOR_INTEGRATION}_betaC*_nu*_ns*_ns*
}

#Trap CTRL-C in order to delete aux files
trap ctrl_c INT
function ctrl_c(){
    if [ $DELETE_INTERMEDIATE_FILES = 'TRUE' ]; then
        DeleteAuxiliaryFiles
        exit -3
    fi
}

function CheckErrorCodeOfPreparationOfFileForIntegration(){
    local ERROR_CODE=$1
    if [ $ERROR_CODE -ne 0 ]; then
        if [ $ERROR_CODE -eq 2 ]; then
            printf "#Unable to calculate collapse at desired precision due to too low resolution in x of data!\n"
            return 1
        else
            [ $DELETE_INTERMEDIATE_FILES = 'TRUE' ] && DeleteAuxiliaryFiles
            exit -1
        fi
    fi
    return 0
}
#-----------------------------------------------------------------------------------------------------------------#

DATA_FILENAMES=()
VOLUMES=()
X_COLUMN=1
declare -A X_MIN
declare -A X_MAX
Y_COLUMN=8
BETA_C=()
NU=()
COLLAPSE_THRESHOLD='5'
COLLAPSE_RESOLUTION='0.5'
FACTOR_TO_INCREASE_COLLAPSE_RESOLUTION='0.8'
SUFFIX_RESCALED_DATA='_rescaledForCollapse'
SUFFIX_DATA_ON_GRID='_filteredOnGrid'
SUFFIX_SQUARE_DIFFERENCE='_squareDifference'
FILENAME_DATA_FOR_INTEGRATION='FileReadyForIntegration.dat'
DELETE_INTERMEDIATE_FILES='TRUE'
MAKE_PLOT='TRUE'
USE_FIXED_RESOLUTION='FALSE'
JUST_DELETE_AUX_FILES='FALSE'

#Extract options and their arguments into variables, checking for proper input. Allocate further needed variables
ParseCommandLineOptionsAndChecksGivenInformation "$@"
if [ $JUST_DELETE_AUX_FILES = 'TRUE' ]; then
    DeleteAuxiliaryFiles
fi
INITIAL_COLLAPSE_RESOLUTION=$COLLAPSE_RESOLUTION
BETA_C_NU_STRING="_betaC${BETA_C[0]}_nu${NU[0]}"

#Header of output
printf "%-19s %5s %-8s %5s %-6s %5s %-17s %5s %-60s\n" "#Volumes" "" "Beta_C" "" "nu" "" "WorseCollapse" "" "CollapseQualities"
for BETA_LOOP in ${BETA_C[@]}; do
    for NU_LOOP in ${NU[@]}; do
        SUFFIX_RESCALED_DATA_LOOP="_betaC${BETA_LOOP}_nu${NU_LOOP}${SUFFIX_RESCALED_DATA}"
        #Rescale data
        for INDEX in ${!DATA_FILENAMES[@]}; do
            RescaleDataForGivenFile ${DATA_FILENAMES[$INDEX]} ${BETA_LOOP} ${NU_LOOP} ${VOLUMES[$INDEX]} ${DATA_FILENAMES[$INDEX]}${SUFFIX_RESCALED_DATA_LOOP}
        done
        #Prepare data and perform analytic collapse (perform numerical integration and estimate error)
        printf "%-19s %5s %.6f %5s %.4f %5s " "$(printf "ns%d_" ${VOLUMES[@]} | head --bytes -1)" "" "$BETA_LOOP" "" "$NU_LOOP"
        COLLAPSE_VALUES_AS_ARRAY=()
        COLLAPSE_ERRORS_AS_ARRAY=()
        COLLAPSE_RESULTS_AS_STRING=''
        for((INDEX_I=0; INDEX_I<${#DATA_FILENAMES[@]}; INDEX_I++)); do
            for((INDEX_II=$(($INDEX_I+1)); INDEX_II<${#DATA_FILENAMES[@]}; INDEX_II++)); do
                COLLAPSE_RESOLUTION=$INITIAL_COLLAPSE_RESOLUTION
                TMP_FILENAME=${FILENAME_DATA_FOR_INTEGRATION}_betaC${BETA_LOOP}_nu${NU_LOOP}_ns${VOLUMES[$INDEX_I]}_ns${VOLUMES[$INDEX_II]}
                PrepareIntegrationDataGivenPairOfFiles ${DATA_FILENAMES[$INDEX_I]}${SUFFIX_RESCALED_DATA_LOOP}  ${DATA_FILENAMES[$INDEX_II]}${SUFFIX_RESCALED_DATA_LOOP}  $COLLAPSE_RESOLUTION  $TMP_FILENAME
                CheckErrorCodeOfPreparationOfFileForIntegration $? || continue 3
                SQRT_INTEGRAL_F_MINUS_G_SQUARED=( $(CalculateDistanceBetweenFunctionsNormalizedWithIntervalExtent $TMP_FILENAME 1 2 4) )
                while [ $USE_FIXED_RESOLUTION = 'FALSE' ]; do
                    PREVIOUS_INTEGRAL_RESULT=( ${SQRT_INTEGRAL_F_MINUS_G_SQUARED[@]} )
                    COLLAPSE_RESOLUTION=$(awk '{print $1*$2}' <<< "$COLLAPSE_RESOLUTION $FACTOR_TO_INCREASE_COLLAPSE_RESOLUTION")
                    PrepareIntegrationDataGivenPairOfFiles ${DATA_FILENAMES[$INDEX_I]}${SUFFIX_RESCALED_DATA_LOOP}  ${DATA_FILENAMES[$INDEX_II]}${SUFFIX_RESCALED_DATA_LOOP}  $COLLAPSE_RESOLUTION  $TMP_FILENAME
                    CheckErrorCodeOfPreparationOfFileForIntegration $? || continue 4
                    [ $? -ne 0 ] && [ $DELETE_INTERMEDIATE_FILES = 'TRUE' ] && DeleteAuxiliaryFiles && exit -1
                    SQRT_INTEGRAL_F_MINUS_G_SQUARED=( $(CalculateDistanceBetweenFunctionsNormalizedWithIntervalExtent $TMP_FILENAME 1 2 4) )
                    if [ $(awk '{print (($1<1.e-16) || ($2<1.e-16))}' <<< "${PREVIOUS_INTEGRAL_RESULT[0]} ${SQRT_INTEGRAL_F_MINUS_G_SQUARED[0]}") -eq 1 ]; then
                        continue
                    fi
                    if [ $(awk '{print (sqrt(($1-$2)^2)/$1*100<$3 && sqrt(($1-$2)^2)/$2*100<$3)}' <<< "${PREVIOUS_INTEGRAL_RESULT[0]} ${SQRT_INTEGRAL_F_MINUS_G_SQUARED[0]} $COLLAPSE_THRESHOLD") -eq 1 ]; then
                        break
                    fi
                done
                COLLAPSE_VALUES_AS_ARRAY+=( ${SQRT_INTEGRAL_F_MINUS_G_SQUARED[0]} )
                COLLAPSE_ERRORS_AS_ARRAY+=( ${SQRT_INTEGRAL_F_MINUS_G_SQUARED[1]} )
                COLLAPSE_RESULTS_AS_STRING=${COLLAPSE_RESULTS_AS_STRING}$(printf "%.6f %.6f   " "${SQRT_INTEGRAL_F_MINUS_G_SQUARED[0]}" "${SQRT_INTEGRAL_F_MINUS_G_SQUARED[1]}")
            done
        done
        INDEX_OF_WORSE_COLLAPSE=$(KeyOfMaximumOfArray ${COLLAPSE_VALUES_AS_ARRAY[@]})
        printf "%.6f %.6f %5s %s\n" "${COLLAPSE_VALUES_AS_ARRAY[$INDEX_OF_WORSE_COLLAPSE]}" "${COLLAPSE_ERRORS_AS_ARRAY[$INDEX_OF_WORSE_COLLAPSE]}" "" "$COLLAPSE_RESULTS_AS_STRING"
    done
done
#Plot if required
if [ $MAKE_PLOT = 'TRUE' ]; then
    PlotRescaledDataAndDifferences
fi

#Delete intermidiate files if required
if [ $DELETE_INTERMEDIATE_FILES = 'TRUE' ]; then
    DeleteAuxiliaryFiles
fi
