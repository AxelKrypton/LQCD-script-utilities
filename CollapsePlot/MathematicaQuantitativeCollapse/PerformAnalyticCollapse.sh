#!/bin/bash

#Wrapper script to run the mathematica code in a more friendly way.

#====================================================================================================
#Global variables
FLOAT_REGEX='[+-]?[0-9]+[.]?[0-9]*'
MATHEMATICA_SCRIPT_GLOBALPATH="${HOME}/Script/CollapsePlot/BashMathematica/PerformAnalyticCollapse.wl"
PRODUCE_DATA_FILES="FALSE"
RUN_ANALYTIC_COLLAPSE="TRUE"
BC_MIN=""
BC_MAX=""
BC_RES=""
NU_MIN=""
NU_MAX=""
NU_RES=""
DDX_MIN=""
DDX_MAX=""
DDX_RES=""
STANDARD_OUTPUT_FILE=""
FILENAMES=()

#Parse command line parameters
function ElementInArray() {
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

if ElementInArray "--help" $@ || ElementInArray "-h" $@; then
    printf "\e[38;5;202m\n\t"
    printf "This script slightly more than a wrapper for the mathematica calculation to perform the analytic\n\t"
    printf "collapse plot of the kurtosis of the imaginary part of the polyakov loop. It is far from being\n\t"
    printf "general and it assumes the format of files as that of the output of the python code. \n\t"
    printf "\n\t\e[38;5;13m\e[1m"
    printf "\e[4mPossible options to the script\e[24m:\e[21m\n\t\e[38;5;2m"
    printf "\n\t \e[1m-f | --filenames\e[21m           -> Specify the file(s) that have to be used by the script as input."
    printf "\n\t \e[1m\e[21m                              If given in combination with the option \e[1m-p\e[21m, the files are used to make a local"
    printf "\n\t \e[1m\e[21m                              modified copy, otherwise they are given as input to the mathematica script."
    printf "\n\t \e[1m-p | --produceDatafiles\e[21m    -> This option will make the script elaborate the files given using the -f option"
    printf "\n\t \e[1m\e[21m                              to produce the input files for the mathematica script. For each spatial volume,"
    printf "\n\t \e[1m\e[21m                              mathematica needs a file containing the {beta, kurtosis} data in two columns and"
    printf "\n\t \e[1m\e[21m                              one containing the {estimatorNumber, beta, kurtosis} data in three columns."
    printf "\n\t \e[1m\e[21m                              The file given to this script are those produced by the python code and therefore"
    printf "\n\t \e[1m\e[21m                              they have an header and many columns to be removed."
    printf "\n\t \e[1m-o | --stdOutput\e[21m           -> In this way it is possible to specify a name of a file to which the mathematica script" 
    printf "\n\t \e[1m\e[21m                              will print its output. If not given then the mathematica script will print to the shell."
    printf "\n\t \e[1m--bC\e[21m                       -> Use this option to specify the range and the resolution in beta to be used. Give them as a"
    printf "\n\t \e[1m\e[21m                              single command line parameter, i.e. do not forget the quotation marks: \"bCmin bCmax bCres\"."
    printf "\n\t \e[1m\e[21m                              Specify a zero resolution to make mathematica do a continuous scan (slower!)."
    printf "\n\t \e[1m--nu\e[21m                       -> Use this option to specify the range and the resolution in nu to be used. Give them as a"
    printf "\n\t \e[1m\e[21m                              single command line parameter, i.e. do not forget the quotation marks: \"nuMin nuMax nuRes\"."
    printf "\n\t \e[1m\e[21m                              Specify a zero resolution to make mathematica do a continuous scan (slower!)."
    printf "\n\t \e[1m--ddx\e[21m                      -> Use this option to specify the range and the resolution in the factor to be applied to DeltaX"
    printf "\n\t \e[1m\e[21m                              to be used. Give them as a single command line parameter, i.e. do not forget the quotation"
    printf "\n\t \e[1m\e[21m                              marks: \"ddxMin ddxMax ddxRes\"."
    printf "\n\n"
    printf "\e[38;5;13m\tNOTE: The options \e[1m--bC --nu --ddx\e[21m shall not be combined together with the -p option."
    printf "\n\n\e[0m"
    exit 0
fi

while [ "$1" != "" ]; do
    case $1 in
        --bC)
            if [[ $2 =~ ^${FLOAT_REGEX}[[:space:]]+${FLOAT_REGEX}[[:space:]]+${FLOAT_REGEX}$ ]]; then
                TEMPORARY_VARIABLE=( $2 )
                BC_MIN=${TEMPORARY_VARIABLE[0]}
                BC_MAX=${TEMPORARY_VARIABLE[1]}
                BC_RES=${TEMPORARY_VARIABLE[2]}
            else
                printf "\n\e[91m You did not correctly specify the \e[1m$1\e[21m option! Exiting...\e[0m\n\n" && exit -1
            fi
            shift
            ;;
        --nu )
            if [[ $2 =~ ^${FLOAT_REGEX}[[:space:]]+${FLOAT_REGEX}[[:space:]]+${FLOAT_REGEX}$ ]]; then
                TEMPORARY_VARIABLE=( $2 )
                NU_MIN=${TEMPORARY_VARIABLE[0]}
                NU_MAX=${TEMPORARY_VARIABLE[1]}
                NU_RES=${TEMPORARY_VARIABLE[2]}
            else
                printf "\n\e[91m You did not correctly specify the \e[1m$1\e[21m option! Exiting...\e[0m\n\n" && exit -1
            fi
            shift
            ;;
        --ddx )
            if [[ $2 =~ ^${FLOAT_REGEX}[[:space:]]+${FLOAT_REGEX}[[:space:]]+${FLOAT_REGEX}$ ]]; then
                TEMPORARY_VARIABLE=( $2 )
                DDX_MIN=${TEMPORARY_VARIABLE[0]}
                DDX_MAX=${TEMPORARY_VARIABLE[1]}
                DDX_RES=${TEMPORARY_VARIABLE[2]}
            else
                printf "\n\e[91m You did not correctly specify the \e[1m$1\e[21m option! Exiting...\e[0m\n\n" && exit -1
            fi
            shift
            ;;
        --bCmin )
            if [[ $2 =~ ^${FLOAT_REGEX}$ ]]; then
                BC_MIN=$2
                shift
            fi
            [ "$BC_MIN" = "" ] && printf "\n\e[91m You did not correctly specify the \e[1m$1\e[21m option! Exiting...\e[0m\n\n" && exit -1
            ;;
        --bCmax )
            if [[ $2 =~ ^${FLOAT_REGEX}$ ]]; then
                BC_MAX=$2
                shift
            fi
            [ "$BC_MAX" = "" ] && printf "\n\e[91m You did not correctly specify the \e[1m$1\e[21m option! Exiting...\e[0m\n\n" && exit -1
            ;;
        --bCres )
            if [[ $2 =~ ^${FLOAT_REGEX}$ ]]; then
                BC_RES=$2
                shift
            fi
            [ "$BC_RES" = "" ] && printf "\n\e[91m You did not correctly specify the \e[1m$1\e[21m option! Exiting...\e[0m\n\n" && exit -1
            ;;
        --nuMin )
            if [[ $2 =~ ^${FLOAT_REGEX}$ ]]; then
                NU_MIN=$2
                shift
            fi
            [ "$NU_MIN" = "" ] && printf "\n\e[91m You did not correctly specify the \e[1m$1\e[21m option! Exiting...\e[0m\n\n" && exit -1
            ;;
        --nuMax )
            if [[ $2 =~ ^${FLOAT_REGEX}$ ]]; then
                NU_MAX=$2
                shift
            fi
            [ "$NU_MAX" = "" ] && printf "\n\e[91m You did not correctly specify the \e[1m$1\e[21m option! Exiting...\e[0m\n\n" && exit -1
            ;;
        --nuRes )
            if [[ $2 =~ ^${FLOAT_REGEX}$ ]]; then
                NU_RES=$2
                shift
            fi
            [ "$NU_RES" = "" ] && printf "\n\e[91m You did not correctly specify the \e[1m$1\e[21m option! Exiting...\e[0m\n\n" && exit -1
            ;;
        --ddxMin )
            if [[ $2 =~ ^${FLOAT_REGEX}$ ]]; then
                DDX_MIN=$2
                shift
            fi
            [ "$DDX_MIN" = "" ] && printf "\n\e[91m You did not correctly specify the \e[1m$1\e[21m option! Exiting...\e[0m\n\n" && exit -1
            ;;
        --ddxMax )
            if [[ $2 =~ ^${FLOAT_REGEX}$ ]]; then
                DDX_MAX=$2
                shift
            fi
            [ "$DDX_MAX" = "" ] && printf "\n\e[91m You did not correctly specify the \e[1m$1\e[21m option! Exiting...\e[0m\n\n" && exit -1
            ;;
        --ddxRes )
            if [[ $2 =~ ^${FLOAT_REGEX}$ ]]; then
                DDX_RES=$2
                shift
            fi
            [ "$DDX_RES" = "" ] && printf "\n\e[91m You did not correctly specify the \e[1m$1\e[21m option! Exiting...\e[0m\n\n" && exit -1
            ;;
        -o | --stdOutput )
            if [[ $2 =~ ^[^-] ]]; then
                STANDARD_OUTPUT_FILE=$2
                shift
            fi
            ;;
        -f | --filenames )
            while [[ $2 =~ ^[^-] ]]; do
                FILENAMES+=( $2 )
                shift
            done
            ;;
        -p | --produceDatafiles )
            PRODUCE_DATA_FILES="TRUE"
            RUN_ANALYTIC_COLLAPSE="FALSE"
            ;;
        * ) printf "\n\e[38;5;9m Option \e[1m$1\e[21m invalid! Aborting...\n\n\e[0m"; exit -1
            #printf "\n\e[33m Value \e[1m$2\e[21m for option \e[1m$1\e[21m is invalid! Skipping it!\e[0m\n"
    esac
    shift
done

#====================================================================================================
#Checks on command line parameters
case ${#FILENAMES[@]} in
    0 ) 
        printf "\n\e[91m No data file specified! Aborting...\e[0m\n\n" && exit -1 ;;
    1 ) 
        if [ $RUN_ANALYTIC_COLLAPSE = "TRUE" ]; then
            printf "\n\e[91m Only one data file specified! At least two are needed! Aborting...\e[0m\n\n" && exit -1
        fi
        ;;
    * ) 
        ;;
esac

for FILE in ${FILENAMES[@]}; do
    if [ ! -f $FILE ]; then
        printf "\n\e[91m File \"$FILE\" not found! Aborting...\e[0m\n\n"
        exit -1
    fi
done

if [ $RUN_ANALYTIC_COLLAPSE = "TRUE" ]; then
    if [ "$BC_MIN" = "" ] || [ "$BC_MAX" = "" ] || [ "$BC_RES" = "" ] || [ "$NU_MIN" = "" ] || [ "$NU_MAX" = "" ] || [ "$NU_RES" = "" ] || [ "$DDX_MIN" = "" ] || [ "$DDX_MAX" = "" ] || [ "$DDX_RES" = "" ]; then
        printf "\n\e[91m At least one of the options \"--bC[min,max,res] --nu[Min,MaxRes] --ddx[Min,Max,Res]\" was not specified! Aborting...\e[0m\n\n"
        exit -1
    fi
    if [ $(bc -l <<< "$DDX_RES == 0") -eq 1 ]; then
        printf "\n\e[91m The resolution of ddx cannot be zero! Aborting...\e[0m\n\n"
        exit -1        
    fi
    if { [ $(bc -l <<< "$BC_RES != 0") -eq 1 ] && [ $(bc -l <<< "$NU_RES == 0") -eq 1 ]; } || { [ $(bc -l <<< "$BC_RES == 0") -eq 1 ] && [ $(bc -l <<< "$NU_RES != 0") -eq 1 ]; }; then
        printf "\n\e[91m The resolution of bC and nu must be at the moment either both zero or both different from zero! Aborting...\e[0m\n\n"
        exit -1        
    fi
fi

if [ $PRODUCE_DATA_FILES = "TRUE" ]; then
    if [ "$BC_MIN" != "" ] || [ "$BC_MAX" != "" ] || [ "$BC_RES" != "" ] || [ "$NU_MIN" != "" ] || [ "$NU_MAX" != "" ] || [ "$NU_RES" != "" ] || [ "$DDX_MIN" != "" ] || [ "$DDX_MAX" != "" ] || [ "$DDX_RES" != "" ]; then
        printf "\n\e[91m At least one of the options \"--bC[min,max,res] --nu[Min,MaxRes] --ddx[Min,Max,Res]\" was specified together with \"-p\" one! Aborting...\e[0m\n\n"
        exit -1
    fi
fi

#====================================================================================================
#Produce locally the data files for mathematica assuming that 
# 1) the beta and the kurtosis are in the columns 1 and 8 of the datafile
# 2) the estimator number, beta and kurtosis are in the columns 1, 2 and 9 of the estimator
#    file that has the same name as the data file with suffix "_estimators" before the extension (.dat)
# 3) the first line in the file is a comment and it is discarded
if [ $PRODUCE_DATA_FILES = "TRUE" ]; then
    for FILE in ${FILENAMES[@]}; do
        BASEFILENAME=${FILE##*/}
        if [ -f $BASEFILENAME ]; then
            printf "\n\e[0;33m \e[1m\e[4mWARNING\e[24m:\e[0;33m File \"$BASEFILENAME\" existing, creating a backup!\e[0m\n\n"
            mv $BASEFILENAME ${BASEFILENAME}_$(date "+%d-%m-%Y_%H%M")
            mv ${BASEFILENAME/.dat/_estimators.dat} ${BASEFILENAME/.dat/_estimators.dat}_$(date "+%d-%m-%Y_%H%M")
        fi
        awk 'NR>1 {printf "%s %s\n", $1, $8}' $FILE > $BASEFILENAME
        awk 'NR>1 {printf "%s %s %s\n", $1, $2, $9}' ${FILE/.dat/_estimators.dat} > ${BASEFILENAME/.dat/_estimators.dat}
    done
fi
#====================================================================================================
#Check locally if files exist
if [ $RUN_ANALYTIC_COLLAPSE = 'TRUE' ]; then
    if [ "$STANDARD_OUTPUT_FILE" = "" ]; then
        STANDARD_OUTPUT_FILE="stdout"
        $MATHEMATICA_SCRIPT_GLOBALPATH $BC_MIN $BC_MAX $BC_RES $NU_MIN $NU_MAX $NU_RES $DDX_MIN $DDX_MAX $DDX_RES $STANDARD_OUTPUT_FILE ${FILENAMES[@]##*/}
    else
        $MATHEMATICA_SCRIPT_GLOBALPATH $BC_MIN $BC_MAX $BC_RES $NU_MIN $NU_MAX $NU_RES $DDX_MIN $DDX_MAX $DDX_RES $STANDARD_OUTPUT_FILE ${FILENAMES[@]##*/} <<< "" &
        printf "\n\e[32m Calculation in mathematica started in background with pid ${!}\e[0m\n\n"
    fi
fi
#====================================================================================================
exit 0

#./PerformAnalyticCollapse.wl 5.33477 5.33477 0.01 0.37 0.39 0.02 0.1 0.2 0.1 out.txt k1650_ns16.dat k1650_ns20.dat k1650_ns24.dat 

