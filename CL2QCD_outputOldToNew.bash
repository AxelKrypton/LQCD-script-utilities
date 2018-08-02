#!/bin/bash

# Script to transform the CL2QCD output file from old to new format.
# It takes the files to be updated as command line arguments, it
# creates a backup (where this script is sourced) and it overwrites
# the given file with the new format. The backup has as name the old
# file global path with / replaced by _.
#
# The change in formats are the following.
#   OLD:  Traj_num - Plaq_tot - Plaq_t - Plaq_s - Poly_re - Poly_im - Poly_abs - dH - exp(dH) - Acc_prob - Acc - 0 - 0
#   NEW:  Traj_num - Plaq_tot - Plaq_t - Plaq_s - Poly_re - Poly_im - Poly_abs - dH - Acc - Time_Tr
# with better field formatting. As time in the new file, the value 0 will be used!

function PrintError(){
    printf "\e[38;5;9m \e[1m\e[4mERROR\e[24m:\e[21m %s\e[0m\n\n" "$1"
}

while [ $# -gt 0 ]; do
    if [ -f "$1" ]; then
        fileGlobalPath="$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
        backupName="${fileGlobalPath////_}"; backupName=${backupName:1}
        if [ -f "$backupName" ]; then
            PrintError "Backup file \"$backupName\" alredy existing! Skipping it."
        else
            cp "$1" "$backupName" || exit -2
            awk '{printf "%8s %25s %25s %25s %25s %25s %25s %25s %6s %10s\n", $1, $2, $3, $4, $5, $6, $7, $8, $11, $12}' "$1" > tmpFileWhichShouldNotExist && mv tmpFileWhichShouldNotExist "$1"
        fi
    else
        PrintError "File \"$1\" not found! Skipping it."
    fi
    shift
done
