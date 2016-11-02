#!/bin/bash

# This script is intended to produce all the possible fits of the Binder.
# Run it with -h | --help to get information about how it works. 
# 
###################################################################################

#--------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source "$HOME/Script/PathManagement.sh" || exit -2
#--------------------------------------------------------------------------------#

function ElementInArray() {
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

function PrintArray(){
    local NAME_OF_THE_ARRAY=$1
    local INDEX=""
    [ $(eval echo "\${#$NAME_OF_THE_ARRAY[@]}") -eq 0 ] && echo "Array $NAME_OF_THE_ARRAY is empty!" && return
    for INDEX in $(eval echo "\${!$NAME_OF_THE_ARRAY[@]}"); do
        echo "$NAME_OF_THE_ARRAY[$INDEX]=$(eval echo "\${$NAME_OF_THE_ARRAY[$INDEX]}")"
    done
}

function PrintAllPossibleRangesCombinations() {
    if (( $1 < 1 )); then
        for INDEX in $(eval echo "\${!RANGES${NSPACE[$1]}[@]}"); do
            ARRAY_TMP[$1]=$(eval echo "\${RANGES${NSPACE[$1]}[$INDEX]}")
            echo "${ARRAY_TMP[@]}"
        done
    else
        for INDEX in $(eval echo "\${!RANGES${NSPACE[$1]}[@]}"); do
            ARRAY_TMP[$1]=$(eval echo "\${RANGES${NSPACE[$1]}[$INDEX]}")
            printf "$(PrintAllPossibleRangesCombinations $(( $1 - 1 )))\n" >> $ALL_BETA_RANGES_FILENAME
        done
    fi
}

function GetBetaValuesWithAwk() {
    AWK_VARIABLES=$1
    FILE_TO_PROCESS=$2
    awk $AWK_VARIABLES '
    /^[ #]+/{next}
    {
        if(useRawData == "TRUE")
        {
            if($2 == "merged" && (length(min) == 0 ? 1 : $1 >= min) && (length(max) == 0 ? 1 : $1 <= max)){printf "%.4f\n", $1}
        }
        else 
        {
            if((length(min) == 0 ? 1 : $1 >= min) && (length(max) == 0 ? 1 : $1 <= max)){printf "%.6f\n", $1}
        }
    }' $FILE_TO_PROCESS   
}

#================================================================================================================================

function ParseCommandLineOptions() {
    while [ "$1" != "" ]; do
        case $1 in
            -H  | --getMoreInformation )
                printf "\n\e[38;5;208m"
                printf "\tThis script is supposed to make all possible fits of the Binder Cumulant\n"
                printf "\tfor given kappa, nt, and volumes. It consists of the following few steps.\n"
                echo ""
                printf "\t1) All the beta values for each volume are read from the reweigthed data files (that\n"
                printf "\t   must be in the folder specified via the \e[38;5;228m--dataPathPrefix\e[38;5;208m option vith subfolders \n"
                printf "\t   \"kXXXX/ntX/nsXX/muiPiT_kXXXX_ntX_nsXX_reweighting/\" and filename\n"
                printf "\t   \"muiPiT_kXXXX_ntX_nsXX_\${OBSERVABLE_NAME}_reweighted.dat\"). If the options\n"
                printf "\t   \e[0;32m--betaMin\e[38;5;208m and/or \e[0;32m--betaMax\e[38;5;208m are given, then only the beta values in the correct\n"
                printf "\t   range are read from the reweigthed data files. Note that the user can specify\n"
                printf "\t   one value (that is then applied to all volumes) or as many as the considered volumes\n"
                printf "\t   (in this case the first value is used for the smallest volume, etc.). Afterwards, all the\n"
                printf "\t   possible fit beta ranges are calculated, volume after volume. Only some are\n"
                printf "\t   temporary saved:\n"
                printf "\t    - if the option \e[0;32m--minNumDataPerVolume\e[38;5;208m is given, all ranges not fulfilling\n"
                printf "\t      such a condition are ignored;\n"
                printf "\t    - if the option \e[0;32m--betaToBeFitAround\e[38;5;208m is used to specify a beta critical value,\n"
                printf "\t      then all the ranges not including it will be not saved;\n"
                printf "\t    - the option \e[0;32m--allowedAsymmetryPercentage\e[38;5;208m can be used to specify a maximum level of\n"
                printf "\t      allowed asymmetry of the range with respect to the beta value to be fitted around.\n"
                printf "\t      The asymmetry is defined as \e[38;5;141mabs((betaMin - betaToBeFitAround)/(betaMax - betaMin) - 0.5)\e[38;5;208m\n"
                printf "\t      and it is calculated for all the possible ranges per volume. It is a number between\n"
                printf "\t      0 and 50. When it exceeds the maximum allowed value specified by the user, then the\n"
                printf "\t      correspondent range is ignored.\n"
                printf "\t   Then all the possible combinations of the valid fit ranges per volume are produced\n"
                printf "\t   and saved in the file specified via the \e[0;32m--allRangesFilename\e[38;5;208m option. If this file\n"
                printf "\t   already exists (and the option \e[0;32m--doNotReuseBetaRanges\e[38;5;208m has not been given), it is \n"
                printf "\t   tried to be reused. In this case a check on the number of lines is done: if such\n"
                printf "\t   a check fails, the file is overwritten with the correct one. Otherwise it is used,\n"
                printf "\t   but a warning is printed to the user, since the performed check does not ensure\n"
                printf "\t   that the existing file is correct.\n"
                echo ""
                printf "\tThe script can be here interrupted using the \e[38;5;13m--produceOnlyAllBetaRanges\e[38;5;208m option.\n"
                echo ""
                printf "\t2) A filtering procedure is run on all the possible beta ranges:\n"
                printf "\t    - if a set of ranges contains in total a number of points smaller than or equal to the\n"
                printf "\t      number of fit parameters (specified via \e[38;5;228m--fitParameters\e[38;5;208m) is ignored;\n"
                printf "\t    - the ranges on higher volumes should be included in all those of smaller\n"
                printf "\t      volumes, otherwise they are discarded (use \e[0;32m--deactivatePyramidRanges\e[38;5;208m\n"
                printf "\t      option to deactivate this rule).\n"
                printf "\t   The ranges that survive to the filtering procedure are saved into the file given\n"
                printf "\t   via the \e[38;5;13m--rangesToBeFittedFilename\e[38;5;208m option. This option can be also used to make\n"
                printf "\t   fits using different kind of beta ranges (however in the file there must be as\n"
                printf "\t   many columns as the number of volumes times 2).\n"
                echo ""
                printf "\tThe script can be here interrupted using the \e[38;5;13m--produceOnlyFilteredBetaRanges\e[38;5;208m option.\n"
                echo ""
                printf "\t3) The gnuplot script given via \e[38;5;228m--fitFilenameGlobalpath\e[38;5;208m is called on each valid\n"
                printf "\t   beta range (those contained in the \e[0;32m--rangesToBeFittedFilename\e[38;5;208m file).\n"
                printf "\t   All the fit results are added to the file given via \e[0;32m--fitResultsStdout\e[38;5;208m\n"
                printf "\t   (and the stderr is put in \e[0;32m--fitResultsStderr\e[38;5;208m). Such results are filtered\n"
                printf "\t   deleting the bad fits (goodness of the fit smaller then P or bigger than\n"
                printf "\t   100-P where P is given via \e[0;32m--rejectionPercentage\e[38;5;208m). If any file\n"
                printf "\t   already exists it is renamed to a file with the same name and the date as\n"
                printf "\t   postfix. In this way the fit results file has always the same structure and\n"
                printf "\t   can be further filtered afterwards.\n"
                echo ""
                printf "\tDuring the fitting part, a progress status bar is displayed. Though very useful\n"
                printf "\tto know the status of the script, it could slow down the script. That's why one can\n"
                printf "\ttune the update frequency via the \e[0;32m--progressBarUpdateFreq\e[38;5;208m option\n"
                printf "\t(such a frequency must be integer).\n"
                echo ""
                printf "\tThis script has to be called from a folder whose name contains\n"
                printf "\tthe sorted volumes that are being fitted in the form \"nsXX\" like for\n"
                printf "\texample \"gnuplot_fit_ns16_ns20_ns24\". Furthermore the parameters\n"
                printf "\tkappa and nt are deduced from the path, i.e. there has to be in the\n"
                printf "\tpath a folder named kXXXX and ntY (with / before and after).\n"
                printf "\n\e[0m"
                exit
                shift;;
            -h | --help )
                printf "\n\e[0;36m"
                echo "Call the script $0 with the following optional arguments:"
                echo -e "\e[38;5;208m  -H | --getMoreInformation        ->    to get an explanation of how the script works\e[0;32m"
                echo -e "\e[38;5;228m  --fitFilenameGlobalpath          ->    if not given, the gnuplot script is automatically generated"
                echo -e "  --dataPathPrefix                 ->    default value = $DATA_PATH_PREFIX"
                echo -e "  --fitParameters                  ->    defualt value = $NUMBER_OF_FIT_PARAMETERS"
                echo -e "  --fitType                        ->    defualt value = $FIT_TYPE"
                echo -e "  --observableName                 ->    default value = $OBSERVABLE_NAME"
                echo -e "\e[0;32m  --allBetaRangesFilename          ->    default value = $ALL_BETA_RANGES_FILENAME "
                echo -e "  --doNotReuseBetaRanges           ->    default value = $DO_NOT_REUSE_BETA_RANGES"
                echo -e "  --rangesToBeFittedFilename       ->    default value = $BETA_RANGES_TO_BE_FITTED"
                echo -e "  --fitResultsStdout               ->    default value = $FIT_RESULTS_STDOUT"
                echo -e "  --fitResultsStderr               ->    default value = $FIT_RESULTS_STDERR"
                echo -e "  --minNumDataPerVolume            ->    default value = $MINIMUM_NUMBER_OF_DATAPOINTS_PER_VOLUME"
                echo -e "  --betaMin                        ->    default value = unset (not taken into account)"
                echo -e "  --betaMax                        ->    default value = unset (not taken into account)"
                echo -e "  --betaToBeFitAround              ->    default value = unset (not taken into account)"
                echo -e "  --allowedAsymmetryPercentage     ->    default value = unset (i.e. any asymmetry is allowed)"
                echo -e "  --deactivatePyramidRanges        ->    if given, do not apply pyramid filtering"
                echo -e "  --useRawData                     ->    if given, the raw instead of the reweighted data is fitted"
                echo -e "  --numberOfFitsDoneInParallel     ->    default value = $NUMBER_OF_FIT_TO_BE_DONE_IN_PARALLEL"
                echo -e "  --rejectionPercentage            ->    default value = $REJECTION_PERCENTAGE"
                echo -e "  --progressBarUpdateFreq          ->    default value = $PROGRESS_BAR_UPDATE_FREQUENCY (integer, in %)"
                echo -e "\e[38;5;13m  --produceOnlyAllBetaRanges       ->    if given, produce only beta ranges"
                echo -e "  --produceOnlyFilteredBetaRanges  ->    if given, produce and filter beta ranges"
                echo -e "  --useRangesToBeFittedFile        ->    if given, only fitting part is done"
                echo ""
                echo -e "\e[1m\e[4;36mNOTE\e[0;36m: The \e[38;5;13mmagenta\e[0;36m options are mutually exclusive!"
                echo -e "\e[0;36m      The \e[38;5;228mcream\e[0;36m options rely on external information: change them consciously!"
                echo -e ""
                echo -e "\e[1m\e[4;31mATTENTION\e[0m\e[38;5;196m: All the options that require a value must be specified without spaces,"
                echo -e "           like --option=value. Those that could accept more than one value must be given without equal sign,"
                echo -e "           like --option value1 value2 or --option value in case just one value is given."
                printf "\n\e[0m"
                exit
                shift;;
            --fitFilenameGlobalpath=* )        FIT_GLOBALPATH=${1#*=}; USE_RAW_DATA="FALSE" shift ;;
            --dataPathPrefix=* )               DATA_PATH_PREFIX=${1#*=}; shift ;;
            --fitParameters=* )                NUMBER_OF_FIT_PARAMETERS=${1#*=}; shift ;;
            --fitType=* )                      FIT_TYPE=${1#*=}; shift ;;
            --observableName=* )               OBSERVABLE_NAME=${1#*=}; shift ;;
            --allBetaRangesFilename=* )        ALL_BETA_RANGES_FILENAME=${1#*=}; shift ;;
            --doNotReuseBetaRanges )           DO_NOT_REUSE_BETA_RANGES="TRUE"; shift ;;
            --rangesToBeFittedFilename=* )     BETA_RANGES_TO_BE_FITTED=${1#*=}; shift ;;
            --fitResultsStdout=* )             FIT_RESULTS_STDOUT=${1#*=}; shift ;;
            --fitResultsStderr=* )             FIT_RESULTS_STDERR=${1#*=}; shift ;;
            --minNumDataPerVolume=* )          MINIMUM_NUMBER_OF_DATAPOINTS_PER_VOLUME=${1#*=}; shift ;;
            --betaToBeFitAround=* )            BETA_TO_BE_INCLUDED_IN_RANGES="${1#*=}"; shift ;;
            --allowedAsymmetryPercentage=* )   ALLOWED_ASYMMETRY_PERCENTAGE="${1#*=}"; shift ;;
            --deactivatePyramidRanges )        DEACTIVATE_PYRAMID_RANGES="TRUE"; shift ;;
            --useRawData )                     USE_RAW_DATA="TRUE"; FIT_FILENAME="fit_gnuplot_raw.plt"; shift;;
            --numberOfFitsDoneInParallel=* )   NUMBER_OF_FIT_TO_BE_DONE_IN_PARALLEL=${1#*=}; shift ;;
            --rejectionPercentage=* )          REJECTION_PERCENTAGE=${1#*=}; shift ;;
            --progressBarUpdateFreq=* )        PROGRESS_BAR_UPDATE_FREQUENCY=${1#*=}; shift ;;
            --produceOnlyAllBetaRanges )       PRODUCE_ONLY_ALL_BETA_RANGES="TRUE"; MUTUALLYEXCLUSIVEOPTS_PASSED+=( "$1" ); shift ;;
            --produceOnlyFilteredBetaRanges )  PRODUCE_ONLY_FILTERED_BETA_RANGES="TRUE"; MUTUALLYEXCLUSIVEOPTS_PASSED+=( "$1" ); shift ;;
            --useRangesToBeFittedFile )        USE_RANGES_TO_BE_FITTED_FILE="TRUE"; MUTUALLYEXCLUSIVEOPTS_PASSED+=( "$1" ); shift ;;
            --betaMin )
                while [[ "$2" =~ ^[[:digit:]]+[.]?[[:digit:]]*$ ]]; do
                BETA_MINIMUM_TO_BE_CONSIDERED+=( $2 );
                shift
                done
                shift ;;
            --betaMax )
                while [[ "$2" =~ ^[[:digit:]]+[.]?[[:digit:]]*$ ]]; do
                BETA_MAXIMUM_TO_BE_CONSIDERED+=( $2 );
                shift
                done
                shift ;;

            * ) printf "\n\e[0;31m Invalid option \e[1m$1\e[0;31m (see help for further information)! Aborting...\n\n\e[0m" ; exit -1 ;;
        esac

        if [ ${#MUTUALLYEXCLUSIVEOPTS_PASSED[@]} -gt 1 ]; then  
            printf "\n\e[0;31m The options\n\n\e[1m" 
            for OPT in "${MUTUALLYEXCLUSIVEOPTS[@]}"; do
                printf "  %s\n" "$OPT"
            done
            printf "\n\e[0;31m are mutually exclusive and must not be combined! Aborting...\n\n\e[0m" 
            exit -1
        fi
    done
}

#================================================================================================================================
#Having loaded PathManagement.sh we get for free all the parameters variables and functionalities
CheckWilsonStaggeredVariables
if [ $WILSON = 'TRUE' ]; then
    DATA_PATH_PREFIX='/home/phil-configs/wilson_nf2_muipi4/ImagMu'
elif [ $STAGGERED = 'TRUE' ]; then
    DATA_PATH_PREFIX='/home/phil-configs/Staggered'
fi
#Declare constant variables and check on file existence
MUTUALLYEXCLUSIVEOPTS=( "--produceOnlyBetaRanges" "--produceOnlyFilteredBetaRanges" "--useRangesToBeFittedFile")
MUTUALLYEXCLUSIVEOPTS_PASSED=( )
FIT_GLOBALPATH=""
OBSERVABLE_NAME="poly_im_withZeroMean"
ALL_BETA_RANGES_FILENAME="AllPossibleBetaRanges"
BETA_RANGES_TO_BE_FITTED="BetaRangesToBeFitted"
USE_RANGES_TO_BE_FITTED_FILE="FALSE"
FIT_RESULTS_STDOUT="FitByBruteForce.dat"
FIT_RESULTS_STDERR="FitByBruteForce.err"
FIT_TYPE="linear"
NUMBER_OF_FIT_PARAMETERS=4
MINIMUM_NUMBER_OF_DATAPOINTS_PER_VOLUME=1
REJECTION_PERCENTAGE=0
DO_NOT_REUSE_BETA_RANGES="FALSE"
PRODUCE_ONLY_ALL_BETA_RANGES="FALSE"
PRODUCE_ONLY_FILTERED_BETA_RANGES="FALSE"
DEACTIVATE_PYRAMID_RANGES="FALSE"
PROGRESS_BAR_UPDATE_FREQUENCY=1 #In percentage
TEMPORARY_FILE_WITH_GNUPLOT_COMMANDS="TemporaryFileWithGnuplotCommandsThatHopefullyDoesNotExist"
BETA_MINIMUM_TO_BE_CONSIDERED=()
BETA_MAXIMUM_TO_BE_CONSIDERED=()
NUMBER_OF_FIT_TO_BE_DONE_IN_PARALLEL=70
#-----------------------------------------------------------------
if ElementInArray "--help" $@ || ElementInArray "-h" $@; then
    SPECIFIED_COMMAND_LINE_OPTIONS=( "--help" )
elif ElementInArray "-H" $@; then
    SPECIFIED_COMMAND_LINE_OPTIONS=( "-H" )
else
    SPECIFIED_COMMAND_LINE_OPTIONS=( $@ )
fi
ParseCommandLineOptions ${SPECIFIED_COMMAND_LINE_OPTIONS[@]}
BINDER_FIT_GLOBALPATH="${HOME}/Script/BinderFit/BinderFitVSbeta.sh"
#================================================================================================================================
#Read out from the path the parameters (do not check for multiple occurence!)
ReadSingleParameterFromPath $PWD $NFLAVOUR_PREFIX
ReadSingleParameterFromPath $PWD $CHEMPOT_PREFIX
ReadSingleParameterFromPath $PWD $MASS_PREFIX
ReadSingleParameterFromPath $PWD $NTIME_PREFIX
ReadSingleParameterFromPathWithMultipleOccurence ${PWD##*/} $NSPACE_PREFIX #Here read out from basename!
CheckParametersExtractedFromPath $NFLAVOUR_PREFIX $CHEMPOT_PREFIX $MASS_PREFIX $NTIME_PREFIX $NSPACE_PREFIX

#=================================================================================================================================
#Checks on variables
if [ "$FIT_GLOBALPATH" != "" ] && [ ! -f $FIT_GLOBALPATH ]; then
    printf "\n\e[0;31m File \"$FIT_GLOBALPATH\" not found! Aborting...\n\n\e[0m"
    exit -1
fi
if [ ! -d $DATA_PATH_PREFIX ]; then
    printf "\n\e[0;31m Directory \"$DATA_PATH_PREFIX\" not found! Aborting...\n\n\e[0m"
    exit -1
fi
#This check could be avoided just sorting the volumes, in any case volumes MUST be sorted for pyramid check!
if ! $(for VOL in "${NSPACE[@]}"; do echo "$VOL"; done | sort -C); then
    printf "\n\e[0;31m Volumes extracted from directory \"$(basename $PWD)\" not sorted, rename it! Aborting...\n\n\e[0m"
    exit -1
fi
#Set global data paths
for VOL in ${NSPACE[@]}; do
    PARAMS_STRING="$(GetParametersString $NFLAVOUR_PREFIX $CHEMPOT_PREFIX $MASS_PREFIX $NTIME_PREFIX)_${NSPACE_PREFIX}${VOL}"
    if [ "$USE_RAW_DATA" = "TRUE" ]; then
        DATA_GLOBALPATH[$VOL]="${DATA_PATH_PREFIX}$(GetParametersPath $NFLAVOUR_PREFIX $CHEMPOT_PREFIX $MASS_PREFIX $NTIME_PREFIX)/${NSPACE_PREFIX}${VOL}/${PARAMS_STRING}_analysis/${PARAMS_STRING}_observables_${OBSERVABLE_NAME}.dat"
    else
        DATA_GLOBALPATH[$VOL]="${DATA_PATH_PREFIX}$(GetParametersPath $NFLAVOUR_PREFIX $CHEMPOT_PREFIX $MASS_PREFIX $NTIME_PREFIX)/${NSPACE_PREFIX}${VOL}/${PARAMS_STRING}_reweighting/${PARAMS_STRING}_${OBSERVABLE_NAME}_reweighted.dat"
    fi
    if [ ! -f ${DATA_GLOBALPATH[$VOL]} ]; then
        printf "\n\e[0;31m File \"${DATA_GLOBALPATH[$VOL]}\" not found! Aborting...\n\n\e[0m"
        exit -1
    fi
done
if [ $USE_RANGES_TO_BE_FITTED_FILE = "TRUE" ] && [ ! -f $BETA_RANGES_TO_BE_FITTED ]; then
    printf "\n\e[0;31m Asked to use beta ranges from file \"$BETA_RANGES_TO_BE_FITTED\", but the file has not been found! Aborting...\n\n\e[0m"
    exit -1
fi
if [[ ! $PROGRESS_BAR_UPDATE_FREQUENCY =~ ^[[:digit:]]+$ ]]; then
    printf "\n\e[0;31m Option --progressBarUpdateFreq requires an integer number! Aborting...\n\n\e[0m"
    exit -1
fi
#Checks on beta min and max
if [ ${#BETA_MINIMUM_TO_BE_CONSIDERED[@]} -gt 1 ] && [ ${#BETA_MINIMUM_TO_BE_CONSIDERED[@]} -ne ${#NSPACE[@]} ]; then 
    printf "\n\e[0;31m Option --betaMin requires either one beta value or as many as the number of volumes! Aborting...\n\n\e[0m"
    exit -1
fi
if [ ${#BETA_MAXIMUM_TO_BE_CONSIDERED[@]} -gt 1 ] && [ ${#BETA_MAXIMUM_TO_BE_CONSIDERED[@]} -ne ${#NSPACE[@]} ]; then 
    printf "\n\e[0;31m Option --betaMax requires either one beta value or as many as the number of volumes! Aborting...\n\n\e[0m"
    exit -1
fi
#Check that if asymmetryPercentageAllowed is given then betaToBeFitAround has also been given
if  [ ${ALLOWED_ASYMMETRY_PERCENTAGE:+x} ]; then
    if [ ! ${BETA_TO_BE_INCLUDED_IN_RANGES:+x} ]; then #${VAR:+x} means VAR is defined and not ""
        printf "\n\e[0;31m Option --allowedAsymmetryPercentage is a secondary option of --betaToBeFitAround which was not given! Aborting...\n\n\e[0m"
        exit -1
    elif  [[ ! $ALLOWED_ASYMMETRY_PERCENTAGE =~ ^[[:digit:]]{1,2}[.]?[[:digit:]]*$ ]] || [ $(bc -l <<< "$ALLOWED_ASYMMETRY_PERCENTAGE > 50") -eq 1 ]; then
        printf "\n\e[0;31m Option --allowedAsymmetryPercentage invalid (it must a number x with 0<=x<=50)! Aborting...\n\n\e[0m"
        exit -1    
    fi
fi
#Check on NUMBER_OF_FIT_TO_BE_DONE_IN_PARALLEL
if [[ ! $NUMBER_OF_FIT_TO_BE_DONE_IN_PARALLEL =~ ^[1-9][[:digit:]]*$ ]]; then
    printf "\n\e[0;31m Option --numberOfFitsDoneInParallel invalid (it must an integer number without leading zero)! Aborting...\n\n\e[0m"
    exit -1    
fi
#=================================================================================================================================
printf "\n\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)-5)) ))\n\e[0m"
#Read out from the file the beta values that must be in the first column
#NOTE: I have to check how many betas have been given and build an array with the value in the entry with the VOL label
if [ ${#BETA_MINIMUM_TO_BE_CONSIDERED[@]} -eq 0 ]; then
    unset -v 'BETA_MINIMUM_TO_BE_CONSIDERED'
else
    if [ ${#BETA_MINIMUM_TO_BE_CONSIDERED[@]} -eq 1 ]; then
        for VOL in ${NSPACE[@]}; do TMP_ARRAY[$VOL]=${BETA_MINIMUM_TO_BE_CONSIDERED[0]}; done
    else
        for INDEX in ${!NSPACE[@]}; do TMP_ARRAY[${NSPACE[$INDEX]}]=${BETA_MINIMUM_TO_BE_CONSIDERED[$INDEX]}; done
    fi
    unset -v 'BETA_MINIMUM_TO_BE_CONSIDERED'    
    for VOL in ${NSPACE[@]}; do BETA_MINIMUM_TO_BE_CONSIDERED[$VOL]=${TMP_ARRAY[$VOL]}; done
    unset -v 'TMP_ARRAY'
fi

if [ ${#BETA_MAXIMUM_TO_BE_CONSIDERED[@]} -eq 0 ]; then
    unset -v 'BETA_MAXIMUM_TO_BE_CONSIDERED'
else
    if [ ${#BETA_MAXIMUM_TO_BE_CONSIDERED[@]} -eq 1 ]; then
        for VOL in ${NSPACE[@]}; do TMP_ARRAY[$VOL]=${BETA_MAXIMUM_TO_BE_CONSIDERED[0]}; done
    else
        for INDEX in ${!NSPACE[@]}; do TMP_ARRAY[${NSPACE[$INDEX]}]=${BETA_MAXIMUM_TO_BE_CONSIDERED[$INDEX]}; done
    fi
    unset -v 'BETA_MAXIMUM_TO_BE_CONSIDERED'    
    for VOL in ${NSPACE[@]}; do BETA_MAXIMUM_TO_BE_CONSIDERED[$VOL]=${TMP_ARRAY[$VOL]}; done
    unset -v 'TMP_ARRAY'
fi

for VOL in ${NSPACE[@]}; do
    if [ ${#BETA_MINIMUM_TO_BE_CONSIDERED[@]} -ne 0 ] && [ ${#BETA_MAXIMUM_TO_BE_CONSIDERED[@]} -ne 0 ]; then
        if [ $(bc <<< "${BETA_MINIMUM_TO_BE_CONSIDERED[$VOL]} > ${BETA_MAXIMUM_TO_BE_CONSIDERED[$VOL]}") -eq 1 ]; then
            read BETA_MINIMUM_TO_BE_CONSIDERED[$VOL] BETA_MAXIMUM_TO_BE_CONSIDERED[$VOL] <<< "${BETA_MAXIMUM_TO_BE_CONSIDERED[$VOL]} ${BETA_MINIMUM_TO_BE_CONSIDERED[$VOL]}"
        fi
    fi
    #If BETA_MINIMUM_TO_BE_CONSIDERED[$VOL] and/or BETA_MAXIMUM_TO_BE_CONSIDERED[$VOL] are not definied or empty, awk will handle this.
    AWK_VARIABLE_STRING="-v min=${BETA_MINIMUM_TO_BE_CONSIDERED[$VOL]} -v max=${BETA_MAXIMUM_TO_BE_CONSIDERED[$VOL]} -v useRawData=$USE_RAW_DATA"
    #The variable AWK_VARIABLE_STRING must be quoted in order for awk to work with it.
    BETAS[$VOL]=$(GetBetaValuesWithAwk "$AWK_VARIABLE_STRING" ${DATA_GLOBALPATH[$VOL]})
    if [ ${#BETAS[$VOL]} -eq 0 ]; then
        printf "\n\e[0;31m Error retrieving beta values for ns${VOL} (no valid value found)! Aborting...\n\n\e[0m"
        exit -1
    fi
    NUMBER_OF_BETAS[$VOL]=$(( $(grep -o " " <<< ${BETAS[$VOL]} | wc -l) + 1 ))
done

if [ $USE_RANGES_TO_BE_FITTED_FILE = "FALSE" ]; then
    # Create all the possible combinations of beta_min and beta_max for each volume.
    #
    # NOTE: Since the number of volumes is variable, then it is not at all easy to
    #       get it work in general! Here it was achieved using eval to append the 
    #       volume to the name of the variable!
    #
    # Now, for efficiency reason (for big numbers the recursive function called below can 
    # need days), it is better to apply some filtering here. Basically the filtering set
    # by --minNumDataPerVolume and --betaToBeFitAround can be done here.
    printf "\e[0;36m Creating all possible ranges per volume...\n\e[0m"
    NUMBER_ALL_POSSIBLE_BETA_RANGES=1
    TOTAL_NUMBER_OF_FITS_PER_VOLUME=()
    RANGES_DIM=""
    for VOL in ${NSPACE[@]}; do
        SKIPPED_FITS_BETA_OUT[$VOL]=0
        SKIPPED_FITS_LACK_POINTS[$VOL]=0
        SKIPPED_FITS_ASYMMETRY[$VOL]=0
        printf "\e[0;35m  - ns$VOL  \e[0m"
        for BETA_MIN in ${BETAS[$VOL]}; do
            for BETA_MAX in ${BETAS[$VOL]}; do
                if [ $(bc -l <<< "$BETA_MIN <= $BETA_MAX") -eq 1 ]; then
                    #If beta is not in the range skip
                    if [ ${BETA_TO_BE_INCLUDED_IN_RANGES:+x} ]; then #this means if BETA_TO_BE_INCLUDED_IN_RANGES is defined and not ""
                        if [ $(bc -l <<< "$BETA_MIN <= $BETA_TO_BE_INCLUDED_IN_RANGES && $BETA_TO_BE_INCLUDED_IN_RANGES <= $BETA_MAX") -eq 0 ]; then
                            (( SKIPPED_FITS_BETA_OUT[$VOL]++ ))
                            continue
                        fi
                        if [ $BETA_MIN != $BETA_MAX ] && [ ${ALLOWED_ASYMMETRY_PERCENTAGE:+x} ]; then # betaMin != betaMax since in this case I would divide by zero
                            if [ $(bc -l <<< "sqrt(((($BETA_TO_BE_INCLUDED_IN_RANGES - $BETA_MIN)/($BETA_MAX - $BETA_MIN)) - 0.5)^2)*100 <= $ALLOWED_ASYMMETRY_PERCENTAGE") -eq 0 ]; then
                            (( SKIPPED_FITS_ASYMMETRY[$VOL]++ ))
                            continue
                            fi
                        fi
                    fi
                    TMP_LINE_BETA_MIN=$(grep -n "^$BETA_MIN" <<< "${BETAS[$VOL]}" | awk '{split($0, res, ":"); print res[1]}')
                    TMP_LINE_BETA_MAX=$(grep -n "^$BETA_MAX" <<< "${BETAS[$VOL]}" | awk '{split($0, res, ":"); print res[1]}')
                    if [[ ! $TMP_LINE_BETA_MIN =~ [[:digit:]]+ ]] || [[ ! $TMP_LINE_BETA_MAX =~ [[:digit:]]+ ]]; then
                        printf "\n\e[0;31m Error calculating the number of fit points grepping data files (script line $LINENO), investigate!!\n"
                        exit -1
                    fi
                    #If there are too less points in a volume, skip fit
                    if [ $(($TMP_LINE_BETA_MAX - $TMP_LINE_BETA_MIN + 1)) -lt $MINIMUM_NUMBER_OF_DATAPOINTS_PER_VOLUME ]; then
                        (( SKIPPED_FITS_LACK_POINTS[$VOL]++ ))
                        continue
                    fi
                    eval "RANGES$VOL+=( \"$BETA_MIN $BETA_MAX\" )"
                fi
            done
        done
        RANGES_DIM="${RANGES_DIM}*$(eval echo \${#RANGES$VOL[@]})"
        (( NUMBER_ALL_POSSIBLE_BETA_RANGES *= $(eval echo \${#RANGES$VOL[@]}) ))
        TOTAL_NUMBER_OF_FITS_PER_VOLUME[$VOL]=$(( ${NUMBER_OF_BETAS[$VOL]} * (${NUMBER_OF_BETAS[$VOL]} + 1) / 2 ))
        printf "\e[0;35m ($(eval echo \${#RANGES$VOL[@]}) saved out of ${TOTAL_NUMBER_OF_FITS_PER_VOLUME[$VOL]}: "
        printf "${SKIPPED_FITS_BETA_OUT[$VOL]} skipped because given beta was out of range, "
        printf "${SKIPPED_FITS_ASYMMETRY[$VOL]} skipped because range too much asymmetric, "
        printf "${SKIPPED_FITS_LACK_POINTS[$VOL]} skipped due to lack of data points)\n\e[0m"
    done
    printf "\e[0;36m ...done!\n\n\e[0m"
    #Now that we have all the possible combinations per volume, we have to build up all the
    #possible combinations between volumes. It is not easy again but it is possible using
    #a recursive function!
    if [ $DO_NOT_REUSE_BETA_RANGES = "TRUE" ]; then
        [ -f $ALL_BETA_RANGES_FILENAME ] && mv $ALL_BETA_RANGES_FILENAME ${ALL_BETA_RANGES_FILENAME}_$(date +'%F_%H%M')
        printf "\e[0;36m Producing ${RANGES_DIM:1}=$NUMBER_ALL_POSSIBLE_BETA_RANGES combinations of ranges...\n\e[0m"
        START_TIME=`date +%s`
        [ ! -f $ALL_BETA_RANGES_FILENAME ] && PrintAllPossibleRangesCombinations $(( ${#NSPACE[@]} -1 ))
        END_TIME=`date +%s`
        printf "\e[0;36m ...done in $(($END_TIME-$START_TIME)) seconds!\n\e[0m"
    else
        if [ ! -f $ALL_BETA_RANGES_FILENAME ]; then
            printf "\e[0;33m File \"$ALL_BETA_RANGES_FILENAME\" not found! It will be created.\n\e[0m"
            printf "\e[0;36m Producing ${RANGES_DIM:1}=$NUMBER_ALL_POSSIBLE_BETA_RANGES combinations of ranges...\n\e[0m"
            START_TIME=`date +%s`
            [ ! -f $ALL_BETA_RANGES_FILENAME ] && PrintAllPossibleRangesCombinations $(( ${#NSPACE[@]} -1 ))
            END_TIME=`date +%s`
            printf "\e[0;36m ...done in $(($END_TIME-$START_TIME)) seconds!\n\e[0m"
        elif [ $(wc -l < $ALL_BETA_RANGES_FILENAME) -ne $NUMBER_ALL_POSSIBLE_BETA_RANGES ]; then
            printf "\e[0;33m File \"$ALL_BETA_RANGES_FILENAME\" has $(wc -l < $ALL_BETA_RANGES_FILENAME) lines, but $NUMBER_ALL_POSSIBLE_BETA_RANGES are expected! It will be created again.\n\e[0m"
            mv $ALL_BETA_RANGES_FILENAME ${ALL_BETA_RANGES_FILENAME}_$(date +'%F_%H%M')
            printf "\e[0;36m Producing ${RANGES_DIM:1}=$NUMBER_ALL_POSSIBLE_BETA_RANGES combinations of ranges...\n\e[0m"
            START_TIME=`date +%s`
            [ ! -f $ALL_BETA_RANGES_FILENAME ] && PrintAllPossibleRangesCombinations $(( ${#NSPACE[@]} -1 ))
            END_TIME=`date +%s`
            printf "\e[0;36m ...done in $(($END_TIME-$START_TIME)) seconds!\n\e[0m"
        else
            printf "\e[38;5;208m File \"$ALL_BETA_RANGES_FILENAME\" has $(wc -l < $ALL_BETA_RANGES_FILENAME) lines, exactly how many are expected!\n"
            printf " In any case this does not assure the correctness of the found file, namely it is not sure that the options\n"
            printf " --minNumDataPerVolume and --betaToBeFitAround are respected. It is left to the user to ensure it.\n\e[0m"
        fi
    fi
    unset -v 'START_TIME' 'END_TIME'
    printf "\n"
    if [ $PRODUCE_ONLY_ALL_BETA_RANGES = "TRUE" ]; then
        printf "\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)-5)) ))\n\n\e[0m"
        exit 0
    fi
    #=================================================================================================================================
    # Do some filtering on the ranges file in order to reduce the actual number of fits
    START_TIME=`date +%s`
    rm -f $BETA_RANGES_TO_BE_FITTED
    printf "\e[0;36m Filtering $ALL_BETA_RANGES_FILENAME considering given options (run script with -H option for more info)...\n\e[0m"
    AUX_VAR=$(printf "%s," "${BETAS[@]}")
    awk -v betasFlatArray="${AUX_VAR%?}" -v number_of_fit_parameters="$NUMBER_OF_FIT_PARAMETERS" -v deactivate_pyramid_filter="$DEACTIVATE_PYRAMID_RANGES" \
    'BEGIN{ split(betasFlatArray, betas, ",") }
    {
        total_number_of_fitted_points=0
        for(i=1; i<=NF; i+=2){
            #The following if is the pyramid filter check
            if( deactivate_pyramid_filter=="FALSE" && i>2 && ( ($i < beta_min) || ($(i+1) > beta_max) ) ){
            next
        }
        beta_min=$i
        beta_max=$(i+1)
        #Here it is counted how many points per volume are considered
        tmp=substr(betas[(i+1)/2], index(betas[(i+1)/2], beta_min))
        tmp=substr(tmp, 1, index(tmp, beta_max)-1)              #The -1 is crucial because index() returns the position of the first digit of beta_max
        total_number_of_fitted_points+=(gsub(/[.]/,"", tmp)+1)  #The +1 is crucial because in the line above I do not count beta_max
                #ATTENTION: To remove the -1 and the +1 in the two lines above does not give the same result!!!
        }
        if(total_number_of_fitted_points <= number_of_fit_parameters){
        next
        }
        print $0
    }' $ALL_BETA_RANGES_FILENAME >> $BETA_RANGES_TO_BE_FITTED
    unset -v 'AUX_VAR'
    printf "\e[0;35m  -> excluded $(( $NUMBER_ALL_POSSIBLE_BETA_RANGES - $(wc -l < $BETA_RANGES_TO_BE_FITTED) )) ranges!\n\e[0m"
    END_TIME=`date +%s`
    printf "\e[0;36m ...done in $(($END_TIME-$START_TIME)) seconds!\n\n\e[0m"
    unset -v 'START_TIME' 'END_TIME'
fi
if [ $PRODUCE_ONLY_FILTERED_BETA_RANGES = "TRUE" ]; then
    printf "\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)-5)) ))\n\n\e[0m"
    exit 0
fi
#=================================================================================================================================
#Build string for gnuplot parameters and then a file with the gnuplot commands to be later invoqued
printf "\e[0;36m Creating gnuplot commands...\e[0m"
if [ "$FIT_GLOBALPATH" == "" ]; then
    source "${HOME}/Script/FittingUtilities/CreateGnuplotBinderFitScript.sh" || exit -2
    GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH="GnuplotScriptUsedInBruteForceFit.plt"
    CreateGnuplotTemplateFitScriptWithoutPlotting
    FIT_GLOBALPATH="$(pwd)/${GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH}"
fi
if [ $WILSON = 'TRUE' ]; then
    GNUPLOT_PARAMETERS="obs='${OBSERVABLE_NAME}'; kappa=${MASS}; nt=${NTIME};"
elif [ $STAGGERED = 'TRUE' ]; then
    GNUPLOT_PARAMETERS="obs='${OBSERVABLE_NAME}'; mass='${MASS}'; nt=${NTIME};"
fi
for INDEX in "${!NSPACE[@]}"; do
    GNUPLOT_PARAMETERS="$GNUPLOT_PARAMETERS ns$INDEX=${NSPACE[$INDEX]};"
done
LINE_WITH_ERROR=$(awk -v number_of_volumes="${#NSPACE[@]}" '{if(NF != 2*number_of_volumes){wrong=1; print NR}}END{if(wrong==1){exit}else{print 0}}' $BETA_RANGES_TO_BE_FITTED)
if [ $LINE_WITH_ERROR -ne 0 ]; then
    printf "\n\e[0;31m Error reading the beta ranges for fit from file \"$BETA_RANGES_TO_BE_FITTED\" at line ${LINE_WITH_ERROR}. Aborting...\n\n\e[0m"
    exit -1
fi
unset -v 'LINE_WITH_ERROR'
awk -v gnuplot_parameters="$GNUPLOT_PARAMETERS" -v fit_globalpath="$FIT_GLOBALPATH" \
'{
    gnuplot_command = "gnuplot -e \42" gnuplot_parameters 
    for(i=1; i<=NF; i+=2){
        gnuplot_command = gnuplot_command " b" (i-1)/2 "l=\47" $i "\47; b" (i-1)/2 "r=\47"  $(i+1) "\47;"
    }
    gnuplot_command = gnuplot_command "\42 " fit_globalpath
    print gnuplot_command
}' $BETA_RANGES_TO_BE_FITTED > $TEMPORARY_FILE_WITH_GNUPLOT_COMMANDS
printf "\e[0;36m done!\n\n\e[0m"
#=================================================================================================================================
printf "\e[0;36m Fitting...\n\e[0m"
if [ -f $FIT_RESULTS_STDOUT ]; then
    FIT_RESULTS_STDOUT_BACKUP="${FIT_RESULTS_STDOUT}_$(date +'%F_%H%M')"
    printf "\e[38;5;11m   WARNING: Found \"$FIT_RESULTS_STDOUT\" existing file, renaming it to \"$FIT_RESULTS_STDOUT_BACKUP\"!\n\e[0m"
    mv $FIT_RESULTS_STDOUT $FIT_RESULTS_STDOUT_BACKUP || exit -2
fi
if [ -f $FIT_RESULTS_STDERR ]; then
    FIT_RESULTS_STDERR_BACKUP="${FIT_RESULTS_STDERR}_$(date +'%F_%H%M')"
    printf "\e[38;5;11m   WARNING: Found \"$FIT_RESULTS_STDERR\" existing file, renaming it to \"$FIT_RESULTS_STDERR_BACKUP\"!\n\e[0m"
    mv $FIT_RESULTS_STDERR $FIT_RESULTS_STDERR_BACKUP || exit -2
fi
if [ $FIT_TYPE = "linear" ]; then
    echo "#Fitted_Volumes   NDF chi2       Q          nu dnu          betaC dbetaC            B4 dB4           a1 da1           Beta_Ranges" > $FIT_RESULTS_STDOUT
elif [ $FIT_TYPE = "quadratic" ]; then
    echo "#Fitted_Volumes   NDF chi2       Q          nu dnu          betaC dbetaC            B4 dB4           a1 da1           a2 da2           Beta_Ranges" > $FIT_RESULTS_STDOUT
else
    printf "\n\e[0;31m Unknown fit_type! Aborting...\n\n\e[0m"
    exit -1
fi
echo "Standard error of the gnuplot fits made by brute force on $(date +'%F %H:%M')" > $FIT_RESULTS_STDERR
LINES_READ=0
FIT_IN_WHICH_ERROR_OCCURRED=0
COUNTER_PARALLEL_FITS=0
for((INDEX=0; INDEX<${#NUMBER_OF_FIT_TO_BE_DONE_IN_PARALLEL}; INDEX++)); do 
    GLOBBING_INDICES_EXPRESSION="$GLOBBING_INDICES_EXPRESSION[^a-z]"
done
TOTAL_NUMBER_OF_FITS=$(wc -l < $BETA_RANGES_TO_BE_FITTED)
PROGRESS_BAR_LAST_UPDATE=0
START_TIME=`date +%s`
#Remove accidentally there folders
rm -f $GLOBBING_INDICES_EXPRESSION/*  #ATTENTION: important to rm here for the last parallelization
rmdir $GLOBBING_INDICES_EXPRESSION 2> /dev/null #Just to avoid to remove a file with numeric name
while read GNUPLOT_COMMAND; do
    #Progress bar for the user
    # NOTE: The default behavior for printf if you give it more arguments than there are specified in the format string is to loop back to the beginning of the format string and run it again.
    #       In printf %0.s is a string of zero char (%0s) and the period tells printf to truncate the string if it's longer than the specified length (otherwise it prints everything) [BASH specific]
    PERCENTAGE_FITS_DONE=$(($LINES_READ*100/$TOTAL_NUMBER_OF_FITS))
    if [ $PERCENTAGE_FITS_DONE -ge $PROGRESS_BAR_LAST_UPDATE ]; then
        PROGRESS_BAR_LAST_UPDATE=$(( $PROGRESS_BAR_LAST_UPDATE + $PROGRESS_BAR_UPDATE_FREQUENCY ))
        if [ $PERCENTAGE_FITS_DONE -eq 0 ]; then
            PROGRESS_BAR="   [$(printf '%0.s.' {1..100})] ($(printf "%${#TOTAL_NUMBER_OF_FITS}d" "$LINES_READ" )/$TOTAL_NUMBER_OF_FITS)\r"
        else
			TIME_TO_END=$(bc -l <<< "($(date +%s) - $START_TIME)/$PERCENTAGE_FITS_DONE*(100-$PERCENTAGE_FITS_DONE)" | awk '{printf "%5d", $1}')
            PROGRESS_BAR="   [$(printf '%0.s=' $(seq 1 $PERCENTAGE_FITS_DONE))$(printf '%0.s.' $(seq 1 $((100-$PERCENTAGE_FITS_DONE))))] ($(printf "%${#TOTAL_NUMBER_OF_FITS}d" "$LINES_READ" )/$TOTAL_NUMBER_OF_FITS)   $TIME_TO_END sec. to end\e[K\r"
        fi
        printf "$PROGRESS_BAR"
    fi
    (( LINES_READ++ ))
    #Call gnuplot: stdout and stderr are redirected to own file having as suffix the number COUNTER_PARALLEL_FITS with as many leading zero as the digits of NUMBER_OF_FIT_TO_BE_DONE_IN_PARALLEL
    LOCAL_INDEX_PARALLEL_FIT_WITH_LEADING_ZERO=$(printf "%0${#NUMBER_OF_FIT_TO_BE_DONE_IN_PARALLEL}d" $COUNTER_PARALLEL_FITS)
    mkdir $LOCAL_INDEX_PARALLEL_FIT_WITH_LEADING_ZERO
    cd $LOCAL_INDEX_PARALLEL_FIT_WITH_LEADING_ZERO
    eval $GNUPLOT_COMMAND 1> ${FIT_RESULTS_STDOUT}_$LOCAL_INDEX_PARALLEL_FIT_WITH_LEADING_ZERO 2> ${FIT_RESULTS_STDERR}_$LOCAL_INDEX_PARALLEL_FIT_WITH_LEADING_ZERO &
    cd ..
    (( COUNTER_PARALLEL_FITS++ ))
    #Check whether to wait or not
    if [ $COUNTER_PARALLEL_FITS -eq $NUMBER_OF_FIT_TO_BE_DONE_IN_PARALLEL ] || [ $LINES_READ -eq $(wc -l < $TEMPORARY_FILE_WITH_GNUPLOT_COMMANDS) ]; then
        wait
        COUNTER_PARALLEL_FITS=0
        #Collect fit results in stdout file and errors in sterr file
        cat $GLOBBING_INDICES_EXPRESSION/${FIT_RESULTS_STDOUT}_$GLOBBING_INDICES_EXPRESSION >> $FIT_RESULTS_STDOUT
        cat $GLOBBING_INDICES_EXPRESSION/${FIT_RESULTS_STDERR}_$GLOBBING_INDICES_EXPRESSION >> $FIT_RESULTS_STDERR
        #If errors occurred report it to the user
        for FILENAME in $GLOBBING_INDICES_EXPRESSION/${FIT_RESULTS_STDERR}_$GLOBBING_INDICES_EXPRESSION; do
            LOCAL_INDEX=$(sed 's/^0*//' <<< "${FILENAME##*_}")
            if [ $(wc -l < $FILENAME) -ne 0 ]; then
                #Global number of line in TEMPORARY_FILE_WITH_GNUPLOT_COMMANDS where there is the gnuplot command that gave an error (+1 because the local index ranges from 0 but the line from 1)
                if [ $LINES_READ -le $NUMBER_OF_FIT_TO_BE_DONE_IN_PARALLEL ]; then
                    FAILED_GNUPLOT_COMMAND_FILELINENUMBER=$(( $LOCAL_INDEX + 1 ))
                else
                    FAILED_GNUPLOT_COMMAND_FILELINENUMBER=$(( $LINES_READ + $LOCAL_INDEX + 1 - $NUMBER_OF_FIT_TO_BE_DONE_IN_PARALLEL ))
                fi
                FAILED_GNUPLOT_COMMAND=$(sed -n $FAILED_GNUPLOT_COMMAND_FILELINENUMBER'p' $TEMPORARY_FILE_WITH_GNUPLOT_COMMANDS)
                printf "\e[38;5;202m  - Gnuplot error occurred for ranges: $(echo ${FAILED_GNUPLOT_COMMAND} | grep -o "[[:digit:]][.][[:digit:]]\+" | awk '{print $0}' ORS=" ")\e[K\n\e[0m$PROGRESS_BAR"
                (( FIT_IN_WHICH_ERROR_OCCURRED++ ))
            fi
        done
        rm $GLOBBING_INDICES_EXPRESSION/*  #ATTENTION: important to rm here for the last parallelization
        rmdir $GLOBBING_INDICES_EXPRESSION #Just to avoid to remove a file with numeric name
    fi
done < $TEMPORARY_FILE_WITH_GNUPLOT_COMMANDS
#Complete progress bar
printf "   [$(printf '%0.s=' {1..100})] ($(printf "%${#TOTAL_NUMBER_OF_FITS}d" "$LINES_READ" )/$TOTAL_NUMBER_OF_FITS)"
END_TIME=`date +%s`
printf "\e[0;36m\n ...done in $(($END_TIME-$START_TIME)) seconds!\n\e[0m"
printf "\n" >> $FIT_RESULTS_STDERR
rm $TEMPORARY_FILE_WITH_GNUPLOT_COMMANDS
#=================================================================================================================================
#Select good fits
if [ $REJECTION_PERCENTAGE -eq 0 ]; then
    printf "\e[38;5;83m\n Rejection percentage equal to $REJECTION_PERCENTAGE, no filtering will be performed!\n\e[0m"
else
    if [ $USE_RANGES_TO_BE_FITTED_FILE = "FALSE" ]; then
        TOTAL_NUMBER_OF_POSSIBLE_FIT=1
        for VOL in ${NSPACE[@]}; do (( TOTAL_NUMBER_OF_POSSIBLE_FIT*=${TOTAL_NUMBER_OF_FITS_PER_VOLUME[$VOL]} )); done
        TOTAL_NUMBER_OF_SKIPPED_FIT=$(( $TOTAL_NUMBER_OF_POSSIBLE_FIT - $TOTAL_NUMBER_OF_FITS ))
    fi
    [ ! ${TOTAL_NUMBER_OF_SKIPPED_FIT:+x} ] && TOTAL_NUMBER_OF_SKIPPED_FIT="---"
    #NOTE: The following line could seem tricky and the reason why it works magic. Indeed it is simply
    #      used the fact that bash does first the redirection (i.e. < $FIT_RESULTS_STDOUT) and then it
    #      executes the list of commands in {}. Now, when the file is removed, its content is in the std input!
    { rm $FIT_RESULTS_STDOUT && awk -v totalRanges="$TOTAL_NUMBER_OF_FITS" \
                                    -v skipped="$TOTAL_NUMBER_OF_SKIPPED_FIT" \
                                    -v perc="$REJECTION_PERCENTAGE" \
                                    -v fitWithError="$FIT_IN_WHICH_ERROR_OCCURRED" \
                                    '{if($0 ~ /^[ #]+/){print $0} else if(($4 < perc) || ($4 > (100-perc))){rej++; next} else {print $0}} \
                                    END{printf "#Rejected %d fits out of %d done (%s previously skipped according to specified options, in %d some error occurred)\n", rej, totalRanges, skipped, fitWithError}' > $FIT_RESULTS_STDOUT; } < $FIT_RESULTS_STDOUT 
    #Print to screen some information
    FILTERING_RESULT="$(tac $FIT_RESULTS_STDOUT | grep "." -m 1)"
    printf "\n\e[1;32m ${FILTERING_RESULT:1}\n\e[0m"
fi
#Selecting best fit and printing it to file and screen
printf "\e[1;36m\n Best fit (chi2 closest to 1):\e[0m"
BEST_FIT="$(awk 'BEGIN{diff=100}/^[ #]+/{next}{if(sqrt(($3-1.)^2) < diff){diff=sqrt(($3-1.)^2); line=$0}}END{print line}' $FIT_RESULTS_STDOUT)"
if [ "$BEST_FIT" == "" ]; then
    BEST_FIT="No best fit found => ALL fits have been rejected!"
    printf "\e[1;31m"
else
    BEST_FIT="$(sed 's/\t/  /g' <<< "$BEST_FIT" )"
    printf "\e[1;36m"
    if [ -f $BINDER_FIT_GLOBALPATH ]; then
        BEST_FIT_AS_ARRAY=( $BEST_FIT )
        if [ $FIT_TYPE = "linear" ]; then
            RANGES_BEST_FIT="${BEST_FIT_AS_ARRAY[@]:12}"
            $BINDER_FIT_GLOBALPATH -b ${RANGES_BEST_FIT[@]} >> /dev/null
        elif [ $FIT_TYPE = "quadratic" ]; then
            RANGES_BEST_FIT="${BEST_FIT_AS_ARRAY[@]:14}"        
            $BINDER_FIT_GLOBALPATH -b ${RANGES_BEST_FIT[@]} --quadratic >> /dev/null
        fi
    fi
fi
echo "#Fits produced by $BASH_SOURCE called on $(date +'%F %H:%M') with options $@" >> $FIT_RESULTS_STDOUT
printf "# Best fit (chi2 closest to 1):\n" >> $FIT_RESULTS_STDOUT
printf "#   $BEST_FIT\n\n\n" >> $FIT_RESULTS_STDOUT
printf "   $BEST_FIT\n\e[0m"
printf "\e[0;36m$(printf '%0.s=' $( seq 1 $(($(tput cols)-5)) ))\n\n\e[0m"
#printf "\e[0;36m=====================================================================================================================\n\n\e[0m"

exit 0
