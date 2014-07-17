#!/bin/bash

# This script is intended to copy Chiral Condensate files from somewhere 
# (in case also remote location) to somewhere else. 
#
#      bash CopyPbp.sh  <path_to_pbp_folder> <destination_folder>
#
# NOTE: To right this script quickly, everything ending with "pbp.dat" is copied
#       back to the destination folder. This means that if there is something that
#       is not a chiral condensate file, it is copied back as well.
#       This should not be the case but however is up to the user to manage it.
#
#Wrong arguments for the script => exit!
if [ $# -ne 2 ]; then
    printf "\nPlease use the following syntax:\n"
    printf "\t\e[0;32m $0 <path_to_pbp_folder> <destination_folder>\e[0m\n\n"
    exit -1

#Otherwise continue!
else
    source=$1
    destination=$2
    rsync_options="-avuzh"
    # Check existence files
    if [[ $1 == *:* ]]; then
	if ssh ${1%%:*} test ! -d "${1##*:}" ; then printf "\n\e[0;31mRemote directory \"$1\" does not exists!\e[0m\n\n"; exit -1; fi
    else
	if test ! -d "${1##*:}" ; then printf "\n\e[0;31mDirectory \"$1\" does not exists!\e[0m\n\n"; exit -1; fi
    fi

    # Copy all the configurations
    printf "\n\e[0;32mCOPYING PBP FILES FROM \e[0;35m $1 \e[0;32m TO \e[0;35m $2 \e[0;32m...\n"
    printf "\n\e[0;34m"
    rsync $rsync_options --stats $1/*pbp.dat $2
    printf " \e[0m\n"
fi
