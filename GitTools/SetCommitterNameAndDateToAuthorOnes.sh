#!/bin/bash

function ParseCommandLineOption(){
    while [ "$1" != "" ]; do
        case $1 in
            -h | --help )
                printf "\n\e[0;91m"
                echo "This script will rewrite the history of your git repository on all branches,"
                echo "therefore use it with care (from great powers comes great responsibilities)!" 
                printf "\n\e[0;36m"
                echo "Running the script, the history of the repository from where the script is run will"
                echo "be analysed, looking for commits in which the author and the committer differ."
                echo "If found, the committer name/mail and date for such a commit will be set to the author"
                echo "ones and the history from there on will change."
                echo ""
                echo "An example of when this script can be useful is after a rebase, if the person who did"
                echo "it changed only the style of the commits and does not wish to be the committer, neither"
                echo "to change the time stamp of the committer."
                printf "\n\e[0;32m"
                printf "\n\e[0m"
                exit
                shift ;;
            * ) printf "\n\e[0;31m Option \e[1m$1\e[22m not recognized! Aborting...\n\n\e[0m" ; exit -1 ;;
        esac
    done
}

function ExecuteGitOperations(){ 
    #Rewrite history
    local COMMAND_TO_BE_RUN
    COMMAND_TO_BE_RUN="git filter-branch --env-filter ' 
                           if [ \"\$GIT_AUTHOR_NAME\" != \"\$GIT_COMMITTER_NAME\" ] || [ \"\$GIT_AUTHOR_DATE\" != \"\$GIT_COMMITTER_DATE\" ];
                           then 
                               export GIT_COMMITTER_NAME=\"\$GIT_AUTHOR_NAME\"   ;
                               export GIT_COMMITTER_EMAIL=\"\$GIT_AUTHOR_EMAIL\" ;
                               export GIT_COMMITTER_DATE=\"\$GIT_AUTHOR_DATE\"   ;
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

ParseCommandLineOption "$@"
ExecuteGitOperations
exit 0
