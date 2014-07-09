#!/bin/bash

# This script is to get the value of the total number of trajectories of a simulation
# from the input file of tmLQCD. This is actually not an input parameter for tmLQCD
# program, but it is a needed number to automatize properly the simulation. The point
# is that the tmLQCD hmc_tm does exactely "Measurement" trajectories, no matter from
# which trajectory it starts. Then if one has already performed 80 trajectories out 
# of 100, he should resume the program with "Measurement=20". And if the simulation
# is automatically resumed with the same input file as at the beginning, then the
# program will perform again 100 going up to 180. If instead there is written somewhere
# the total desired number of trajectories, we can automatically modify "Measurement"
# before resuming a simulation. This script just reads this number that must be
# specified after the string "# Total number of trajectories =". Of course there
# must be ONLY ONE such a line in the input file and the hash (#) at the beginning
# is mandatory otherwise the hmc_tm executable crashes. The only freedom is the amount
# of blank spaces between the words that can be ONE or more. This means that the following
# examples are all valid:
#
#    "# Total number of trajectories = "
#    " #  Total  number  of  trajectories  =  "
#    "  #   Total   number    of    trajectories   =   "
#    "   #    Total    number      of     trajectories    =    "
#    "    #     Total     number       of       trajectories      =     "
#    "     #      Total      number        of        trajectories       =      "
#    "      #       Total       number         of         trajectories        =       "
#    "       #        Total        number          of           trajectories         =        "
#    "        #         Total         number           of             trajectories         =         "
#
#
# If there is no line with the required line the script will return 0.
# allowed string is not a white space, the line is discarded. 
# Of course, the input file is supposed to contain ONLY one valid line
# from which the value will be extracted. 
#
# IMPORTANT: The number is returned with the line
#
#               echo "export PARAM_READ=$(($TotNumTraj))
#
#            that means that one should call this script with
#
#               eval $(bash GetTotNumTrajectories.sh inputFile)
#
#            in order to be able to recover the value afterwards from PARAM_READ.
#            In the same fashion, in case of errors the variable ERROR_OCCURRED is set to 1.
#            This is done because we will call this script from within another script.
#
# Note that if in the valid line, after the number there is a comment starting by 
# an hash (#), this script is still working.
#
# Note also that this scripts does not work if the parameter is negative.


# Wrong arguments for the script => exit!
if [ $# -ne 1 ]; then 
    #printf "\nPlease use the following syntax:\n"
    #printf "\t\e[0;32m $0 <input_file>\e[0m\n\n"
    echo "export ERROR_OCCURRED=1"
# Otherwise continue!
else
    #
    # Check if input file is properly written. At the same time
    # we save which line of the output of the grep command contains
    # the right Parameter. This is to read out the number more quickly 
    # later on.
    #
    # In particular we check that in the line the characters before the Parameter are only spaces or hashes
    # and that the number after the equal is actually a proper number.
    #
    Parameter="# Total number of trajectories"
    numberGreppedLine_Param=$(grep -e "#\s*Total\s*number\s*of\s*trajectories\s*=" $1 | sed 's/  */ /g' | awk -v Param="$Parameter" '\
BEGIN{digitsBeforeParam; equalPosition; correct = 0; lineNumber}
{
  digitsBeforeParam = index($0, Param);
  if(digitsBeforeParam == 1){
    correct++;
    lineNumber = NR;
  }
  for (i = 1; i < digitsBeforeParam; i = i + 1){
    if(substr($0,i,1) != " " && substr($0,i,1) != "#"){
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
	#echo "  - with not a proper number after the = sign, including a negative proper number!"
	echo "export ERROR_OCCURRED=1"
	exit -1
    else
	#
	# Get the actual Parameter value (here we are sure that the line contains only space before Param and,
	# maybe, a comment starting by # after the number)
	#
	ParamVal=$(grep -e "#\s*Total\s*number\s*of\s*trajectories\s*=" $1 | sed 's/  */ /g' | awk -v line=$numberGreppedLine_Param -v Param="$Parameter" '\
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
	    #echo "\"$Parameter\" is present in the input file but either has no number after = sign, or it is set to zero!"
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