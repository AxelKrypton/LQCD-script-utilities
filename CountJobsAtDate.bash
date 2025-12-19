#!/bin/bash

# Script intended to calculate the number of jobs pending or running
# at a given time in the past. It is done supposing SLURM is used on
# the cluster.

exit

#TODO: 1) -u | --user option to specify user
#      2) -d | --date option to specify date at which the counting
#         has to be done (check that input is valid to be used with
#         the date command; check using date command and testing error code)
#      3) the input date has to be given to -S and -E option of sacct to get
#         the list of existing jobs at date.
#      4) This script will be used to fill up past pending information in the
#         cluster usage => think how to print result.

#Core command to develop the script
for DATE in $(sacct -nP --user asciarra -S 2016-09-10T02:00 -E 2016-09-10T02:00 --format=Submit,Start | grep -v batch); do echo "$(date -d ${DATE%|*} +%s) $(date -d ${DATE#*|} +%s)"; done | awk -v mid="$(date -d 2016-09-10T02:00 +%s)" '$1<mid && $2>mid{pendingJobs++}END{print pendingJobs}'
