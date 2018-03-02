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
    declare -A "CPR_authorYears=( $(git blame -c common_header_files/types_hmc.h | awk 'BEGIN{FS="[\(-]"}{print $2 }' 2>/dev/null | sort | uniq | awk '{array[$1" "$2]=array[$1" "$2]","$3}END{for(key in array){printf "[%s]=%s ", key, array[key]}}') )"
fi

# Remove initial comma in year string and collapse years (the strategy here is to print the first year, followed by "-", and replace following years
# by "-" if they are consecutive; at the end replace in the resulting string 2 or less "-" by "," and 3 or more "-" by one "-")
for author in "${!CPR_authorYears[@]}"; do
    CPR_authorYears["${author}"]=$(echo "${CPR_authorYears["$author"]:1}" |
                                           tr ',' '\n' |
                                           awk 'NR==1{previousYear=$1; printf "%d-", $1; lastYearPrinted=1} NR>1{if($1==previousYear+1){printf "-"; lastYearPrinted=0; previousYear=$1}else{if(lastYearPrinted==0){printf "%d-", previousYear}; printf "%d-", $1; previousYear=$1; lastYearPrinted=1}}END{if(lastYearPrinted==0){printf "%d-", $1}}' |
                                           sed -e 's/[-][-][-]\+/|/g' -e 's/[-][-]\?/,/g' -e 's/|/-/g')
done
    
# Remove last comma and create different associative array for later (years as keys)
declare -A CPR_yearsAuthor
for author in "${!CPR_authorYears[@]}"; do
    CPR_yearsAuthor[${CPR_authorYears["$author"]%?}]="$author"
done



for yearString in "${!CPR_yearsAuthor[@]}"; do
    printf "%s Copyright (c) %s %s\n"   "${CPR_prefix}"   "${yearString}"   "${CPR_yearsAuthor[$yearString]}"
done | sort
