#!/bin/bash

# This script is intended to produce the plot of the
# critical exponent nu as function of the quark mass.
# It automatically deals with Wilson or Staggered using
# kappa or the mass on the x axis (use command line options
# though to be sure the correct data columns are used).

#Setting of the correct case based on the path.
STAGGERED="FALSE"
WILSON="FALSE"
[ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ] && STAGGERED="TRUE"
[ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ] && WILSON="TRUE"

#Variables for the script
COLUMN_X=1
COLUMN_Y=6
COLUMN_DY=7
COLUMN_CHI2=4
DO_NOT_CORRECT_ERRORS='FALSE'
DATA_FILENAME='CriticalExponents_nt6.dat'
OUTPUT_FILENAME='CriticalExponentsPlot'

#Parse command line parameters
function ElementInArray() {
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

if ElementInArray "--help" $@ || ElementInArray "-h" $@; then
    printf "\n\t\e[38;5;13m\e[1m\e[4m"
    printf "Possible options for the script\e[24m:\e[21m\n\n\t\e[38;5;10m"
	printf "   -f | --dataFilename      ->   default value = $DATA_FILENAME\n\t"
	printf "   -o | --outputFilename    ->   default value = $OUTPUT_FILENAME (provide it without extension!)\n\t"
	printf "   -x | --columnX           ->   default value = $COLUMN_X\n\t"
	printf "   -y | --columnY           ->   default value = $COLUMN_Y\n\t"
	printf "   --dy | --columnDY        ->   default value = $COLUMN_DY\n\t"
	printf "   -c | --columnChi2        ->   default value = $COLUMN_CHI2\n\t"
    printf "   --doNotCorrectErrors     ->   do NOT correct y axis errors using the chi square\n\t"
    printf "\n\e[0m"
    exit 3
fi

while [ "$1" != "" ]; do
    case $1 in
        -f | --dataFilename )
            DATA_FILENAME=$2
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
        -c | --columnChi2 )
            if [[ $2 =~ [[:digit:]]+ ]]; then
                COLUMN_CHI2=$2
                shift
            fi
            shift
            ;;

        --doNotCorrectErrors )
            DO_NOT_CORRECT_ERRORS='TRUE'
            shift
            ;;
        * ) printf "\n\e[38;5;9m Option \e[1m$1\e[21m invalid! Aborting...\n\n\e[0m"; exit -1
    esac
done

#==============================================================================================================
if [ $DO_NOT_CORRECT_ERRORS = 'FALSE' ]; then
    printf "\n\t\e[38;5;11m\e[1m\e[4mWARNING\e[24m:\e[21m Did you ensure that the column associated to chi2 is correct? Use the \e[38;5;10m-h | --help\e[38;5;11m option in case!\n\n\e[0m"
fi

#==============================================================================================================
#Find minimum and maximum x column to set xrange later
XRANGE=( $(awk -v xCol="$COLUMN_X" 'BEGIN{min=1000; max=-1000}/^($|[#]+)/{next}$xCol<min{min=$xCol}$xCol>max{max=$xCol}END{print min, max}' $DATA_FILENAME) )
TMP_FILE_FOR_GNUPLOT_SCRIPT='TemporaryFileThatShouldNotExist.plt'
rm -f $TMP_FILE_FOR_GNUPLOT_SCRIPT
#Prepare the gnuplot temporary script
echo 'set terminal lua tikz standalone solid preamble '"'"'\usepackage{amsmath}'"'" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
echo "set output '${OUTPUT_FILENAME}.tex'"  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
echo 'dataFile = "'$DATA_FILENAME'"'  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT

echo 'stats "'$DATA_FILENAME'" nooutput'                        >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
echo "set xrange[${XRANGE[0]}*0.99:${XRANGE[1]}*1.01]" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
echo 'set yrange[.25:.8]'                              >> $TMP_FILE_FOR_GNUPLOT_SCRIPT     
echo 'f(x) = 0.5'                                      >> $TMP_FILE_FOR_GNUPLOT_SCRIPT    
echo 'g(x) = 1./3'                                     >> $TMP_FILE_FOR_GNUPLOT_SCRIPT    
echo 'h(x) = 0.6301'                                   >> $TMP_FILE_FOR_GNUPLOT_SCRIPT 
echo 'set title "Fitted values of $\\nu$"'             >> $TMP_FILE_FOR_GNUPLOT_SCRIPT  
echo 'set key left top'                                >> $TMP_FILE_FOR_GNUPLOT_SCRIPT    
echo 'set ylabel "$\\nu$"'                             >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
if [ $WILSON = 'TRUE' ]; then
    echo 'set xlabel "$\\kappa$"'      >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
elif [ $STAGGERED = 'TRUE' ]; then
    echo 'set xlabel "$m$"'      >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
fi

if [ $DO_NOT_CORRECT_ERRORS = 'FALSE' ]; then
    echo 'plot \'                                                                   >> $TMP_FILE_FOR_GNUPLOT_SCRIPT  
    echo '    h(x) title "Second-order" lc 1 \'                                     >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo '    , f(x) title "Tricritical" lc 3 \'                                    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT  
    echo '    , g(x) title "First-order" lc 5 \'                                    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo '    , dataFile index 0 u '$COLUMN_X':'$COLUMN_Y':($'$COLUMN_DY'/sqrt($'$COLUMN_CHI2')) w e notitle'    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo "if(STATS_blocks > 1){" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo '  replot dataFile index 1 u '$COLUMN_X':'$COLUMN_Y':($'$COLUMN_DY'/sqrt($'$COLUMN_CHI2')) w e ls 0 lc 4 pt 4 notitle'   >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo '}' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
else
    echo 'plot \'                                                                      >> $TMP_FILE_FOR_GNUPLOT_SCRIPT  
    echo '    h(x) title "Second-order" lc 1 \'                                        >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo '    , f(x) title "Tricritical" lc 3 \'                                       >> $TMP_FILE_FOR_GNUPLOT_SCRIPT  
    echo '    , g(x) title "First-order" lc 5 \'                                       >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo '    , dataFile index 0 u '$COLUMN_X':'$COLUMN_Y':'$COLUMN_DY' w e notitle'   >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo "if(STATS_blocks > 1){" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo '  replot dataFile index 1 u '$COLUMN_X':'$COLUMN_Y':'$COLUMN_DY' w e ls 0 lc 4 pt 4 notitle'   >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo '}' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
fi

#==============================================================================================================
ERROR_GNUPLOT="$(gnuplot $TMP_FILE_FOR_GNUPLOT_SCRIPT)"
#If any error plotting, then clean and exit
[ "$ERROR_GNUPLOT" != "" ] && echo "Error in gnuplot:" && echo $ERROR_GNUPLOT && rm $TMP_FILE_FOR_GNUPLOT_SCRIPT && exit -1
#Otherwise produce pdf suppressing output (maybe dangerous if pdflatex prompt for input, but it shouldn't)
pdflatex ${OUTPUT_FILENAME}.tex >> /dev/null
rm ${OUTPUT_FILENAME}.tex
rm ${OUTPUT_FILENAME}.log
rm ${OUTPUT_FILENAME}.aux
rm $TMP_FILE_FOR_GNUPLOT_SCRIPT
#Open file for user in background
evince ${OUTPUT_FILENAME}.pdf &

exit 0
