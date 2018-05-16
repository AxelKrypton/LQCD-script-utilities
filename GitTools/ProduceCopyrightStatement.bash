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
                echo "  -p | --prefix           ->    Prefix for each line of the copyright statement"
                echo "  -f | --filename         ->    file in the git to be used"
                echo "  -s | --substitute       ->    look for copyright statement in file and replace it"
                echo "  -b | --beginCopyright   ->    used with -s option to specify where the copyright statement begins"
                echo "                                (if not given, a line started with the prefix followed by 'Copyright' is used)"
                echo "  -e | --endCopyright     ->    used with -s option to specify where the copyright statement ends"
                echo "                                (if not given, a line with only the prefix and no trailing spaces is used)"
                echo "  --preview               ->    if -s is given, make file preview using less and ask confirmation"
                printf "\n\e[0m"
                exit
                shift ;;
            -f | --filename )
                CPR_filename="$2"
                shift 2 ;;
            -p | --prefix )
                CPR_prefix="$2"
                shift 2 ;;
            -s | --substitute )
                CPR_substitute='TRUE'
                shift ;;
            --preview )
                CPR_preview='TRUE'
                shift ;;
            -b | --beginCopyright )
                CPR_beginCopyright="$2"
                shift 2 ;;
            -e | --endCopyright )
                CPR_endCopyright="$2"
                shift 2 ;;
            * ) printf "\n\e[0;31m Option \e[1m$1\e[21m not recognized! Aborting...\n\n\e[0m" ; exit -1 ;;
        esac
    done
}

#----------------------------------------------------------------------#
# Global vasriables
CPR_filename=''
CPR_prefix=''
CPR_substitute='FALSE'
CPR_preview='FALSE'
CPR_endCopyright=''
CPR_beginCopyright=''

ParseCommandLineOption "$@"
if [ "${CPR_filename}" = '' ]; then
    printf "\n\e[0;91m Option \"-f\" is mandatory! Aborting...\n\n\e[0m"; exit -1
fi
if [ "${CPR_endCopyright}" = '' ]; then
    CPR_endCopyright="$(sed 's/[ ]*$//' <<< "${CPR_prefix}")"
fi
if [ "${CPR_beginCopyright}" = '' ]; then
    CPR_beginCopyright="${CPR_prefix}Copyright"
fi
CPR_beginCopyrightEscaped="$(sed -e 's/\*/[*]/g' <<< "${CPR_beginCopyright}")"
CPR_endCopyrightEscaped="$(sed -e 's/\*/[*]/g' <<< "${CPR_endCopyright}")"

# If file is valid use git blame to get all the authors who contributed to the file and use awk to
# build a bash associative array initialisation string which can be used with "declare -A"
if [ ! -f "${CPR_filename}" ]; then
    printf "\n\e[0;91m File \"${CPR_filename}\" not existing! Aborting...\n\n\e[0m"; exit -1
else
    #In the last awk command the year=$NF; $NF=""; commands are needed to consider that a name could be made up by many words
    declare -A "CPR_authorYearsTmp=( $(git blame -c ${CPR_filename} | awk 'BEGIN{FS="[\(-]"}{print $2 }' 2>/dev/null | sort | uniq | awk '{year=$NF; $NF=""; array[$0]=array[$0]","year}END{for(key in array){printf "[%s]=%s ", key, array[key]}}') )"
fi

#Remove last trailing space from author and do not consider author "Not Committed Yet"
declare -A CPR_authorYears
for author in "${!CPR_authorYearsTmp[@]}"; do
    if [[ ! $author =~ Not\ Committed\ Yet ]]; then
        CPR_authorYears["${author%?}"]=${CPR_authorYearsTmp["${author}"]}
    fi
done

# Remove initial comma in year string and collapse years (the strategy here is to print the first year, followed by "-", and replace following years
# by "-" if they are consecutive (i.e. if the previous and the following in the list are the previous and the following year); at the end replace
# in the resulting string 2 or more "-" by one "|", 1 "-" by "," and "|" by "-"). Print always a "-" after the end so that there is always a "," at
# the end, which will be replaced later (see below).
for author in "${!CPR_authorYears[@]}"; do
    CPR_authorYears["${author}"]=$(awk 'BEGIN{FS=","}{printf "%d-", $1; for(i=2; i<NF; i++){if($(i-1)+1==$i && $(i)+1==$(i+1)){printf "-"}else{printf "%d-", $i}}; if(NF>1){printf "%d-", $NF}}' <<< "${CPR_authorYears["$author"]:1}" | sed -e 's/[-][-]\+/|/g' -e 's/[-]/,/g' -e 's/|/-/g')
done

# Remove last comma 
declare -A CPR_yearsAuthor
for author in "${!CPR_authorYears[@]}"; do
    CPR_authorYears["${author}"]=${CPR_authorYears["$author"]%?}
done

# Print copyright statement sorted by year
CPR_copyright=$(for author in "${!CPR_authorYears[@]}"; do
                    printf "%sCopyright (c) %s %s\n"   "${CPR_prefix}"   "${CPR_authorYears[${author}]}"   "${author}"
                done | sort)
echo; echo "----------------------------------------------------------------"
printf "${CPR_copyright//%/%%}\n"
echo "----------------------------------------------------------------"; echo
if [ ${CPR_substitute} = 'TRUE' ]; then
    if [ ${CPR_preview} = 'TRUE' ]; then
        sed ':a;N;$!ba;s@'"${CPR_beginCopyrightEscaped}"'.*\n'"${CPR_endCopyrightEscaped}"'@LINE_WHERE_COPYRIGHT_SHOULD_BE_INSERTED\n'"${CPR_prefix}"'\n'"${CPR_endCopyright}"'@g' ${CPR_filename} | awk -v "copyright=${CPR_copyright}" '{if($0=="LINE_WHERE_COPYRIGHT_SHOULD_BE_INSERTED"){printf copyright"\n"}else{print $0}}' | less
        printf "\n\e[0;96m Would you like to replace the given file with the previewed one (Y/N)? \e[0m"
        while read CONFIRM; do
            if [ "$CONFIRM" = "Y" ]; then
                break;
            elif [ "$CONFIRM" = "N" ]; then
                echo; exit
            else
                printf "\n\e[0;33m Please enter Y (yes) or N (no): \e[0m"
            fi
        done; unset -v 'CONFIRM'
    fi
    CPR_filenameBackup="ORIGINAL_${CPR_filename////__}"
    cp "${CPR_filename}" "${CPR_filenameBackup}" || exit -1
    #Print file with new copyright overwriting old one which was already backed up
    sed ':a;N;$!ba;s@'"${CPR_beginCopyrightEscaped}"'.*\n'"${CPR_endCopyrightEscaped}"'@LINE_WHERE_COPYRIGHT_SHOULD_BE_INSERTED\n'"${CPR_prefix}"'\n'"${CPR_endCopyright}"'@g' ${CPR_filenameBackup} | awk -v "copyright=${CPR_copyright}" '{if($0=="LINE_WHERE_COPYRIGHT_SHOULD_BE_INSERTED"){printf copyright"\n"}else{print $0}}' > "${CPR_filename}"
fi
