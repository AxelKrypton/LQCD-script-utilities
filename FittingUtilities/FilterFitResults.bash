#!/bin/bash

OPTION_COUNTER=0

#Explanation of the regular expression in the parser
#^([sl]{1}[+-]?)?[[:digit:]]+(\.[[:digit:]]+)?$
#The first part ^([sl]{1}[+-]?)? represents an optional group in the beginning of the string.
#If one decides to put an instance of this group into the string, certain criteria on this instance enter:
#There must only be one "l" or one "s". Then there can be either a "+" or a minus "-". 
#The second part [[:digit:]]+(\.[[:digit:]]+)?$ is constructed in a similar fashion.
#Here again the important element is the optional group at the end of the string (\.[[:digit:]]+)?$ . 
#If one decides to put an instance of this group into the string,
#the instance has to start with a period followed by at least one digit.

CRITERIA_STRING_SMALLER=l
CRITERIA_STRING_LARGER=g

CHI2_PASSED=0
Q_PASSED=0

POSSIBLE_PARAMETERS_ARRAY+=( chi2 )
POSSIBLE_PARAMETERS_ARRAY+=( Q )
POSSIBLE_PARAMETERS_ARRAY+=( nu )
POSSIBLE_PARAMETERS_ARRAY+=( betaC )
POSSIBLE_PARAMETERS_ARRAY+=( B4 )
POSSIBLE_PARAMETERS_ARRAY+=( a1 )
POSSIBLE_PARAMETERS_ARRAY+=( a2 )
POSSIBLE_PARAMETERS_ARRAY+=( MinOv% )
POSSIBLE_PARAMETERS_ARRAY+=( MinSymm% )

PARSED_FILE_TO_FILTER="FALSE"
PERFORM_FILTERING="FALSE"
PRODUCE_OVERLAP_PERCENTAGE="FALSE"

function join()
{
    local IFS=$1
    shift
    echo "$*"
}

while [ $# -gt 0 ];
do
    case $1 in
    -h | --help)
        printf "\n \e[4;32mAvailable options:\n\e[0m\n"
        printf "\e[0;32m   -h | --help                       -> print this help message\n\e[0m"
        printf "\e[0;32m   -o                                -> produce overlap percentage and xRanges columns\n\e[0m"
        printf "\e[0;32m   -p <name> [<X>] [l<X>] [g<X>]     -> filters according the specified criteria\n\e[0m"
        printf "\e[0;32m   -f                                -> input file (if no specified, then standard input)\n\e[0m"
        echo ""
        printf " \e[4;32mHow to specify filtering criterion:\n\n\e[0m"
        printf "\e[0;32m   <name> -> the name of the column (as it is in the header)\n\e[0m"
        printf "\e[0;32m   [<X>]  -> percentage (without %% symbol). For chi2 fits without \n\e[0m"
        printf "\e[0;32m             1-X/100. < chi2 < 1+X/100. are excluded. For Q fits\n\e[0m"
        printf "\e[0;32m             without 50-X < Q < 50+X are excluded. For anything else\n\e[0m"
        printf "\e[0;32m             fits with a relative error bigger than X are excluded.\n\e[0m"
        printf "\e[0;32m   [l<X>] -> fits with the parameter less than X are kept.\n\e[0m"
        printf "\e[0;32m   [g<X>] -> fits with the parameter greater than X are kept.\n\n\e[0m"
        exit
        ;;
    -o) PRODUCE_OVERLAP_PERCENTAGE="TRUE"
        ;;
    -p) if [ $OPTION_COUNTER -gt 0 ]; then echo "Currently only filtering by one parameter at a time is implemented."; break; fi  
        PERFORM_FILTERING="TRUE"
        PARAMETER=$2
        shift
        while [[ $2 =~ ^([$CRITERIA_STRING_SMALLER$CRITERIA_STRING_LARGER][+-]?)?[[:digit:]]+(\.[[:digit:]]+)?$ ]] 
        do                                                
            CRITERIA_ARRAY+=( $2 )
            if [ ${#CRITERIA_ARRAY[@]} -gt 3 ]; then echo "Maximally three criteria allowed at a time...terminating"; exit; fi
            shift
        done
        (( OPTION_COUNTER++ ))
        ;;
    -f) FILE_TO_FILTER=$2
		if [ ! -f $FILE_TO_FILTER ]; then echo "Specified file not found...terminating"; exit -1; fi
        PARSED_FILE_TO_FILTER="TRUE"
        #echo "parsed file to filter: "$FILE_TO_FILTER
        shift
        ;;
    -*) echo $0: $1: unrecognized option >&2
        exit
        ;;
    *)  echo $0: $1: unrecognized option >&2
        exit
        ;;
    esac
    shift
done

#Get absoulte path to the script
SCRIPT_PATH="`readlink -e $0`"
ABSOLUTE_FOLDER_PATH="${SCRIPT_PATH%%$(basename $SCRIPT_PATH)}"

#Store either file content or std input into a variable
[ $PARSED_FILE_TO_FILTER = "TRUE" ] && INFORMATION_TO_BE_FILTERED=$FILE_TO_FILTER || INFORMATION_TO_BE_FILTERED="-"
INFORMATION_TO_BE_FILTERED="$(cat $INFORMATION_TO_BE_FILTERED)"

#Call awk auxiliary script to produce overlap percentage
if [ $PRODUCE_OVERLAP_PERCENTAGE = "TRUE" ];
then
    INFORMATION_TO_BE_FILTERED="$(awk -f ${ABSOLUTE_FOLDER_PATH}CalculateXrange.awk <<< "$INFORMATION_TO_BE_FILTERED")"
fi

#Filtering part
if [ $PERFORM_FILTERING = "TRUE" ];
then
    #Checking the specified parameter
    grep -w -q "$PARAMETER" <<< "${POSSIBLE_PARAMETERS_ARRAY[@]}"
    if [ $? -ne 0 ]; then echo "Parameter specification unrecognized...terminating"; exit; fi

    #Checking Criteria array: Only a single occurence of "$CRITERIA_STRING_SMALLER", "$CRITERIA_STRING_LARGER" or a simple number allowed.
    PURE_NUMBER_OCCURENCE=0
    for i in ${CRITERIA_ARRAY[@]}
    do
        if [[ $i =~ ^[[:digit:]]+(\.[[:digit:]]+)?$ ]]; then (( PURE_NUMBER_OCCURENCE++ )); PERCENTAGE=$i; fi
        if [[ $i =~ ^[$CRITERIA_STRING_SMALLER][+-]?[[:digit:]]+(\.[[:digit:]]+)?$ ]]; then MAXIMUM=$i; fi
        if [[ $i =~ ^[$CRITERIA_STRING_LARGER][+-]?[[:digit:]]+(\.[[:digit:]]+)?$ ]]; then MINIMUM=$i; fi
    done

    #Exclude case in which the user uses percentage on MinOv% or on MinSymm%
    if [ ${PERCENTAGE+x} ]
    then
        [ $PARAMETER == "MinOv%" ] && echo "Invalid criterion for -p option given: impossible to filter on \"MinOv%\" using a percentage, use only l<X> or g<X>. Aborting..." && exit -1
        [ $PARAMETER == "MinSymm%" ] && echo "Invalid criterion for -p option given: impossible to filter on \"MinSymm%\" using a percentage, use only l<X> or g<X>. Aborting..." && exit -1
    fi

    if [ $(wc -l < <(grep -o "$CRITERIA_STRING_LARGER" <<< "${CRITERIA_ARRAY[@]}")) -gt 1 ] || [ $(wc -l < <(grep -o "$CRITERIA_STRING_SMALLER" <<< "${CRITERIA_ARRAY[@]}")) -gt 1 ] || [ $PURE_NUMBER_OCCURENCE -gt 1 ]
    then
        echo "Each criteria specification must only occur one time...terminating"; exit
    fi

    #Extract number from maximum and minimum
    MINIMUM=$(grep -Eo "[+-]?[[:digit:]]+(\.[[:digit:]]+)?$" <<< "$MINIMUM")
    MAXIMUM=$(grep -Eo "[+-]?[[:digit:]]+(\.[[:digit:]]+)?$" <<< "$MAXIMUM")

    #Extract information for later filtering
    COLUMN_NR_OF_PARAMETER=$(head -n1 <<< "$INFORMATION_TO_BE_FILTERED" | awk -v parameter=$PARAMETER 'NR==1{for(i=1;i<=NF;++i){if($i == parameter){print i}}}')
    COLUMN_BETA_CRITICAL=$(head -n1 <<< "$INFORMATION_TO_BE_FILTERED" | awk -v parameter="betaC" 'NR==1{for(i=1;i<=NF;++i){if($i == parameter){print i}}}')
    COLUMN_CHI2=$(head -n1 <<< "$INFORMATION_TO_BE_FILTERED" | awk -v parameter="chi2" 'NR==1{for(i=1;i<=NF;++i){if($i == parameter){print i}}}')
    COLUMN_RANGES=$(head -n1 <<< "$INFORMATION_TO_BE_FILTERED" | awk -v parameter="^Beta_Ranges.*" 'NR==1{for(i=1;i<=NF;++i){if($i ~ parameter){print i}}}')
    
    if [ $PARAMETER = "chi2" ]
    then
        CHI2_PASSED=1    
    elif [ $PARAMETER = "Q" ]
    then
        Q_PASSED=1
    fi

    NR_LINES_IN_FILE=$(wc -l <<< "$INFORMATION_TO_BE_FILTERED")

    #Filtering
    CRITERIA_ARRAY_JOINED=$(join "_" ${CRITERIA_ARRAY[*]})
    CRITERIA_ARRAY_JOINED=${PARAMETER}_$CRITERIA_ARRAY_JOINED
    awk -v parameter=$PARAMETER -v column=$COLUMN_NR_OF_PARAMETER -v column_betaC=$COLUMN_BETA_CRITICAL -v column_chi2=$COLUMN_CHI2 -v column_Ranges=$COLUMN_RANGES \
        -v perc=$PERCENTAGE -v min=$MINIMUM -v max=$MAXIMUM \
        -v chi2_passed=$CHI2_PASSED -v q_passed=$Q_PASSED -v nrlines=$NR_LINES_IN_FILE -v criteria_string="$CRITERIA_ARRAY_JOINED" \
    -f ${ABSOLUTE_FOLDER_PATH}FilterFitResults.awk <<< "$INFORMATION_TO_BE_FILTERED"

else #if no filtering, then cat input
    cat <<< "$INFORMATION_TO_BE_FILTERED"
fi

