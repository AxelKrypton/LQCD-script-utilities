#!/bin/bash

# This script is to create the file .nstore_counter in the folder
# that is given as argument. Basically the file .nstore_counter
# contains one line with four entries:
#  1) the index of the next configuration to be saved. This is not
#     really intuitive in tmLQCD code because if the user decide to
#     save configurations every Nsave trajectories, then the files
#     will be named conf.index where index is such that
#         trajectory_counter = (index + 1) * Nsave
#     (with some initial 0). Note that the configuration for
#     trajectory_counter=0 is not saved (the index qould be -1). 
#     This means that conf.0000 is the gauge configuration after
#     Nsave trajectories.
#  2) the trajectory number of the following Monte Carlo iteration
#     to be done.
#  3) the name of the gauge configuration file to start the simulation
#     from.
#  4) the file containing the state of the random number generator
#     to start the simulation from.
#
# This script will look inside the folder given as argument for files whose
# name start by "conf." and "rlxd." finding the highest common index following
# these names. Found this number it will overwrite or create the correct
# ".nstore_counter" file to continue the simulation from the last saved
# configuration. 


#Wrong arguments for the script => exit!
if [ $# -ne 2 ]; then 
    printf "\nPlease use the following syntax:\n"
    printf "\t\e[0;32m $0 <path_to_the_folder_where_to_look> <Nsave>\e[0m\n\n"
    exit -1

#Otherwise continue!
else
    # Save position from where the script is run to move back in the end
    starting_position=$(pwd)
    cd $1
    # NOTE: The way we look for the index is working only if in the directory we have the right structure.
    #       This means that the files "conf.index" must have all the indices with the same number of digits
    #       and there must not be any file whose name contains "conf." but not of the type "conf.index". 
    #       Actually, we check that all the indices have the same number of digits and we stop the script
    #       if we encounter some error. Also a check that the index does not contain anything else than 
    #       numbers between 0 and 9 is performed. In principle in the folder there could be some folder
    #       that violates these rules: this will not make the script interrupt because we do not look among
    #       directory names.
    #
    # Checking correct directory structure
    #
    ### ---> conf.index
    #
    correctDirectoryStructure=$(ls -l | grep -v '^d' | awk 'NR>1{print $9}' | grep "conf." | grep -v 'save' | awk '{print substr($1,index($1, "conf.")+5,length($1))}' | awk '\
BEGIN {wrongFormat=0; digitsOfIndex}                         
{ 
  for (i = 1; i <= NF; i = i + 1){ 
    if(NR==1 && i==1)
      digitsOfIndex=length($i);
    else{
      if(length($i) != digitsOfIndex)
        wrongFormat++;
    }  
    for (j = 1; j <= length($i); j = j + 1){
      if(!(substr($i,j,1) ~ /^[0-9]+$/)) wrongFormat++;
    }
  }
}
END {print wrongFormat}')
    #
    ### ---> rlxd.index
    #
    correctDirectoryStructure=$(($correctDirectoryStructure+$(ls -l | grep -v '^d' | awk 'NR>1{print $9}' | grep "rlxd." | grep -v 'save' | awk '{print substr($1,index($1, "rlxd.")+5,length($1))}' | awk '\
BEGIN {wrongFormat=0; digitsOfIndex}                         
{ 
  for (i = 1; i <= NF; i = i + 1){ 
    if(NR==1 && i==1)
      digitsOfIndex=length($i);
    else{
      if(length($i) != digitsOfIndex)
        wrongFormat++;
    }  
    for (j = 1; j <= length($i); j = j + 1){
      if(!(substr($i,j,1) ~ /^[0-9]+$/)) wrongFormat++;
    }
  }
}
END {print wrongFormat}')))
    #
    # Now we check if we found something wrong
    #   
    if [ $correctDirectoryStructure -eq 0 ]; then
	#
	# Look for higher index. In principle one could look only among the conf files and not also among the rlxd files.
	# The reason for looking among both is just to be conservative. During a simulation, one should produce as many
	# rlxd files as conf files. If for some reason there are more of the first or of the second type, it means that
	# something strange happened and this situation should be investigated. It is better then to interrupt the run 
	# and not make it restart from an older configuration.
	index_conf=$(ls -l | grep -v '^d' | awk 'NR>1{print $9}' | grep "conf." | grep -v 'save' | awk '{print substr($1,index($1, "conf.")+5,length($1))}' | awk '\
BEGIN {maximumIndex}                         
{ 
  for (i = 1; i <= NF; i = i + 1){ 
    if(NR==1 && i==1)
      maximumIndex=$i;
    else{
      if($i > digitsOfIndex)
        maximumIndex=$i;
    }  
  }
}
END {print maximumIndex}')
	index_rlxd=$(ls -l | grep -v '^d' | awk 'NR>1{print $9}' | grep "rlxd." | grep -v 'save' | awk '{print substr($1,index($1, "rlxd.")+5,length($1))}' | awk '\
BEGIN {maximumIndex}                         
{ 
  for (i = 1; i <= NF; i = i + 1){ 
    if(NR==1 && i==1)
      maximumIndex=$i;
    else{
      if($i > digitsOfIndex)
        maximumIndex=$i;
    }  
  }
}
END {print maximumIndex}')
	#
	# Check that both conf.max_index and rlxd.max_index exist. This is done just comparing the maximum indices found.
	#
	if [ -z ${index_conf:+x} ]; then
	    echo "Index of conf NOT correctly found. Probably no conf.index file present in the directory!"
	    exit -1
	fi
	if [ -z ${index_rlxd:+x} ]; then
	    echo "Index of rlxd NOT correctly found. Probably no rlxd.index file present in the directory!"
	    exit -1
	fi
	if [ $index_conf -ne $index_rlxd ]; then
	    echo "Maximum index of conf different from that of rlxd! ---> Problem to be investigated!"
	    exit -1
	else
	    index=$index_conf
	    if [ $(find . -maxdepth 1 -name "conf.$index" | wc -l) -ne 1 -o $(find . -maxdepth 1 -name "rlxd.$index" | wc -l) -ne 1 ]; then
		echo "conf.$index and rlxd.$index should be both presents, but they have not been found as unique!!! AAAAARGH!"
		exit -1
	    fi
	    #
     	    # Write the new .nstore_counter file
	    #
	    index_without_zeros=$(echo $index | sed 's/0*//')
	    echo "$(($index_without_zeros+1)) $(( $(($index_without_zeros+1)) * $2 +1 )) conf.$index rlxd.$index" > .nstore_counter
	    echo "New .nstore_counter file created in $PWD ---> $(cat .nstore_counter)"
	fi
    else
	echo "Something wrong in the directory!!"
	exit -1
    fi

    cd $starting_position
    exit 0
fi
