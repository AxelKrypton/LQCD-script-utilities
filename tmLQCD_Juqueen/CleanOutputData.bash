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


# This script is to clean the output.data file of tmLQCD
# from repeated data. It is quite often to have this problem,
# because of the wall_clock_time of Juqueen. In fact, when a
# a simulation is stopped before the end, the job script will
# submit another job continuing the simulation, but it will be
# resumed from the last checkpoint (i.e. the last configuration)
# saved. Then mostly some trajectory are done again and in the
# datafile these data appear more than once. This script just
# delete them according to the trajectory number. It means that
# the output.data file is read checking the first column number
# line by line. If in one line this number is smaller of the
# previous, such a line is canceled.
#
# Note that the file can also be named differently from output.data
# (it has to be given as argument to the script), but MUST HAVE the
# typical format of tmLQCD (or at least the trajectory number as
# first column). The original data are conserved in a file named
# as the original datafile plus a "_raw" suffix. The new cleaned
# datafile is created where the old one was (and hence where the
# new _raw file is put).
#
# ATTENTION: Do not use this script if you collected data coming from
#            different runs into the same file!


#Wrong arguments for the script => exit!
if [ $# -ne 1 ]; then
    printf "\nPlease use the following syntax:\n"
    printf "\t\e[0;32m $0 <path_to_the_output_filedata>\e[0m\n\n"
    exit -1

#Otherwise continue!
else
    #Rename $1 to ./$1 if there is no / in $1 ----> Maybe this is not needed, but for sure it works
    grep_result=$(echo $1 | grep '/')
    if [ -z ${grep_result:+x} ]; then  # ${parameter:+word} substitute word if parameter Set and Not Null, substitute null if parameter Set But Null ot parameter Unset
	path_to_file="./$1"
    else
	path_to_file=$1
    fi

    #If in the folder where the file $1 is located, there is already a file named $1_raw, then this script does nothing!
    if [ -e $1_raw ]; then
	echo "The file \"$1_raw\" already exists! Aborting..."
	exit -1
    fi

    #If the file has not to be cleaned, then nothing is done.
    #NOTE: To read the file once  to check it and once to modify it is not so good, but for the moment it is ok. It should not be really slow.
    file_to_be_cleaned=$(awk 'BEGIN{traj_num = -1; file_to_be_cleaned=0}{if($1>traj_num){traj_num = $1} else {file_to_be_cleaned=1; exit;}}END{print file_to_be_cleaned}' $1)
    if [ $file_to_be_cleaned -eq 0 ]; then
	echo "The given file \"$path_to_file\" has not to be cleaned!"
	exit 0
    else
        #Move the original datafile to one with the same name plus "_raw" as ending
	mv $path_to_file ${path_to_file}_raw
	echo "Backup of input file done ($path_to_file ---> ${path_to_file}_raw)"

	#Clean the file $1 with awk putting the output into $path_to_file (use of >> just as unnecessary care)
	awk 'BEGIN{traj_num = -1}{if($1>traj_num){ print $0; traj_num = $1}}' ${path_to_file}_raw >> $path_to_file
	echo "File \"$path_to_file\" has been cleaned!"
	exit 0
    fi
fi

    #raw_filename_path="${path_to_file%/*}/" # ${parameter%[word]}  Remove Smallest Suffix Pattern.
    #original_filename="${path_to_file##*/}" # ${parameter##[word]} Remove Largest Prefix Pattern.
                                             # See http://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_06_02 for details
