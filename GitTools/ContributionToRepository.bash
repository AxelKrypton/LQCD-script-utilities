#!/usr/bin/env bash
#
#  Copyright (c) 2021 Alessandro Sciarra
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
