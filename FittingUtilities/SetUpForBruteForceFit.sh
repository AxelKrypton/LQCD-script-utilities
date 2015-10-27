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

#Warn if any folder is here
if [ $(ls | wc -l) -ne 0 ]; then
	printf "\n\e[38;5;11m \e[1m\e[4mWARNING\e[24m:\e[21m Directory not empty! Maybe for some folder\n"
    printf "          the brute force fit command will not be created!\n\e[0m"
fi

#Ask for number of volumes
POSSIBLE_VOLS=( "12 18" "18 24" "16 20 24" "20 24 30" "16 20 24 30" "20 24 30 36" )
printf "\nWhich volumes have been simulated for this kappa?\n"
select VOLUMES in "${POSSIBLE_VOLS[@]}"; do
	if ! ElementInArray "$VOLUMES" "${POSSIBLE_VOLS[@]}"; then
		continue
	else
		break
	fi
done

#Create folders
VOLUMES=( $VOLUMES )
FOLDER_NAMES=( $(MakeFolderNames | sort | uniq | awk 'BEGIN{OFS="_";}{for(i=1; i<=NF; i++){$i="ns"$i}; print $0}') )
for FOLD in ${FOLDER_NAMES[@]}; do
	[ ! -d "gnuplot_fit_${FOLD}_linear" ] && mkdir "gnuplot_fit_${FOLD}_linear"
	[ ! -d "gnuplot_fit_${FOLD}_quadratic" ] && mkdir "gnuplot_fit_${FOLD}_quadratic"
done

#Ask for number of volumes
echo ""
declare -A BETA_MIN_ARRAY
declare -A BETA_MAX_ARRAY
while [ ${#BETA_MIN_ARRAY[@]} -ne ${#VOLUMES[@]} ]; do
	while [[ ! $TMP =~ ^[[:digit:]]([.][[:digit:]]+)?$ ]]; do
		printf "Please enter beta_min for ns${VOLUMES[${#BETA_MIN_ARRAY[@]}]}: "
		read TMP
	done
	BETA_MIN_ARRAY[${VOLUMES[${#BETA_MIN_ARRAY[@]}]}]="$TMP"
	unset -v 'TMP'
done
echo ""
while [ ${#BETA_MAX_ARRAY[@]} -ne ${#VOLUMES[@]} ]; do
	while [[ ! $TMP =~ ^[[:digit:]]([.][[:digit:]]+)?$ ]]; do
		printf "Please enter beta_max for ns${VOLUMES[${#BETA_MAX_ARRAY[@]}]}: "
		read TMP
	done
	BETA_MAX_ARRAY[${VOLUMES[${#BETA_MAX_ARRAY[@]}]}]="$TMP"
	unset -v 'TMP'
done
echo ''
SCRIPT_PATH="`readlink -e $0`"
ABSOLUTE_FOLDER_PATH="${SCRIPT_PATH%%$(basename $SCRIPT_PATH)}"

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

echo ''
