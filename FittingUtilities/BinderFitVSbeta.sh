#!/bin/bash

#######################################################################################
#
#   This fit script is suited to perform a multi-branch fit of the Binder cumulant 
#   of an observable specified by the user. The type of the fit is by default linear.
#   We assume that some information is included in the path from which this script
#   is called. In particular the mass (whose prefix can be either "k" or "mass") and
#   the temporal and spatial extensions of the lattice (prefixes "nt" and "ns").
#   The finite size scaling form used in the fit for the Binder Cumulant reads
#   
#                  B4(beta,ns) = B4(beta,ns=inf) + a*x + a^2*x^2 + ...
#
#   where x=(beta-betaC)*ns^(1/nu).
#
#######################################################################################

#Source auxiliary files
source "${HOME}/Script/FittingUtilities/CreateGnuplotBinderFitScript.sh" || exit -2

#Setting of the correct case based on the path.                                                                                                                                                                                                                                
STAGGERED="FALSE"
WILSON="FALSE"
[ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ] && STAGGERED="TRUE"
[ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ] && WILSON="TRUE"

#Check on path
if [ $STAGGERED = 'FALSE' ] && [ $WILSON = 'FALSE' ]; then
    printf "\n\e[0;31m Unable to choose between Wilson and Staggered from path! Aborting...\n\n\e[0m"
    exit -1
fi
if [ $STAGGERED = 'TRUE' ] && [ $WILSON = 'TRUE' ]; then
    printf "\n\e[0;31m Unable to choose between Wilson and Staggered from path! Aborting...\n\n\e[0m"
    exit -1
fi

#Variables connected to command line options
FIT_TYPE='linear'
BETA_RANGES=()
OBSERVABLE='poly_im_withZeroMean'
QUIET_MODE='TRUE'
COMMIT_MESSAGE='TRUE'
TEX_PLOT='FALSE'
PRODUCE_TEMPLATE='FALSE'

#Variables for the script
TMP_FILE_FOR_GNUPLOT_SCRIPT='FileThatHopefullyDoesNotExist.plt'
TMP_FILE_FOR_DATA_TO_BE_FITTED='DataToBeFitted.dat'
if [ $WILSON = 'TRUE' ]; then
    DATA_PATH_PREFIX='/home/phil-configs/wilson_nf2_muipi4/ImagMu'
    MASS_PREFIX='k'
elif [ $STAGGERED = 'TRUE' ]; then
    DATA_PATH_PREFIX='/home/phil-configs/Staggered/Nf2'
    MASS_PREFIX='mass'
fi

#Function to get the file global path given: mass, nt, ns, observable
function GetDatafileGlobalpath(){
    echo "$DATA_PATH_PREFIX/muiPiT/${MASS_PREFIX}${1}/nt${2}/ns${3}/muiPiT_${MASS_PREFIX}${1}_nt${2}_ns${3}_reweighting/muiPiT_${MASS_PREFIX}${1}_nt${2}_ns${3}_${4}_reweighted.dat"
}

#Parse command line parameters
function ElementInArray() {
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

if ElementInArray "--help" $@ || ElementInArray "-h" $@; then
    printf "\n\t\e[38;5;202m"
    printf "This script has to be called from a folder whose name contains\n\t"
    printf "the volumes that are being fitted in the form \"nsXX\" like for\n\t"
    printf "example \"gnuplot_fit_ns16_ns20_ns24\". Furthermore the parameters\n\t"
    printf "mass and nt are deduced from the path, i.e. there has to be in the\n\t"
    printf "path a folder named \"mass_prefix\"XXXX and ntY (with / before and after).\n\t"
    printf "\n\t\e[38;5;13m\e[1m"
    printf "Further option to the script:\e[21m\n\n\t\e[38;5;10m"
    printf "   -b | --betaRanges   ->   Beta ranges for the fit (given as pairs min max in order of increasing volumes)\n\t"
    printf "   -v | --verbose      ->   Print additional output during fit procedure\n\t"
    printf "   --quadratic         ->   Perform a quadratic fit instead of a linear one\n\t"
    printf "   --noCommit          ->   Do not print commit id to pdf\n\t"
    printf "   --tex               ->   Produce pdf via .tex in a nicer form\n\t"
    printf "   --produceTemplate   ->   Produce only gnuplot script template, NO FIT IS DONE!\n\t"
    printf "   --templateName      ->   Filename in which the gnuplot script is saved\n\t"
    printf "\n\t\e[38;5;27m"
    printf "\e[1m\e[4mNOTE\e[24m:\e[21m The option \e[38;5;10m--produceTemplate\e[38;5;27m can be combined with \e[38;5;10m--verbose\e[38;5;27m and\n\t"
    printf "      with \e[38;5;10m--quadratic\e[38;5;27m options. Any other option given in combination with it will be ignored.\n"
    printf "\n\t\e[38;5;9m"
    printf "\e[1m\e[4mATTENTION\e[24m:\e[21m The file specified by the option \e[38;5;10m--templateName\e[38;5;9m is \e[1moverwritten\e[21m if already existing!\n\t"
    printf "\n\e[0m"
    exit 3
fi

while [ "$1" != "" ]; do
    case $1 in
        --quadratic )
            FIT_TYPE='quadratic'
            shift
            ;;
        -b | --betaRanges )
            while [[ $2 =~ ^[+-]?[[:digit:]]+[.]?[[:digit:]]+$ ]]; do
                BETA_RANGES+=( $2 )
                shift
            done
            shift
            ;;
        -v | --verbose )
            QUIET_MODE='FALSE'
            shift
            ;;
        --noCommit )
            COMMIT_MESSAGE='FALSE'
            shift
            ;;
        --tex )
            TEX_PLOT='TRUE'
            shift
            ;;
        --produceTemplate )
            PRODUCE_TEMPLATE='TRUE'
            shift
            ;;
        --templateName )
            GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH=$2
            shift 2
            ;;
        * ) printf "\n\e[38;5;9m Option \e[1m$1\e[21m invalid! Aborting...\n\n\e[0m"; exit -1
    esac
done

#==============================================================================================================
#Read out from the path the parameters (do not check for multiple occurence!)
MASS=$(echo $PWD | grep -o "/$MASS_PREFIX[[:digit:]]*/" | grep -o "[[:digit:]]*")
[ "$MASS" == "" ] && printf "\n\e[0;31m Unable to recover mass parameter from path! Aborting...\n\n\e[0m" && exit -1
NTIME=$(echo $PWD | grep -o "/nt[[:digit:]]*/"); NTIME=${NTIME/\/nt/}; NTIME=${NTIME%?}
[ "$NTIME" == "" ] && printf "\n\e[0;31m Unable to recover nt from path! Aborting...\n\n\e[0m" && exit -1
VOLUMES=( $(basename $PWD | grep -o "ns[[:digit:]]*" | grep -o "[[:digit:]]*") )
[ ${#VOLUMES[@]} -eq 0 ] && printf "\n\e[0;31m Unable to recover volumes from directory name! Aborting...\n\n\e[0m" && exit -1
[ ${#VOLUMES[@]} -lt 1 ] && printf "\n\e[0;31m One volume is not enough to perform the fit! Aborting...\n\n\e[0m" && exit -1

#==============================================================================================================
#Checks on command line parameters
if [ $PRODUCE_TEMPLATE = 'FALSE' ]; then
    if [ ${#BETA_RANGES[@]} -ne $(( ${#VOLUMES[@]} * 2 )) ]; then
        printf "\n\e[0;31m $(( ${#VOLUMES[@]} * 2 )) values are needed to specify beta ranges where to fit for ${#VOLUMES[@]} volumes (${#BETA_RANGES[@]} were provided)! Aborting...\n\n\e[0m"
        exit -1
    fi
fi

#==============================================================================================================
#If template has to be produced, then produce it and exit
if [ $PRODUCE_TEMPLATE = 'TRUE' ]; then
    if [ ! ${GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH:+x} ]; then
        if [ $WILSON = 'TRUE' ]; then
            GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH="BinderFitTemplate_Wilson_${#VOLUMES[@]}volumes_${FIT_TYPE}.plt"
        elif [ $STAGGERED = 'TRUE' ]; then
            GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH="BinderFitTemplate_Staggered_${#VOLUMES[@]}volumes_${FIT_TYPE}.plt"
        fi
    fi       
    CreateGnuplotTemplateFitScriptWithoutPlotting
    exit
fi
#==============================================================================================================
#Produce datafile for gnuplot putting together data to be fitted from different volumes in the correct beta ranges
# NOTE: For the gnuplot multi range fit, the data coming from each volume should correspond to an index
#       in the gnuplot terminology. This means that the data coming from each volume must be separated
#       by 2 empty lines.
#
# We also use the for loop to fill min and max for fit
rm -f $TMP_FILE_FOR_DATA_TO_BE_FITTED
FIT_LOWER_BOUND=${BETA_RANGES[0]}
FIT_UPPER_BOUND=${BETA_RANGES[1]}
for INDEX in ${!VOLUMES[@]}; do
    BETA_MIN=${BETA_RANGES[$(($INDEX*2))]}
    BETA_MAX=${BETA_RANGES[$(($INDEX*2+1))]}
    awk -v betaMin="$BETA_MIN" -v betaMax="$BETA_MAX" '$1>=betaMin && $1<=betaMax{print $0}' $(GetDatafileGlobalpath $MASS $NTIME ${VOLUMES[$INDEX]} $OBSERVABLE) >> $TMP_FILE_FOR_DATA_TO_BE_FITTED
    printf "\n\n" >> $TMP_FILE_FOR_DATA_TO_BE_FITTED
    [ $(bc <<< "$BETA_MIN < $FIT_LOWER_BOUND") -eq 1 ] && FIT_LOWER_BOUND="$BETA_MIN"
    [ $(bc <<< "$BETA_MAX > $FIT_UPPER_BOUND") -eq 1 ] && FIT_UPPER_BOUND="$BETA_MAX"
done && unset -v 'BETA_MIN' 'BETA_MAX' 'INDEX'
#Check if there was any range without any data inside
if [ $(awk 'BEGIN{failed=0; lastEmptyLine=-1; num=0}/^$/{if(NR==lastEmptyLine+1){num++; if(num>1){failed=1; exit}}else{num=0}; lastEmptyLine=NR}END{print failed}' $TMP_FILE_FOR_DATA_TO_BE_FITTED) -eq 1 ]; then
    printf "\n\e[0;31m No data found for the given observable in some provided beta ranges! Aborting...\n\n\e[0m"
    exit -1
fi

#==============================================================================================================
#Create and run gnuplot script
if [ $FIT_TYPE = 'linear' ]; then
    OUTPUT_FILENAME='fit_linear_'$OBSERVABLE'_multiple_ranges'
elif [ $FIT_TYPE = 'quadratic' ]; then
    OUTPUT_FILENAME='fit_quadratic_'$OBSERVABLE'_multiple_ranges'
fi
if [ $TEX_PLOT = 'FALSE' ]; then
    OUTPUT_FILENAME=$OUTPUT_FILENAME'.pdf'
else
    OUTPUT_FILENAME=$OUTPUT_FILENAME'.tex'
fi
if [ $COMMIT_MESSAGE = 'TRUE' ]; then
    COMMIT_ID="commit $(git --git-dir=${HOME}/Script/.git log --pretty=format:"%H" -n 1 -- ${0##*Script/})"
fi
CreateGnuplotFitWithHardCodedParameters
gnuplot $TMP_FILE_FOR_GNUPLOT_SCRIPT
rm $TMP_FILE_FOR_GNUPLOT_SCRIPT
rm $TMP_FILE_FOR_DATA_TO_BE_FITTED
#==============================================================================================================
#In case compile tex file
if [ $TEX_PLOT = 'TRUE' ]; then
    pdflatex $OUTPUT_FILENAME 1>> /dev/null
    rm ${OUTPUT_FILENAME}
    rm ${OUTPUT_FILENAME/.tex/.log}
    rm ${OUTPUT_FILENAME/.tex/.aux}
fi

OUTPUT_FILENAME=${OUTPUT_FILENAME/$OBSERVABLE/all_$OBSERVABLE}
evince ${OUTPUT_FILENAME/.*/.pdf} &
exit 0
