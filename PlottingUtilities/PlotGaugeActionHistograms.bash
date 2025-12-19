#!/bin/bash
#
#  Copyright (c) 2016 Alessandro Sciarra
#  Copyright (c) 2016 Christopher Czaban
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



add_plot() {
    local INPUT_FILE=${INPUT_FILES_ARRAY[$INDEX]}
    local BETA=$(echo $INPUT_FILE | grep -o "[[:digit:]]\.[[:digit:]]\{4\}")
    echo "stats \"$DIR_WITH_INPUT_FILES/$INPUT_FILE\" using $COLUMN_X_AXIS name \"beta$INDEX\" nooutput" >> $GNUPLOT_TEMP_SCRIPT
    if [ $INDEX -eq 0 ]; then
        echo "plot \"$DIR_WITH_INPUT_FILES/$INPUT_FILE\" u ($BIN_FUNCTION(\$$COLUMN_X_AXIS,$BOXWIDTH)):(1./($BOXWIDTH*beta${INDEX}_records)) smooth frequency with boxes title gprintf(\"$BETA ---> Mean = % 6.5f \", beta${INDEX}_mean)" >> $GNUPLOT_TEMP_SCRIPT
    else
        echo "replot \"$DIR_WITH_INPUT_FILES/$INPUT_FILE\" u ($BIN_FUNCTION(\$$COLUMN_X_AXIS,$BOXWIDTH)):(1./($BOXWIDTH*beta${INDEX}_records)) smooth frequency with boxes title gprintf(\"$BETA ---> Mean = % 6.5f \", beta${INDEX}_mean)" >> $GNUPLOT_TEMP_SCRIPT
    fi
}

#Source PathManagement in order to have functionalities
source ${HOME}/Script/PathManagement.sh || exit -2

ReadParametersFromPath $(pwd) #To set PARAMETERS_STRING

BETA_ARRAY=()
DIR_WITH_INPUT_FILES="${PARAMETERS_STRING}_reweighting"
if [ ! -d "$DIR_WITH_INPUT_FILES" ]; then
    echo "Directory \"${DIR_WITH_INPUT_FILES}\" not found! ...exiting"
    exit -1
fi

COLUMN_X_AXIS="1"
BOXWIDTH="10"
GNUPLOT_TEMP_SCRIPT="temporaryScriptForGnuplotThatHopefullyDoesNotExist.plt"
rm -f $GNUPLOT_TEMP_SCRIPT
BIN_FUNCTION="bin"

while [ "$#" -gt 0 ]; do
    case $1 in
        -b)
            while [[ "$2" =~ ^[[:digit:]]\.[[:digit:]]{4}$ ]]
            do
                BETA_ARRAY+=( $2 )
                shift
            done
            ;;
        -w)
            BOXWIDTH=$2
            shift
            ;;
        -c)
            BIN_FUNCTION="binc"
            ;;
        -h)
            printf '\n\e[32m'
            echo " Possible options:"
            echo "   -b (Specify beta value, e.g. -b x.xxxx y.yyyy. If -b is not given the script will take alle available files."
            echo "   -w (Specifiy boxwidth for the histograms, default is 10.)"
            echo "   -c (Provide if the bins should be centered.)"
            printf '\n\e[0m'
            exit
            ;;
        -*)
            echo $0: $1: unrecognized option...exiting. >&2
            exit
            ;;
        *)
            echo $0: $1: unrecognized option...exiting. >&2
            exit
            ;;
    esac
    shift
done

[[ ! $BOXWIDTH =~ ^[[:digit:]]+$ ]] && echo "Specified boxwidth invalid - setting it to 10" && BOXWIDTH=10

echo "$BIN_FUNCTION(x,s) = s*int(x/s)" >> $GNUPLOT_TEMP_SCRIPT
echo "set boxwidth $BOXWIDTH" >> $GNUPLOT_TEMP_SCRIPT
echo "set title \"Histogram(s) of the gauge action\"" >> $GNUPLOT_TEMP_SCRIPT
echo "set xlabel \"gauge action\"" >> $GNUPLOT_TEMP_SCRIPT
echo "set ylabel \"\#\"" >> $GNUPLOT_TEMP_SCRIPT

if [ ${#BETA_ARRAY[@]} -eq 0 ]; then
    INPUT_FILES_ARRAY=( $(ls $DIR_WITH_INPUT_FILES | grep "rawDataForReweighting_b[[:digit:]]\.[[:digit:]]\{4\}") )
else
    for BETA in ${BETA_ARRAY[@]}; do
        if [ -f "$DIR_WITH_INPUT_FILES/rawDataForReweighting_b$BETA" ]; then
            INPUT_FILES_ARRAY+=( "rawDataForReweighting_b$BETA" )
        fi
    done
fi

if [ ${#INPUT_FILES_ARRAY[@]} -eq 0 ]; then
    echo "No input files found...exiting"
    rm $GNUPLOT_TEMP_SCRIPT
    exit
fi
for INDEX in ${!INPUT_FILES_ARRAY[@]}; do
    add_plot
done

echo "pause -1 \"Press enter to quit (all plots will be closed)\"" >> $GNUPLOT_TEMP_SCRIPT
echo "q" >> $GNUPLOT_TEMP_SCRIPT
gnuplot $GNUPLOT_TEMP_SCRIPT
echo
rm $GNUPLOT_TEMP_SCRIPT
