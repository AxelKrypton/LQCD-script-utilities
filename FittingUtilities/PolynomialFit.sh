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
XRANGE=()
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
    printf "\e[4mPossible options to the script\e[24m:\e[22m\n\n\t\e[38;5;10m"
    printf "   -f | --filename          ->   The data file, default \"$DATA_FILENAME\" (globalpath or path from present folder)\n\t"
    printf "   -v | --verbose           ->   Print additional output during fit procedure\n\t"
    printf "   -d | --degree            ->   Degree of the polynomial, default = $POLYNOMIAL_DEGREE\n\t"
	printf "   -o | --outputFilename    ->   default value = $OUTPUT_FILENAME (provide it without extension!)\n\t"
	printf "   -x | --columnX           ->   default value = $COLUMN_X\n\t"
	printf "   -y | --columnY           ->   default value = $COLUMN_Y\n\t"
	printf "   --dy | --columnDY        ->   default value = $COLUMN_DY\n\t"
    printf "   -e | --extrapolateTo     ->   extrapolate fitted quantity to provided value(s)\n\t"
	printf "   --xRange                 ->   requires two entries, default is gnuplot determined\n\t"
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
            while [[ $2 =~ ^[+-]?[[:digit:]]+[.]?[[:digit:]]*$ ]]; do
                EXTRAPOLATE_TO+=( $2 )
                shift
            done
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
        * ) printf "\n\e[38;5;9m Option \e[1m$1\e[22m invalid! Aborting...\n\n\e[0m"; exit -1
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

if [ ${#XRANGE[@]} -ne 0 ] && [ ${#XRANGE[@]} -ne 2 ]; then
    printf "\n\e[0;31m X range has been not correctly specified (two numbers should be given)! Aborting...\n\n\e[0m"
    exit -1
fi

#==============================================================================================================
#Find min and max of x column including extrapolation points (if xrange not given)
if [ ${#XRANGE[@]} -eq 0 ]; then
    if [ $(grep -c '\$' <<< "$COLUMN_X $COLUMN_Y") -eq 0 ]; then
        X_MIN=$(awk '/^($|[#]+)/{next} {if(min==""){min=$'$COLUMN_X'}else{if($'$COLUMN_X'<min){min=$'$COLUMN_X'}}}END{print min}' $DATA_FILENAME)
        X_MAX=$(awk '/^($|[#]+)/{next} {if(max==""){max=$'$COLUMN_X'}else{if($'$COLUMN_X'>max){max=$'$COLUMN_X'}}}END{print max}' $DATA_FILENAME)
    else
        X_MIN=$(awk '/^($|[#]+)/{next} {if(min==""){min='$COLUMN_X'}else{if('$COLUMN_X'<min){min='$COLUMN_X'}}}END{print min}' $DATA_FILENAME)
        X_MAX=$(awk '/^($|[#]+)/{next} {if(max==""){max='$COLUMN_X'}else{if('$COLUMN_X'>max){max='$COLUMN_X'}}}END{print max}' $DATA_FILENAME)
    fi
    for NEW_POINT in ${EXTRAPOLATE_TO[@]}; do
        [ $(awk '{if($1<$2){print 0}else{print 1}}' <<< "$NEW_POINT $X_MIN") -eq 0 ] && X_MIN=$NEW_POINT
        [ $(awk '{if($1>$2){print 0}else{print 1}}' <<< "$NEW_POINT $X_MAX") -eq 0 ] && X_MAX=$NEW_POINT
    done
    X_MIN=$(awk '{print $1-0.03*($2-$1)}' <<< "$X_MIN $X_MAX")
    X_MAX=$(awk '{print $2+0.03*($2-$1)}' <<< "$X_MIN $X_MAX")
fi
#==============================================================================================================
#Remove temporary file for gnuplot if existing
rm -f $TMP_FILE_FOR_GNUPLOT_SCRIPT
#Since the gnuplot fit syntax changed from version 4 to version 5, let's define here some handy variables
GNUPLOT_VERSION=$(gnuplot -V | awk '{print int($2)}')
if [ $GNUPLOT_VERSION -le 4 ]; then
    FIT_ERRORS_STRING=''
else
    FIT_ERRORS_STRING='zerrors'
fi
# Starting values for fit params
#echo "set fit noerrorscaling" >> $TMP_FILE_FOR_GNUPLOT # From version 5.0 to get the errors correct and not to divide them by the sqrt of chi2. See https://sourceforge.net/p/gnuplot/bugs/1511/
for((i=0; i<=$POLYNOMIAL_DEGREE; i++)); do
    echo "a${i}=1"    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
done
# Terminal get the fit in pdf via latex
#
# ATTENTION: Gnuplot has some support files for the lua tikz terminal that should be installed
#            somewhere in the tex distribution when gnuplot gets installed. If these are missing
#            or present but produced with a different version of gnuplot than that in use, there
#            could be problems in the later compilation of the .tex file. This happens, for example,
#            using gnuplot 5.0 and having the support files of gnuplot 4.6. 
#            Reading http://tex.stackexchange.com/questions/267031/tikz-problem-since-texlive-2015-update
#            and in particular the comment of Akira Kakuto to the answer of egreg, it is possible to
#            create the support files locally from where the gnuplot script is run and be sure that
#            the latex compilations finds the correct support files. That is what we do here!
#
echo 'set term lua tikz latex createstyle' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT #Creates support files locally
echo 'set terminal lua tikz standalone preamble '"'"'\usepackage{amsmath, mathabx}'"'" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT

echo 'set fit errorvariables  # to get the errors' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
if [ $QUIET_MODE = 'TRUE' ]; then
    echo 'set fit quiet' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
fi
# Fit function: polynomial
echo -n "f(x) = a0" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
for((i=1; i<=$POLYNOMIAL_DEGREE; i++)); do
    echo -n " + a${i}*x**${i} " >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
done
echo ''  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
# Actual fit
echo -n 'fit f(x) "'$DATA_FILENAME'" u '$COLUMN_X':'$COLUMN_Y':'$COLUMN_DY ' '$FIT_ERRORS_STRING' via  a0' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
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
echo -n '$}}\n\n\n".sprintf("$a_0=$%.6f$\\:\\pm\\:$%.6f' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
for((i=1; i<=$POLYNOMIAL_DEGREE; i++)); do
    echo -n '$\\quad a_'${i}'=$%.6f$\\:\\pm\\:$%.6f' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    if [ $(bc <<< "(${i}-1)%2==0") -eq 1 ]; then
        [ $i -ne $POLYNOMIAL_DEGREE ] && echo -n '\n\n' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    fi
done
echo -n '", a0, a0_err/FIT_STDFIT'  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
for((i=1; i<=$POLYNOMIAL_DEGREE; i++)); do
    echo -n ', a'${i}', a'${i}'_err/FIT_STDFIT' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
done
echo ')."\n\n".sprintf("$\\chi^2_{\\mbox{d.o.f.}}=$%.3f", FIT_STDFIT**2)."\n"' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
# Plot information
echo 'set xlabel "'$LABEL_X'"'                          >> $TMP_FILE_FOR_GNUPLOT_SCRIPT 
echo 'set ylabel "'$LABEL_Y'"'                          >> $TMP_FILE_FOR_GNUPLOT_SCRIPT  
echo 'set key at graph 0.9, graph 0.95 spacing 1.25'    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT 
echo 'set title titlePlot'                              >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
if [ ${#XRANGE[@]} -ne 0 ]; then
    echo 'set xrange ['${XRANGE[0]}':'${XRANGE[1]}']'   >> $TMP_FILE_FOR_GNUPLOT_SCRIPT 
else
    echo 'set xrange ['$X_MIN':'$X_MAX']'   >> $TMP_FILE_FOR_GNUPLOT_SCRIPT 
fi
#Extrapolate
if [ ${#EXTRAPOLATE_TO[@]} -ne 0 ]; then
    echo 'set print "-"' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo -n 'f_err(x) = sqrt((a0_err/FIT_STDFIT)**2 ' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    for((i=1; i<=$POLYNOMIAL_DEGREE; i++)); do
        echo -n '+ x**(2*'${i}')*(a'${i}'_err/FIT_STDFIT)**2' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    done
    echo ')' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'print "\nExtrapolation to new points:\n\n'$LABEL_X'\t\t'$LABEL_Y'"' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    for NEW_POINT in ${EXTRAPOLATE_TO[@]}; do
        echo 'print sprintf("%f\t\t%f %f", '$NEW_POINT', f('$NEW_POINT'), f_err('$NEW_POINT'))' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    done
    echo 'print ""' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'set print' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
fi
unset -v 'i' 'NEW_POINT'
#Set output name
echo 'set output  "'$OUTPUT_FILENAME'.tex"'   >> $TMP_FILE_FOR_GNUPLOT_SCRIPT 
#Actual plot
if [ ${#EXTRAPOLATE_TO[@]} -ne 0 ]; then
    for NEW_POINT in ${EXTRAPOLATE_TO[@]}; do
        echo 'set arrow from '$NEW_POINT',graph(0,0) to '$NEW_POINT',graph(1,1) nohead lt 0' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    done
fi
echo -n 'plot "'$DATA_FILENAME'" u '$COLUMN_X':'$COLUMN_Y':'$COLUMN_DY ' w e notitle, f(x) lc 3 notitle'  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT 
if [ ${#EXTRAPOLATE_TO[@]} -ne 0 ]; then
    for NEW_POINT in ${EXTRAPOLATE_TO[@]}; do
        echo -n ', "+" using ('$NEW_POINT'):(f('$NEW_POINT')):(f_err('$NEW_POINT')) w e pt 7 lc rgb "#FF8000" notitle' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    done
fi
echo '' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT

#==============================================================================================================
#==============================================================================================================

function RunGnuplotScriptAndProducePdf(){
    gnuplot $TMP_FILE_FOR_GNUPLOT_SCRIPT
    pdflatex ${OUTPUT_FILENAME}.tex 1>> /dev/null
}

function CleanAuxiliaryFiles(){
    rm ${OUTPUT_FILENAME}{.tex,.log,.aux}
    local SUPPORT_GNUPLOT_LUATEX_FILES=("gnuplot-lua-tikz-common.tex"  "gnuplot-lua-tikz.sty"  "gnuplot-lua-tikz.tex"  "t-gnuplot-lua-tikz.tex")
    rm ${SUPPORT_GNUPLOT_LUATEX_FILES[@]}
    rm fit.log
    rm $TMP_FILE_FOR_GNUPLOT_SCRIPT
    rm -f "texput.log"
}

#==============================================================================================================

RunGnuplotScriptAndProducePdf
CleanAuxiliaryFiles
evince ${OUTPUT_FILENAME}.pdf &

exit 0
