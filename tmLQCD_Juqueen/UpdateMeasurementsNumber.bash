#!/bin/bash
#
#  Copyright (c) 2014 Alessandro Sciarra
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


# This script is to change the number of Measurements in the input file
# of tmLQCD.
# The string that will be replaced is:
#
#   "Measurements = some_number"
#
# without ANY '#' at the beginning and zero or more spaces before and after the '='.
#
# The arguments of this script are the input file and the new number to be set.


#Wrong arguments for the script => exit!
if [ $# -ne 2 ]; then
    printf "\nPlease use the following syntax:\n"
    printf "\t\e[0;32m $0 <input_file> <new_number_of_measurements>\e[0m\n\n"
    exit -1

#Otherwise continue!
else
    #Check if input file is properly written
    Parameter="Measurements"
    numberGreppedLine_Param=$(grep -e "Measurements\s*=" $1 | sed 's/  */ /g' | awk -v Param="$Parameter" '\
BEGIN{digitsBeforeParam; equalPosition; correct = 0; lineNumber}
{
  digitsBeforeParam = index($0, Param);
  if(digitsBeforeParam == 1){
    correct++;
    lineNumber = NR;
  }
  for (i = 1; i < digitsBeforeParam; i = i + 1){
    if(substr($0,i,1) != " "){
      break;
    }
    if( i == (digitsBeforeParam-1)){
      correct++;
      lineNumber = NR;
    }
  }
  if(lineNumber == NR){
    equalPosition = index(substr($0, digitsBeforeParam), "=");
    for (i = digitsBeforeParam + equalPosition; i <= length($0); i = i + 1){
      if(substr($0,i,1) == "#")
        break;
      if((!(substr($0,i,1) ~ /^[0-9]+$/)) && substr($0,i,1) != " "){
        correct--;
        lineNumber = -1;
        break;
      }
    }
  }
}
END{
     if(correct != 1) printf "%d", -1;
     else print lineNumber
}')

    if [ $numberGreppedLine_Param -eq -1 ]; then
	echo "Wrong structure of the input file, i.e. the parameter \"$Parameter\" is"
	echo "  - not present OR"
	echo "  - present more than once OR"
	echo "  - with not a proper number after the = sign, including a negative proper number!"
	exit -1
    else

        #Grep for the exact line and extract the number of the line
	parameterLine=$(grep -n "Measurements\s*=" $1 | sed 's/  */ /g' | awk -v line=$numberGreppedLine_Param 'NR==line{print substr($1,0,index($1, ":")-1)}')

	if [ $parameterLine ]; then
	    awk -v line=$parameterLine -v newNumber=$2 'NR!=line{print $0} NR==line{printf "#%s\n%s%d\n", $0, "Measurements = ", newNumber}' $1 > fileThatHopefullyDoesNotExists
	    mv fileThatHopefullyDoesNotExists $1
	fi

	exit 0

    fi
fi
