#!/bin/bash

export LC_NUMERIC="en_US.UTF-8"

# Global variables:
NFLAVOUR_POSITION=0
CHEMPOT_POSITION=1
MASS_POSITION=2
NTIME_POSITION=3
NSPACE_POSITION=4
NFLAVOUR_PREFIX="Nf"
CHEMPOT_PREFIX="mui"
MASS_PREFIX="mass"
OUTPUT_FILE="rhmc_output"
NTIME_PREFIX="nt"
NSPACE_PREFIX="ns"
PARAMETER_PREFIXES=([$NFLAVOUR_POSITION]=$NFLAVOUR_PREFIX [$CHEMPOT_POSITION]=$CHEMPOT_PREFIX [$MASS_POSITION]=$MASS_PREFIX [$NTIME_POSITION]=$NTIME_PREFIX [$NSPACE_POSITION]=$NSPACE_PREFIX)
NFLAVOUR=""
CHEMPOT=""
MASS=""
NSPACE=""
NTIME=""
REQNTIME=""
declare -A PARAMETER_VARIABLE_NAMES=([$NFLAVOUR_PREFIX]="NFLAVOUR" [$CHEMPOT_PREFIX]="CHEMPOT" [$MASS_PREFIX]="MASS" [$NTIME_PREFIX]="NTIME" [$NSPACE_PREFIX]="NSPACE")
NFLAVOUR_REGEX='[[:digit:]]\(.[[:digit:]]\)\?'
CHEMPOT_REGEX='\(0\|PiT\)'
MASS_REGEX='\([0-9][.]\)\?[[:digit:]]\{4\}'
NTIME_REGEX='[[:digit:]]\{1,2\}'
NSPACE_REGEX='[[:digit:]]\{1,2\}'
PARAMETER_REGEXES=([$NFLAVOUR_POSITION]=$NFLAVOUR_REGEX [$CHEMPOT_POSITION]=$CHEMPOT_REGEX [$MASS_POSITION]=$MASS_REGEX [$NTIME_POSITION]=$NTIME_REGEX [$NSPACE_POSITION]=$NSPACE_REGEX)
BETA_PREFIX="b"
SEED_PREFIX="s"
SEED_REGEX='[[:digit:]]\{4\}'
BETA_POSTFIX=""
BETA_POSITION=5
BETA_REGEX='[[:digit:]][.][[:digit:]]\{4\}'
BETA_FOLDER_SHORT_REGEX=$BETA_REGEX'_'$SEED_PREFIX'[[:digit:]]\{4\}_[[:alpha:]]\+'
BETA_FOLDER_REGEX=$BETA_PREFIX$BETA_FOLDER_SHORT_REGEX
BETA_FOLDER_MERGED_REGEX=$BETA_PREFIX$BETA_REGEX
PARAMETERS_PATH=""
PARAMETERS_STRING=""
ILL_FORMED_PATH="FALSE"

#Parse command line parameters
function ElementInArray() {
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

if ElementInArray "--help" $@ || ElementInArray "-h" $@; then
    printf "\n\t\e[38;5;13m\e[1m"
    printf "\e[4mThis script is meant to be used in the "Nf" folder. Possible options to the script\e[24m:\e[22m\n\n\t\e[38;5;10m"
    printf "   --nt          ->   The nt value for which the statistics should be produced\n\t"
    printf "\n\e[0m"
    exit 3
fi

while [ "$1" != "" ]; do
    case $1 in
        --nt )
            REQNTIME="$2"
            shift 2
            ;;
        * ) printf "\n\e[38;5;9m Option \e[1m$1\e[22m invalid! Aborting...\n\n\e[0m"; exit -1
    esac
done


#-------------------------------------------------------------
# Global functions

#Function that returns true if any parameters corresponding to the given prefixes is unset
function IsAnyParameterUnsetAmong(){
    for PREFIX in $@; do
        [[ -z ${PARAMETER_VARIABLE_NAMES[$PREFIX]:+x} ]] &&  printf "\n\e[0;31m Accessing PARAMETER_VARIABLE_NAMES array with not existing prefix! Aborting...\n\n\e[0m" && exit -1
        if [ "${!PARAMETER_VARIABLE_NAMES[$PREFIX]}" = "" ]; then
            return 0
        fi
    done && unset -v 'PREFIX'
    return 1
}

#This function set the global variables PARAMETERS_PATH and PARAMETERS_STRING after having checked that the parameters have been extracted
function SetParametersPathAndString(){

    IsAnyParameterUnsetAmong $@ &&  printf "\n\e[0;31m Function \"$FUNCNAME\" called before extracting parameters! Aborting...\n\n\e[0m" && exit -1
    local PARAMETERS_VALUE=([$NFLAVOUR_POSITION]=$NFLAVOUR [$CHEMPOT_POSITION]=$CHEMPOT [$MASS_POSITION]=$MASS [$NTIME_POSITION]=$NTIME [$NSPACE_POSITION]=$NSPACE)
    for ((i=0; i<${#PARAMETER_PREFIXES[@]}; i++)); do
	    PARAMETERS_PATH="$PARAMETERS_PATH/${PARAMETER_PREFIXES[$i]}${PARAMETERS_VALUE[$i]}"
	    PARAMETERS_STRING="$PARAMETERS_STRING${PARAMETER_PREFIXES[$i]}${PARAMETERS_VALUE[$i]}_"
    done
    PARAMETERS_STRING=${PARAMETERS_STRING%?} #Remove last underscore
}

function ReadParametersFromPath(){

    local PARAMETERS_VALUE=()
    #Path given as first argument to this function
    local PATH_TO_BE_USED="/$1/" 
    for ((i=0; i<${#PARAMETER_PREFIXES[@]}; i++)); do
	    if [ $(echo $PATH_TO_BE_USED | grep -o "/${PARAMETER_PREFIXES[$i]}" | wc -l) -ne 1 ]; then
	        printf "\n\e[0;31m Unable to recover \"${PARAMETER_PREFIXES[$i]}\" from the path \"$1\". Aborting...\n\n\e[0m"
            exit -1
	    fi
	    PARAMETERS_VALUE[$i]=$(echo "$PATH_TO_BE_USED" | awk -v expr="${PARAMETER_PREFIXES[$i]}" \
                                                             -v expr_len=${#PARAMETER_PREFIXES[$i]} \
                                                             '{print substr($0, index($0, "/"expr) + expr_len + 1, index(substr($0, index($0, "/"expr) + expr_len+1), "/") - 1)}')
    done
    NFLAVOUR=${PARAMETERS_VALUE[$NFLAVOUR_POSITION]}
    CHEMPOT=${PARAMETERS_VALUE[$CHEMPOT_POSITION]}
    MASS=${PARAMETERS_VALUE[$MASS_POSITION]}
    NTIME=${PARAMETERS_VALUE[$NTIME_POSITION]}
    NSPACE=${PARAMETERS_VALUE[$NSPACE_POSITION]}

#TODO: consider re-enabling the following checks if it makes sense for this script
    #Check that the recovered parameters make sense (remove escape characters from regex)
    if [[ ! $MASS =~ ^${MASS_REGEX//\\/}$ ]]; then
            ILL_FORMED_PATH="TRUE"
#	    printf "\n\e[0;31m Parameter \"$MASS_PREFIX\" from the path \"$1\" not allowed! Aborting...\n\n\e[0m"
#	    exit -1
    elif [[ ! $NTIME =~ ^${NTIME_REGEX//\\/}$ ]]; then
            ILL_FORMED_PATH="TRUE"
#	    printf "\n\e[0;31m Parameter \"$NTIME_PREFIX\" from the path \"$1\" not allowed! Aborting...\n\n\e[0m"
#	    exit -1
    elif [[ ! $NSPACE =~ ^${NSPACE_REGEX//\\/}$ ]]; then
            ILL_FORMED_PATH="TRUE"
#	    printf "\n\e[0;31m Parameter \"$NSPACE_PREFIX\" from the path \"$1\" not allowed! Aborting...\n\n\e[0m"
#	    exit -1
    elif [[ ! $NFLAVOUR =~ ^${NFLAVOUR_REGEX//\\/}$ ]]; then
            ILL_FORMED_PATH="TRUE"
#	    printf "\n\e[0;31m Parameter \"$NFLAVOUR_PREFIX\" from the path \"$1\" not allowed! Aborting...\n\n\e[0m"
#	    exit -1
    elif [[ ! $CHEMPOT =~ ^${CHEMPOT_REGEX//\\/}$ ]]; then
            ILL_FORMED_PATH="TRUE"
#	    printf "\n\e[0;31m Parameter \"$CHEMPOT_PREFIX\" from the path \"$1\" not allowed! Aborting...\n\n\e[0m"
#	    exit -1
    fi
    #Set parameters path
    SetParametersPathAndString
}


for d in $PWD/*/*/*/* ; do
    if [[ ! $d == *"scalingPlots" ]]; then
        ReadParametersFromPath $d
        [[ $ILL_FORMED_PATH == "TRUE" ]] && unset ILL_FORMED_PATH && unset PARAMETERS_STRING && continue

        if [[ $NTIME == $REQNTIME ]] || [[ -z "$REQNTIME" ]]; then

            stat=0
            bCount=0
            betas=()
            for bdir in $d/*; do
                betaDirName=${bdir##*/}
                betas+=($(grep -o $BETA_REGEX <<< $betaDirName))
                if [[ $betaDirName =~ ^${BETA_FOLDER_MERGED_REGEX//\\/}$ ]]; then
                    stat=$((stat+$(wc -l < $d/$betaDirName/$OUTPUT_FILE)))
                    bCount=$((bCount+1))
                fi
            done
            statInt=$stat
            stat=$((stat/1000))
            modStat=$((stat%50))
            stat=$((stat-modStat))

            betaC="-"
            betaCFile="$d/${PARAMETERS_STRING}_betacEstimates/${PARAMETERS_STRING}_betaC_pbp_from_skewness_reweightedData.dat"
            [[ -f $betaCFile ]] && betaC=$(printf "%.4f" $(awk 'NR==2{print $1}' $betaCFile))
            observablesFile="$d/${PARAMETERS_STRING}_analysis/${PARAMETERS_STRING}_observables_pbp.dat"
            [[ -f $observablesFile ]] && nIndepEvents=$(awk '{if ($2=="merged") {sum += $28; count++}} END {  if (NR > 0) print sum / count ; }' $observablesFile)
            [[ -f $observablesFile ]] && zeroishSkew=$(awk -v bMin=${betas[0]} -v bMax=${betas[-1]} ' function abs(v) {return v < 0 ? -v : v} {if ($1==bMin && $2!="merged" && $18>=abs($17)) {occ++}; if ($1==bMax && $2!="merged" && $18>=abs($17)) { occ++};} END {  if (NR > 0) printf "%d", occ; }' $observablesFile)
            maxSkewDiscrepancyFile="$d/${PARAMETERS_STRING}_analysis/${PARAMETERS_STRING}_maxSigmaDiscrepancyForSkewness.dat"
            [[ -f $maxSkewDiscrepancyFile ]] && maxSkewDiscrepancy=$(awk '{if(min==""){min=max=$2}; if($2>max) {max=$2}; if($2< min) {min=$2};} END {printf "%.1f", max}' $maxSkewDiscrepancyFile)

#Uncomment to print it in a suitable form for tables in the chiralPT draft
#        [[ ! $printedMass == $MASS ]] && printf '\\\ \n& 0.%s ' $MASS && printedMass=$MASS
#            printf '& %6s\sep %.0fk\sep %d\sep %d\sep %.1f ' $betaC $stat $bCount $zeroishSkew $maxSkewDiscrepancy

#Uncomment for printing more information than needed for the table in the draft...
             printf '%d\t%.1f\t0.%s\t%2d\t%6s\t%.0fk|%2d|%3.0f|%d|%.1f\n' $NTIME $NFLAVOUR $MASS $NSPACE $betaC $stat $bCount $nIndepEvents $zeroishSkew $maxSkewDiscrepancy
        fi
    fi
    unset PARAMETERS_STRING
    unset NTIME
    unset NFLAVOUR
    unset MASS
    unset NSPACE
done
#printf '\\\ \n'

