#!/bin/bash

# This script is intended to rename configurations generated with tmLQCD
# adjusting the index number to the trajectory number, using the Nsave parameter.
# The Nsave parameter is read from the output.para file and then the path to the
# folder containing configurations and the output.para file should be given to
# this script as parameter
#
#      bash  RenameTMLQCDconfigs.sh  <path_to_configs_folder>
#
# If in the folder no valid output.para file is contained, this script is
# aborted. This could be if the output.para file was not present, or if it contained
# several different values of Nsave.
#
# The relation between the index and the trajectory number is the following.
#
#     trajectory_number = (index + 1) * Nsave
#
# that means, for example, if Nsave=50, conf.0001 will become conf.0100 (actually the
# number of digits to be used in the new names is determined using the maximum found index).
#
# NOTE: This script will abort if the indexes of configurations have not exactly 4 digits.
#       It is done "ad hoc" for our simulations with tmLQCD and it is to prevent to rename
#       twice the same configurations!
#       Furthermore, if the maximum trajectory number has more than 5 digits, then this
#       script stop as well (in CL2QCD the default number of digits is 5 and for the moment
#       it is enough to have this restriction).

#Wrong arguments for the script => exit!
if [ $# -ne 1 ]; then
    printf "\nPlease use the following syntax:\n"
    printf "\t\e[0;32m $0 <path_to_configs_folder>\e[0m\n\n"
    exit -1

#Otherwise continue!
else
    #Rename $1 to ./$1 if it does not start with . ----> Maybe this is not needed, but for sure it works
    grep_result=$(echo $1 | awk '{print substr($0, 1, 1)}')
    if [ "$grep_result" != "." ]; then  # ${parameter:+word} substitute word if parameter Set and Not Null, substitute null if parameter Set But Null ot parameter Unset
	folder="./$1"
    else
	folder=$1
    fi
    
    folder=${folder%/*} # ${parameter%[word]}  Remove Smallest Suffix Pattern.
    # Check if the folder exists
    if [ ! -d $1 ]; then
	echo "Directory \"$folder\" does not exist or cannot be accessed! Aborting..."
	exit -1
    fi
    # Check if the folder contains a output.para file
    if [ ! -e $1/output.para ]; then
	echo "File \"$folder/output.para\" does not exist or cannot be accessed! Aborting..."
	exit -1
    fi

    # Check if output.para is valid and in case read Nsave
    Nsave=$(grep "Nsave=" $1/output.para | awk '\
BEGIN{digitsBeforeParam; correct=1; previousNumber; actualNumber}
{
  digitsBeforeParam = index($0, "Nsave=");
  for (i = digitsBeforeParam + 6; i <= length($0); i = i + 1){
    if((!(substr($0,i,1) ~ /^[0-9]+$/)) && substr($0,i,1) != " "){
      correct = 0;
      break;
    }
  }
  if(correct == 1){
    actualNumber = substr($0, digitsBeforeParam + 6);
    if(NR==1){
      previousNumber = actualNumber;
    }
    if(actualNumber != previousNumber){
      correct = 0;
      exit;
    }
  }
}
END{
  if(correct == 0){
    print -1;
  }else{
    print actualNumber;
  }
}')
    if [ -z ${Nsave:+x} ]; then
	echo "Variable \"Nsave\" unset or empty after search for it! Problem to be investigated! Aborting..."
	exit -1
    fi
    if [ $Nsave -eq -1 ]; then
	echo "Unable to read Nsave out of file \"$1\", check it! Aborting..."
	exit -1
    fi

    # Now Nsave has been read. We can look for the highest index of conf.index files
    # in order to know how many digits in the new conf. files we will need.
    #
    # NOTE: Here we also check that each index has 4 digits, if not we set max_index_conf
    #       to -1 and later on we interrupt the script.
    numDigitsAllowedTMLQCD=4
    numDigitsAllowedCL2QCD=5
    max_index_conf=$(ls -l $folder | grep -v "^d" | awk 'NR>1{print $9}' | grep "conf." | grep -v "save" | awk '{print substr($1,index($1, "conf.")+5,length($1))}' | awk -v allowedDigits=$numDigitsAllowedTMLQCD '\
BEGIN {maximumIndex; correctNumDigits = 1}                         
{ 
  if(length($0) != allowedDigits){
    correctNumDigits = 0;
    exit;
  }
  for (i = 1; i <= NF; i = i + 1){ 
    if(NR==1 && i==1)
      maximumIndex=$i;
    else{
      if($i > digitsOfIndex)
        maximumIndex=$i;
    }  
  }
}
END {
  if(correctNumDigits == 1){
    print maximumIndex;
  }else{
    print -1;
  }
}')
    if [ -z ${max_index_conf:+x} ]; then
	echo "Variable \"max_index_conf\" unset or empty after search for it! Problem to be investigated! Aborting..."
	exit -1
    fi
    if [ $max_index_conf -eq -1 ]; then
	echo "Configurations in folder \"$folder\" have not valid indexes (e.g. 4 digits)! Aborting..."
	exit -1
    fi
    
    # Estimate maximum trajectory number and check it
    max_index_conf=$(echo $max_index_conf | sed 's/^0*//') #Removing leading zeros!
    max_traj_number=$(($Nsave * ($max_index_conf + 1)))

    if [ $(($(echo "$(($Nsave * ($max_index_conf + 1)))" | wc -m) -1)) -gt $numDigitsAllowedCL2QCD ]; then # wc counts the endline, too -> I have to subtract 1
	echo "Maximum trajectory number would have more than 5 digits and it is not allowed! Aborting..."
	exit -1
    fi

    # Rename configurations from the biggest index to the smallest (this is here not mandatory because one cannot
    # overwrite files, since the old have 4 digits and the new 5). In any case we use mv -i.
    for f in $(ls -lr $folder | grep -v "^d" | awk 'NR>1{print $9}' | grep "conf." | grep -v "save")
    do
	new_index=$(echo $f | awk '{print substr($1,index($1, "conf.")+5,length($1))}' | sed 's/^0*//') #Removing leading zeros!
	new_index=$(($Nsave * ($new_index + 1)))
	new_name=`printf "conf.%0${numDigitsAllowedCL2QCD}d" $new_index`
	mv -i $folder/$f $folder/$new_name
	echo "Renamed $f ---> $new_name" 
    done
fi

exit 0

