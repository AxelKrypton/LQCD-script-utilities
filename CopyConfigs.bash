#!/bin/bash
#
#  Copyright (c) 2014,2015 Alessandro Sciarra
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


# This script is intended to copy configurations generated with tmLQCD
# from somewhere (in case also remote location) to somewhere else. The configurations
# files are just copied (not renamed,...). Since the script RenameTMLQCDconfigs.sh
# adjusts the index number to the trajectory number using the output.para file,
# if present, also this file will be copied (if not a warning is thrown).
#
#      bash CopyConfigsFromRemote.sh  <path_to_configs_folder> <destination_folder>
#
# NOTE: To write this script quickly, everything starting with "conf." is copied
#       back to the destination folder. This means that if there is something that
#       is not a configuration (i.e. not a lime file), it is copied back as well.
#       This should not be the case but however is up to the user to manage it.
#
#Wrong arguments for the script => exit!
if [ $# -ne 2 ]; then
    printf "\nPlease use the following syntax:\n"
    printf "\t\e[0;32m $0 <path_to_configs_folder> <destination_folder>\e[0m\n\n"
    exit -1

#Otherwise continue!
else
    source=$1
    destination=$2
    rsync_options="-avuzh"
    # Check existence files
    if [[ $1 == *:* ]]; then
	if ssh ${1%%:*} test ! -d "${1##*:}" ; then printf "\n\e[0;31mRemote directory \"$1\" does not exists!\e[0m\n\n"; exit -1; fi
	if ssh ${1%%:*} test ! -e "${1##*:}/output.para" ; then printf "\n\e[0;33mRemote file \"$1/output.para\" does not exists!\e[0m\n"; else rsync -q $rsync_options $1/output.para $2; printf "\n\e[0;36mFile $1/output.data copied successfully!\n"; fi
    else
	if test ! -d "${1##*:}" ; then printf "\n\e[0;31mDirectory \"$1\" does not exists!\e[0m\n\n"; exit -1; fi
	if test ! -e "${1##*:}/output.para" ; then printf "\n\e[0;31mFile \"$1/output.para\" does not exists!\e[0m\n"; else rsync -q $rsync_options $1/output.p\
ara $2; printf "\n\e[0;36mFile $1/output.data copied successfully!\n"; fi
    fi

    # Copy all the configurations
    printf "\n\e[0;32mCOPYING CONFIGURATIONS FROM \e[0;35m $1 \e[0;32m TO \e[0;35m $2 \e[0;32m...\n"
    printf "\n\e[0;34m"
    rsync $rsync_options --stats $1/conf.* $2
    printf " \e[0m\n"
    # Delete conf.save if it has been copied
    rm -f $2/conf.save
fi

exit 0
