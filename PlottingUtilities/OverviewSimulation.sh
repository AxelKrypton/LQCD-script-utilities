#!/bin/bash

# This script is intended to plot an overview of the simulations
# specified by the command line options.

#-----------------------------------------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source "$HOME/Script/PathManagement.sh" || exit -2
source "$HOME/Script/UtilityFunctions.sh" || exit -2
#-----------------------------------------------------------------------------------------------------------------#

#-----------------------------------------------------------------------------------------------------------------#
# Auxiliary functions
function SumGivenIntegers(){
    local SUM=0
    for ELEM in $@; do
        SUM=$(( $SUM + $ELEM ))
    done
    unset -v 'ELEM'
    echo $SUM
}

function MakeGnuplotHistogram() {
    rm -f $GNUPLOT_TEMP_SCRIPT
    #Switch between mass and beta overview setting the same quantities to the correct value
    ARRAY_FOR_HISTOGRAM_POSITIONING=()
    if [ $MASS_OVERVIEW = 'TRUE' ]; then
        if [ $MASS_PREFIX = 'mass' ]; then
            local XAXIS_BOTTOM_LABEL='m'
        elif [ $MASS_PREFIX = 'k' ]; then
            local XAXIS_BOTTOM_LABEL='\\kappa'
        fi
        #The following is to order data that in an associative array are in general not!
        for INDEX in $(printf "%s\n" ${!NUMBER_OF_VOLUMES[@]} | sort -n | xargs -n1 printf "%s "); do
            ARRAY_FOR_HISTOGRAM_POSITIONING+=( ${NUMBER_OF_VOLUMES["$INDEX"]} )
        done
        local ARRAY_XAXIS_BOTTOM=( "${MASSES[@]}" )
        #Add 0. in front of masses values for labels in plot
        for INDEX in ${!ARRAY_XAXIS_BOTTOM[@]}; do
            ARRAY_XAXIS_BOTTOM[$INDEX]="0.${ARRAY_XAXIS_BOTTOM[$INDEX]}"
        done
        local XAXIS_UPPERLEFT_LABEL='N_{\\sigma}'
        local ROTATE='FALSE'
        local XAXIS_UPPERLEFT_LABEL_POSITION_UP="0.03"
        local XAXIS_UPPERLEFT_LABEL_POSITION_DOWN="0.039"
        local FACTOR_TO_DIVIDE_FOR_COLOR=$NTIME
    elif [ $BETA_OVERVIEW = 'TRUE' ]; then
        local XAXIS_BOTTOM_LABEL='\\beta'
        #The following is to order data that in an associative array are in general not!
        for INDEX in $(printf "%s\n" ${!NUMBER_OF_CHAINS[@]} | sort -n | xargs -n1 printf "%s "); do
            ARRAY_FOR_HISTOGRAM_POSITIONING["$INDEX"]=${NUMBER_OF_CHAINS["$INDEX"]}
        done
        local ARRAY_XAXIS_BOTTOM=( "${BETAS[@]}" )
        local XAXIS_UPPERLEFT_LABEL="seed"
        local ROTATE='TRUE'
        local XAXIS_UPPERLEFT_LABEL_POSITION_UP="0.00"
        local XAXIS_UPPERLEFT_LABEL_POSITION_DOWN="0.03"
        local FACTOR_TO_DIVIDE_FOR_COLOR="1000"
    fi

    #Before preparing the plot calculate some information
    local HISTOGRAM_SHIFTS=([0]=0)
    local HISTOGRAM_XLABEL=()
    for((INDEX=1; INDEX<${#ARRAY_FOR_HISTOGRAM_POSITIONING[@]}; INDEX++)); do
        HISTOGRAM_SHIFTS[$INDEX]=$(( $(SumGivenIntegers ${ARRAY_FOR_HISTOGRAM_POSITIONING[@]:0:$INDEX}) + $INDEX ))
    done
    for INDEX in ${!ARRAY_XAXIS_BOTTOM[@]}; do
        HISTOGRAM_XLABEL[$INDEX]="$( bc -l <<< "${HISTOGRAM_SHIFTS[$INDEX]} + (${ARRAY_FOR_HISTOGRAM_POSITIONING[$INDEX]}-1)/2" )"
    done
    local MAXIMUM_YVALUE=$(awk 'BEGIN{max=0}$3>max{max=$3}END{print max}' $TEMPORARY_DATA_FILE)

    #Set up the gnuplot script
    echo 'stats "'$TEMPORARY_DATA_FILE'" using 3 name "A" nooutput' >> $GNUPLOT_TEMP_SCRIPT
    echo 'set yrange [0:1.05*A_max]' >> $GNUPLOT_TEMP_SCRIPT
    if [ $ROTATE = 'TRUE' ]; then
        echo 'set xtics rotate by -45 offset -0.5,0.5' >> $GNUPLOT_TEMP_SCRIPT
    else
        echo 'set xtics offset 0,0.5' >> $GNUPLOT_TEMP_SCRIPT
    fi
    echo '' >> $GNUPLOT_TEMP_SCRIPT
    echo 'set style data histogram' >> $GNUPLOT_TEMP_SCRIPT
    echo 'set style fill solid 0.25 border -1' >> $GNUPLOT_TEMP_SCRIPT
    echo 'set boxwidth 0.95 relative' >> $GNUPLOT_TEMP_SCRIPT
    echo 'set xtic scale 0' >> $GNUPLOT_TEMP_SCRIPT
    echo 'set format y "%.2s%c"' >> $GNUPLOT_TEMP_SCRIPT
    echo "set ytics add ('' 0)" >> $GNUPLOT_TEMP_SCRIPT
    echo 'set xrange [-1:A_records+A_blocks-1]' >> $GNUPLOT_TEMP_SCRIPT
    echo '' >> $GNUPLOT_TEMP_SCRIPT
    echo "shifts = \"${HISTOGRAM_SHIFTS[@]}\"" >> $GNUPLOT_TEMP_SCRIPT
    for INDEX in ${!ARRAY_XAXIS_BOTTOM[@]}; do
        if [ "$1" = 'TRUE' ]; then
            echo "set label \"\\\\footnotesize\$${ARRAY_XAXIS_BOTTOM[$INDEX]}\$\" at ${HISTOGRAM_XLABEL[$INDEX]},screen 0.005 center" >> $GNUPLOT_TEMP_SCRIPT
        else
            echo "set label \"${ARRAY_XAXIS_BOTTOM[$INDEX]}\" at ${HISTOGRAM_XLABEL[$INDEX]},screen 0.01 center" >> $GNUPLOT_TEMP_SCRIPT
        fi
    done
    echo '' >> $GNUPLOT_TEMP_SCRIPT
    if [ "$1" = 'TRUE' ]; then
        echo 'set terminal lua tikz standalone solid preamble '"'"'\usepackage{amsmath, mathabx}'"'" >> $GNUPLOT_TEMP_SCRIPT
        echo "set output \"${OUTPUT_PLOT_FILENAME}.tex\"" >> $GNUPLOT_TEMP_SCRIPT
        echo 'set label "\\scriptsize{$'$XAXIS_UPPERLEFT_LABEL'\\to$}" at screen '$XAXIS_UPPERLEFT_LABEL_POSITION_UP', screen 0.053 left' >> $GNUPLOT_TEMP_SCRIPT
        echo 'set label "\\scriptsize{$'$XAXIS_BOTTOM_LABEL'\\to$}" at screen '$XAXIS_UPPERLEFT_LABEL_POSITION_DOWN', screen 0.01 left' >> $GNUPLOT_TEMP_SCRIPT
        echo 'plot for [i=1:A_blocks] "'$TEMPORARY_DATA_FILE'" index i-1 using ($0+word(shifts,i)):3:($2/'$FACTOR_TO_DIVIDE_FOR_COLOR'):xticlabels("\\scriptsize{$".stringcolumn(2)."$}") with boxes title "" linecolor variable, \' >> $GNUPLOT_TEMP_SCRIPT
        echo '     for [i=1:A_blocks] "'$TEMPORARY_DATA_FILE'" index i-1 using ($0+word(shifts,i)):3:4 with labels center offset 0,-1 notitle' >> $GNUPLOT_TEMP_SCRIPT
    fi
    if [ "$1" = 'FALSE' ]; then
        echo 'plot for [i=1:A_blocks] "'$TEMPORARY_DATA_FILE'" index i-1 using ($0+word(shifts,i)):3:($2/'$FACTOR_TO_DIVIDE_FOR_COLOR'):xticlabels(2) with boxes title "" linecolor variable, \' >> $GNUPLOT_TEMP_SCRIPT
        echo "                        ''" 'using ($0+word(shifts,i)):3:4 with labels center offset 0,-1 notitle' >> $GNUPLOT_TEMP_SCRIPT
        echo '' >> $GNUPLOT_TEMP_SCRIPT
        echo 'pause -1 ' >> $GNUPLOT_TEMP_SCRIPT
        echo 'q' >> $GNUPLOT_TEMP_SCRIPT
    fi
    unset -v 'INDEX'
}

function ProducePlotAndRemoveAuxiliaryFiles(){
    MakeGnuplotHistogram $SAVE_PLOT
    gnuplot $GNUPLOT_TEMP_SCRIPT
    rm $GNUPLOT_TEMP_SCRIPT
    rm $TEMPORARY_DATA_FILE
    if [ $SAVE_PLOT = 'TRUE' ]; then
        pdflatex ${OUTPUT_PLOT_FILENAME}.tex 1>> /dev/null
        rm ${OUTPUT_PLOT_FILENAME}.tex
        rm ${OUTPUT_PLOT_FILENAME}.log
        rm ${OUTPUT_PLOT_FILENAME}.aux
        evince ${OUTPUT_PLOT_FILENAME}.pdf &
    fi
}

#-----------------------------------------------------------------------------------------------------------------#
#Having loaded PathManagement.sh we get for free all the parameters variables and functionalities
CheckWilsonStaggeredVariables
if [ $STAGGERED = 'TRUE' ]; then
    DATAFILE_NAME="rhmc_output"
elif [ $WILSON = 'TRUE' ]; then
    DATAFILE_NAME="hmc_output"
fi

MASS_OVERVIEW='FALSE'
BETA_OVERVIEW='FALSE'
GNUPLOT_TEMP_SCRIPT="GnuplotTemporaryScript.plt"
TEMPORARY_DATA_FILE="TemporaryDataFileForHistogram.dat"
NTIME=6
SAVE_PLOT='FALSE'
OUTPUT_PLOT_FILENAME=""

# extract options and their arguments into variables.
while [ "$1" != "" ]; do
    case $1 in
        -h | --help )
	        printf "\n\e[0;34m"
            echo "   The script can be used to get an overview of certain simulations"
            echo "   in terms of accumulated statistics. There are 2 mutually exclusive"
            echo "   possibilities:"
            echo ""
            echo "     1) get an overview of total statistics per volume;"
            echo "     2) get an overview of total statistics per beta."
            echo ""
            echo "   In the first case this script has to be invoqued from where the mass"
            echo "   folders are, while in the second from where the beta folders are."
            echo ""
	        printf "\n \e[1m\e[4m\e[38;5;48m"
	        echo "Call the script $0 with the following optional arguments:"
	        printf "\n\e[0;32m"
	        echo "   -k | -m | --masses      ->    mass values to be used (use the number in the folder names)"
	        echo "   -b | --betas            ->    beta values to be used"
            echo "   -s | --save             ->    save the output plot"
	        echo "   -o | --outputFilename   ->    default value = OverviewSimulationsPer(Masses|Betas) (provide it without extension!)"
	        echo "   --nt                    ->    nt value to be used (default ${NTIME})"
	        printf "\n\e[0m"
	        exit
	        shift;;
        -k | -m | --masses )
            MASSES=()
            if [ $BETA_OVERVIEW = 'TRUE' ]; then
                printf "\n\e[0;31mOption \"-b | --betas\" and \"-k | --masses\" are mutually exclusive! Aborting...\n\n\e[0m" ; exit -1
            fi
            MASS_OVERVIEW='TRUE'
            while [[ $2 =~ ^[[:digit:]]{4}$ ]]; do
                MASSES+=( "$2" )
                shift
            done
            shift ;;
        -b | --betas )
            BETAS=()
            if [ $MASS_OVERVIEW = 'TRUE' ]; then
                printf "\n\e[0;31mOption \"-b | --betas\" and \"-k | --masses\" are mutually exclusive! Aborting...\n\n\e[0m" ; exit -1
            fi
            BETA_OVERVIEW='TRUE'
            while [[ $2 =~ ^[[:digit:]]{1}[.]?[[:digit:]]*$ ]]; do
                BETAS+=( "$(printf "%1.4f" "$2")" )
                shift
            done
            shift ;;
        --nt )
            if [[ $2 =~ ^[[:digit:]]+$ ]]; then
                NTIME=$2
            else
                printf "\n\e[0;31mValue for --nt option invalid! Aborting...\n\n\e[0m" ; exit -1
            fi
            CheckParametersExtractedFromPath $NTIME_PREFIX
            shift 2 ;;
        -s | --save )
            SAVE_PLOT='TRUE'
            shift ;;
        -o | --outputFilename )
            OUTPUT_FILENAME=$2
            shift 2 ;;
        * ) printf "\n\e[0;31mOption \"$1\" invalid! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
done

if [ "$OUTPUT_FILENAME" = "" ]; then
    [ $MASS_OVERVIEW = 'TRUE' ] && OUTPUT_PLOT_FILENAME="OverviewSimulationsPerMasses"
    [ $BETA_OVERVIEW = 'TRUE' ] && OUTPUT_PLOT_FILENAME="OverviewSimulationsPerBetas"
else
    OUTPUT_PLOT_FILENAME=$OUTPUT_FILENAME
fi

if [ $MASS_OVERVIEW = 'TRUE' ]; then
    declare -A NUMBER_OF_VOLUMES
    rm -f $TEMPORARY_DATA_FILE
    #If masses were not given, then collect all
    if [ ${#MASSES[@]} -eq 0 ]; then
        MASSES=( $(ls -d ${MASS_PREFIX}*/ | grep -o "$MASS_REGEX") )
        if [ ${#MASSES[@]} -eq 0 ]; then
            printf "\n\e[0;31m No mass folder found! Aborting...\n\n\e[0m"
            exit -1
        fi
    fi
    #Go through masses and volumes and collect total statistics per volume from merged chains
    for VALUE in ${MASSES[@]}; do
        if [ ! -d ${MASS_PREFIX}${VALUE} ]; then
            printf "\n\e[0;31mFolder \"${MASS_PREFIX}${VALUE}\" not found, skipping it!\n\e[0m"
            continue
        fi
        NUMBER_OF_VOLUMES["$VALUE"]=0
        for VOLUME in $(ls -d ${MASS_PREFIX}${VALUE}/${NTIME_PREFIX}${NTIME}/${NSPACE_PREFIX}*/); do
            EXTRACTED_NSPACE=${VOLUME%?}
            EXTRACTED_NSPACE=${EXTRACTED_NSPACE##*/ns}
            [ $(ls -d ${VOLUME}/b?.????*Chain/ 2>/dev/null | wc -l) -eq 0 ] && continue
            LIST_BETA_WITH_CHAINS=( $(ls -d ${VOLUME}/b?.????*Chain/ | grep -Eo "b.[.]...." | sort -u | awk -v vol="${VOLUME}" -v file="$DATAFILE_NAME" '{print vol""$1"/"file}') )
            printf "$VALUE\t$EXTRACTED_NSPACE\t$(wc -l ${LIST_BETA_WITH_CHAINS[@]} | awk 'END{print $1}')\t${#LIST_BETA_WITH_CHAINS[@]}\n" >> $TEMPORARY_DATA_FILE
            (( NUMBER_OF_VOLUMES["$VALUE"]++ ))
        done
        printf "\n\n" >> $TEMPORARY_DATA_FILE
    done
    #If no data collected exit
    if [ ! -s $TEMPORARY_DATA_FILE ]; then
        printf "\n\e[0;31m No data were collected! Aborting...\n\n\e[0m"
        exit -1
    fi
    #Remove last two empty lines of data file
    { rm $TEMPORARY_DATA_FILE && head -n -2 > $TEMPORARY_DATA_FILE; } < $TEMPORARY_DATA_FILE
    #Finally plot
    ProducePlotAndRemoveAuxiliaryFiles
    exit
fi

if [ $BETA_OVERVIEW = 'TRUE' ]; then
    declare -A NUMBER_OF_CHAINS
    rm -f $TEMPORARY_DATA_FILE
    #If betas were not given, then collect all
    if [ ${#BETAS[@]} -eq 0 ]; then
        BETAS=( $(ls -d b?.????_s????_continueWithNewChain/ | grep -o "$BETA_REGEX" | sort -u) )
        if [ ${#BETAS[@]} -eq 0 ]; then
            printf "\n\e[0;31m No betas folder with new chains found! Aborting...\n\n\e[0m"
            exit -1
        fi
    fi
    #Go through betas and chains and collect statistics per chain
    for VALUE in ${BETAS[@]}; do
        if [ $(ls -1 -d b${VALUE}_s????_continueWithNewChain/ | wc -l) -eq 0 ]; then
            printf "\n\e[0;31mFolder(s) for beta=${VALUE} not found, skipping it!\n\e[0m"
            continue
        fi
        NUMBER_OF_CHAINS["$VALUE"]=0
        for CHAIN in $(ls -d b${VALUE}_s????_continueWithNewChain/); do
            SEED=${CHAIN%%_continue*}
            SEED=${SEED##*_s}
            printf "$VALUE\t$SEED\t$(wc -l < b${VALUE}_s${SEED}_continueWithNewChain/$DATAFILE_NAME)\n" >> $TEMPORARY_DATA_FILE
            (( NUMBER_OF_CHAINS["$VALUE"]++ ))
        done
        printf "\n\n" >> $TEMPORARY_DATA_FILE
    done
    #If no data collected exit
    if [ ! -s $TEMPORARY_DATA_FILE ]; then
        printf "\n\e[0;31m No data were collected! Aborting...\n\n\e[0m"
        exit -1
    fi
    #Remove last two empty lines of data file
    { rm $TEMPORARY_DATA_FILE && head -n -2 > $TEMPORARY_DATA_FILE; } < $TEMPORARY_DATA_FILE
    #Finally plot
    ProducePlotAndRemoveAuxiliaryFiles
    exit
fi
