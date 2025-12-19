function ParseCommandLineOptionsAndChecksGivenInformation(){

    while [ "$1" != "" ]; do
        case $1 in
            -h | --help )
	            printf "\n\e[0;32m"
	            echo "Call the script $0 with the following optional arguments:"
	            echo "  -h | --help"
	            echo "  -f | --filename                ->   Files containing data to be collapsed (at least 2)"
	            echo "  -v | --ns                      ->   Volumes of the data, in the same order as files (at least 2)"
	            echo "  -x | --xColumn                 ->   Column in the file containing the quantity to be put on x-axis (counting from 1, default = $X_COLUMN)"
                echo "                                      This quantity is considered without error!"
                echo "  --xmin                         ->   Only data between xmin and xmax will be considered in the collapse. This means that data outside"
                echo "  --xmax                              the given range are not considered (and then not rescaled). These are used only if given."
                echo "                                      Since each volume can in principle have a different range, insert the option value as "
                echo "                                      \"ns xmin\" or \"ns xmax\" without forgetting the quotation marks (i.e. \"16 5.456\")!"  
	            echo "  -y | --yColumn                 ->   Column in the file containing observable to be collapsed (counting from 1, default = $Y_COLUMN)"
                echo "                                      The error on the observable is considered automatically to be in the following column!"
                echo "  -b | --betaC                   ->   The critical value for beta to be used in the collapse. More values can be given."
                echo "                                      If desired, a minimum and maximum value together with a resolution can be specified, in order"
                echo "                                      to do an homogeneous scan. Use the following syntax \"[min max res]\" without forgetting the"
                echo "                                      quotation marks! This syntax can be used several times!"
                echo "  -r | --integralResolution      ->   The resolution in x for the numerical integral (default = $COLLAPSE_RESOLUTION)"
                echo "  -t | --integralThreshold       ->   The resolution in x for the numerical integral is varied until the result is correct up to the"
                echo "                                      given threshold (default = ${COLLAPSE_THRESHOLD}%). If used, then the initial integral resolution"
                echo "                                      used is the one specified via the -r | --integralResolution option. Note that it is a percentage, so"
                echo "                                      if for example you desire the collapse correct up to 1% just give \"-t 1\"" 
                echo "  --factorToIncreaseResolution   ->   This is the factor by which the integral resolution is multiplied at each iteration to make the"
                echo "                                      result converge to the desired precition. It has to be a number in between 0 and 1 (default ${FACTOR_TO_INCREASE_COLLAPSE_RESOLUTION})" 
                echo "  --nu                           ->   The value of the exponent nu to be used in the collapse. More values can be given."
                echo "                                      If desired, a minimum and maximum value together with a resolution can be specified, in order"
                echo "                                      to do an homogeneous scan. Use the following syntax \"[min max res]\" without forgetting the quotation marks!"
                echo "  --useFixedIntegralResolution   ->   Ignore integral threshold and use given resolution"
                echo "  --doNotDeleteAuxFiles          ->   Keep all intermediate produced files"
                echo "  --doNotPlot                    ->   Disable plotting functionalities"
                echo "  --justDeleteAuxFiles           ->   Do not calculate anything, but delete auxiliary files maybe preduced in a previous run"
	            echo -e "\n\e[0;35mNOTE: \e[0;35m!"
	            printf "\n\e[0m"
	            exit
                ;;
            -f | --filename )  
                while [[ ! $2 =~ ^- ]] && [ "$2" != "" ]; do
                    DATA_FILENAMES+=( $2 )
                    shift
                done
                shift ;;
            -v | --ns )  
                while [[ ! $2 =~ ^- ]] && [ "$2" != "" ]; do
                    VOLUMES+=( $2 )
                    shift
                done
                shift ;;
            -x | --xColumn )
                if [[ $2 =~ ^[[:digit:]]+$ ]]; then
                    X_COLUMN=$2
                    shift
                else
                    printf "\n\e[38;5;202m Value \e[1m${2}\e[21m not valid for option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1
                fi
                shift ;;
            --xmin )
                while [[ $2 =~ ^[[:digit:]]+[[:space:]]+[+-]?[[:digit:]]*[.]?[[:digit:]]*$ ]]; do
                    local TMP=( $2 )
                    X_MIN[${TMP[0]}]=${TMP[1]}
                    shift
                done
                shift ;;
            --xmax )
                while [[ $2 =~ ^[[:digit:]]+[[:space:]]+[+-]?[[:digit:]]*[.]?[[:digit:]]*$ ]]; do
                    local TMP=( $2 )
                    X_MAX[${TMP[0]}]=${TMP[1]}
                    shift
                done
                shift ;;
            -y | --yColumn )
                if [[ $2 =~ ^[[:digit:]]+$ ]]; then
                    Y_COLUMN=$2
                    shift
                else
                    printf "\n\e[38;5;202m Value \e[1m${2}\e[21m not valid for option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1
                fi
                shift ;;
            -b | --betaC )
                while [[ ! $2 =~ ^- ]] && [ "$2" != "" ]; do
                    if [[ $2 =~ ^\[[+-]?[[:digit:]]*[.]?[[:digit:]]*[[:space:]]+[+-]?[[:digit:]]*[.]?[[:digit:]]*[[:space:]]+[+-]?[[:digit:]]*[.]?[[:digit:]]*\]$ ]]; then
                        local BETA_RANGE="${2##*\[}"
                        BETA_RANGE=( ${BETA_RANGE%?} )
                        BETA_C+=( $(awk 'BEGIN{ORS=" "}{for(i=$1; i<=$2+$3/1e6; i+=$3){print i}}' <<< "${BETA_RANGE[0]} ${BETA_RANGE[1]} ${BETA_RANGE[2]}") )
                        shift
                    elif [[ $2 =~ ^[+-]?[[:digit:]]*[.]?[[:digit:]]*$ ]]; then
                        BETA_C+=( $2 )
                        shift
                    else
                        printf "\n\e[38;5;202m Value \e[1m${2}\e[21m not valid for option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1
                    fi
                done
                shift ;;
            -r | --resolution )
                if [[ $2 =~ ^[+-]?[[:digit:]]*[.]?[[:digit:]]*$ ]]; then
                    COLLAPSE_RESOLUTION=$2
                    shift
                else
                    printf "\n\e[38;5;202m Value \e[1m${2}\e[21m not valid for option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1
                fi
                shift ;;
            -t | --integralThreshold )
                if [[ $2 =~ ^[+-]?[[:digit:]]*[.]?[[:digit:]]*$ ]]; then
                    COLLAPSE_THRESHOLD=$2
                    shift
                else
                    printf "\n\e[38;5;202m Value \e[1m${2}\e[21m not valid for option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1
                fi
                shift ;;
            --factorToIncreaseResolution )
                if [[ $2 =~ ^[+-]?[[:digit:]]*[.]?[[:digit:]]*$ ]] && [ $(awk '{print (($1>0) && ($1<1))}' <<< $2) -eq 1 ]; then
                    FACTOR_TO_INCREASE_COLLAPSE_RESOLUTION=$2
                    shift
                else
                    printf "\n\e[38;5;202m Value \e[1m${2}\e[21m not valid for option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1
                fi
                shift ;;
            --nu )
                while [[ ! $2 =~ ^- ]] && [ "$2" != "" ]; do
                    if [[ $2 =~ ^\[[+-]?[[:digit:]]*[.]?[[:digit:]]*[[:space:]]+[+-]?[[:digit:]]*[.]?[[:digit:]]*[[:space:]]+[+-]?[[:digit:]]*[.]?[[:digit:]]*\]$ ]]; then
                        local NU_RANGE="${2##*\[}"
                        NU_RANGE=( ${NU_RANGE%?} )
                        NU+=( $(awk 'BEGIN{ORS=" "}{for(i=$1; i<=$2+$3/1e6; i+=$3){print i}}' <<< "${NU_RANGE[0]} ${NU_RANGE[1]} ${NU_RANGE[2]}") )
                        shift
                    elif [[ $2 =~ ^[+-]?[[:digit:]]*[.]?[[:digit:]]*$ ]]; then
                        NU+=( $2 )
                        shift
                    else
                        printf "\n\e[38;5;202m Value \e[1m${2}\e[21m not valid for option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1
                    fi
                done
                shift ;;
            --useFixedIntegralResolution )
                USE_FIXED_RESOLUTION='TRUE'
                shift ;;
            --doNotDeleteAuxFiles )
                DELETE_INTERMEDIATE_FILES='FALSE'
                shift ;;
            --doNotPlot )
                MAKE_PLOT='FALSE'
                shift ;;
            --justDeleteAuxFiles )
                JUST_DELETE_AUX_FILES='TRUE'
                shift ;;
            * ) printf "\n\e[0;31m Unknouwn option \e[1m${1}\e[21m! Aborting...\n\n\e[0m" 1>&2; exit -1 ;;
        esac
    done

    if [ ${#DATA_FILENAMES[@]} -lt 2 ]; then
        printf "\n\e[0;31m At least two data files are needed! Aborting...\n\n\e[0m" 1>&2; exit -1
    fi
    if [ ${#VOLUMES[@]} -ne ${#DATA_FILENAMES[@]} ]; then
        printf "\n\e[0;31m Volume for each datafile is needed (${#DATA_FILENAMES[@]} files provided but only ${#VOLUMES[@]} volumes)! Aborting...\n\n\e[0m" 1>&2; exit -1
    fi

    if [ ${#BETA_C[@]} -eq 0 ]; then
        printf "\n\e[0;31m The critical beta must be provided! Aborting...\n\n\e[0m" 1>&2; exit -1
    fi

    if [ ${#NU[@]} -eq 0 ]; then
        printf "\n\e[0;31m The value of the critical exponent nu must be provided! Aborting...\n\n\e[0m" 1>&2; exit -1
    fi

    for FILE in ${DATA_FILENAMES[@]}; do
        if [ ! -f $FILE ]; then
            printf "\n\e[0;31m File \"$FILE\" not found! Aborting...\n\n\e[0m" 1>&2; exit -1
        fi
    done && unset -v 'FILE'

    #Fill not given ranges with default label
    for VOL in ${VOLUMES[@]}; do
        if ! KeyInArray $VOL X_MIN; then
            X_MIN[$VOL]='notGiven'
        fi
        if ! KeyInArray $VOL X_MAX; then
            X_MAX[$VOL]='notGiven'
        fi
    done && unset -v 'VOL'

    #Check wether the file are sorted according to x column
    for FILE in ${DATA_FILENAMES[@]}; do
        if $(sort --numeric-sort --check=silent --key $X_COLUMN $FILE); then
            continue
        else
            printf "\n\e[0;31m File \"$FILE\" not sorted according to column $X_COLUMN! Aborting...\n\n\e[0m" 1>&2; exit -1
        fi
    done && unset -v 'FILE'

}
