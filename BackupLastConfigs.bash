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

function ParseCommandLineOptions()
{
    while [[ $# -ne 0 ]]; do
        case $1 in
            -h | --help )
                printf "\n\e[0;92m"
                echo " Call the script $0 with the following optional arguments:"
                printf "\n\e[0;96m"
                echo "   -r | --remote         ->    remote name (default = '${remoteName}')"
                echo "   -s | --software       ->    remote name (default = '${softwareName}')"
                echo "   --remotePrefix        ->    remote prefix (by default hard-coded)"
                echo "   --rsyncOptions        ->    options passed to rsync (default = '${rsyncOptions}')"
                echo "   --now                 ->    start the syncronization immediately and not at 21"
                echo "   --doNotRemoveFiles    ->    only the backup is done and no older checkpoint is deleted"
                echo "   --doNotRedirect       ->    no redirection of standard output and error is done"
                echo "   --cleanAllFolders     ->    all beta folders instead of synchronised ones are considered removing checkpoints"
                echo "   --preservePermissions ->    source permissions are preserved, otherwise destination default are used"
                printf "\n\e[0;93m"
                echo " NOTE: Changing rsync permissions could affect permissions on reciever that are"
                echo "       by default set to \"--chmod=Du=rwx,Dg=rwx,Do=r,Fu=rw,Fog=r\" how it should be."
                printf "\n\e[0m"
                exit
                shift;;
            -r | --remote )
                remoteName="$2"
                shift 2
                ;;
            -s | --software )
                if [[ ! $2 =~ ^(CL2QCD|openQCD-FASTSUM)$ ]]; then
                    printf "\n\e[0;91m Only 'CL2QCD' and 'openQCD-FASTSUM' supported as software. Aborting...\n\n\e[0m"
                    exit -1
                fi
                softwareName="$2"
                shift 2
                ;;
            --remotePrefix )
                remotePrefixCommandLine="$2"
                shift 2
                ;;
            --rsyncOptions )
                rsyncOptions="$2"
                shift 2
                ;;
            --now )
                syncNow='TRUE'
                shift
                ;;
            --doNotRemoveFiles )
                removeOlderFiles='FALSE'
                shift
                ;;
            --doNotRedirect )
                redirectOutpuTtoFiles='FALSE'
                shift
                ;;
            --cleanAllFolders )
                cleanAllFolders='TRUE'
                shift
                ;;
            --preservePermissions)
                useDestinationPermissions='FALSE'
                shift
                ;;
            * )
                printf "\n\e[0;91m Error parsing the options! Aborting...\n\n\e[0m"
                exit -1
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------------------------------#
#Variables
remoteName='hlr'
softwareName='CL2QCD'
rsyncOptions='qluz'
syncNow='FALSE'
removeOlderFiles='TRUE'
redirectOutpuTtoFiles='TRUE'
useDestinationPermissions='TRUE'
remotePrefixCommandLine=''
cleanAllFolders='FALSE'

ParseCommandLineOptions "$@"

if [[ ${softwareName} = 'CL2QCD' ]]; then
    dataFileMustExist='FALSE'
else
    dataFileMustExist='TRUE'
fi

#Having loaded PathManagement.sh we get for free all the parameters variables and functionalities
CheckWilsonStaggeredVariables
#Build path regex for later
pathRegex=""
for index in ${!PARAMETER_REGEXES[@]}; do
    pathRegex="${pathRegex}/${PARAMETER_PREFIXES[index]}${PARAMETER_REGEXES[index]}"
done && unset -v 'index'
readonly pathRegex="${pathRegex}/${BETA_FOLDER_REGEX}"

readonly wilsonConfigurationPathPrefix="/home/phil-configs/ColumbiaPlot_Wilson_${softwareName}"
readonly staggeredConfigurationPathPrefix="/home/phil-configs/ColumbiaPlot_Staggered_${softwareName}"

#Associative array to make the script user specific
declare -A remotePrefix
if [[ "${remotePrefixCommandLine}" != '' ]]; then
    remotePrefix["$(whoami)_${remoteName}"]="${remotePrefixCommandLine}"
else
    if [[ ${STAGGERED} = 'TRUE' ]]; then
        expectedPosition="${staggeredConfigurationPathPrefix}/Checkpoints"
        #Each user can put here the remote prefix if she/he does not want to give it via command line
        remotePrefix["sciarra_hlr"]="/scratch/latticeqcd/sciarra/Staggered"
        remotePrefix["sciarra_lcsc"]="/lustre/lcsc/asciarra/StaggeredProject"
        remotePrefix["kaiser_lcsc"]="/lustre/lcsc/rekaiser/StaggeredProject"
	remotePrefix["kaiser_hlr"]="/scratch/latticeqcd/kaiser/StaggeredProject"
    elif [[ ${WILSON} = 'TRUE' ]]; then
        expectedPosition="${wilsonConfigurationPathPrefix}/Checkpoints"
        #Each user can put here the remote prefix if she/he does not want to give it via command line
        remotePrefix["sciarra_hlr"]="/scratch/latticeqcd/sciarra/Wilson"
        remotePrefix["sciarra_juwels"]="/p/scratch/cpw2/CPWilson"
    fi
fi

#If not in the expected position, abort
if [[ $(pwd) != ${expectedPosition} ]]; then
    printf "\n\e[0;91m The actual position is not the expected one: \"${expectedPosition}\". Aborting...\n\n\e[0m"
    exit -1
fi

#Remote path must be not empty
if [[ "${remotePrefix[$(whoami)_${remoteName}]}" = '' ]]; then
    printf "\n\e[0;91m The script does not know the remote prefix for \"$(whoami)_${remoteName}\".\n"
    printf " Use the --remotePrefix option or edit \"${BASH_SOURCE[0]}\" accordingly.\n\n\e[0m"
    exit -1
fi

#Folders to move at the end the produced files
readonly configurationListsFolderGlobalPath="${expectedPosition}/ListsOfCheckpoints"
readonly synchronizationOutputFolderGlobalPath="${expectedPosition}/SynchronizationOutput"

for folder in "${configurationListsFolderGlobalPath}" "${synchronizationOutputFolderGlobalPath}"; do
    if [[ ! -d "${folder}" ]]; then
        mkdir "${folder}"
    fi
done
#-------------------------------------------------------------------------------------------------------#
function SleepTillNextBackup()
{
    local timeForBackup currentEpoch targetEpoch sleepSeconds
    timeForBackup='21'
	currentEpoch=$(date +'%s')
	targetEpoch=$(date -d "${timeForBackup}" +'%s')
	sleepSeconds=$(( (targetEpoch - currentEpoch + 3600*24) % (3600*24) ))
    printf "\n\t\e[38;5;147mEntering sleeping mode. Performing next backup on \e[38;5;86m$(date -d @$((currentEpoch + sleepSeconds)) +"%d.%m.%Y \e[38;5;147mat\e[38;5;86m %H:%M")\e[0m\n\n"
	sleep ${sleepSeconds}
}

function IsSizeLastTwoFilesTheSame()
{
    local filePrefix lastTwoFiles sizesOfLastTwoFiles
    filePrefix="$1"
    lastTwoFiles=( $(printf "%s\n" "${filePrefix}".[0-9]* | sort -V | tail -n2) )
    if [[ ${#lastTwoFiles[@]} -eq 0 ]]; then
        printf "\e[0;91m No '${filePrefix}' file found in folder \e[0;93m$(pwd)\e[0;91m -> To be invastigated...\n\e[0m" >&2
        return 1
    elif [[ ${#lastTwoFiles[@]} -eq 1 ]]; then
        return 0
    else
        #Test if the size of the two files is the same
        sizesOfLastTwoFiles=( $(stat -c '%s' "${lastTwoFiles[@]}") )
        if [[ ${sizesOfLastTwoFiles[0]} -ne ${sizesOfLastTwoFiles[1]} ]]; then
            printf "\e[0;91m Last two '${filePrefix}' in folder \e[0;93m$(pwd)\e[0;91m have different sizes [${sizesOfLastTwoFiles[0]}!=${sizesOfLastTwoFiles[1]}] -> To be invastigated...\n\e[0m" >&2
            return 1
        else
            return 0
        fi
    fi
}
#-------------------------------------------------------------------------------------------------------#
shopt -s nullglob # to work on filenames more comfortably

while :
do
    #The following cd is to always start the backup in the correct place. If during a backup (in the cleaning phase below -> removeOlderFiles)
    #an error occurs and the script exits in the wrong place, then at the following backup the folders tree will be created from the wrong place,
    #and this in principle again and again and again leading to very long unexpected paths!
    cd "${expectedPosition}"
    if [[ ${syncNow} = 'FALSE' ]]; then
        SleepTillNextBackup
	fi

    if [[ ${redirectOutpuTtoFiles} = 'TRUE' ]]; then
        standardOutputFilename="From_${remoteName}_$(whoami)_on_$(date +'%F_%H%M').out"
        standardErrorFilename="${standardOutputFilename%.out}.err"
        exec 3>&1 4>&2 1> "${standardOutputFilename}" 2> "${standardErrorFilename}"
    fi

    #-------------------------------------------------------------------------------------------------------#
    #Actual syncronization
    if [[ ${syncNow} = 'FALSE' ]]; then
        printf "\n\e[38;5;39mStarting backup of last configurations: $(date +'%F')\e[0m\n\n"
    fi
    checkpointsListFilename="Checkpoints_from_${remoteName}_$(whoami)_on_$(date +'%F_%H%M')"

    #Getting configurations from remote (supposing folder structure)
    #ATTENTION: To list all the folders one could think to use find with -regex but this is much slower than using shell globbing.
    #           Nevertheless with bash globbing it is not really possible to force a precise structure in the name of a folder,
    #           e.g. I did not come up with the analog of the regex [0-9]+ using globbing.
    #           This is the reason why I use the * everywhere as glob charachter and then I do an if on BETA using regex (it seems fast enough).
    #
    #           The line inside the if seems also quite complicated, but what it does is simple. I want to know which is the last full checkpoint
    #           available on the cluster and avoid to copy back a prng/conf for which there is not the correspondent conf/prng.
    printf "\n\e[38;5;39m Obtaining list of files from remote...\e[0m"
    startTime=$(date +%s)
    case "${softwareName}" in
        CL2QCD )
            ssh "${remoteName}" 'bash -O extglob -s' > "${checkpointsListFilename}" << EOF
for BETA in ${remotePrefix[$(whoami)_${remoteName}]}/${NFLAVOUR_PREFIX}*/${CHEMPOT_PREFIX}*/${MASS_PREFIX}*/${NTIME_PREFIX}*/${NSPACE_PREFIX}*/${BETA_PREFIX}*; do
    if [[ \$BETA =~ ^${remotePrefix[$(whoami)_${remoteName}]}${pathRegex//\\/}$ ]]; then
        basename -a \$(printf "%s\n" \$BETA/@(conf|prng).+([0-9])) |\
                 sort -t '.' -k2nr |\
                 awk 'BEGIN{FS="."} NR==1{tr=\$2} {if(\$2!=tr){printf "\n"}; tr=\$2} {printf "%s ", \$0}END{printf "\n"}' |\
                 awk -v beta="\$BETA" 'NF==2{printf "%s\n%s\n", beta"/"\$1, beta"/"\$2; exit}'
    fi
done
EOF
            ;;
        openQCD-FASTSUM )
            ssh "${remoteName}" 'bash -O extglob -s' > "${checkpointsListFilename}" << EOF
for BETA in ${remotePrefix[$(whoami)_${remoteName}]}/${NFLAVOUR_PREFIX}*/${CHEMPOT_PREFIX}*/${MASS_PREFIX}*/${NTIME_PREFIX}*/${NSPACE_PREFIX}*/${BETA_PREFIX}*; do
    if [[ \$BETA =~ ^${remotePrefix[$(whoami)_${remoteName}]}${pathRegex//\\/}$ ]]; then
        basename -a \$(printf "%s\n" \$BETA/@(conf|prng|data).+([0-9])) |\
                 sort -t '.' -k2nr |\
                 awk 'BEGIN{FS="."} NR==1{tr=\$2} {if(\$2!=tr){printf "\n"}; tr=\$2} {printf "%s ", \$0}END{printf "\n"}' |\
                 awk -v beta="\$BETA" 'NF==3{printf "%s\n%s\n%s\n", beta"/"\$1, beta"/"\$2, beta"/"\$3; exit}'
    fi
done
EOF
            ;;
        * )
            printf "\n\e[0;91m Unknown software but this branch should not be entered! Aborting...\n\n\e[0m"
            exit -1
            ;;
    esac
    printf "\e[38;5;39m obtained $(wc -l < ${checkpointsListFilename}) files in \e[38;5;48m$(SecondsToTimeString $(( $(date +%s) - ${startTime} )) )\e[38;5;39m!\n\n\e[0m"

    #Remove remote prefix from file lines because it will be put in rsync command in order to get
    #the folder structure created on the local folder in case
    sed -i 's@'"${remotePrefix[$(whoami)_${remoteName}]}/"'@@g' "${checkpointsListFilename}"
    #Copy the files from remote
    printf "\e[38;5;39m Syncronizing with the remote...\e[0m"
    startTime=$(date +%s)
    if [[ ${useDestinationPermissions} = 'TRUE' ]]; then
        rsync -"${rsyncOptions}" --no-p --no-g --chmod=ugo=rwX --files-from="${checkpointsListFilename}" "${remoteName}:${remotePrefix[$(whoami)_${remoteName}]}" .
    else
        rsync -"${rsyncOptions}" --perms --files-from="${checkpointsListFilename}" "${remoteName}:${remotePrefix[$(whoami)_${remoteName}]}" .
    fi
    printf "\e[38;5;39m ...done in \e[38;5;48m$(SecondsToTimeString $(( $(date +%s) - ${startTime} )) )\e[38;5;39m!\n\n\e[0m"

    #-------------------------------------------------------------------------------------------------------#
    if [[ ${removeOlderFiles} = 'TRUE' ]]; then
        startTime=$(date +%s)
        # Go through all beta folders and check if there are more than one checkpoint. Check size of configurations
        # and if everything is fine, keep only last. Strictly speaking this check does not ensure that the
        # configuration is valid, but CL2QCD already makes some checks in production, trying to read back
        # the produced checkpoint.
        #
        #NOTE: The option -links 2 filters for directories that have two (hard) links to their name. Effectively,
        #      this filters for all directories that have no subdirectories, because only those have two links:
        #      The one in their parent directory and the . link in themselves. Those with subdirectories also
        #      have the .. links in their subdirectories.
        listOfProblematicFolders=()
        listOfRemovedFiles=()
        listOfFoldersToBeCleaned=()
        if [[ ${cleanAllFolders} = 'TRUE' ]]; then
            readarray -d '' listOfFoldersToBeCleaned < <(find . -type d -links 2 -print0)
        else
            readarray -t listOfFoldersToBeCleaned < "${checkpointsListFilename}"
            listOfFoldersToBeCleaned=( "${listOfFoldersToBeCleaned[@]%/*}" )
            readarray -d $'\0' -t listOfFoldersToBeCleaned < <(printf '%s\0' "${listOfFoldersToBeCleaned[@]}" | sort -z | uniq -z)
        fi
        printf "\e[38;5;39m Checkpoints to be checked and cleaned in ${#listOfFoldersToBeCleaned[@]} folders...\e[0m\n"
        for folder in "${listOfFoldersToBeCleaned[@]}"; do
            cd "${expectedPosition}" # To come back to the correct position in case of 'continue'
            if [[ $(basename "${folder}") =~ ^$(basename "${configurationListsFolderGlobalPath}") ]]; then
                continue
            elif [[ $(basename "${folder}") =~ ^$(basename "${synchronizationOutputFolderGlobalPath}") ]]; then
                continue
            fi
            cd "${folder}"
            # The size of 'data' files increases during simulation, do not check it
            for prefix in 'conf' 'prng'; do
                if ! IsSizeLastTwoFilesTheSame "${prefix}"; then
                    listOfProblematicFolders+=( "$(pwd)" )
                    continue 2
                fi
            done
            numberLastCheckpoint="$(printf "%s\n" conf.[0-9]* | sort -V | tail -n1 | cut -d'.' -f 2)"
            for prefix in 'conf' 'prng' 'data'; do
                if [[ ! -f "${prefix}.${numberLastCheckpoint}" ]]; then
                    if [[ ${prefix} = 'data' ]] && [[ ${dataFileMustExist} = 'FALSE' ]]; then
                        continue
                    else
                        printf "\e[0;91m Checkpoint ${numberLastCheckpoint} is incomplete in \e[0;93m$(pwd)\e[0;91m -> To be invastigated...\n\e[0m" >&2    
                        listOfProblematicFolders+=( "$(pwd)" )
                        continue 2
                    fi
                fi
            done
            # Here previous checkpoints can be removed
            regexLastCheckpoint="(conf|prng|data)[.]${numberLastCheckpoint}"
            for checkpointFile in {conf,prng,data}.[0-9]*; do
                if [[ ! ${checkpointFile} =~ ^${regexLastCheckpoint}$ ]]; then
                    listOfRemovedFiles+=( "$(pwd)/${checkpointFile}" )
                    rm "${checkpointFile}"
                fi
            done
        done
        #Short report for the user
        if [[ ${#listOfRemovedFiles[@]} -gt 0 ]]; then
            printf "\n\e[38;5;105m ${#listOfRemovedFiles[@]} checkpoint files have been deleted:\n\e[0m"
            for checkpointFile in "${listOfRemovedFiles[@]}"; do
                printf "\e[38;5;39m   ${checkpointFile}\n\e[0m"
            done
        fi
        if [[ ${#listOfProblematicFolders[@]} -gt 0 ]]; then
            printf "\n\e[38;5;105m There are ${#listOfProblematicFolders[@]} folders in which an error occurred:\n\e[0m"
            for folder in "${listOfProblematicFolders[@]}"; do
                printf "\e[38;5;39m   ${folder}\n\e[0m"
            done
        fi
        printf "\n\e[38;5;39m ...checkpoint processing done in \e[38;5;48m$(SecondsToTimeString $(( $(date +%s) - ${startTime} )) )\e[38;5;39m!\n\n\e[0m"
    fi

    cd "${expectedPosition}"

    subfolderName="$(date +'%Y_%m')_${remoteName}_$(whoami)"
    mkdir -p "${configurationListsFolderGlobalPath}/${subfolderName}"    || exit -2
    mkdir -p "${synchronizationOutputFolderGlobalPath}/${subfolderName}" || exit -2
    mv "${checkpointsListFilename}" "${configurationListsFolderGlobalPath}/${subfolderName}" || exit -2
    if [[ ${redirectOutpuTtoFiles} = 'TRUE' ]]; then
        mv "${standardOutputFilename}" "${synchronizationOutputFolderGlobalPath}/${subfolderName}" || exit -2
        mv "${standardErrorFilename}"  "${synchronizationOutputFolderGlobalPath}/${subfolderName}" || exit -2
        #Restore stdout and stderr for following iteration
        exec 1>&3 2>&4
    fi

    if [[ ${syncNow} = 'TRUE' ]]; then
        break
    fi
done

exit 0
