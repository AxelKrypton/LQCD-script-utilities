#!/bin/bash

# This script is intended to copy the last configuration per beta
# from a remote location to somewhere else. The last configuration
# files are just copied (not renamed,...).
#
# NOTE: The name of a configuration is supposed to be "conf.[[:digit:]]+".
#       This means that if there is something that is not a configuration
#       (i.e. not a lime file), it is copied back as if it was.
#       This should not be the case but however is up to the user to manage it.

#--------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source "$HOME/Script/PathManagement.sh" || exit -2
source "$HOME/Script/UtilityFunctions.sh" || exit -2
#--------------------------------------------------------------------------------#

function ParseCommandLineOptions(){

    while [ "$1" != "" ]; do
        case $1 in
            -h | --help )
                printf "\n\e[0;32m"
                echo " Call the script $0 with the following optional arguments:"
                echo "   -h | --help"
                echo "   -r | --remote         ->    remote name (default = $REMOTE_NAME)"
                echo "   --remotePrefix        ->    remote prefix (default = ${REMOTE_PREFIX[$(whoami)]})"
                echo "   --rsyncOptions        ->    options passed to rsync (default = $RSYNC_OPTIONS)"
                echo "   --now                 ->    if given, start the syncronization immediately and not at 21"
                echo "   --doNotRemoveFiles    ->    if given, only the backup is done and no older checkpoint is deleted"
                echo "   --doNotRedirect       ->    if given, no redirection of standard output and error is done"
                echo " "
                echo " NOTE: Changing rsync permissions could affect permissions on reciever that are"
                echo "       by default set to \"--chmod=Du=rwx,Dg=rwx,Do=r,Fu=rw,Fog=r\" how it should be."
                printf "\n\e[0m"
                exit
                shift;;
            -r | --remote )       REMOTE_NAME="$2"; shift 2 ;;
            --remotePrefix )      REMOTE_PREFIX[$(whoami)]="$2"; shift 2 ;;
            --rsyncOptions )      RSYNC_OPTIONS="$2"; shift 2 ;;
            --now )               SYNC_NOW="TRUE"; shift ;;
            --doNotRemoveFiles )  REMOVE_OLDER_FILES="FALSE"; shift ;;
            --doNotRedirect )     REDIRECT_OUTPUT_TO_FILES="FALSE"; shift ;;
            * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
        esac
    done

}

#-------------------------------------------------------------------------------------------------------#
#Having loaded PathManagement.sh we get for free all the parameters variables and functionalities
CheckWilsonStaggeredVariables
#Build path regex for later
RESULTING_REGEX=""
for INDEX in ${!PARAMETER_REGEXES[@]}; do
    RESULTING_REGEX="$RESULTING_REGEX/${PARAMETER_PREFIXES[$INDEX]}${PARAMETER_REGEXES[$INDEX]}"
done && unset -v 'INDEX'
RESULTING_REGEX="$RESULTING_REGEX/$BETA_FOLDER_REGEX"

WILSON_CONFIGS_POSITION="/home/phil-configs/wilson_nf2_muipi4/ImagMu"
STAGGERED_CONFIGS_POSITION="/home/phil-configs/Staggered"

#Associative array to make the script user specific
declare -A REMOTE_PREFIX

if [ $STAGGERED = "TRUE" ]; then
    EXPECTED_POSITION="${STAGGERED_CONFIGS_POSITION}/LastConfigurations"
    #Each user can put here the remote prefix if she/he does not want to give it via command line
    REMOTE_PREFIX["sciarra"]="/lustre/lcsc/asciarra/StaggeredProject"
elif [ $WILSON = "TRUE" ]; then
    EXPECTED_POSITION="${WILSON_CONFIGS_POSITION}/LastConfigurations"
    #Each user can put here the remote prefix if she/he does not want to give it via command line
    REMOTE_PREFIX["sciarra"]="/scratch/hfftheo/sciarra/WilsonProject/muiPiT"
    REMOTE_PREFIX["czaban"]="/scratch/hfftheo/czaban/WilsonProject/Nf2/mui0"
    REMOTE_PREFIX["cuteri"]="/scratch/hfftheo/cuteri/ImagMu/muiPiT"
fi

#Variables
if [ $(grep -c "lcsc" <<< "${REMOTE_PREFIX[$(whoami)]}") -eq 0 ]; then
    REMOTE_NAME="hlr"
else
    REMOTE_NAME="lcsc"
fi
RSYNC_OPTIONS="qluz"
SYNC_NOW='FALSE'
REMOVE_OLDER_FILES='TRUE'
REDIRECT_OUTPUT_TO_FILES='TRUE'
ParseCommandLineOptions $@

#If not in the expected position, abort
if [ $(pwd) != ${EXPECTED_POSITION} ]; then
    printf "\n\e[0;91m The actual position is not the expected one: \"${EXPECTED_POSITION}\". Aborting...\n\n\e[0m"
    exit -1
fi

#Folders to move at the end the produced files
CONF_LIST_FOLDER="${EXPECTED_POSITION}/ConfigurationLists"
SYNC_OUTPUT_FOLDER="${EXPECTED_POSITION}/SyncronizationOutput"
#-------------------------------------------------------------------------------------------------------#

while :
do
    #The following cd is to always start the backup in the correct place. If during a backup (in the cleaning phase below -> REMOVE_OLDER_FILES)
    #an error occurs and the script exits in the wrong place, then at the following backup the folders tree will be created from the wrong place,
    #and this in principle again and again and again leading to very long unexpected paths!
    cd ${EXPECTED_POSITION}
    if [ $SYNC_NOW = "FALSE" ]; then
	    #Just to wait time for backup
        TIME_FOR_BACKUP='21'
	    CURRENT_EPOCH=$(date +%s)
	    TARGET_EPOCH=$(date -d $TIME_FOR_BACKUP +%s)
	    SLEEP_SECONDS=$(awk 'BEGIN{secInDay=3600*24}{print (($1-$2)+secInDay)%(secInDay)}' <<< "$TARGET_EPOCH $CURRENT_EPOCH" )
        printf "\n\t\e[38;5;147mEntering sleeping mode. Performing next backup on \e[38;5;86m$(date -d @$(( $CURRENT_EPOCH + $SLEEP_SECONDS)) +"%d.%m.%Y \e[38;5;147mat\e[38;5;86m %H:%M")\e[0m\n\n"
	    sleep $SLEEP_SECONDS
	fi

    if [ $REDIRECT_OUTPUT_TO_FILES = 'TRUE' ]; then
        #Redirection of output and error to files containing date and time
        STANDARD_OUTPUT_FILENAME="SyncronizationFrom_${REMOTE_NAME}_$(whoami)_on_$(date +'%F_%H%M').out"
        STANDARD_ERROR_FILENAME="${STANDARD_OUTPUT_FILENAME%.out}.err"
        exec 3>&1 4>&2 1>$STANDARD_OUTPUT_FILENAME 2>$STANDARD_ERROR_FILENAME
    fi

    #-------------------------------------------------------------------------------------------------------#
    #Actual syncronization
    [ $SYNC_NOW = "FALSE" ] && printf "\n\e[38;5;39mStarting backup of last configurations: $(date +'%F')\e[0m\n\n"
    CONF_LIST_FILE="ConfigurationListFrom_${REMOTE_NAME}_$(whoami)_on_$(date +'%F_%H%M')"

    #Getting configurations from remote (supposing folder structure)
    #ATTENTION: To list all the folders one could think to use find with -regex but this is much slower than using shell globbing.
    #           Nevertheless with bash globbing it is not really possible to force a precise structure in the name of a folder,
    #           e.g. I did not come up with the analog of the regex [0-9]+ using globbing.
    #           This is the reason why I use the * everywhere as glob charachter and then I do an if on BETA using regex (it seems fast enough).
    #
    #           The line inside the if seems also quite complicated, but what it does is simple. I want to know which is the last full checkpoint
    #           available on the cluster and avoid to copy back a prng/conf for which there is not the correspondent conf/prng.
    printf "\n\e[38;5;39m Obtaining list of files from remote...\e[0m"
    START_TIME=$(date +%s)
    ssh $REMOTE_NAME 'bash -s' > $CONF_LIST_FILE << EOF
for BETA in ${REMOTE_PREFIX[$(whoami)]}/${NFLAVOUR_PREFIX}*/${CHEMPOT_PREFIX}*/${MASS_PREFIX}*/${NTIME_PREFIX}*/${NSPACE_PREFIX}*/${BETA_PREFIX}*; do
if [[ \$BETA =~ ^${REMOTE_PREFIX[$(whoami)]}${RESULTING_REGEX//\\/}$ ]]; then
    ls \$BETA | grep "^\(prng\|conf\).[[:digit:]]\+$" | sort -t '.' -k2n | awk '{printf "%s ", \$0; if(\$0 ~ /^prng/){printf "\n"}}' | tac | awk -v beta="\$BETA" 'NF==2{printf "%s\n%s\n", beta"/"\$1, beta"/"\$2; exit}'
fi
done
EOF
    printf "\e[38;5;39m obtained $(wc -l < $CONF_LIST_FILE) files in \e[38;5;48m$(SecondsToTimeString $(( $(date +%s) - $START_TIME )) )\e[38;5;39m!\n\n\e[0m"

    #Remove remote prefix from file lines because it will be put in rsync command in order to get
    #the folder structure created on the local folder in case
    sed -i 's@'${REMOTE_PREFIX[$(whoami)]}/'@@g' $CONF_LIST_FILE
    #Copy the files from remote
    printf "\e[38;5;39m Syncronizing with the remote...\e[0m"
    START_TIME=$(date +%s)
    rsync -${RSYNC_OPTIONS} --perms --files-from=$CONF_LIST_FILE --chmod=Du=rwx,Dg=rwx,Do=r,Fu=rw,Fog=r $REMOTE_NAME:${REMOTE_PREFIX[$(whoami)]} .
    printf "\e[38;5;39m ...done in \e[38;5;48m$(SecondsToTimeString $(( $(date +%s) - $START_TIME )) )\e[38;5;39m!\n\n\e[0m"

    #-------------------------------------------------------------------------------------------------------#
    if [ $REMOVE_OLDER_FILES = 'TRUE' ]; then
        #Go through all beta folders and check if there are more than one checkpoint. Check size of configurations
        #and if everything is fine, keep only last.
        #Strictly speaking this check does not ensure that the configuration is valid, but CL2QCD already makes
        #some checks in production, trying to read back the produced checkpoint.
        #NOTE: The option -links 2 filters for directories that have two (hard) links to their name. Effectively,
        #      this filters for all directories that have no subdirectories, because only those have two links:
        #      The one in their parent directory and the . link in themselves. Those with subdirectories also
        #      have the .. links in their subdirectories.
        LIST_OF_PROBLEMATIC_FOLDERS=()
        for DIR in $(find . -type d -links 2); do
            if [[ $(basename $DIR) =~ ^$(basename $CONF_LIST_FOLDER) ]] || [[ $(basename $DIR) =~ ^$(basename $SYNC_OUTPUT_FOLDER) ]]; then
                continue
            fi
            cd $DIR
            if [ $(ls conf.[0-9]* 2>> /dev/null | wc -l) -eq 0 ]; then
                >&2 printf "\e[0;91m Error occurred trying to list files in folder \e[0;93m$(pwd)\e[0;91m -> To be invastigated...\n\e[0m"
                LIST_OF_PROBLEMATIC_FOLDERS+=( "$(pwd)" )
                cd $EXPECTED_POSITION
                continue
            fi
            LAST_TWO_CONFIGURATIONS=( $(ls conf.[0-9]* | sort -V | tail -n2) )
            if [ ${#LAST_TWO_CONFIGURATIONS[@]} -gt 1 ]; then
                #Test if the size of the two files is the same
                SIZES_OF_LAST_TWO_CONFS=( $(du -b ${LAST_TWO_CONFIGURATIONS[@]} | cut -f1) )
                if [ ${SIZES_OF_LAST_TWO_CONFS[0]} -ne ${SIZES_OF_LAST_TWO_CONFS[1]} ]; then
                    >&2 printf "\e[0;91m Last two configurations in folder \e[0;93m$(pwd)\e[0;91m have different sizes [${SIZES_OF_LAST_TWO_CONFS[0]}!=${SIZES_OF_LAST_TWO_CONFS[1]}] -> To be invastigated...\n\e[0m"
                    KEEP_ONLY_LAST_CONFIGURATION='FALSE'
                else
                    KEEP_ONLY_LAST_CONFIGURATION='TRUE'
                fi
                #Test if associated to confs there are prng and if they have same size
                LAST_TWO_PRNG=( ${LAST_TWO_CONFIGURATIONS[@]/conf/prng} )
                if [ ! -f ${LAST_TWO_PRNG[0]} ] || [ ! -f ${LAST_TWO_PRNG[1]} ]; then
                    >&2 printf "\e[0;91m Prng file(s) associated to last two configurations in folder \e[0;93m$(pwd)\e[0;91m not found! To be invastigated...\n\e[0m"
                    KEEP_ONLY_LAST_PRNG='FALSE'            
                else
                    SIZES_OF_LAST_TWO_PRNG=( $(du -b ${LAST_TWO_PRNG[@]} | cut -f1) )
                    if [ ${SIZES_OF_LAST_TWO_PRNG[0]} -ne ${SIZES_OF_LAST_TWO_PRNG[1]} ]; then
                        >&2 printf "\e[0;91m Last two prng files in folder \e[0;93m$(pwd)\e[0;91m have different sizes [${SIZES_OF_LAST_TWO_PRNG[0]}!=${SIZES_OF_LAST_TWO_PRNG[1]}] -> To be invastigated...\n\e[0m"
                        KEEP_ONLY_LAST_PRNG='FALSE'
                    else
                        KEEP_ONLY_LAST_PRNG='TRUE'
                    fi
                fi
                #Remove in case previous checkpoints
                if [ $KEEP_ONLY_LAST_CONFIGURATION = 'TRUE' ] && [ $KEEP_ONLY_LAST_PRNG = 'TRUE' ]; then
                    ls {conf,prng}.[0-9]* | grep -v "${LAST_TWO_CONFIGURATIONS[1]}\|${LAST_TWO_PRNG[1]}" | xargs -n1 rm -f
                else
                    LIST_OF_PROBLEMATIC_FOLDERS+=( "$(pwd)" )
                fi
            fi
            cd $EXPECTED_POSITION
        done
        #Short report for the user
        if [ ${#LIST_OF_PROBLEMATIC_FOLDERS[@]} -gt 0 ]; then
            printf "\n\e[38;5;105m There are ${#LIST_OF_PROBLEMATIC_FOLDERS[@]} folders in which no configuration was found or it was not possible to delete files:\n\e[0m"
            for DIR in ${LIST_OF_PROBLEMATIC_FOLDERS[@]}; do
                printf "\e[38;5;39m   $DIR\n\e[0m"
            done
            echo
        fi
    fi

    mv "$CONF_LIST_FILE" "$CONF_LIST_FOLDER" | exit -2
    if [ $REDIRECT_OUTPUT_TO_FILES = 'TRUE' ]; then
        mv "$STANDARD_OUTPUT_FILENAME" "$SYNC_OUTPUT_FOLDER"
        mv "$STANDARD_ERROR_FILENAME"  "$SYNC_OUTPUT_FOLDER"
        #Restore stdout and stderr for following iteration
        exec 1>&3 2>&4
    fi

    [ $SYNC_NOW = "TRUE" ] && break
done

exit 0
