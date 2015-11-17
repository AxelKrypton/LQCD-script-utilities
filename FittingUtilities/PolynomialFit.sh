#!/bin/bash

#######################################################################################
#
#   This script is suited to perform a polynomial fit of a generic data set.
#
#######################################################################################

#Variables connected to command line options
POLYNOMIAL_DEGREE=3
DATA_FILENAME='betaC'
TMP_FILE_FOR_GNUPLOT_SCRIPT='FileThatHopefullyDoesNotExist.plt'
QUIET_MODE='TRUE'
COLUMN_X=1
COLUMN_Y=2
COLUMN_DY=3
OUTPUT_FILENAME='PolynomialFit'
EXTRAPOLATE_TO=()
LABEL_X="x"
LABEL_Y="y"
PLOT_TITLE=""

#Parse command line parameters
function ElementInArray() {
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

if ElementInArray "--help" $@ || ElementInArray "-h" $@; then
    printf "\n\t\e[38;5;13m\e[1m"
    printf "\e[4mPossible options to the script\e[24m:\e[21m\n\n\t\e[38;5;10m"
    printf "   -f | --filename          ->   The data file, default \"$DATA_FILENAME\" (globalpath or path from present folder)\n\t"
    printf "   -v | --verbose           ->   Print additional output during fit procedure\n\t"
    printf "   -d | --degree            ->   Degree of the polynomial, default = $POLYNOMIAL_DEGREE\n\t"
	printf "   -o | --outputFilename    ->   default value = $OUTPUT_FILENAME (provide it without extension!)\n\t"
	printf "   -x | --columnX           ->   default value = $COLUMN_X\n\t"
	printf "   -y | --columnY           ->   default value = $COLUMN_Y\n\t"
	printf "   --dy | --columnDY        ->   default value = $COLUMN_DY\n\t"
    printf "   -e | --extrapolateTo     ->   extrapolate fitted quantity to provided value(s)\n\t"
	printf "   --xLabel                 ->   default value = $LABEL_X\n\t"
	printf "   --yLabel                 ->   default value = $LABEL_Y\n\t"
	printf "   --plotTitle              ->   default value = \"$PLOT_TITLE\"\n\t"
    printf "\n\e[0m"
    exit 3
fi

while [ "$1" != "" ]; do
    case $1 in
        -f | --filename )
            DATA_FILENAME="$2"
            shift 2
            ;;
        -v | --verbose )
            QUIET_MODE='FALSE'
            shift
            ;;
        -d | --degree )
            POLYNOMIAL_DEGREE=$2
            shift 2
            ;;
        -o | --outputFilename )
            OUTPUT_FILENAME=$2
            shift 2
            ;;
        -x | --columnX )
            if [[ $2 =~ [[:digit:]]+ ]]; then
                COLUMN_X=$2
                shift
            fi
            shift
            ;;
        -y | --columnY )
            if [[ $2 =~ [[:digit:]]+ ]]; then
                COLUMN_Y=$2
                shift
            fi
            shift
            ;;
        --dy | --columnDY )
            if [[ $2 =~ [[:digit:]]+ ]]; then
                COLUMN_DY=$2
                shift
            fi
            shift
            ;;
        -e | --extrapolateTo )
            while [[ $2 =~ ^[+-]?[[:digit:]]+[.]?[[:digit:]]+$ ]]; do
                EXTRAPOLATE_TO+=( $2 )
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
        * ) printf "\n\e[38;5;9m Option \e[1m$1\e[21m invalid! Aborting...\n\n\e[0m"; exit -1
    esac
done

#==============================================================================================================
#Checks on command line parameters
if [ ! -f $DATA_FILENAME ]; then
    printf "\n\e[0;31m File \"$DATA_FILENAME\" not found! Aborting...\n\n\e[0m"
    exit -1
fi

if [[ ! $POLYNOMIAL_DEGREE =~ ^[[:digit:]]+$  ]]; then
    printf "\n\e[0;31m The polynomial degree must be a positive integer! Aborting...\n\n\e[0m"
    exit -1
fi

#==============================================================================================================
#==============================================================================================================
#Remove temporary file for gnuplot if existing
rm -f $TMP_FILE_FOR_GNUPLOT_SCRIPT
# Starting values for fit params
for((i=0; i<=$POLYNOMIAL_DEGREE; i++)); do
    echo "a${i}=1"    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
done
# Terminal get the fit in pdf via latex
echo 'set terminal lua tikz standalone solid preamble '"'"'\usepackage{amsmath, mathabx}'"'" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
echo 'set fit errorvariables  # to get the errors' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
echo 'set fit quiet' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
# Fit function: polynomial
echo -n "f(x) = a0" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
for((i=1; i<=$POLYNOMIAL_DEGREE; i++)); do
    echo -n " + a${i}*x**${i} " >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
done
echo ''  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
# Actual fit
echo -n 'fit f(x) "'$DATA_FILENAME'" u '$COLUMN_X':'$COLUMN_Y':'$COLUMN_DY ' via  a0' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
for((i=1; i<=$POLYNOMIAL_DEGREE; i++)); do
    echo -n ", a${i}" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
done
echo ''  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
# Add line to plot title with fit parameters
echo -n 'titlePlot = "'$PLOT_TITLE'\n\n\\textcolor{blue}{\\fbox{$f(x)=a_0' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
for((i=1; i<=$POLYNOMIAL_DEGREE; i++)); do
    if [ $i -eq 1 ]; then
        echo -n ' + a_'${i}' \\: x '    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    else
        echo -n ' + a_'${i}' \\: x^'${i}    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    fi
done
echo -n '$}}\n\n\n".sprintf("$a_0=$%.3f$\\:\\pm\\:$%.3f' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
for((i=1; i<=$POLYNOMIAL_DEGREE; i++)); do
    echo -n '$\\quad a_'${i}'=$%.3f$\\:\\pm\\:$%.3f' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    if [ $(bc <<< "(${i}-1)%2==0") -eq 1 ]; then
        [ $i -ne $POLYNOMIAL_DEGREE ] && echo -n '\n\n' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    fi
done
echo -n '", a0, a0_err'  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
for((i=1; i<=$POLYNOMIAL_DEGREE; i++)); do
    echo -n ', a'${i}', a'${i}'_err' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
done
echo ')."\n"' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
# Plot information
echo 'set xlabel "'$LABEL_X'"'                          >> $TMP_FILE_FOR_GNUPLOT_SCRIPT 
echo 'set ylabel "'$LABEL_Y'"'                          >> $TMP_FILE_FOR_GNUPLOT_SCRIPT  
echo 'set key at graph 0.9, graph 0.95 spacing 1.25'    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT 
echo 'set title titlePlot'                              >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
#Set output name
echo 'set output  "'$OUTPUT_FILENAME'.tex"'   >> $TMP_FILE_FOR_GNUPLOT_SCRIPT 
#Actual plot
echo 'plot "'$DATA_FILENAME'" u '$COLUMN_X':'$COLUMN_Y':'$COLUMN_DY ' notitle, f(x) lc 3 notitle'  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT 
#Extrapolate
if [ ${#EXTRAPOLATE_TO[@]} -ne 0 ]; then
    echo 'set print "-"' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'print "\nExtrapolation to new points:\n\n'$LABEL_X'\t\t'$LABEL_Y'"' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    for NEW_POINT in ${EXTRAPOLATE_TO[@]}; do
        echo 'print sprintf("%f\t%f", '$NEW_POINT', f('$NEW_POINT'))' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    done
    echo 'print ""' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'set print' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
fi
unset -v 'i' 'NEW_POINT'

#==============================================================================================================
#==============================================================================================================

function RunGnuplotScriptAndProducePdf(){
    gnuplot $TMP_FILE_FOR_GNUPLOT_SCRIPT
    pdflatex ${OUTPUT_FILENAME}.tex 1>> /dev/null
}

function CleanAuxiliaryFiles(){
    rm ${OUTPUT_FILENAME}{.tex,.log,.aux}
    rm fit.log
    rm -f "texput.log"
}

#==============================================================================================================

RunGnuplotScriptAndProducePdf
CleanAuxiliaryFiles
evince ${OUTPUT_FILENAME}.pdf &

exit 0
