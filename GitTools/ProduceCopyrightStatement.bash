#!/bin/bash

# This script is intended to produce a copyright statement for a file
# in a git repository, which contains all the authors which contributed
# to the file. The format looks like the following:
#
# Copyright (c) 2018 Alessandro Sciarra
#----------------------------------------------------------------------#

function ParseCommandLineOption(){
    while [ "$1" != "" ]; do
        case $1 in
            -h | --help )
                printf "\n\e[0;36m"
                echo 'This script is intended to produce a copyright statement for a file'
                echo 'in a git repository, which contains all the authors which contributed'
                echo 'to the file. The format looks like the following:'
                echo ''
                echo 'Copyright (c) 2018 Alessandro Sciarra'
                echo ''
                printf "\n\e[0;32m"
                echo "Call the script $0 with the following optional arguments:"
                echo "  --help"
                echo "  -p | --prefix      ->    Prefix for each line of the copyright statement"
                echo "  -f | --filename    ->    file in the git to be used"
                printf "\n\e[0m"
                exit
                shift ;;
            -f | --filename )
                CPR_filename="$2"
                shift 2 ;;
            -p | --prefix )
                CPR_prefix="$2"
                shift 2 ;;
            * ) printf "\n\e[0;31m Option \e[1m$1\e[21m not recognized! Aborting...\n\n\e[0m" ; exit -1 ;;
        esac
    done
}

#----------------------------------------------------------------------#
# Global vasriables
CPR_filename=''
CPR_prefix=''

ParseCommandLineOption "$@"
if [ "${CPR_filename}" = '' ]; then
    printf "\n\e[0;91m Option \"-f\" is mandatory! Aborting...\n\n\e[0m"; exit -1
fi    

# If file is valid use git blame to get all the authors who contributed to the file and use awk to
# build a bash associative array initialisation string which can be used with "declare -A"
if [ ! -f "${CPR_filename}" ]; then
    printf "\n\e[0;91m File \"${CPR_filename}\" not existing! Aborting...\n\n\e[0m"; exit -1
else
    declare -A "CPR_authorYears=( $(git blame -c ${CPR_filename} | awk 'BEGIN{FS="[\(-]"}{print $2 }' 2>/dev/null | sort | uniq | awk '{array[$1" "$2]=array[$1" "$2]","$3}END{for(key in array){printf "[%s]=%s ", key, array[key]}}') )"
fi

# Remove initial comma in year string and collapse years (the strategy here is to print the first year, followed by "-", and replace following years
# by "-" if they are consecutive (i.e. if the previous and the following in the list are the previous and the following year); at the end replace
# in the resulting string 2 or more "-" by one "|", 1 "-" by "," and "|" by "-"). Print always a "-" after the end so that there is always a "," at
# the end, which will be replaced later (see below).
for author in "${!CPR_authorYears[@]}"; do
    CPR_authorYears["${author}"]=$(awk 'BEGIN{FS=","}{printf "%d-", $1; for(i=2; i<NF; i++){if($(i-1)+1==$i && $(i)+1==$(i+1)){printf "-"}else{printf "%d-", $i}}; if(NF>1){printf "%d-", $NF}}' <<< "${CPR_authorYears["$author"]:1}" | sed -e 's/[-][-]\+/|/g' -e 's/[-]/,/g' -e 's/|/-/g')
done
    
# Remove last comma and create different associative array for later (years as keys)
declare -A CPR_yearsAuthor
for author in "${!CPR_authorYears[@]}"; do
    CPR_yearsAuthor[${CPR_authorYears["$author"]%?}]="$author"
done

# Print copyright statement sorted by year
for yearString in "${!CPR_yearsAuthor[@]}"; do
    printf "%s Copyright (c) %s %s\n"   "${CPR_prefix}"   "${yearString}"   "${CPR_yearsAuthor[$yearString]}"
done | sort
