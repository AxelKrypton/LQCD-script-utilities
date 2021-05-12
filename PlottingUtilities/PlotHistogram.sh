#!/bin/bash

#=========================================================================#
#                                                                         #
#   This script is suited to plot the histogram of a generic data set.    #
#                                                                         #
#=========================================================================#

#Variables connected to command line options
DATA_FILENAME=()
TMP_FILE_FOR_GNUPLOT_SCRIPT='FileThatHopefullyDoesNotExist.plt'
COLUMN_X=1
LABEL_X="x"
LABEL_Y="\\\#"
PLOT_TITLE=""
USE_BINWIDTH='FALSE'
USE_BINNUMBER='FALSE'
NORMALIZE='FALSE'
SAVE_PLOT='FALSE'
OUTPUT_FILENAME='Histogram'

#Parse command line parameters
function ElementInArray() {
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

if ElementInArray "--help" $@ || ElementInArray "-h" $@; then
    printf "\n\t\e[38;5;13m\e[1m"
    printf "\e[4mPossible options to the script\e[24m:\e[22m\n\n\t\e[38;5;10m"
    printf "   -f | --filename          ->   The data file (globalpath or path from present folder, one or more)\n\t"
	printf "   -x | --columnX           ->   default value = $COLUMN_X\n\t"
	printf "   -w | --binWidth          ->   width of bins to be used\n\t"
	printf "   -n | --binNumber         ->   number of bins to be used\n\t"
	printf "   --xRange                 ->   requires two entries, default is gnuplot determined\n\t"
	printf "   --xLabel                 ->   default value = $LABEL_X\n\t"
	printf "   --yLabel                 ->   default value = $LABEL_Y\n\t"
	printf "   --plotTitle              ->   default value = \"$PLOT_TITLE\"\n\t"
	printf "   --normalize              ->   normalize the histogram (area=1)\n\t"
	printf "   -s | --save              ->   Save and opens histogram as pdf file!\n\t"
	printf "   -o | --outputFilename    ->   default value = $OUTPUT_FILENAME (provide it without extension!)\n\t"
    printf "\n\e[0m"
    exit 3
fi

while [ "$1" != "" ]; do
    case $1 in
        -f | --filename )
            while [[ ! $2 =~ ^(-|$) ]]; do
                DATA_FILENAME+=( "$2" )
                shift
            done
            shift ;;
        -x | --columnX )
            if [[ $2 =~ ^[[:digit:]]+$ ]]; then
                COLUMN_X=$2
                shift
            fi
            shift
            ;;
        -w | --binWidth )
            if [[ $2 =~ ^[0-9]+[.]?[[:digit:]]*$ ]]; then
                BIN_WIDTH=$2
                USE_BINWIDTH='TRUE'
                shift
            fi
            shift
            ;;
        -n | --binNumber )
            if [[ $2 =~ ^[0-9]+[.]?[[:digit:]]*$ ]]; then
                BIN_NUMBER=$2
                USE_BINNUMBER='TRUE'
                shift
            fi
            shift
            ;;
        --xRange )
            while [[ $2 =~ ^[+-]?[[:digit:]]+[.]?[[:digit:]]*$ ]]; do
                XRANGE+=( $2 )
                shift
            done
            shift
            ;;
        --xLabel )
            LABEL_X="$2"
            shift 2
            ;;
        --yLabel )
            LABEL_Y="$2"
            shift 2
            ;;
        --plotTitle )
            PLOT_TITLE="$2"
            shift 2
            ;;
        --normalize )
            NORMALIZE='TRUE'
            shift 
            ;;
        -s | --save )
            SAVE_PLOT='TRUE'
            shift 
            ;;
        -o | --outputFilename )
            OUTPUT_FILENAME=$2
            shift 2
            ;;
        * ) printf "\n\e[38;5;9m Option \e[1m$1\e[22m invalid! Aborting...\n\n\e[0m"; exit -1
    esac
done

#==============================================================================================================
#Checks on command line parameters
if [ ${#DATA_FILENAME[@]} -eq 0 ]; then
        printf "\n\e[38;5;9m No file specified! Aborting...\n\n\e[0m"
        exit -1
fi

for FILE in "${DATA_FILENAME[@]}"; do
    if [ ! -f "$FILE" ]; then
        printf "\n\e[38;5;9m File \"$FILE\" not found! Aborting...\n\n\e[0m"
        exit -1
    fi
done && unset 'FILE'

if [ ${#XRANGE[@]} -ne 0 ] && [ ${#XRANGE[@]} -ne 2 ]; then
    printf "\n\e[38;5;9m X range has been not correctly specified (two numbers should be given)! Aborting...\n\n\e[0m"
    exit -1
fi

if [ $USE_BINWIDTH = $USE_BINNUMBER ]; then
    printf "\n\e[38;5;9m Either the number of bins or the width of the bins should be specified!! Aborting...\n\n\e[0m"
    exit -1
fi

#==============================================================================================================#
#Produce plot script: Redirect standard output to file
rm -f $TMP_FILE_FOR_GNUPLOT_SCRIPT
exec 3>&1 1>$TMP_FILE_FOR_GNUPLOT_SCRIPT
if [ $SAVE_PLOT = 'TRUE' ]; then
    echo 'set term lua tikz latex createstyle' #Creates support files locally
    echo 'set terminal lua tikz standalone preamble '"'"'\usepackage{amsmath, mathabx}'"'"
    echo 'set output  "'$OUTPUT_FILENAME'.tex"'
    echo ''
fi
echo "set title \"$PLOT_TITLE\""
echo "set xlabel \"$LABEL_X\""
echo "set ylabel \"$LABEL_Y\""
echo ''
echo "array Min_all[${#DATA_FILENAME[@]}]"
echo "array Max_all[${#DATA_FILENAME[@]}]"
for INDEX in "${!DATA_FILENAME[@]}"; do
    echo "stats \"${DATA_FILENAME[INDEX]}\" using $COLUMN_X name \"data\" nooutput"
    (( INDEX++ ))
    echo "Min_all[$INDEX] = data_min"
    echo "Max_all[$INDEX] = data_max"
    echo ''
done

echo "Min = Min_all[1]"  # where binning starts
echo "Max = Max_all[1]"  # where binning ends
echo "do for [i=1:${#DATA_FILENAME[@]}] {"
echo "    if (Min > Min_all[i]) {"
echo "        Min = Min_all[i]"
echo "    }"
echo "    if (Max < Max_all[i]) {"
echo "        Max = Max_all[i]"
echo "    }"
echo "}"
echo ''

#echo 'print Min_all'
#echo 'print Max_all'

if [ $USE_BINNUMBER = 'TRUE' ]; then
    echo "n = $BIN_NUMBER" # the number of bins
    echo "binwidth = (Max-Min)/n"
fi
if [ $USE_BINWIDTH = 'TRUE' ]; then
    echo "binwidth = $BIN_WIDTH"
fi
echo''
if [ ${#XRANGE[@]} -ne 0 ]; then
    echo 'set xrange ['${XRANGE[0]}':'${XRANGE[1]}']'
else
    echo 'set autoscale x'
fi
echo 'set yrange [0:]'
echo''
echo "bin(x) = binwidth*(floor((x-Min)/binwidth)+0.5) + Min"
echo "set boxwidth binwidth"
echo "set style fill solid border -1"
echo ''
if [ $NORMALIZE = 'FALSE' ]; then
    for INDEX in "${!DATA_FILENAME[@]}"; do
        echo -n "$([ $INDEX -eq 0 ] && echo 'plot') '${DATA_FILENAME[INDEX]}' using (bin(\$$COLUMN_X)):(1.0) smooth freq with boxes title \"${DATA_FILENAME[INDEX]//_/ }\", "
    done
else
    for INDEX in "${!DATA_FILENAME[@]}"; do
        echo -n "$([ $INDEX -eq 0 ] && echo 'plot') '${DATA_FILENAME[0]}' using (bin(\$$COLUMN_X)):(1.0/(binwidth*data_records)) smooth freq with boxes title \"${DATA_FILENAME[INDEX]//_/ }\", "
    done
fi
echo '' # Crucial to complete plot command which has no newline
if [ $SAVE_PLOT = 'FALSE' ]; then
    echo "pause -1 \"Press enter to quit (all plots will be closed)\""
    echo "q"
fi
#Restore standard output
exec 1>&3

#==============================================================================================================#
function RunGnuplotScriptAndProducePdfIfAsked(){
    gnuplot $TMP_FILE_FOR_GNUPLOT_SCRIPT
    [ $SAVE_PLOT = 'TRUE' ] && pdflatex ${OUTPUT_FILENAME}.tex 1>> /dev/null
}

function CleanAuxiliaryFiles(){
    rm -f ${OUTPUT_FILENAME}{.tex,.log,.aux}
    local SUPPORT_GNUPLOT_LUATEX_FILES=("gnuplot-lua-tikz-common.tex"  "gnuplot-lua-tikz.sty"  "gnuplot-lua-tikz.tex"  "t-gnuplot-lua-tikz.tex")
    rm -f ${SUPPORT_GNUPLOT_LUATEX_FILES[@]}
    rm $TMP_FILE_FOR_GNUPLOT_SCRIPT
}
#==============================================================================================================
#Plot and if save compile latex file
echo ''
RunGnuplotScriptAndProducePdfIfAsked
CleanAuxiliaryFiles
[ $SAVE_PLOT = 'TRUE' ] && evince ${OUTPUT_FILENAME}.pdf & 
echo ''
exit 0

