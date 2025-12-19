#!/bin/bash
#
#  Copyright (c) 2017,2019 Alessandro Sciarra
#
#  This file is part of "Script utilities".
#
#  "Script utilities" is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  "Script utilities" is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with "Script utilities". If not, see <http://www.gnu.org/licenses/>.
#


#Inspired from https://help.github.com/articles/changing-author-info/

function ElementInArray() {
    #Remember in BASH 0 means true and >0 means false
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

function GetElementOfArrayAndFollowingIfNotAnOption(){
    local ELEMENT_TO_BE_FOUND=$1; shift
    #Assume that element to be found is in array, do not check
    while [ "$1" != '' ]; do
        if [[ "$ELEMENT_TO_BE_FOUND" == "$1" ]]; then
            shift
            if [[ $1 =~ ^- ]]; then
                echo "$ELEMENT_TO_BE_FOUND"
            else
                echo "$ELEMENT_TO_BE_FOUND $1"
            fi
            return
        else
            shift
        fi
    done
}

function ParseCommandLineOption(){
    while [ "$1" != "" ]; do
        case $1 in
            -h | --help )
                printf "\n\e[0;91m"
                echo "This script will rewrite the history of your git repository on all branches,"
                echo "therefore use it with care (from great powers comes great responsibilities)!"
                printf "\n\e[0;36m"
                echo "Running the script, the history of the repository from where the script is run will"
                echo "be analysed, looking for wrong authors and/or committers. If found, the information"
                echo "for such a commit will be changed and the history from there on will change."
                echo ""
                printf "\n\e[0;32m"
                echo "Call the script $0 with the following optional arguments:"
                echo "  --help"
                echo "  --oldAuthorEmail      ->    Author email to be corrected"
                echo "  --newAuthorEmail      ->    Author email to be used"
                echo "  --newAuthorName       ->    Author name to be used"
                echo "  --oldCommitterEmail   ->    Committer email to be corrected (if not given, use old author email)"
                echo "  --newCommitterEmail   ->    Committer email to be used      (if not given, use new author email)"
                echo "  --newCommitterName    ->    Committer name to be used       (if not given, use new author name)"
                echo ""
	            echo "  --use-mailmap         ->    Execute author and committer replacement using a file in the format"
                echo "                              of a complete git .mailmap file. If the file is specified after the"
                echo "                              option, it is used, otherwise the file used is the \".mailmap\" one. The"
                echo "                              \"complete\" adjective means that the file must contain four information"
                echo "                              per line: \"Proper Name <proper@email.xx> Wrong Name <wrong@email.xx>\""
                printf "\n\e[1;33mNOTE: \e[22;36m"
                echo "If the option \"--use-mailmap\" is given, all the other ones are ignored!"
                printf "\n\e[0m"
                exit
                shift ;;
            --oldAuthorEmail )
                OLD_AUTHOR_EMAIL="$2"
                shift 2 ;;
            --newAuthorEmail )
                NEW_AUTHOR_EMAIL="$2"
                shift 2 ;;
            --newAuthorName )
                NEW_AUTHOR_NAME="$2"
                shift 2 ;;
            --oldCommitterEmail )
                OLD_COMMITTER_EMAIL="$2"
                shift 2 ;;
            --newCommitterEmail )
                NEW_COMMITTER_EMAIL="$2"
                shift 2 ;;
            --newCommitterName )
                NEW_COMMITTER_NAME="$2"
                shift 2 ;;
            --use-mailmap )
                USE_MAILMAP='TRUE'
                if [[ $2 =~ ^[^-] ]]; then
                    MAILMAP_FILENAME=$2; shift
                fi
                shift ;;
            * ) printf "\n\e[0;31m Option \e[1m$1\e[22m not recognized! Aborting...\n\n\e[0m" ; exit -1 ;;
        esac
    done
}

function ExecuteGitOperations(){
    #Rewrite history
    local COMMAND_TO_BE_RUN
    COMMAND_TO_BE_RUN="git filter-branch --env-filter '
                           WRONG_AUTHOR_EMAIL=\"$1\" ;
                           CORRECT_AUTHOR_EMAIL=\"$2\" ;
                           CORRECT_AUTHOR_NAME=\"$3\" ;
                           WRONG_COMMITTER_EMAIL=\"$4\" ;
                           CORRECT_COMMITTER_EMAIL=\"$5\" ;
                           CORRECT_COMMITTER_NAME=\"$6\" ;
                           if [ \"\$GIT_COMMITTER_EMAIL\" = \"\$WRONG_COMMITTER_EMAIL\" ] || [ \"\$GIT_COMMITTER_EMAIL\" = \"\$CORRECT_COMMITTER_EMAIL\" ];
                           then
                               export GIT_COMMITTER_NAME=\"\$CORRECT_COMMITTER_NAME\"   ;
                               export GIT_COMMITTER_EMAIL=\"\$CORRECT_COMMITTER_EMAIL\" ;
                           fi ;
                           if [ \"\$GIT_AUTHOR_EMAIL\" = \"\$WRONG_AUTHOR_EMAIL\" ] || [ \"\$GIT_AUTHOR_EMAIL\" = \"\$CORRECT_AUTHOR_EMAIL\" ];
                           then
                               export GIT_AUTHOR_NAME=\"\$CORRECT_AUTHOR_NAME\"   ;
                               export GIT_AUTHOR_EMAIL=\"\$CORRECT_AUTHOR_EMAIL\" ;
                           fi ;
    ' --tag-name-filter cat -- --all"

    printf "\n\e[36m Rewriting history...\n\n\e[0m"
    eval $(echo "$COMMAND_TO_BE_RUN")
    if [ $(git for-each-ref --format="%(refname)" refs/original/ | wc -l) -ne 0 ]; then
        git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d
    fi

    #Ensure all old refs are fully removed
    printf "\n\e[36m Ensure all old refs are fully removed...\n"
    rm -Rf .git/logs .git/refs/original

    #Git repository state before cleaning
    printf "\n\e[36m Git repository state before cleaning:\n\n\e[0m"
    git count-objects -vH

    #Cleaning
    printf "\n\e[36m Cleaning...\n\n\e[0m"
    git gc --prune=all --aggressive

    #Git repository state after cleaning
    printf "\n\e[36m Git repository state after cleaning:\n\n\e[0m"
    git count-objects -vH
}

#===================================================================================================================================#
#Script variables
OLD_AUTHOR_EMAIL=''
NEW_AUTHOR_EMAIL=''
NEW_AUTHOR_NAME=''
OLD_COMMITTER_EMAIL=''
NEW_COMMITTER_EMAIL=''
NEW_COMMITTER_NAME=''
USE_MAILMAP='FALSE'
MAILMAP_FILENAME=".mailmap"

#ParseCommandLineOption
SPECIFIED_COMMAND_LINE_OPTIONS=( "$@" )
if ElementInArray "--help" ${SPECIFIED_COMMAND_LINE_OPTIONS[@]}; then
    SPECIFIED_COMMAND_LINE_OPTIONS=( "--help" )
elif ElementInArray "--use-mailmap" ${SPECIFIED_COMMAND_LINE_OPTIONS[@]}; then
    SPECIFIED_COMMAND_LINE_OPTIONS=( $(GetElementOfArrayAndFollowingIfNotAnOption "--use-mailmap" ${SPECIFIED_COMMAND_LINE_OPTIONS[@]}) )
fi
ParseCommandLineOption "${SPECIFIED_COMMAND_LINE_OPTIONS[@]}"

#Check options
if [ $USE_MAILMAP = 'FALSE' ]; then

    if [ "$OLD_AUTHOR_EMAIL" = '' ] || [ "$NEW_AUTHOR_EMAIL" = '' ] || [ "$NEW_AUTHOR_NAME" = '' ]; then
        echo "OLD_AUTHOR_EMAIL=$OLD_AUTHOR_EMAIL"
        echo "NEW_AUTHOR_EMAIL=$NEW_AUTHOR_EMAIL"
        echo " NEW_AUTHOR_NAME=$NEW_AUTHOR_NAME"
        printf "\n\e[0;31m Options \e[1m--oldAuthorEmail --newAuthorEmail --newAuthorName\e[22m are mandatory! Aborting...\n\n\e[0m"
        exit -1
    fi

    #Use author information for committer if not differently specified
    [ "$OLD_COMMITTER_EMAIL" = '' ] && OLD_COMMITTER_EMAIL=$OLD_AUTHOR_EMAIL
    [ "$NEW_COMMITTER_EMAIL" = '' ] && NEW_COMMITTER_EMAIL=$NEW_AUTHOR_EMAIL
    [ "$NEW_COMMITTER_NAME" = '' ]  &&  NEW_COMMITTER_NAME=$NEW_AUTHOR_NAME

    ExecuteGitOperations $OLD_AUTHOR_EMAIL  $NEW_AUTHOR_EMAIL "$NEW_AUTHOR_NAME" $OLD_COMMITTER_EMAIL $NEW_COMMITTER_EMAIL "$NEW_COMMITTER_NAME"

else

    if [ ! -f $MAILMAP_FILENAME ]; then
        printf "\n\e[0;91m File \e[1m$MAILMAP_FILENAME\e[22m not found! Aborting...\n\n\e[0m"
        exit -1
    fi

    #In mailmap the format is:   proper name <proper@mail>   wrong name <wrong@mail>
    while read LINE; do
        #Discard empty lines and comments in lines or commented lines (# as comment symbol)
        if [[ $LINE =~ ^[[:blank:]]*# ]] || [[ $LINE =~ ^[[:blank:]]*$ ]]; then
            continue
        fi
        LINE=`echo $LINE | awk '{split($0, res, "#"); print res[1]}'`

        #Parse the line extracting the information to call ExecuteGitOperations
        NEW_AUTHOR_NAME="${LINE%%<*}"
        LINE="${LINE#*<}"
        NEW_AUTHOR_EMAIL="${LINE%%>*}"
        LINE="${LINE#*<}"
        OLD_AUTHOR_EMAIL="${LINE%>*}"
        #Committer from author
        OLD_COMMITTER_EMAIL=$OLD_AUTHOR_EMAIL
        NEW_COMMITTER_EMAIL=$NEW_AUTHOR_EMAIL
        NEW_COMMITTER_NAME=$NEW_AUTHOR_NAME

        printf "\n\e[1;33m=========================================================================================\n\n\e[0m"
        echo "<$OLD_AUTHOR_EMAIL>  ->  $NEW_AUTHOR_NAME <$NEW_AUTHOR_EMAIL>   |   <$OLD_COMMITTER_EMAIL>  ->  $NEW_COMMITTER_NAME <$NEW_COMMITTER_EMAIL>"
        ExecuteGitOperations $OLD_AUTHOR_EMAIL  $NEW_AUTHOR_EMAIL "$NEW_AUTHOR_NAME" $OLD_COMMITTER_EMAIL $NEW_COMMITTER_EMAIL "$NEW_COMMITTER_NAME"

    done < <(cat $MAILMAP_FILENAME)
    printf "\n\e[1;33m=========================================================================================\n\n\e[0m"

fi

#Done
echo; exit 0
