#!/bin/bash

# This script is to get the value of one INTEGER POSITIVE NUMERIC parameter from the input file
# of tmLQCD. Let us call it "Param". The string that will be looked for can be:
#
#   "Param ="
#   "Param="
#
# with, in case, some white spaces in front. If at least one char before the
# allowed string is not a white space, the line is discarded. 
# Of course, the input file is supposed to contain ONLY one valid line
# from which the value will be extracted. 
#
# IMPORTANT: The number is returned with the line
#
#               echo "export PARAM_READ=$(($ParamVal))"
#
#            that means that one should call this script with
#
#               eval $(bash GetParameterValue.sh inputFile ParameterName)
#
#            in order to be able to recover the value afterwards from PARAM_READ.
#            In the same fashion, in case of errors the variable ERROR_OCCURRED is set to 1.
#                
#
# Note that if in the valid line, after the number there is a comment starting by 
# an hash (#), this script is still working.
#
# Note also that this scripts does not work if the parameter is 0.


# Wrong arguments for the script => exit!
if [ $# -ne 2 ]; then 
    #printf "\nPlease use the following syntax:\n"
    #printf "\t\e[0;32m $0 <input_file> <Parameter>\e[0m\n\n"
    echo "export ERROR_OCCURRED=1"
# Otherwise continue!
else
    #
    # Check if input file is properly written. At the same time
    # we save which line of the output of the grep command contains
    # the right Parameter. This is to read out the number more quickly 
    # later on.
    #
    numberGreppedLine_Param=$(grep -e "$2 =" -e "$2=" $1 | awk -v Param=$2 '\
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
	#echo "Wrong structure of the input file, i.e. the parameter $2 is"
	#echo "  - not present OR"
	#echo "  - present more than once OR"
	#echo "  - with not a proper number after the = sign!"
	echo "export ERROR_OCCURRED=1"
	exit -1
    else
	#
	# Get the actual Param value (here we are sure that the line contains only space before Param and,
	# maybe, a comment starting by # after the number)
	#
	ParamVal=$(grep -e "$2 =" -e "$2=" $1 | awk -v line=$numberGreppedLine_Param -v Param=$2 '\
BEGIN{digitsBeforeParam; equalPosition; hashPosition}
{
  if(NR == line){
    digitsBeforeParam = index($0, Param); 
    equalPosition = index(substr($0, digitsBeforeParam), "=");
    hashPosition = index(substr($0, digitsBeforeParam + equalPosition), "#");
    if(hashPosition == 0)
     print substr($0, digitsBeforeParam + equalPosition);
    else
     print substr($0, digitsBeforeParam + equalPosition, hashPosition-1);
  }
}')
	#
	# If ParamVal as number is 0 there was something wrong!
	#
	if [ $(($ParamVal)) -eq 0 ]; then 
	    #echo "$2 is present in the input file but either has no number after = sign, or it is set to zero!"
	    echo "export ERROR_OCCURRED=1"
	    exit -1
	else
	    if [ ! -z ${ERROR_OCCURRED+x} ]; then
		echo "export ERROR_OCCURRED="
	    fi
	    echo "export PARAM_READ=$(($ParamVal))"
	    exit 0
	fi
    fi
fi