#!/bin/bash

# This script is to comment the hot/cold starting condition in the input file
# of tmLQCD and to uncomment the continue starting condition. 
# The strings that will be replaced MUST have a space before and after the '='
# symbol, i.e. the input file can contain:
#
#   "StartCondition = cold"
#   "StartCondition = hot"
#   "StartCondition = continue"
#
# with in case some '#' at the beginning.


#Wrong arguments for the script => exit!
if [ $# -ne 1 ]; then 
    printf "\nPlease use the following syntax:\n"
    printf "\t\e[0;32m $0 <input_file>\e[0m\n\n"
    exit -1

#Otherwise continue!
else
    #Check if input file is properly written
    if [ $(grep -n "StartCondition = continue" $1 | wc -l) -gt 1 ]; then
	echo "Input file for $0 has several times the \"continue\" starting condition!"
	exit -1
    fi

    if [ $(grep -n "StartCondition = cold" $1 | wc -l) -gt 1 ]; then
	echo "Input file for $0 has several times the \"cold\" starting condition!"
	exit -1
    fi

    if [ $(grep -n "StartCondition = hot" $1 | wc -l) -gt 1 ]; then
	echo "Input file for $0 has several times the \"hot\" starting condition!"
	exit -1
    fi

    #Grep for the exact line and extract the number of the line
    contLine=$(grep -n "StartCondition = continue" $1 | awk '{print substr($1,0,index($1, ":")-1)}')
    coldLine=$(grep -n "StartCondition = cold" $1 | awk '{print substr($1,0,index($1, ":")-1)}')
    hotLine=$(grep -n "StartCondition = hot" $1 | awk '{print substr($1,0,index($1, ":")-1)}')

    if [ $contLine ]; then
	awk -v line=$contLine 'NR!=line{print $0} NR==line{printf "StartCondition = continue\n"}' $1 > fileThatHopefullyDoesNotExists
	mv fileThatHopefullyDoesNotExists $1
    fi

    if [ $coldLine ]; then
	awk -v line=$coldLine 'NR!=line{print $0} NR==line{printf "#StartCondition = cold\n"}' $1 > fileThatHopefullyDoesNotExists
	mv fileThatHopefullyDoesNotExists $1
    fi


    if [ $hotLine ]; then
	awk -v line=$hotLine 'NR!=line{print $0} NR==line{printf "#StartCondition = hot\n"}' $1 > fileThatHopefullyDoesNotExists
	mv fileThatHopefullyDoesNotExists $1
    fi

    exit 0
fi
