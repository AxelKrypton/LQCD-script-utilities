#!/usr/bin/env bash

#######################################################################################
#
#   This script is suited to read the critical beta values with their errors and
#   the critical mass with its error from the output files of the
#     - GatherKurtosisValuesAtBetaC.sh
#     - KurtosisFitVSmassWithMultipleEstimators.bash
#   scripts, respectively, and to perform three polynomialFits to extract the
#   critical value of beta at the critical mass and its error.
#
#######################################################################################

#Variables connected to command line options
POLYNOMIAL_DEGREE=1
QUANT_NAME="betaC"
QUANT_DATA_FILENAME='pbp_KurtosisAtBetaC.dat'
AUX_QUANT_DATA_FILENAME='aux_'${QUANT_DATA_FILENAME}
MC_DATA_FILENAME='KurtosisFit_Bootstrap.dat'
MC=""
MC_ERR=""
TMP_FILE_FOR_GNUPLOT_SCRIPT='FileThatHopefullyDoesNotExist.plt'
QUIET_MODE='TRUE'
COLUMN_X=1
COLUMN_Y=3
COLUMN_DY=(8 9)
OUTPUT_FILENAME=$QUANT_NAME'_atCriticalMass'
EXTRAPOLATE_TO=()
LABEL_X="m"
LABEL_Y=$QUANT_NAME
LABEL_DY="d"$QUANT_NAME
#more variables
AUXILIARY_FILE='auxiliaryFileForGnuplotOutput.out'
EXTRACTEDCRITICALQUANT=()
EXTRACTEDCRITICALERR=()
NF=""
NT=""

#Parse command line parameters
function ElementInArray() {
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

if ElementInArray "--help" $@ || ElementInArray "-h" $@; then
    printf "\n\t\e[38;5;13m\e[1m"
    printf "\e[4mPossible options to the script\e[24m:\e[22m\n\n\t\e[38;5;10m"
    printf "   -q | --quantity          ->   The name of the quantity of which we seek the value corresponding to the critical mass, default = $QUANT_NAME\n\t"
    printf "   --fqc                    ->   The data file where to read the values for the relevant quantity and corresponding errors for all masses, default \"$QUANT_DATA_FILENAME\" (globalpath or path from present folder)\n\t"
    printf "   --fmc                    ->   The data file where to read the critical mass and its error, default \"$MC_DATA_FILENAME\" (globalpath or path from present folder)\n\t"
    printf "   --mc                     ->   The value of the critical mass where to extrapolate the polynomial fit\n\t"
    printf "   --dmc                    ->   The value of the error of the critical mass where to extrapolate the polynomial fit\n\t"
    printf "   -v | --verbose           ->   Print additional output during fit procedure\n\t"
    printf "   -d | --degree            ->   Degree of the polynomial, default = $POLYNOMIAL_DEGREE\n\t"
    printf "   -o | --outputFilename    ->   default value = $OUTPUT_FILENAME (provide it without extension!)\n\t"
    printf "   -x | --columnX           ->   default value = $COLUMN_X\n\t"
    printf "   -y | --columnY           ->   default value = $COLUMN_Y\n\t"
    printf "   --dy | --columnDY        ->   default value = $COLUMN_DY\n\t"
    printf "                                 Multiple space-separated integer values are interpreted as columns of asymmetric \n\t"
    printf "                                 errors. The maximum is then considered to build a symmetric error for the fit.\n\t"
    printf "\n\e[0m"
    exit 3
fi

while [ "$1" != "" ]; do
    case $1 in
        -q | --quantity )
            QUANT_NAME="$2"
            shift 2
            ;;
        --fqc )
            QUANT_DATA_FILENAME="$2"
            shift 2
            ;;
        --fmc )
            MC_DATA_FILENAME="$2"
            shift 2
            ;;
        --mc )
            MC="$2"
            shift 2
            ;;
        --dmc )
            MC_ERR="$2"
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
            COLUMN_DY=()
            while [[ $2 =~ [[:digit:]]+ ]]; do
                COLUMN_DY+=( $2 )
                shift
            done
            if [ ${#COLUMN_DY[@]} -eq 1 ]; then
                COLUMN_DY=${COLUMN_DY[0]}
            elif [ ${#COLUMN_DY[@]} -eq 2 ]; then
                COLUMN_DY="(\$${COLUMN_DY[0]}>\$${COLUMN_DY[1]}?\$${COLUMN_DY[0]}:\$${COLUMN_DY[1]})"
            else
                printf "\n\e[0;31m Maximum 2 columns of errors can be dealt with! Aborting...\n\n\e[0m"
                exit -1
            fi
            shift
            ;;
        * ) printf "\n\e[38;5;9m Option \e[1m$1\e[22m invalid! Aborting...\n\n\e[0m"; exit -1
    esac
done

#==============================================================================================================
#Checks on command line parameters
if [ ! -f $QUANT_DATA_FILENAME ]; then
    printf "\n\e[0;31m File \"$QUANT_DATA_FILENAME\" not found! Aborting...\n\n\e[0m"
    exit -1
fi

if [[ ! $POLYNOMIAL_DEGREE =~ ^[[:digit:]]+$  ]]; then
    printf "\n\e[0;31m The polynomial degree must be a positive integer! Aborting...\n\n\e[0m"
    exit -1
fi

#==============================================================================================================
#Read point where to extrapolate from the file containing the information on the critical mass and its error
if [[ -z "$MC" ]]; then
    if [ ! -f $MC_DATA_FILENAME ]; then
        printf "\n\e[0;31m File \"$MC_DATA_FILENAME\" not found! Aborting...\n\n\e[0m"
        exit -1
    fi
    echo
    echo "The critical mass and its error will be read from the second line of the file \"${MC_DATA_FILENAME}\""
    NF=$(awk 'NR==2{print $1}' $MC_DATA_FILENAME)
    NT=$(awk 'NR==2{print $2}' $MC_DATA_FILENAME)
    MC=$(awk 'NR==2{print $9}' $MC_DATA_FILENAME)
    MC_ERR=$(awk 'NR==2{print $10}' $MC_DATA_FILENAME)
    printf '  %s = %s\n' 'Nf' "${NF}"  'nt' "${NT}"  'm_c' "${MC} +- ${MC_ERR}"
fi
if [[ -z "$MC_ERR" ]]; then
    MC_ERR=0
    EXTRAPOLATE_TO=($MC)
else
    EXTRAPOLATE_TO=(  $(awk -v "mc=${MC}" -v "mcErr=${MC_ERR}" 'BEGIN{printf "%.12f  %.12f  %.12f", mc-mcErr, mc, mc+mcErr}')  )
fi

#==============================================================================================================
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

echo 'set fit errorvariables covariancevariables # to get the errors' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
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
echo -n 'fit f(x) "'$AUX_QUANT_DATA_FILENAME'" u '$COLUMN_X':'$COLUMN_Y':'$COLUMN_DY ' '$FIT_ERRORS_STRING' via  a0' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
for((i=1; i<=$POLYNOMIAL_DEGREE; i++)); do
    echo -n ", a${i}" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
done
echo ''  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT

#Extrapolate
if [ ${#EXTRAPOLATE_TO[@]} -ne 0 ]; then
    echo 'set print "-"' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo -n 'f_err(x) = sqrt((a0_err/FIT_STDFIT)**2 ' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    for((i=1; i<=$POLYNOMIAL_DEGREE; i++)); do
        echo -n '+ x**(2*'${i}')*(a'${i}'_err/FIT_STDFIT)**2' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
	for((j=0; j<i; j++));do
		echo -n '+ 2*x**('${j}'+'${i}')*FIT_COV_a'${j}'_a'${i}'/FIT_STDFIT**2' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
	done
    done
    echo ')' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'set print "-"' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'print "Extrapolation to new points:\n'$LABEL_X'\t\t'$LABEL_Y'\t\t\t'$LABEL_DY'"' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    for NEW_POINT in ${EXTRAPOLATE_TO[@]}; do
        echo 'print sprintf("%.8f\t\t%f\t\t%f\t\t", '$NEW_POINT', f('$NEW_POINT'), f_err('$NEW_POINT'))' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    done
    echo 'print ""' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'set print "'$AUXILIARY_FILE'"' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'print "#'$LABEL_X'\t\t\t'$LABEL_Y'\t\t\t'$LABEL_DY'"' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    for NEW_POINT in ${EXTRAPOLATE_TO[@]}; do
        echo 'print sprintf("%.8f\t\t%f\t\t%f\t\t", '$NEW_POINT', f('$NEW_POINT'), f_err('$NEW_POINT'))' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    done
    echo 'set print' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
fi
unset -v 'i' 'NEW_POINT'

#==============================================================================================================
#==============================================================================================================

function RunGnuplotScript(){
    gnuplot $TMP_FILE_FOR_GNUPLOT_SCRIPT
}

function ProcessGnuplotResults(){
    EXTRQ=$(awk -v "mc=${MC}" 'BEGIN{b=sprintf("%.8f", mc)} $1==b{print $2}' $AUXILIARY_FILE)
    res=$(awk   -v "mc=${MC}" 'BEGIN{b=sprintf("%.8f", mc)} $1==b{print $3}' $AUXILIARY_FILE)
    if [[ ! $MC_ERR == 0 ]]; then
        EXTRQ1=$(awk -v "mc=${MC}" -v "mcErr=${MC_ERR}" 'BEGIN{b1=sprintf("%.8f", mc-mcErr)} $1==b1{print $2}' $AUXILIARY_FILE)
        EXTRQ2=$(awk -v "mc=${MC}" -v "mcErr=${MC_ERR}" 'BEGIN{b2=sprintf("%.8f", mc+mcErr)} $1==b2{print $2}' $AUXILIARY_FILE)
        res=$(awk -v "mc=${MC}" -v "mcErr=${MC_ERR}" 'BEGIN{b1=sprintf("%.8f", mc-mcErr); b2=sprintf("%.8f", mc+mcErr)} $1==b1{extrQ1=$2} $1==b2{extrQ2=$2} END{printf "%.8f", 0.5*(extrQ2 - extrQ1)}' $AUXILIARY_FILE)
    fi
    printf 'Results for the critical beta\n'
    printf '#%-12s %-12s %-12s %-12s\n' 'mC' 'mc_err' "$QUANT_NAME" "${QUANT_NAME}_err"
    printf '%.8f    %.8f   %.8f   %.8f\n\n' $MC $MC_ERR $EXTRQ ${res}
    EXTRACTEDCRITICALQUANT=(${EXTRACTEDCRITICALQUANT[@]} $EXTRQ)
    EXTRACTEDCRITICALERR=(${EXTRACTEDCRITICALQUANT[@]} ${res})
}


function CleanAuxiliaryFiles(){
    [[ -f fit.log ]] && rm fit.log
    [[ -f $AUXILIARY_FILE ]] && rm $AUXILIARY_FILE
    [[ -f $AUX_QUANT_DATA_FILENAME ]] && rm $AUX_QUANT_DATA_FILENAME
}

function CrossCheckCriticalBetasForLargestNs(){
    if (( ${#EXTRACTEDCRITICALQUANT[@]} > 1 )); then
        res=$(printf '%.6f\n' "$(bc -l <<< ${EXTRACTEDCRITICALQUANT[-1]}/2.-${EXTRACTEDCRITICALQUANT[-2]}/2.)")
        if (( $(echo "$res > ${EXTRACTEDCRITICALERR[-1]}" |bc -l) )); then
            printf 'The two largest ns available give significantly different values for the critical beta. Consider increasing statistics...\n'
        fi
    else
        printf "Cannot check the stability of the extracted result comparing the two largest ns values.\n"
    fi
    
    printf 'Saving results for the largest ns...\n\n'
    exec 3>&1 1>$OUTPUT_FILENAME
    printf '#%-5s %-5s  %-12s %-12s %-12s %-12s\n' 'Nf' 'nt' 'mC' 'mc_err' "$QUANT_NAME" "${QUANT_NAME}_err"
    printf '%-5s  %-5s  %.8f   %.8f   %.8f   %.8f\n' $NF $NT $MC $MC_ERR $EXTRQ ${EXTRACTEDCRITICALERR[-1]}
    exec 1>&3 3>&-
}

function ProcessInputFileForThePolynomialFit(){
    NS=($(awk 'NF>0 && NR>1 && /^[^#]/ {print $2}; ' $QUANT_DATA_FILENAME | sort -nu))
    for L in ${NS[@]}; do
        awk -v L=$L '$2==L{print}' $QUANT_DATA_FILENAME >> $AUX_QUANT_DATA_FILENAME

        if (( $(wc -l < $AUX_QUANT_DATA_FILENAME) < $((POLYNOMIAL_DEGREE+1)) )); then
            printf 'Skipping ns=%d because there are not enough data for a polynomial fit of the requested degree\n' $L
            CleanAuxiliaryFiles
        elif grep -q nan $AUX_QUANT_DATA_FILENAME; then
            printf 'Skipping ns=%d because there are nan\n' $L
            CleanAuxiliaryFiles
        else
            printf '\nPerforming polynomial fit for ns=%d\n' $L
            RunGnuplotScript
            ProcessGnuplotResults
            CleanAuxiliaryFiles
        fi
    done
    CrossCheckCriticalBetasForLargestNs
}

#==============================================================================================================

ProcessInputFileForThePolynomialFit
[[ -f $TMP_FILE_FOR_GNUPLOT_SCRIPT ]] && rm $TMP_FILE_FOR_GNUPLOT_SCRIPT

exit 0
