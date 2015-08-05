#!/bin/bash

# This script is intended to copy the last configuration per beta
# from a remote location to somewhere else. The last configuration
# files are just copied (not renamed,...).
#
# NOTE: The name of a configuration is suppposed to be "conf.[[:digit:]]+".
#       This means that if there is something that is not a configuration
#       (i.e. not a lime file), it is copied back as if it was.
#       This should not be the case but however is up to the user to manage it.

source $HOME/Script/UtilityFunctions.sh || exit -2

function ParseCommandLineOptions(){

    while [ "$1" != "" ]; do
        case $1 in
            -h | --help )
                printf "\n\e[0;32m"
                echo "Call the script $0 with the following optional arguments:"
                echo "  -h | --help"
                echo "  -r | --remote      ->    remote name (default = $REMOTE_NAME)"
                echo "  --remotePrefix     ->    remote prefix (default = ${REMOTE_PREFIX[$(whoami)]})"
                echo "  --rsyncOptions     ->    options passed to rsync (default = $RSYNC_OPTIONS)"
                printf "\n\e[0m"
                exit
                shift;;
            -r | --remote )       REMOTE_NAME="$2"; shift 2 ;;
            --remotePrefix )      REMOTE_PREFIX[$(whoami)]="$2"; shift 2 ;;
            --rsyncOptions )      RSYNC_OPTIONS="$2"; shift 2 ;;
            * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
        esac
    done

}

#-------------------------------------------------------------------------------------------------------#

#Wilson o staggered
STAGGERED="FALSE"
WILSON="FALSE"
[ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ] && STAGGERED="TRUE"
[ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ] && WILSON="TRUE"

#Associative array to make the script user specific
declare -A REMOTE_PREFIX
declare -A EXPECTED_POSITION

if [ $STAGGERED = "TRUE" ]; then
    EXPECTED_POSITION["sciarra"]="/home/phil-configs/Staggered/Nf2/mui0/LastConfigurations"
    REMOTE_PREFIX["sciarra"]="/scratch/hfftheo/sciarra/StaggeredNf2Project/muiPiT"
    MASS_PREFIX="mass"
elif [ $WILSON = "TRUE" ]; then
    REMOTE_PREFIX["sciarra"]="/scratch/hfftheo/sciarra/WilsonProject/muiPiT"
    EXPECTED_POSITION["sciarra"]="/home/phil-configs/wilson_nf2_muipi4/ImagMu/muiPiT/LastConfigurations"
    REMOTE_PREFIX["czaban"]="/scratch/hfftheo/czaban/ImagMu_Output_Data/muiPiT"
    EXPECTED_POSITION["czaban"]="/home/phil-configs/wilson_nf2_muipi4/ImagMu/muiPiT/LastConfigurations"
    MASS_PREFIX="k"
fi

#Variables
REMOTE_NAME="loewe"
RSYNC_OPTIONS="quaz"
ParseCommandLineOptions $@
CONF_LIST_FILE="ConfigurationListFrom_${REMOTE_NAME}_$(whoami)_on_$(date +'%F_%H%M')"

#If I am not in the expected position, I ask the user:
if [ $(pwd) != ${EXPECTED_POSITION[$(whoami)]} ]; then
    printf "\n\e[0;33m The actual position is not the expected one: \"${EXPECTED_POSITION[$(whoami)]}\".\n Would you like to backup the configurations anyway (Y/N)? \e[0m"
    CONFIRM="";
    while read CONFIRM; do
        if [ "$CONFIRM" = "Y" ]; then
            break;
        elif [ "$CONFIRM" = "N" ]; then
            echo ""
            exit 0;
        else
            printf "\n\e[0;33m Please enter Y (yes) or N (no): \e[0m"
        fi
    done

fi

#Getting configurations from remote (supposing folder structure)
printf "\n\e[38;5;39m Obtaining list of files from remote... \n\e[0m"
ssh $REMOTE_NAME 'bash -s' > $CONF_LIST_FILE << EOF
    for BETA in ${REMOTE_PREFIX[$(whoami)]}/${MASS_PREFIX}????/nt?/ns*/b?.????*; do
        printf "\$BETA/"
        ls \$BETA | grep "conf.[[:digit:]]\+" | sort -V | tail -n1
        echo
        printf "\$BETA/"
        ls \$BETA | grep "prng.[[:digit:]]\+" | sort -V | tail -n1
        echo
    done
EOF
#Remove empty line
sed -i '/^$/d' $CONF_LIST_FILE
#Remove lines for which either conf or prng has not been found
for FILE in $(grep -v "\(conf\|prng\)" $CONF_LIST_FILE); do
    printf "\e[38;5;9m   Either last conf or prng not found at \"$FILE\"!\n\e[0m"
done
grep "\(conf\|prng\)" $CONF_LIST_FILE > TemporaryFileThatShouldNotExists && mv TemporaryFileThatShouldNotExists $CONF_LIST_FILE
printf "\e[38;5;39m ...obtained $(wc -l < $CONF_LIST_FILE) files!\n\e[0m"

#Remove remote prefix from file lines because it will be put in rsync command in order to get
#the folder structure created on the local folder in case
sed -i 's@'${REMOTE_PREFIX[$(whoami)]}/'@@g' $CONF_LIST_FILE
#Copy the files from remote
printf "\n\e[38;5;39m Syncronizing with the remote... \n\e[0m"
rsync -${RSYNC_OPTIONS} --files-from=$CONF_LIST_FILE $REMOTE_NAME:${REMOTE_PREFIX[$(whoami)]} .
printf "\e[38;5;39m ...done!\n\n\e[0m"

exit 0
