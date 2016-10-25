#!/bin/bash

function PrintHelp(){
	echo ''
	echo '# Script to collect useful commands for working'
	echo '# Since each user could have different preferences, use the LOAD*'
	echo '# variables to decide which aliases to load.'
	echo '#'
	echo '# ATTENTION: Each user should define the following variables (NOT here but where it is sourced)'
	echo '#               XXX_work       -> global path to work directory (scratch on clusters, philconfigs locally)'
	echo '#               XXX_Wilson     -> local path from work to Wilson simulation folder , i.e. to where the mu folder is'
	echo '#               XXX_Staggered  -> local path from work to Staggered simulation folder, i.e. to where the mu folder is'
	echo '#               XXX_kappaList  -> list of kappa values between "" separated by a space, e.g. "1575 1600 1625"'
	echo '#               XXX_massList   -> list of  mass values between "" separated by a space, e.g. "0080 0090 1500"'
	echo '#               XXX_Python     -> global path to Python git, i.e. to ImagMu folder included: "/.../ImagMu"'
	echo '#               XXX_Fits       -> global path to fit git, i.e. git name folder included: "/.../gitNameFolder"'
	echo '#            where XXX is the whoami concatenated with the hostname via underscore, e.g. smith_cluster1234'
	echo '#            Once (some of) the variables above are defined, then source this script with any desired option.'
	echo '#'
	echo '# Explanation of LOAD* variables:'
	echo '#    LOAD_KAPPA_ALIASES  ->  Creates aliases to go to volumes folder in kappa folders'
	echo '#    LOAD_MASS_ALIASES   ->  Creates aliases to go to volumes folder in mass folders'
	echo '#    LOAD_PYTHON_ALIASES ->  Creates aliases to call python functionalities'
	echo '#    LOAD_FIT_ALIASES    ->  Creates aliases to call fits functionalities'
	echo '#    LOAD_JOB_ALIASES    ->  Creates aliases to work with jobs'
	echo '#'
	echo '#'
	echo '# Variable that the user should provide'
	echo '#'
	echo '#   [...]_work=""       -> Needed for LOAD_JOB_ALIASES - LOAD_KAPPA_ALIASES - LOAD_MASS_ALIASES'
	echo '#   [...]_Wilson=""     -> Needed for LOAD_KAPPA_ALIASES'
	echo '#   [...]_Staggered=""  -> Needed for LOAD_MASS_ALIASES'
	echo '#   [...]_kappaList=""  -> Needed for LOAD_KAPPA_ALIASES'
	echo '#   [...]_massList=""   -> Needed for LOAD_MASS_ALIASES'
	echo '#   [...]_Python=""     -> Needed for LOAD_PYTHON_ALIASES'
	echo '#'
	echo '# where [...] is the whoami concatenated with hostname.'
	echo ''
	echo ''
}

#============================================================================================================================#
#============================================================================================================================#

#Variable for setup which alias to source
LOAD_KAPPA_ALIASES="FALSE"
LOAD_MASS_ALIASES="FALSE"
LOAD_PYTHON_ALIASES="FALSE"
LOAD_FIT_ALIASES="FALSE"
LOAD_JOB_ALIASES="FALSE"
LOAD_ROOTHIST_ALIASES="FALSE"
UNSET_USER_VARIABLES="FALSE"

#Parsing the command line argument
while [ "$1" != "" ]; do
    case $1 in
      -h | --help )
          printf "\n\e[38;5;32m"
          PrintHelp
          printf "\e[0;32m"
          echo "Options to load bunches of aliases:"
          echo "  --loadKappa           ->    Creates aliases to go to volumes folder in kappa folders"
          echo "  --loadMass            ->    Creates aliases to go to volumes folder in kappa folders"
          echo "  --loadPython          ->    Creates aliases to call python functionalities"
          echo "  --loadFit             ->    Creates aliases to call fits functionalities"
          echo "  --loadJob             ->    Creates aliases to work with jobs"
          echo "  --loadRootHist        ->    Creates alias to access the 3D Root histogram program"
          echo "  --unsetMyVariables    ->    Unset the variables the user has allocated him/herself"
          printf "\n\e[0m"
          [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit
          shift;;
      --loadKappa )           LOAD_KAPPA_ALIASES="TRUE"; shift ;;
      --loadMass )            LOAD_MASS_ALIASES="TRUE"; shift ;;
      --loadPython )          LOAD_PYTHON_ALIASES="TRUE"; shift ;;
      --loadFit )             LOAD_FIT_ALIASES="TRUE"; shift ;;
      --loadJob )             LOAD_JOB_ALIASES="TRUE"; shift ;;
      --loadRootHist )        LOAD_ROOTHIST_ALIASES="TRUE"; shift ;;
      --unsetMyVariables )    UNSET_USER_VARIABLES="TRUE"; shift;;
      * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1 ;;
    esac
done

#If the script is executed, exit
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit

#Variables for later indirect reference 
IDENTITY="$(whoami)_$(hostname)"
IDENTITY_WORK="${IDENTITY}_work"
IDENTITY_WILSON="${IDENTITY}_Wilson"
IDENTITY_STAGGERED="${IDENTITY}_Staggered"
IDENTITY_KAPPA_LIST="${IDENTITY}_kappaList"
IDENTITY_MASS_LIST="${IDENTITY}_massList"
IDENTITY_PYTHON="${IDENTITY}_Python"
IDENTITY_JOBS="${IDENTITY}_Jobs"
IDENTITY_ROOTHIST="${IDENTITY}_RootHist"

#Checks on variables and directives
if [ $LOAD_KAPPA_ALIASES = "TRUE" ] && {
       [ ! ${!IDENTITY_WORK:+x} ] ||
       [ ! ${!IDENTITY_WILSON:+x} ] ||
       [ ! ${!IDENTITY_KAPPA_LIST:+x} ]; }; then printf "\n\e[0;31m Kappa aliases desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1
fi
if [ $LOAD_MASS_ALIASES = "TRUE" ] && {
       [ ! ${!IDENTITY_WORK:+x} ] ||
       [ ! ${!IDENTITY_STAGGERED:+x} ] ||
       [ ! ${!IDENTITY_MASS_LIST:+x} ]; }; then printf "\n\e[0;31m Mass aliases desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1
fi
if [ $LOAD_PYTHON_ALIASES = "TRUE" ] &&
       [ ! ${!IDENTITY_PYTHON:+x} ]; then printf "\n\e[0;31m Python aliases desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1
fi
if [ $LOAD_JOB_ALIASES = "TRUE" ] &&
       [ ! ${!IDENTITY_WORK:+x} ]; then printf "\n\e[0;31m Job aliases desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1
fi
if [ $LOAD_ROOTHIST_ALIASES = "TRUE" ] && 
       [ ! ${!IDENTITY_ROOTHIST:+x} ]; then printf "\n\e[0;31m Root 3D histogram program alias desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1 
fi

#============================================================================================================================#

#Aliases to run fit programs
if [ $LOAD_FIT_ALIASES = "TRUE" ]; then
    alias BinderFit='bash ${HOME}/Script/FittingUtilities/BinderFitVSbeta.sh'
    alias BruteForceFit='bash ${HOME}/Script/FittingUtilities/BruteForceFit.sh'
    alias FilterFitResults='bash ${HOME}/Script/FittingUtilities/FilterFitResults.sh'
    alias SetUpForBruteForceFit='bash ${HOME}/Script/FittingUtilities/SetUpForBruteForceFit.sh'
    alias SelectBestFits='bash ${HOME}/Script/FittingUtilities/FindClosestValue.sh'
    alias ChooseReweightingFolders='bash ${HOME}/Script/FittingUtilities/ChooseReweightingFoldersAndFindResolution.sh'
    #TODO: Put this alias somewhere else, it is not about fit
    alias QuantitativeCollapse='bash ${HOME}/Script/CollapsePlot/MathematicaQuantitativeCollapse/PerformAnalyticCollapse.sh'
    
    function PlotBestFits(){
        gnuplot -e "filenames='$*'" ${HOME}/Script/PlottingUtilities/PlotBestFits.plt
    }
    function GetFilteringProcedure(){
        echo "FilterFitResults -f FitByBruteForce.dat -o -p a1 100 | FilterFitResults -p chi2 1 | FilterFitResults -p MinOv% g80 > FilteredResults_a1_100_chi2_1_MinOv%_g80"
    }
    function GetSelectingBestFitProcedure(){
        echo 'SelectBestFits <COMPLETE_WITH_OPTIONS> | awk '"'"'{ print length, $0 }'"'"' | sort -n -s | cut -d" " -f2-'
    }

fi

#============================================================================================================================#

#Aliases to work with the python code analysis
if [ $LOAD_PYTHON_ALIASES = "TRUE" ]; then
    alias PyAutocorrelation="python ${!IDENTITY_PYTHON}/ImagMuAutocorrelationAnalysis.py"
    alias PyAnalysis="python ${!IDENTITY_PYTHON}/ImagMuAnalysis.py"
    alias PySynchronization="python ${!IDENTITY_PYTHON}/ImagMuSync.py"
    alias PyReweighting="python ${!IDENTITY_PYTHON}/ImagMuReweighting.py"
    alias PyFindBetaC="python ${!IDENTITY_PYTHON}/ImagMuFindBetaC.py"
    alias PyPlotScaling="python ${!IDENTITY_PYTHON}/ImagMuPlotScaling.py"

    #Some functions for getting most used commands in analysis
    function GetSynchronizationCommand(){
        echo "PySynchronization --betasFile=betasSync --remote=$1"
    }
    function GetAnalysisPbpCommand(){
        echo "PyAnalysis --deactivatePlaq --deactivatePoly --activatePbp"
    }
    function GetAnalysisPolyImWithZeroMeanCommand(){
        echo "PyAnalysis --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_sq"
    }
    function GetAnalysisPolySqCommand(){
        echo "PyAnalysis --deactivatePlaq --deactivatePoly_re --deactivatePoly_im_withZeroMean --deactivatePoly_im --deactivatePoly_im_abs --deactivateSusc"
    }
    function GetReweightingPbpCommand(){
        [ $# -eq 3 ] && local NUM_POINTS=$(bc <<< "($2-$1)/$3+1")
        echo "time PyReweighting --deactivatePlaq --deactivatePoly --activatePbp --deactivateMean --deactivateSusc -za --doNotUseSimulatedPointsAsNewPoints -r $1 $2 -p $NUM_POINTS"
    }
    function GetReweightingPolyImWithZeroMeanCommand(){
        if [ $# -eq 1 ]; then
            local BETA_MIN=$(head -n1 betas | cut -f1)
            local BETA_MAX=$(tail -n1 betas | cut -f1)
            local RESOLUTION=$1
        elif [ $# -eq 3 ]; then
            local BETA_MIN=$1
            local BETA_MAX=$2
            local RESOLUTION=$3
        else
            printf "\n\e[91m One or three arguments needed to \"GetReweightingPolyImWithZeroMeanCommand\" alias!\e[0m\n\n"
            return
        fi
        if [[ ! $BETA_MIN =~ [0-9][.][0-9]+ ]] || [[ ! $BETA_MAX =~ [0-9][.][0-9]+ ]]; then 
            printf "\n\e[91m Wrong format of beta min and beta max!\e[0m\n\n"
            return            
        fi
        local NUM_POINTS=$(bc <<< "($BETA_MAX-$BETA_MIN)/$RESOLUTION+1")
        #[ $(ls -1 | grep -c "^Nf") -ne 0 ] && printf "\n\e[91m Names matching \"^Nf\" detected in present folder, check alias!\e[0m\n\n" && return
        echo -n '[ $(ls Nf?_mui*_nt?_ns??_reweighting 2>/dev/null | wc -l) -eq 0 ]'
        echo -n ' && time PyReweighting --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_sq --deactivateMean --deactivateSusc --deactivateSkew --printEstimatorsToFile -za'
        echo -n " --doNotUseSimulatedPointsAsNewPoints -r $BETA_MIN $BETA_MAX -p $NUM_POINTS"
        echo -n ' && [ $(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/ | wc -l) -eq 1 ]'
        echo -n ' && FOLDER="$(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/)"'
        echo -n ' && mv ${FOLDER%?} ${FOLDER%?}_dBeta'$RESOLUTION
        echo    ' && unset -v '"'FOLDER'"
    }
    function GetReweightingPolySqSkewCommand(){
        [ $# -eq 3 ] && local NUM_POINTS=$(bc <<< "($2-$1)/$3+1")
        echo "time PyReweighting --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_im_withZeroMean --deactivateMean --deactivateSusc -za --doNotUseSimulatedPointsAsNewPoints -r $1 $2 -p $NUM_POINTS"
    }
    function GetFindBetaCPbpCommand(){
        echo "PyFindBetaC --deactivatePlaq --deactivatePoly --activatePbp --deactivateMean --deactivateSusc --deactivateBinder"
    }
    function GetFindBetaCPolySqCommand(){
        echo "PyFindBetaC --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivateMean --deactivateSkew"
    }
    function GetFindBetaCPolySqSkewCommand(){
        echo "PyFindBetaC --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_withZeroMean --deactivatePoly_im_abs --deactivateMean --deactivateSusc"
    }
    function GetPlotScalingPolySqCommand(){
        echo "PyPlotScaling --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_im_withZeroMean --nsArray $@ --doNotPlotRawData --doNotMakeCombinedPlots --deactivateMean --deactivateSkew --deactivateBinder"
    }
    function GetPlotScalingPolyImWithZeroMeanCommand(){
        local BETAC="$1"
        shift
        echo "PyPlotScaling --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_sq --nsArray $@ --doNotPlotRawData --deactivateMean --deactivateSusc --deactivateSkew --betaCForCollapsePlots $BETAC"
    }
fi

#============================================================================================================================#

#Alias for choosing a folder where we are (displaying first ns[[:digit:]] folders sorted numerically)
if [ $LOAD_MASS_ALIASES = "TRUE" ] || [ $LOAD_KAPPA_ALIASES = "TRUE" ]; then
    function PickUpFolder(){
        local FOLDERS_ARRAY=( $(ls -d ${1}*/) )
        local ORDERED_FOLDERS_ARRAY=()
        for INDEX in "${!FOLDERS_ARRAY[@]}"; do
            if [[ ${FOLDERS_ARRAY[$INDEX]} =~ ^n[ts][[:digit:]]+/$ ]]; then
                ORDERED_FOLDERS_ARRAY+=( ${FOLDERS_ARRAY[$INDEX]} )
                unset -v 'FOLDERS_ARRAY[$INDEX]'
            fi
        done
        local OLD_IFS=$IFS      # save the field separator           
        IFS=$'\n'         # new field separator, the end of line           
        ORDERED_FOLDERS_ARRAY=( $(sort -V <<< "${ORDERED_FOLDERS_ARRAY[*]}") )
        IFS=$OLD_IFS     # restore default field separator 
        ORDERED_FOLDERS_ARRAY+=( ${FOLDERS_ARRAY[@]} )
        if [ ${#ORDERED_FOLDERS_ARRAY[@]} -eq 1 ]; then
            cd ${ORDERED_FOLDERS_ARRAY[0]}
        else
            select FOLDER in ${ORDERED_FOLDERS_ARRAY[@]%?}; do
                if [ ${FOLDER:+x} ] && [ -d $FOLDER ]; then
                    cd $FOLDER
                    break
                fi
            done
        fi
    }
fi

#Aliases to go to the kappa folders
if [ $LOAD_KAPPA_ALIASES = "TRUE" ]; then
    for KAPPA in ${!IDENTITY_KAPPA_LIST}; do
    	alias k${KAPPA}="cd ${!IDENTITY_WORK}${!IDENTITY_WILSON}; PickUpFolder Nf; PickUpFolder mui; cd k$KAPPA; PickUpFolder nt; PickUpFolder ns"
    done && unset -v 'NUM_FOLDER' 'KAPPA'
fi


#Aliases to go to the mass folders
if [ $LOAD_MASS_ALIASES = "TRUE" ]; then
    for MASS in ${!IDENTITY_MASS_LIST}; do
	    alias mass${MASS}="cd ${!IDENTITY_WORK}${!IDENTITY_STAGGERED}; PickUpFolder Nf; PickUpFolder mui; cd mass$MASS; PickUpFolder nt; PickUpFolder ns"
    done && unset -v 'NUM_FOLDER' 'MASS'
fi

#============================================================================================================================#

#Aliases to work confortably on jobs

if [ $LOAD_JOB_ALIASES = "TRUE" ]; then
    alias cdw="cd ${!IDENTITY_WORK}" 
    alias JobInfo='${HOME}/Script/MonitorSlurmJobs.sh'
    alias Acceptance="awk '{ sum+=\$11} END {printf \"Accepted %d over %d (%lf%%)\n\", sum, NR, 100*sum/(NR)}'"
    alias LastAcceptance='bash ${HOME}/Script/AcceptanceLastTrajectories.sh'
    alias HandlerJobs='bash ${HOME}/Script/JobScriptAutomation/JobHandler.sh'
	alias FillInMissingLines='bash ${HOME}/Script/FillInMissingLinesOutputFile.sh'
	alias ClusterUsage='bash ${HOME}/Script/ClusterUsage.sh --doNotUpdateFiles'

    #Function to count own jobs according to part of string in job name
    function CountJobs(){
        if [ $# -eq 0 ]; then
             printf "\e[0;91m \n Number of desired chunck of jobname to be used needed as argument!\n\n\e[0m"
             return
        else
            echo
            for COLUMNS in $@; do
                squeue -u $(whoami) -h -t RUNNING,PENDING --format '%j' | cut -d'_' -f$COLUMNS | sort | uniq -c | awk '{sum+=$1; print $0} END{printf "\n Total number of jobs (RUNNING or PENDING): %d\n\n", sum}'
            done && unset -v 'COLUMNS'
        fi
    }
    
    #Function to get overview of jobs on partition
    function OverviewJobs(){
        if [ $# -ne 1 ]; then
             printf "\e[0;31m \n Name of a partition needed as argument!\n\n\e[0m"
             return
        else
            echo
            for f in RUNNING PENDING; do 
                echo "${f}:"
                squeue -h -p $1 -t $f | awk '{print $4}' | sort | uniq -c
                echo
            done && unset -v 'f'
        fi
    }
    
    #Function to easy calculate the walltime
    function Walltime(){
        [ $# -ne 2 ] && printf "\n\e[0;31m Call:    \e[1m$FUNCNAME <number_of_trajectory_to_do> <seconds_per_trajectory>\n\n\e[0m" && return
        local NUMBER_TR_TO_DO=$(bc -l <<< "$1")
        local TIME_TR="$2"
        local T=$(bc -l <<< "$NUMBER_TR_TO_DO * $TIME_TR" )
        local days=$(bc -l <<< "$T/86400" | awk '{printf "%f", $0}')
        local hours=$(bc -l <<< "($T - ${days%.*}*86400)/3600" | awk '{printf "%f", $0}' )
        local minutes=$(bc -l <<< "($T - ${days%.*}*86400 - ${hours%.*}*3600)/60" | awk '{printf "%f", $0}')
        local seconds=$( echo $T | awk 'END{print int($1) % 60}')
        printf "\e[0;32m \n walltime = %d-%02d:%02d:%02d\n\n\e[0m" "${days%.*}" "${hours%.*}" "${minutes%.*}" "${seconds}"
    }

    #Function to know gaps on saved functions
    function CalculateGapsInTrajectoriesBetweenStoredConfigurations(){
        local BETA_ARRAY=( $@ )
        for BETA in ${BETA_ARRAY[@]}; do
            printf "\n  \e[38;5;129m\e[1m\e[4m$BETA\e[0m\n\e[38;5;199m"
            ls $BETA | grep "conf.[[:digit:]]\+" | grep -o "[[:digit:]]\+" | sort -n | \
                awk 'NR==1{tr=$1}NR>1{countGaps[$1-tr]++; tr=$1}END{for(i in countGaps){printf "    Gap %d present %d times\n", i, countGaps[i]}}'
        done && unset -v 'BETA'
        echo ''
    }
    
    #Function to delete conf and prng not multiple of X trajectories
    function DeleteConfPrngNotEvery() {
		local REMAINING_NR="4"
		local USAGE_STRING="\e[31m Usage: $0 <value of which multiples will be deleted> <number up to which the last configurations will not be cleaned> <beta directories ... >\e[0m\n"
        if [[ ! $1 =~ ^[[:digit:]]+$ ]]; then
	        echo "Invalid frequency or frequency not given as first parameter!"
			echo -e $USAGE_STRING	
	        return
        fi
		local FREQUENCY=$1 && shift
		if [[ "$1" =~ ^[[:digit:]]{1,2}$ ]]; then
            if [ "$1" -eq 0 ]; then
                printf "\n\e[31m Please specify a valid POSITIVE number as second argument ...\e[0m\n\n" && return
            fi
            REMAINING_NR=$1 && shift #Here we assume beta to have a prefix like "b"
		fi
        echo ''
        printf "\e[36m Actual position: \e[1m$(pwd)\n\e[21m"
        printf "\e[38;5;202m All conf.XXXXX and prng.XXXXX with XXXXX \e[1mnot multiple of $FREQUENCY\e[21m will be deleted (except the last ${REMAINING_NR}). Proceed (Y/N)?\e[0m "
        local CONFIRM="";
        while read CONFIRM; do
	        if [ "$CONFIRM" = "Y" ]; then break; elif [ "$CONFIRM" = "N" ]; then echo '' && return; else  printf "\n\e[0;33m Please enter Y (yes) or N (no): \e[0m"; fi
        done
        echo ''
        local BETA_ARRAY=( $@ )
        [ ${#BETA_ARRAY[@]} -eq 0 ] && BETA_ARRAY=( $(ls -d b{5,6}*/ 2>/dev/null) )
        for BETA in ${BETA_ARRAY[@]}; do
			if [ -d $BETA ]; then
				printf "  \e[0;32m$BETA\e[0m\n"
				cd $BETA
                local LAST_CONF_NOT_TO_DELETE=($(ls conf.* | grep -o "conf.[[:digit:]]\+$" | sort -V | tail -n$REMAINING_NR))
                (
				    #Start a subshell in order to source "locally"
                    source ~/Script/UtilityFunctions.sh
				    for FILE in conf.????? conf.?????? conf.???????; do
					    #echo "checking $FILE..."
					    if ! ElementInArray $FILE ${LAST_CONF_NOT_TO_DELETE[@]}
					    then
					        local NUM=$(grep -o "[[:digit:]]*" <<< $FILE)
					        if [ ${NUM:+x} ]; then
						        [ $(awk -v freq="$FREQUENCY" '{print $1%freq}' <<< $NUM) -ne 0 ] && rm -f $FILE ${FILE/conf/prng}
					        fi
					    fi
				    done
                )
				cd ..
            else
                printf "  \e[1;31m$BETA\e[21m folder not found, skipping it!\e[0m\n"
            fi
        done && unset -v 'BETA'
        echo ''
    }

    #Functions useful later
    function CompleteFolderName(){
        local FOLDERS_ARRAY=()
        for ARGUMENT in $@; do
            if [[ ! $ARGUMENT =~ ^[[:digit:]][.][[:digit:]]{4}_s[[:digit:]]{4}_[[:alpha:]]{2}$ ]]; then
                echo "False"
                return
            fi
            local SUFFIX=${ARGUMENT##*_}
            if [ $SUFFIX = "fH" ]; then
                local FOLDER=b${ARGUMENT%_*}_thermalizeFromHot
            elif [ $SUFFIX = "fC" ]; then
                local FOLDER=b${ARGUMENT%_*}_thermalizeFromConf
            else
                local FOLDER=b${ARGUMENT%_*}_continueWithNewChain
            fi
            FOLDERS_ARRAY+=( $FOLDER )
        done && unset -v 'ARGUMENT'
        echo ${FOLDERS_ARRAY[@]}
    }
    
    function FindLastStandardOutput(){
        if [ -d $1 ]; then
            local FOLDER="$1"
        else
            local FOLDER=$(CompleteFolderName $1)
        fi
        [ ! -d $FOLDER ] && printf "\n\e[0;91m Folder \"$FOLDER\" not found!\n\n\e[0m" && return -1
        [ $(find $FOLDER -name "?hmc_ref.*.out" | wc -l) -eq 0 ] && printf "\n\e[0;91m No standard output file found in \"$FOLDER\"!\n\n\e[0m" && return -1
        if [ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ]; then
            local FILE="$(ls -rt1 $FOLDER/rhmc_ref.*.out | tail -n1)"
            FILE=${FILE/$FOLDER\//}
        elif [ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ]; then
            local FILE="$(ls -rt1 $FOLDER/hmc_ref.*.out | tail -n1)"
            FILE=${FILE/$FOLDER\//}
        else
            echo "Neither in Staggered nor in Wilson path!"
        fi        
        echo "$FOLDER/$FILE"
    }

    function FindMissingTrajectories(){
        for ARGUMENT in $@; do
            if [ -d $ARGUMENT ]; then
                local FOLDER="$ARGUMENT"
            else
                local FOLDER=$(CompleteFolderName $ARGUMENT)
                [ ! -d $FOLDER ] && printf "\n \e[31mSkipping folder \"$ARGUMENT\" which has not been found!\n" && continue
            fi
            if [ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ]; then
                local FILE="${FOLDER}/rhmc_output"
            elif [ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ]; then
                local FILE="${FOLDER}/hmc_output"
            else
                echo "Neither in Staggered nor in Wilson path!"
            fi
            printf "\n\e[38;5;32m Checking file \e[36m$FILE"
            [ ! -f $FILE ] && printf "\n \e[31mFile \"$FILE\" not found! Skipping it...\n" && continue
            local TRAJ=( $(awk '
                           NR==1{last=$1}
                           NR>1{if($1>last+1){missTraj[arraylength++]=$1}; last=$1}
                           END{if(arraylength==0){exit 0}
                               else{for(i in missTraj){print missTraj[i]}; exit 1}}' $FILE) )
            if [ "${#TRAJ[@]}" -eq 0 ]; then
                printf "\e[32m ...no missing trajectory found!\e[0m\n\n"
            else
                printf "\e[38;5;202m ...found ${#TRAJ[@]} bunch(es) of missing trajectory(ies)!\e[0m\n"
                for VALUE in ${TRAJ[@]}; do
                    local LINE_NUMBER=$(grep -n "^$VALUE[[:space:]]" $FILE | cut -f1 -d':')
                    if [ -z ${EDITOR:+x} ]; then
                        vim +$LINE_NUMBER $FILE
                    else
                        $EDITOR +$LINE_NUMBER $FILE
                    fi
                done && unset -v 'VALUE'
                printf "\n"
            fi
        done && unset -v 'ARGUMENT'
    }


    #Function to estimate time per trajectory giving beta as input
    function TimeTr(){
        local PATH_TO_BE_USED; PATH_TO_BE_USED=$(FindLastStandardOutput $1) #To be able to check error code, local sweeps it away!
        [ $? -ne 0 ] && printf "$PATH_TO_BE_USED" && return -1
        printf "\e[38;5;129m\n Calling:\e[38;5;199m ${HOME}/Script/TimeTrajectoryCL2QCD.sh $PATH_TO_BE_USED\n\e[0m"
        local OUTPUT_TIME_TR="$(${HOME}/Script/TimeTrajectoryCL2QCD.sh $PATH_TO_BE_USED)"
        [ $? -ne 0 ] && printf "$OUTPUT_TIME_TR" && return -1
        printf "$OUTPUT_TIME_TR \n\n"
        local TIME_TR="$(grep -oE "[[:digit:]]+[.][[:digit:]]*" <<< "$OUTPUT_TIME_TR")"
        for INDEX in 1000 5000 10000 25000 50000; do
            local WALLTIME=$(Walltime $INDEX $TIME_TR | grep -oE "[[:digit:]]+-[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}")
            printf "\e[38;5;202m%8s\e[0m  --->  \e[38;5;39m%12s\e[0m\n" "$INDEX" "$WALLTIME"
        done
        echo ''
    }

    #Function to show std output/error 
    function ShowStd(){
        if [[ $1 =~ ^b?[[:digit:]][.] ]]; then
            local FILE_NAME=$(FindLastStandardOutput $1)
        elif [[ $1 =~ ^[[:digit:]]+$ ]]; then
            if [ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ]; then
                local FILE_NAME="JobScripts/rhmc_ref.$1.out"
            elif [ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ]; then
                local FILE_NAME="JobScripts/hmc_ref.$1.out"
            else
                echo "Neither in Staggered nor in Wilson path!"
            fi
        else
            printf "\n\e[0;31m Unknown first command line parameter!\n\n\e[0m"
        fi
        if [ "$2" = "" ]; then
            less $FILE_NAME
        elif [ "$2" = "-e" ]; then
            less ${FILE_NAME/.out/.err}
        else
            printf "\n\e[0;31m Unknown second command line parameter!\n\n\e[0m"
        fi
        #Print jobid and node to screen
        local JOBID=$(grep -o "[[:digit:]]\+" <<< ${FILE_NAME##*hmc})
        printf "\n\e[0;36m Job ID: ${JOBID}   "
        printf "$(grep "Host" JobScripts/?hmc_ref.${JOBID}.out)\n\n\e[0m"
    }

    #Function to eliminate conf.save* and prng.save*
    function rmSave(){
        if [ -d $1 ]; then
            local FOLDER="$1"
        else
            local FOLDER=$(CompleteFolderName $1)
        fi
        echo ""
        for FILE_NAME in $FOLDER/conf.save* $FOLDER/prng.save*; do
            if [ ! -s $FILE_NAME ]; then
                printf "\e[1;31m File $FILE_NAME is empty!\n\n\e[0m"
            fi
        done
        rm -i $FOLDER/conf.save* $FOLDER/prng.save*
        echo ""
    }

    #Function to check correctness simulations output
    function CheckCl2qcdOutput(){
        if [ -f $1 ]; then
            local FILE=$1
        else
            if [ -d $1 ]; then
                local FOLDER="$1"
            else
                local FOLDER=$(CompleteFolderName $1)
            fi
            if [ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ]; then
                local FILE="${FOLDER}/rhmc_output"
            elif [ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ]; then
                local FILE="${FOLDER}/hmc_output"
            else
                echo "Neither in Staggered nor in Wilson path!"
            fi
        fi
        
        printf "\e[38;5;129m\n Calling:\e[38;5;199m ${HOME}/Script/CheckCorrectnessCl2qcdOutputFile.sh \e[38;5;117m$FILE\n\e[0m"
        bash ${HOME}/Script/CheckCorrectnessCl2qcdOutputFile.sh $FILE
    }
    
fi

#============================================================================================================================#
#Aliases to call the Root 3D histogram program
if [ $LOAD_ROOTHIST_ALIASES = "TRUE" ]; then
    
    function CreateRootHistograms(){

        local BETA_ARRAY=()
        local ROOT_INPUT_FILE="hmc_output"
        local TMP_ROOT_PATH_INPUT_FILE="tmpFileForRoot"
        local PATH_PREFIX="/home/phil-configs/wilson_nf2_muipi4/ImagMu"
        local ROOT_PRGOGRAM="/home/czaban/3DPolyLoopHist/3DPolyLoopHist"

        while [ $# -gt 0 ];do
            case $1 in
                -b) 
                    while [[ $2 =~ ^[[:digit:]]\.[[:digit:]]{4}$ ]];do
                        BETA_ARRAY+=( $2 )
                        shift
                    done
                    ;;
                -h)
                    echo "Invoke the function with -b option."
                    echo "Following the -b option, specify the desired beta values."
                    return
                    ;;
                -*)
                    echo "$0: $1: unrecognized option...exiting" >&2
                    return 
                    ;;
                *)
                    echo "$0: $1: unrecognized option...exiting" >&2
                    return
                    ;;
            esac
            shift
        done

        #source $HOME/Script/PathManagement.sh || echo "Error sourcing PathManagement.sh" && return
        #ReadParametersFromPath $(pwd)
        #local CURRENT_PATH=$PATH_PREFIX/$CHEMPOT_PREFIX$CHEMPOT/$KAPPA_PREFIX$KAPPA/$NTIME_PREFIX$NTIME/$NSPACE_PREFIX$NSPACE
        local CURRENT_PATH=$(pwd)

        #Create tmpfile for Root
        local BETA_PATH_ARRAY=()
        for BETA in ${BETA_ARRAY[@]}; do
            BETA_PATH_ARRAY+=( "$BETA	$CURRENT_PATH/b$BETA/$ROOT_INPUT_FILE" )  
        done
        for ((i = 0; i < ${#BETA_PATH_ARRAY[@]}; i++)); do
            echo ${BETA_PATH_ARRAY[i]} >> $TMP_ROOT_PATH_INPUT_FILE
        done

        #Call Root program
        $ROOT_PRGOGRAM --pathInputFile=tmpFileForRoot --addProj

        rm $TMP_ROOT_PATH_INPUT_FILE
    }

fi
#============================================================================================================================#

#Unset user variables
if [ $UNSET_USER_VARIABLES = "TRUE" ]; then
    [ ${!IDENTITY_WORK+x} ] && unset -v $IDENTITY_WORK
    [ ${!IDENTITY_WILSON+x} ] && unset -v $IDENTITY_WILSON
    [ ${!IDENTITY_STAGGERED+x} ] && unset -v $IDENTITY_STAGGERED
    [ ${!IDENTITY_KAPPA_LIST+x} ] && unset -v $IDENTITY_KAPPA_LIST
    [ ${!IDENTITY_MASS_LIST+x} ] && unset -v $IDENTITY_MASS_LIST
    [ ${!IDENTITY_PYTHON+x} ] && unset -v $IDENTITY_PYTHON
    [ ${!IDENTITY_JOBS+x} ] && unset -v $IDENTITY_JOBS
    [ ${!IDENTITY_ROOTHIST+x} ] && unset -v $IDENTITY_ROOTHIST
fi

#Unsetting remaining variables
unset -v LOAD_MASS_ALIASES
unset -v LOAD_KAPPA_ALIASES
unset -v LOAD_PYTHON_ALIASES
unset -v LOAD_FIT_ALIASES
unset -v LOAD_JOB_ALIASES
unset -v IDENTITY
unset -v IDENTITY_WORK
unset -v IDENTITY_WILSON
unset -v IDENTITY_STAGGERED
unset -v IDENTITY_KAPPA_LIST
unset -v IDENTITY_MASS_LIST
unset -v IDENTITY_PYTHON
unset -v IDENTITY_JOBS
unset -v IDENTITY_ROOTHIST




