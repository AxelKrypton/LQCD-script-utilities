#!/bin/bash

# This script is intended to plot an overview of the simulations
# specified by the command line options.

#-----------------------------------------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source $HOME/Script/UtilityFunctions.sh || exit -2
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
    declare -A ARRAY_FOR_HISTOGRAM_POSITIONING
    if [ $MASS_OVERVIEW = 'TRUE' ]; then
        if [ $MASS_PREFIX = 'mass' ]; then
            local XAXIS_BOTTOM_LABEL='m'
        elif [ $MASS_PREFIX = 'k' ]; then
            local XAXIS_BOTTOM_LABEL='\\kappa'
        fi
        for INDEX in "${!NUMBER_OF_VOLUMES[@]}"; do
            ARRAY_FOR_HISTOGRAM_POSITIONING["$INDEX"]=${NUMBER_OF_VOLUMES["$INDEX"]}
        done
        local ARRAY_XAXIS_BOTTOM=( "${MASSES[@]}" )
        #Add 0. in front of masses values for labels in plot
        for INDEX in ${!ARRAY_XAXIS_BOTTOM[@]}; do
            #ARRAY_FOR_HISTOGRAM_POSITIONING[$INDEX]="0.${ARRAY_FOR_HISTOGRAM_POSITIONING[$INDEX]}"
            ARRAY_XAXIS_BOTTOM[$INDEX]="0.${ARRAY_XAXIS_BOTTOM[$INDEX]}"
        done
        local XAXIS_UPPERLEFT_LABEL="N_s"
        local ROTATE='FALSE'
        local XAXIS_UPPERLEFT_LABEL_POSITION_UP="0.03"
        local XAXIS_UPPERLEFT_LABEL_POSITION_DOWN="0.039"
        local FACTOR_TO_DIVIDE_FOR_COLOR=$NTIME
    elif [ $BETA_OVERVIEW = 'TRUE' ]; then
        local XAXIS_BOTTOM_LABEL='\\beta'
        for INDEX in "${!NUMBER_OF_CHAINS[@]}"; do
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
    for((INDEX=1; INDEX<=${#ARRAY_FOR_HISTOGRAM_POSITIONING[@]}; INDEX++)); do
        HISTOGRAM_SHIFTS[$INDEX]=$(( $(SumGivenIntegers ${ARRAY_FOR_HISTOGRAM_POSITIONING[@]:0:$INDEX}) + $INDEX ))
    done
    unset HISTOGRAM_SHIFTS[${#HISTOGRAM_SHIFTS[@]}-1]
    for INDEX in ${!ARRAY_XAXIS_BOTTOM[@]}; do
        # Here I do a loop over integers because I want to initialize HISTOGRAM_XLABEL but then I have to deal with the associative array 
        # ARRAY_FOR_HISTOGRAM_POSITIONING whose indeces have no initial 0. while ARRAY_XAXIS_BOTTOM now contains the mass as decimal number
        # Hence, I use the ${var##0.} expansion that strips the 0. for the masses and leaves the seeds as they are (because the seeds do not contain 0.)
        HISTOGRAM_XLABEL[$INDEX]="$( bc -l <<< "${HISTOGRAM_SHIFTS[$INDEX]} + (${ARRAY_FOR_HISTOGRAM_POSITIONING[${ARRAY_XAXIS_BOTTOM[$INDEX]##0.}]}-1)/2" )"
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
    #Depending on the maximum put tics on y axis (REMARK: make them 5chars long to avoid bad overlay in bottom left corner)
    if [ $MAXIMUM_YVALUE -lt 10000 ]; then
        echo 'set ytic ("   1k" 1e3, "   5k" 5e3, "  10k" 1e4)' >> $GNUPLOT_TEMP_SCRIPT
    elif [ $MAXIMUM_YVALUE -lt 50000 ]; then
        echo 'set ytic ("   5k" 5e3, "  25k" 2.5e4, "  50k" 5e4)' >> $GNUPLOT_TEMP_SCRIPT
    elif [ $MAXIMUM_YVALUE -lt 75000 ]; then
        echo 'set ytic (" 7.5k" 7.5e3, "  30k" 3e4, "52.5k" 5.25e4, "  75k" 7.5e4)' >> $GNUPLOT_TEMP_SCRIPT
    elif [ $MAXIMUM_YVALUE -lt 100000 ]; then
        echo 'set ytic ("  10k" 1e4, "  40k" 4e4, "  70k" 7e4, " 100k" 1e4)' >> $GNUPLOT_TEMP_SCRIPT
    elif [ $MAXIMUM_YVALUE -lt 250000 ]; then
        echo 'set ytic ("  25k" 2.5e4, " 100k" 1e5, " 175k" 1.75e5, " 250k" 2.5e5)' >> $GNUPLOT_TEMP_SCRIPT
    elif [ $MAXIMUM_YVALUE -lt 500000 ]; then
        echo 'set ytic ("  50k" 5e4, " 200k" 2e5, " 350k" 3.5e5, " 500k" 5e5)' >> $GNUPLOT_TEMP_SCRIPT
    elif [ $MAXIMUM_YVALUE -lt 750000 ]; then
        echo 'set ytic ("  75k" 7.5e4, " 300k" 3e5, " 525k" 5.25e5, " 750k" 7.5e5)' >> $GNUPLOT_TEMP_SCRIPT
    elif [ $MAXIMUM_YVALUE -lt 1000000 ]; then
        echo 'set ytic (" 100k" 1e5, " 400k" 4e5, " 700k" 7e5, "   1M" 1e6)' >> $GNUPLOT_TEMP_SCRIPT
    elif [ $MAXIMUM_YVALUE -lt 1500000 ]; then
        echo 'set ytic (" 150k" 1.5e5, " 600k" 6e5, "1.05M" 1.05e6, " 1.5M" 1.5e6)' >> $GNUPLOT_TEMP_SCRIPT
    elif [ $MAXIMUM_YVALUE -lt 2000000 ]; then
        echo 'set ytic (" 200k" 2e5, " 800k" 8e5, " 1.4M" 1.4e6, "   2M" 2e6)' >> $GNUPLOT_TEMP_SCRIPT
    elif [ $MAXIMUM_YVALUE -lt 3000000 ]; then
        echo 'set ytic (" 300k" 3e5, " 1.2M" 1.2e6, " 2.1M" 2.1e6, "   3M" 3e6)' >> $GNUPLOT_TEMP_SCRIPT
    elif [ $MAXIMUM_YVALUE -lt 5000000 ]; then
        echo 'set ytic (" 500k" 5e5, "   2M" 2e6, " 3.5M" 3.5e6, "   5M" 5e6)' >> $GNUPLOT_TEMP_SCRIPT
    elif [ $MAXIMUM_YVALUE -lt 10000000 ]; then
        echo 'set ytic ("   1M" 1e6, "   4M" 4e6, "   7M" 7e6, "  10M" 1e7)' >> $GNUPLOT_TEMP_SCRIPT
    fi
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
        echo 'plot for [i=1:A_blocks] "'$TEMPORARY_DATA_FILE'" index i-1 using ($0+word(shifts,i)):3:($2/'$FACTOR_TO_DIVIDE_FOR_COLOR'):xticlabels("\\scriptsize{$".stringcolumn(2)."$}") with boxes title "" linecolor variable' >> $GNUPLOT_TEMP_SCRIPT
    fi
    if [ "$1" = 'FALSE' ]; then
        echo 'plot for [i=1:A_blocks] "'$TEMPORARY_DATA_FILE'" index i-1 using ($0+word(shifts,i)):3:($2/'$FACTOR_TO_DIVIDE_FOR_COLOR'):xticlabels(2) with boxes title "" linecolor variable' >> $GNUPLOT_TEMP_SCRIPT
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

#Setting of the correct case based on the path.                                                                                                                                                                                                                                
STAGGERED="FALSE"
WILSON="FALSE"
[ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ] && STAGGERED="TRUE"
[ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ] && WILSON="TRUE"

if [ $STAGGERED = 'TRUE' ]; then
    DATAFILE_NAME="rhmc_output"
    MASS_PREFIX="mass"
elif [ $WILSON = 'TRUE' ]; then
    DATAFILE_NAME="hmc_output"
    MASS_PREFIX="k"
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
            echo "   In the first case this script has to be invoqued from where the"
            echo "   mass folders are, while in the second from where the beta folders"
            echo "   are. The prefix of the mass folders is set to k for Wilson and to"
            echo "   mass for staggered (the path must then contain either Wilson or"
            echo "   staggered)."
            echo ""
	        printf "\n \e[1m\e[4m\e[38;5;48m"
	        echo "Call the script $0 with the following optional arguments:"
	        printf "\n\e[0;32m"
	        echo "   -k | --masses           ->    mass values to be used (use the number in the folder names)"
	        echo "   -b | --betas            ->    beta values to be used"
            echo "   -s | --save             ->    save the output plot"
	        echo "   -o | --outputFilename   ->    default value = $OUTPUT_PLOT_FILENAME (provide it without extension!)"
	        echo "   --nt                    ->    nt value to be used (default ${NTIME})"
	        printf "\n\e[0m"
	        exit
	        shift;;
        -k | --masses )
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
            while [[ $2 =~ ^[[:digit:]]{1}[.]?[[:digit:]]+$ ]]; do
                BETAS+=( "$2" )
                shift
            done
            shift ;;
        --nt )
            if [[ $2 =~ ^[[:digit:]]+$ ]]; then
                NTIME=$2
            else
                printf "\n\e[0;31mValue for --nt option invalid! Aborting...\n\n\e[0m" ; exit -1
            fi
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
    [ $MASS_OVERVIEW = 'TRUE' ] && OUTPUT_PLOT_FILENAME="OverviewSimulationsOfMasses"
    [ $BETA_OVERVIEW = 'TRUE' ] && OUTPUT_PLOT_FILENAME="OverviewSimulationsOfBetas"
fi

if [ $MASS_OVERVIEW = 'TRUE' ]; then
    declare -A NUMBER_OF_VOLUMES
    rm -f $TEMPORARY_DATA_FILE
    #If masses were not given, then collect all
    if [ ${#MASSES[@]} -eq 0 ]; then
        MASSES=( $(ls -d ${MASS_PREFIX}*/ | grep -oE "[[:digit:]]{4}") )
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
        for VOLUME in $(ls -d ${MASS_PREFIX}${VALUE}/nt${NTIME}/ns*/); do
            NSPACE=${VOLUME%?}
            NSPACE=${NSPACE##*/ns}
            printf "$VALUE\t$NSPACE\t$(wc -l ${VOLUME}/b?.????/$DATAFILE_NAME | awk 'END{print $1}')\n" >> $TEMPORARY_DATA_FILE
            (( NUMBER_OF_VOLUMES["$VALUE"]++ ))
        done
        printf "\n\n" >> $TEMPORARY_DATA_FILE
    done
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
        BETAS=( $(ls -d b?.????_s????_continueWithNewChain/ | grep -oE "[[:digit:]]{1}[.][[:digit:]]{4}" | sort -u) )
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
    #Remove last two empty lines of data file
    { rm $TEMPORARY_DATA_FILE && head -n -2 > $TEMPORARY_DATA_FILE; } < $TEMPORARY_DATA_FILE
    #Finally plot
    ProducePlotAndRemoveAuxiliaryFiles
    exit
fi
