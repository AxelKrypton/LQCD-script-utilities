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

#--------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source "$HOME/Script/PathManagement.sh" || exit -2
source "${HOME}/Script/FittingUtilities/CreateGnuplotBinderFitScript.sh" || exit -2
#--------------------------------------------------------------------------------#

#Having loaded PathManagement.sh we get for free all the parameters variables and functionalities
CheckWilsonStaggeredVariables

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
    DATA_PATH_PREFIX='/home/phil-configs/Staggered'
    MASS_PREFIX='mass'
fi

#Function to get the file global path given: mass, nt, ns, observable
function GetDatafileGlobalpath(){
    local PARAMS_STRING="$(GetParametersString $NFLAVOUR_PREFIX $CHEMPOT_PREFIX $MASS_PREFIX $NTIME_PREFIX)_${NSPACE_PREFIX}${1}"
    echo "$DATA_PATH_PREFIX$(GetParametersPath $NFLAVOUR_PREFIX $CHEMPOT_PREFIX $MASS_PREFIX $NTIME_PREFIX)/${NSPACE_PREFIX}${1}/${PARAMS_STRING}_reweighting/${PARAMS_STRING}_${OBSERVABLE}_reweighted.dat"
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
ReadSingleParameterFromPath $PWD $NFLAVOUR_PREFIX
ReadSingleParameterFromPath $PWD $CHEMPOT_PREFIX
ReadSingleParameterFromPath $PWD $MASS_PREFIX
ReadSingleParameterFromPath $PWD $NTIME_PREFIX
ReadSingleParameterFromPathWithMultipleOccurence ${PWD##*/} $NSPACE_PREFIX #Here read out from basename!
CheckParametersExtractedFromPath $NFLAVOUR_PREFIX $CHEMPOT_PREFIX $MASS_PREFIX $NTIME_PREFIX $NSPACE_PREFIX

#==============================================================================================================
#Extra checks on command line parameters
[ ${#NSPACE[@]} -eq 0 ] && printf "\n\e[0;31m Unable to recover volumes from directory name! Aborting...\n\n\e[0m" && exit -1
[ ${#NSPACE[@]} -lt 1 ] && printf "\n\e[0;31m One volume is not enough to perform the fit! Aborting...\n\n\e[0m" && exit -1

if [ $PRODUCE_TEMPLATE = 'FALSE' ]; then
    if [ ${#BETA_RANGES[@]} -ne $(( ${#NSPACE[@]} * 2 )) ]; then
        printf "\n\e[0;31m $(( ${#NSPACE[@]} * 2 )) values are needed to specify beta ranges where to fit for ${#NSPACE[@]} volumes (${#BETA_RANGES[@]} were provided)! Aborting...\n\n\e[0m"
        exit -1
    fi
fi

#==============================================================================================================
#If template has to be produced, then produce it and exit
if [ $PRODUCE_TEMPLATE = 'TRUE' ]; then
    if [ ! ${GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH:+x} ]; then
        if [ $WILSON = 'TRUE' ]; then
            GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH="BinderFitTemplate_Wilson_${#NSPACE[@]}volumes_${FIT_TYPE}.plt"
        elif [ $STAGGERED = 'TRUE' ]; then
            GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH="BinderFitTemplate_Staggered_${#NSPACE[@]}volumes_${FIT_TYPE}.plt"
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
for INDEX in ${!NSPACE[@]}; do
    BETA_MIN=${BETA_RANGES[$(($INDEX*2))]}
    BETA_MAX=${BETA_RANGES[$(($INDEX*2+1))]}
    awk -v betaMin="$BETA_MIN" -v betaMax="$BETA_MAX" '$1>=betaMin && $1<=betaMax{print $0}' $(GetDatafileGlobalpath ${NSPACE[$INDEX]}) >> $TMP_FILE_FOR_DATA_TO_BE_FITTED
    printf "\n\n" >> $TMP_FILE_FOR_DATA_TO_BE_FITTED
    [ $(bc <<< "$BETA_MIN < $FIT_LOWER_BOUND") -eq 1 ] && FIT_LOWER_BOUND="$BETA_MIN"
    [ $(bc <<< "$BETA_MAX > $FIT_UPPER_BOUND") -eq 1 ] && FIT_UPPER_BOUND="$BETA_MAX"
done && unset -v 'BETA_MIN' 'BETA_MAX' 'INDEX'
#Check if there was any range without any data inside
if [ ! -f $TMP_FILE_FOR_DATA_TO_BE_FITTED ] || 
   [ $(awk 'BEGIN{failed=0; lastEmptyLine=-1; num=0}/^$/{if(NR==lastEmptyLine+1){num++; if(num>1){failed=1; exit}}else{num=0}; lastEmptyLine=NR}END{print failed}' $TMP_FILE_FOR_DATA_TO_BE_FITTED) -eq 1 ]; then
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
    for TEX_FILE in *.tex; do
        pdflatex $TEX_FILE 1>> /dev/null
        rm ${TEX_FILE}
        rm ${TEX_FILE/.tex/.log}
        rm ${TEX_FILE/.tex/.aux}
    done
fi

OUTPUT_FILENAME=${OUTPUT_FILENAME/$OBSERVABLE/all_$OBSERVABLE}
#If variable DISPLAY is set and not empty (e.g. we are not in ssh without -X) open result
if [ ! -z ${DISPLAY:+x} ]; then
    evince ${OUTPUT_FILENAME/.tex/.pdf} &
fi
exit 0
