#!/bin/bash



#====================================================================================================

function ElementInArray() {
    #Remember in BASH 0 means true and >0 means false
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

function MakeFolderNames(){
	local A=${VOLUMES[0]}
	local B=${VOLUMES[1]}

	if [ ${#VOLUMES[@]} -eq 2 ]; then
        for TMP in {$A,$B}\_{$A,$B}; do
			TMP=( $(sed 's:_: :g' <<< "$TMP") )
			TMP=( $(printf '%s\n' "${TMP[@]}" | sort) )
			echo ${TMP[@]}
		done | awk '$1<$2{print $0}'
	elif [ ${#VOLUMES[@]} -eq 3 ]; then
	    local C=${VOLUMES[2]}
		for TMP in {$A,$B,$C}\_{$A,$B,$C}; do
			TMP=( $(sed 's:_: :g' <<< "$TMP") )
			TMP=( $(printf '%s\n' "${TMP[@]}" | sort) )
			echo ${TMP[@]}
		done | awk '$1<$2{print $0}'
		for TMP in {$A,$B,$C}\_{$A,$B,$C}\_{$A,$B,$C}; do
			TMP=( $(sed 's:_: :g' <<< "$TMP") )
			TMP=( $(printf '%s\n' "${TMP[@]}" | sort) )
			echo ${TMP[@]}
		done | awk '$1<$2 && $2<$3{print $0}'
	else
        local C=${VOLUMES[2]}
	   	local D=${VOLUMES[3]}
		for TMP in {$A,$B,$C,$D}\_{$A,$B,$C,$D}; do
			TMP=( $(sed 's:_: :g' <<< "$TMP") )
			TMP=( $(printf '%s\n' "${TMP[@]}" | sort) )
			echo ${TMP[@]}
		done | awk '$1<$2{print $0}'
		for TMP in {$A,$B,$C,$D}\_{$A,$B,$C,$D}\_{$A,$B,$C,$D}; do
			TMP=( $(sed 's:_: :g' <<< "$TMP") )
			TMP=( $(printf '%s\n' "${TMP[@]}" | sort) )
			echo ${TMP[@]}
		done | awk '$1<$2 && $2<$3{print $0}'
		for TMP in {$A,$B,$C,$D}\_{$A,$B,$C,$D}\_{$A,$B,$C,$D}\_{$A,$B,$C,$D}; do
			TMP=( $(sed 's:_: :g' <<< "$TMP") )
			TMP=( $(printf '%s\n' "${TMP[@]}" | sort) )
			echo ${TMP[@]}
		done | awk '$1<$2 && $2<$3 && $3<$4{print $0}'
	fi

}

#====================================================================================================
#Global variables
SETUP_LINEAR='TRUE'
SETUP_QUADRATIC='FALSE'

#Parse command line parameters
function ElementInArray() {
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

if ElementInArray "--help" $@ || ElementInArray "-h" $@; then
    printf "\n\t\e[38;5;13m\e[1m"
    printf "\e[4mPossible options to the script\e[24m:\e[21m\n\n\t\e[38;5;10m"
    printf "   -q | --quadratic       ->   Enable  set up folders for quadratic fit\n\t"
    printf "   --noLinear             ->   Disable set up folders for    linear fit\n\t"
    printf "\n\e[0m"
    exit 3
fi

while [ "$1" != "" ]; do
    case $1 in
        -q | --quadratic )
            SETUP_QUADRATIC='TRUE'
            shift 
            ;;
        --noLinear )
            SETUP_LINEAR='FALSE'
            shift
            ;;
        * ) printf "\n\e[38;5;9m Option \e[1m$1\e[21m invalid! Aborting...\n\n\e[0m"; exit -1
    esac
done

#====================================================================================================
#Start only is it makes sense
if [ $SETUP_LINEAR = 'FALSE' ] && [ $SETUP_QUADRATIC = 'FALSE' ]; then
    printf "\n\e[38;5;202m No setup has been asked! Nothing done!\n\n\e[0m"
    exit 0
fi

#Warn if any folder is here
if [ $(ls | wc -l) -ne 0 ]; then
	printf "\n\e[38;5;11m \e[1m\e[4mWARNING\e[24m:\e[21m Directory not empty! Maybe for some folder\n"
    printf "          the brute force fit command will not be created!\n\e[0m"
fi

#Ask for number of volumes
POSSIBLE_VOLS=( "12 18" "18 24" "12 18 24" "16 20 24" "18 24 30" "20 24 30" "16 20 24 30" "20 24 30 36" "others" )
printf "\n\e[38;5;118mWhich volumes have been simulated for this kappa?\n\e[0m"
select VOLUMES in "${POSSIBLE_VOLS[@]}"; do
	if ! ElementInArray "$VOLUMES" "${POSSIBLE_VOLS[@]}"; then
		continue
	else
		break
	fi
done

#In case, read new volumes from user cnd check them
if [ "$VOLUMES" = 'others' ]; then
    printf "\n\e[38;5;118mPlease, insert the volumes separated by a space: \e[0m"
    read -a VOLUMES
fi
if [ ${#VOLUMES[@]} -gt 4 ]; then
    printf "\n\e[38;5;9m At the moment, impossible to deal with more than 5 volumes! Aborting...\n\n\e[0m"
    exit -1
fi
for VOL in ${VOLUMES[@]}; do
    if [[ ! $VOL =~ ^[[:digit:]]+$ ]]; then
        printf "\n\e[38;5;9m Inserted invalid volume \"$VOL\"! Aborting...\n\n\e[0m"
        exit -1
    fi
done

#Create folders
VOLUMES=( ${VOLUMES[@]} ) #This line split above string (e.g. "18 24 30") into single array element
FOLDER_NAMES=( $(MakeFolderNames | sort | uniq | awk 'BEGIN{OFS="_";}{for(i=1; i<=NF; i++){$i="ns"$i}; print $0}') )

for FOLD in ${FOLDER_NAMES[@]}; do
	[ $SETUP_LINEAR = 'TRUE' ] && [ ! -d "gnuplot_fit_${FOLD}_linear" ] && mkdir "gnuplot_fit_${FOLD}_linear"
	[ $SETUP_QUADRATIC = 'TRUE' ] && [ ! -d "gnuplot_fit_${FOLD}_quadratic" ] && mkdir "gnuplot_fit_${FOLD}_quadratic"
done

#Ask for number of volumes
echo ""
declare -A BETA_MIN_ARRAY
declare -A BETA_MAX_ARRAY
while [ ${#BETA_MIN_ARRAY[@]} -ne ${#VOLUMES[@]} ]; do
	while [[ ! $TMP1 =~ ^[[:digit:]]([.][[:digit:]]+)?$ ]]; do
		printf "\e[38;5;118mPlease enter beta_min for ns${VOLUMES[${#BETA_MIN_ARRAY[@]}]}: \e[0m"
		read TMP1
	done
	BETA_MIN_ARRAY[${VOLUMES[${#BETA_MIN_ARRAY[@]}]}]="$TMP1"
	while [[ ! $TMP2 =~ ^[[:digit:]]([.][[:digit:]]+)?$ ]]; do
		printf "\e[38;5;128mPlease enter beta_max for ns${VOLUMES[${#BETA_MAX_ARRAY[@]}]}: \e[0m"
		read TMP2
	done
	BETA_MAX_ARRAY[${VOLUMES[${#BETA_MAX_ARRAY[@]}]}]="$TMP2"
	unset -v 'TMP1' 'TMP2'
done
echo ''

SCRIPT_PATH="`readlink -e $0`"
ABSOLUTE_FOLDER_PATH="${SCRIPT_PATH%%$(basename $SCRIPT_PATH)}"

if [ $SETUP_LINEAR = 'TRUE' ]; then
    for FOLDER in *_linear; do
	    #Continue on not empty folder
	    if [ $(ls $FOLDER | wc -l) -ne 0 ]; then
            printf "\e[38;5;9m Folder \e[1m$FOLDER\e[21m existing and not empty! No command is prepared for it!\e[0m\n"
            continue
        fi
	    #If empty build command
	    VOLS_FROM_DIR=( $(echo $FOLDER | grep -o "ns[[:digit:]]*" | grep -o "[[:digit:]]*") )
	    printf "${ABSOLUTE_FOLDER_PATH}BruteForceFit.sh --minNumDataPerVolume=2 --betaMin " > $FOLDER/BruteForceFitCommand
	    for VOL in ${VOLS_FROM_DIR[@]}; do
		    printf "${BETA_MIN_ARRAY[$VOL]} " >> $FOLDER/BruteForceFitCommand
	    done
	    echo -n '--betaMax ' >> $FOLDER/BruteForceFitCommand
	    for VOL in ${VOLS_FROM_DIR[@]}; do
		    printf "${BETA_MAX_ARRAY[$VOL]} " >> $FOLDER/BruteForceFitCommand
	    done
	    echo '' >> $FOLDER/BruteForceFitCommand
    done
fi

if [ $SETUP_QUADRATIC = 'TRUE' ]; then
    for FOLDER in *_quadratic; do
	    #Continue on not empty folder
	    if [ $(ls $FOLDER | wc -l) -ne 0 ]; then
            printf "\e[38;5;9m Folder \e[1m$FOLDER\e[21m existing and not empty! No command is prepared for it!\e[0m\n"
            continue
        fi
	    #If empty build command
	    VOLS_FROM_DIR=( $(echo $FOLDER | grep -o "ns[[:digit:]]*" | grep -o "[[:digit:]]*") )
	    printf "${ABSOLUTE_FOLDER_PATH}BruteForceFit.sh --fitType=quadratic --fitParameters=5 --minNumDataPerVolume=2 --betaMin " > $FOLDER/BruteForceFitCommand
	    for VOL in ${VOLS_FROM_DIR[@]}; do
		    printf "${BETA_MIN_ARRAY[$VOL]} " >> $FOLDER/BruteForceFitCommand
	    done
	    echo -n '--betaMax ' >> $FOLDER/BruteForceFitCommand
	    for VOL in ${VOLS_FROM_DIR[@]}; do
		    printf "${BETA_MAX_ARRAY[$VOL]} " >> $FOLDER/BruteForceFitCommand
	    done
	    echo '' >> $FOLDER/BruteForceFitCommand
    done
fi

echo ''
