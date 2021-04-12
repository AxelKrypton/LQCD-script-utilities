#!/usr/bin/env bash

if [[ $# -gt 0 ]]; then
    printf '\n \e[92mRun the present script without command line options and from inside a git repository.\e[0m\n\n'
    exit 0
fi

function MakeSummaryByCommit()
{
    if hash git-summary; then
        printf '\n \e[96mCreating git contribution summary on present repository branch \e[1;93mby commit number\e[22;96m:\e[0m\n'
        git summary | awk 'NR<=7{print $0} NR>7{printf "\t\t%s\n", $0}'
    else
        printf '\n \e[93mCommand "git-summary" not found, consider to install git-extras => https://github.com/tj/git-extras\[0m\n\n'
    fi
}

function MakeSummaryByLineOfCode()
{
    if hash git-line-summary; then
        printf ' \e[96mCreating git contribution summary on present repository branch \e[1;93mby existing lines of code\e[22;96m:\e[0m\n'
        git line-summary | awk 'NR<=4{print $0} NR>4{printf "\t\t%s\n", $0}'
    else
        printf '\n \e[93mCommand "git-summary" not found, consider to install git-extras => https://github.com/tj/git-extras\[0m\n\n'
    fi
}

function MakeSummaryByAdditionDeletion()
{
    printf ' \e[96mCreating git contribution summary on present repository branch \e[1;93mby addition/deletions\e[22;96m:\e[0m\n\n'
    printf "%20s    \e[92m%12s\e[91m%12s\e[0m\n" "" "Additions" "Deletions"
    git log --numstat --pretty="%ae %H" |\
        sed 's/@.*//g' |\
        awk '{
             if(NF == 1){
                 name = $1
             }
             if(NF == 3){
                 plus[name]+=$1
                 minus[name]-=$2
             }
         }
         END {
             for(name in plus){
                 printf "%20s:   %+12d%+12d\n", name, plus[name], minus[name]
             }
         }' | sort -k2Vr
    printf '\n'
}


if ! git rev-parse --git-dir > /dev/null 2>&1; then
    printf '\n \e[91mYou are not inside a git repository, aborting.\e[0m\n\n'
    exit 1
else
    MakeSummaryByCommit
    MakeSummaryByLineOfCode
    MakeSummaryByAdditionDeletion
fi
