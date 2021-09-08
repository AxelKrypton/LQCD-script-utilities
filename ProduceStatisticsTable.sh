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
REQUESTED_NTIME=""
REQUESTED_NFLAVOUR=""
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
ILL_FORMED_PATH='FALSE'
PRINT_FOR_DRAFT='FALSE'

#Parse command line parameters
function ElementInArray() {
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

if ElementInArray "--help" $@ || ElementInArray "-h" $@; then
    printf "\n\t\e[38;5;13m\e[1m"
    printf "This script is meant to be used in the folder where the \"Nf\" directories are.\n\tPossible options to the script:\e[22m\n\n\t\e[38;5;10m"
    printf "   --nt          ->   The nt value for which the statistics should be produced\n\t"
    printf "   --Nf          ->   The Nf value for which the statistics should be produced\n\t"
    printf "   --draft       ->   Print in format for the draft\n\t"
    printf "\n\e[0m"
    exit 3
fi

while [ "$1" != "" ]; do
    case $1 in
        --nt )
            if [[ $2 =~ ^${NTIME_REGEX//\\/}$ ]]; then
                REQUESTED_NTIME="$2"
            else
                printf "\n\e[38;5;9m Option value \e[1m$2\e[22m invalid! Aborting...\n\n\e[0m"; exit -1 
            fi
            shift 2
            ;;
        --Nf )
            if [[ $2 =~ ^${NFLAVOUR_REGEX//\\/}$ ]]; then
                REQUESTED_NFLAVOUR="$2"
            else
                printf "\n\e[38;5;9m Option value \e[1m$2\e[22m invalid! Aborting...\n\n\e[0m"; exit -1 
            fi
            shift 2
            ;;
        --draft )
            PRINT_FOR_DRAFT='TRUE'
            shift
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

shopt -s extglob

echo
if [[ ${REQUESTED_NTIME} = '' && ${REQUESTED_NFLAVOUR} = '' ]]; then
    PATHS_TO_TARVERSE=( ${PWD}/${NFLAVOUR_PREFIX}[0-9][.][0-9]/${CHEMPOT_PREFIX}*/${MASS_PREFIX}*/${NTIME_PREFIX}*/${NSPACE_PREFIX}+([0-9]) )
elif [[ ${REQUESTED_NTIME} != '' && ${REQUESTED_NFLAVOUR} = '' ]]; then
    PATHS_TO_TARVERSE=( ${PWD}/${NFLAVOUR_PREFIX}[0-9][.][0-9]/${CHEMPOT_PREFIX}*/${MASS_PREFIX}*/${NTIME_PREFIX}${REQUESTED_NTIME}/${NSPACE_PREFIX}+([0-9]) )
elif [[ ${REQUESTED_NTIME} = '' && ${REQUESTED_NFLAVOUR} != '' ]]; then
    PATHS_TO_TARVERSE=( ${PWD}/${NFLAVOUR_PREFIX}${REQUESTED_NFLAVOUR}/${CHEMPOT_PREFIX}*/${MASS_PREFIX}*/${NTIME_PREFIX}*/${NSPACE_PREFIX}+([0-9]) )
else
    PATHS_TO_TARVERSE=( ${PWD}/${NFLAVOUR_PREFIX}${REQUESTED_NFLAVOUR}/${CHEMPOT_PREFIX}*/${MASS_PREFIX}*/${NTIME_PREFIX}${REQUESTED_NTIME}/${NSPACE_PREFIX}+([0-9]) )
fi

# Sort paths using versioning option of sort in order to have .../ns8 before .../ns12
readarray -d $'\0' -t PATHS_TO_TARVERSE < <(printf '%s\0' "${PATHS_TO_TARVERSE[@]}" | sort -zV)

if [[ ${PRINT_FOR_DRAFT} = 'TRUE' ]]; then
    declare -A NUMBER_OF_NF VOLUMES_SETS
    # Assume no space in paths...
    PIECES_OF_PATHS=( $(printf '%s\n' "${PATHS_TO_TARVERSE[@]}" | grep -o "${NFLAVOUR_PREFIX}${NFLAVOUR_REGEX}/${CHEMPOT_PREFIX}${CHEMPOT_REGEX}/${MASS_PREFIX}${MASS_REGEX}/${NTIME_PREFIX}${NTIME_REGEX}" | sort -u) )
    for d in "${PIECES_OF_PATHS[@]}" ; do
        NFLAVOUR=$(cut -d'/' -f1 <<< "${d}")
        (( NUMBER_OF_NF[${NFLAVOUR/${NFLAVOUR_PREFIX}/}]++ ))
        VOLUMES_SETS["${d//\//_}"]="$(printf '%s\n' "${PATHS_TO_TARVERSE[@]}" | grep "${d}" | grep -o "${NSPACE_PREFIX}${NSPACE_REGEX}$" | sed 's/^'"${NSPACE_PREFIX}"'//' | tr '\n' ' ')"
    done
    printf '\e[93m%s\e[0m\n'\
           ' The table for the draft prints aspec ratios in ascending order left to right and'\
           ' you should guarantee yourself that no column is mismatched. Here in the following'\
           ' the list of aspect ratios gathered on the same line:'
    for d in "${!VOLUMES_SETS[@]}"; do
        printf "\e[96m%26s:\e[0m %s\n" "${d}" "${VOLUMES_SETS[${d}]}"
    done | sort
fi

NOT_ROUNDED_STATISTICS=()
for d in "${PATHS_TO_TARVERSE[@]}" ; do
    unset -v 'PARAMETERS_STRING' 'NFLAVOUR' 'CHEMPOT' 'MASS' 'NTIME' 'NSPACE'
    if [[ ! $d == *"scalingPlots" ]]; then
        ReadParametersFromPath $d
        [[ $ILL_FORMED_PATH == "TRUE" ]] && unset ILL_FORMED_PATH && unset PARAMETERS_STRING && continue

        if [[ $NTIME == $REQUESTED_NTIME ]] || [[ -z "$REQUESTED_NTIME" ]]; then

            stat=0
            bCount=0
            betas=()
            for bdir in $d/*; do
                betaDirName=${bdir##*/}
                if [[ ! $betaDirName =~ ^${BETA_FOLDER_MERGED_REGEX//\\/}$ ]]; then
                    continue
                fi
                betas+=($(grep -o $BETA_REGEX <<< $betaDirName))
                [[ ! -f $d/$betaDirName/$OUTPUT_FILE ]] && continue
                stat=$((stat+$(wc -l < $d/$betaDirName/$OUTPUT_FILE)))
                bCount=$((bCount+1))
            done
            # Sort betas to use this assumption later in awk
            readarray -d $'\0' -t betas < <(printf '%s\0' "${betas[@]}" | sort -z)
            if [[ ! ${stat} =~ 000$ ]]; then
                NOT_ROUNDED_STATISTICS+=( "${d}" )
                continue
            fi
            (( stat/=1000 ))

            betaC="-"
            betaCFile="$d/${PARAMETERS_STRING}_betacEstimates/${PARAMETERS_STRING}_betaC_pbp_from_skewness_reweightedData.dat"
            [[ -f $betaCFile ]] && betaC=$(printf "%.6f" $(awk 'NR==2{print $1}' $betaCFile))
            observablesFile="$d/${PARAMETERS_STRING}_analysis/${PARAMETERS_STRING}_observables_pbp.dat"
            [[ -f $observablesFile ]] && nIndepEvents=$(awk '{if ($2=="merged") {sum += $28; count++}} END {  if (NR > 0) print sum / count ; }' $observablesFile)
            [[ -f $observablesFile ]] && zeroishSkew=$(awk -v "bMin=${betas[0]}" -v "bMax=${betas[-1]}" ' function abs(v) {return v < 0 ? -v : v} {if ($1==bMin && $2!="merged" && $18>=abs($17)) {occ++}; if ($1==bMax && $2!="merged" && $18>=abs($17)) { occ++};} END {  if (NR > 0) printf "%d", occ; }' $observablesFile)
            maxSkewDiscrepancyFile="$d/${PARAMETERS_STRING}_analysis/${PARAMETERS_STRING}_maxSigmaDiscrepancyForSkewness.dat"
            [[ -f $maxSkewDiscrepancyFile ]] && maxSkewDiscrepancy=$(awk '{if(min==""){min=max=$2}; if($2>max) {max=$2}; if($2< min) {min=$2};} END {printf "%.1f", max}' $maxSkewDiscrepancyFile)

            if [[ ${PRINT_FOR_DRAFT} = 'TRUE' ]]; then
                if [[ $printedFlavour = '' ]]; then
                    printf '\n\\midrule\n\\multirow{%d}{*}{%s}\n' "${NUMBER_OF_NF[${NFLAVOUR}]}" "${NFLAVOUR}"
                elif [[ ${printedFlavour} != $NFLAVOUR ]]; then
                    printf '\\\\\n\\midrule\n\\multirow{%d}{*}{%s}\n' "${NUMBER_OF_NF[${NFLAVOUR}]}" "${NFLAVOUR}"
                fi
                if [[ $printedMass = '' || ${printedFlavour} != $NFLAVOUR ]]; then
                    printf ' & 0.%-4s '       ${MASS/%+(0)/}  # Remove trailing zeroes
                elif [[ ${printedMass} != $MASS && ${printedFlavour} = $NFLAVOUR ]]; then
                    printf '\\\\\n & 0.%-4s ' ${MASS/%+(0)/}
                fi
                printedFlavour=$NFLAVOUR
                printedMass=$MASS
                printf '& %-9s\sep %.0fk\sep %d\sep %d\sep %.1f ' ${betaC/%+(0)/} $stat $bCount $zeroishSkew $maxSkewDiscrepancy
            else
                printf '%s\t%d\t0.%s\t%2d\t%6s\t%.0fk|%2d|%3.0f|%d|%.1f\n' ${NFLAVOUR} $NTIME $MASS $NSPACE $betaC $stat $bCount $nIndepEvents $zeroishSkew $maxSkewDiscrepancy
            fi
        fi
    fi
done
if [[ ${PRINT_FOR_DRAFT} = 'TRUE' ]]; then
    printf '\\\\\n\n'
else
    echo
fi

if [[ ${#NOT_ROUNDED_STATISTICS[@]} -gt 0 ]]; then
    printf "\n \e[93mWARNING: Statistics of following volumes was not rounded and excluded from the table:\e[0m\n"
    for d in "${NOT_ROUNDED_STATISTICS[@]}"; do
        printf "         \e[96m${d}\e[0m\n"
    done
    echo
fi

