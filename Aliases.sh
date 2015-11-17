#!/bin/bash

# Script to collect useful commands for working
# Since each user could have different preferences, use the LOAD*
# variables to decide which aliases to load.
#
# ATTENTION: Each user should add the following variables (NOT here but where it is sourced in case of future pull)
#               XXX_work       -> global path to work directory (scratch on clusters, philconfigs locally)
#               XXX_Wilson     -> local path from work to Wilson simulation folder , i.e. to where the mu folder is
#               XXX_Staggered  -> local path from work to Staggered simulation folder, i.e. to where the mu folder is
#               XXX_kappaList  -> list of kappa values between "" separated by a space, e.g. "1575 1600 1625"
#               XXX_massList   -> list of  mass values between "" separated by a space, e.g. "0080 0090 1500"
#               XXX_Python     -> global path to Python git, i.e. to ImagMu folder included: "/.../ImagMu"
#               XXX_Fits       -> global path to fit git, i.e. git name folder included: "/.../gitNameFolder"
#            where XXX is the whoami concatenated with the hostname via underscore, e.g. smith_cluster1234
# ATTENTION: The user should unset at the end of this file all the variable introduced!
#
# Explanation of LOAD* variables:
#    LOAD_KAPPA_ALIASES  ->  Creates aliases to go to volumes folder in kappa folders
#    LOAD_MASS_ALIASES   ->  Creates aliases to go to volumes folder in kappa folders
#    LOAD_PYTHON_ALIASES ->  Creates aliases to call python functionalities
#    LOAD_FIT_ALIASES    ->  Creates aliases to call fits functionalities
#    LOAD_JOB_ALIASES    ->  Creates aliases to work with jobs


# Variable that the user should provide
#
#   [...]_work=""       -> Needed for LOAD_JOB_ALIASES - LOAD_KAPPA_ALIASES - LOAD_MASS_ALIASES
#   [...]_Wilson=""     -> Needed for LOAD_KAPPA_ALIASES
#   [...]_Staggered=""  -> Needed for LOAD_MASS_ALIASES
#   [...]_kappaList=""  -> Needed for LOAD_KAPPA_ALIASES
#   [...]_massList=""   -> Needed for LOAD_MASS_ALIASES
#   [...]_Python=""     -> Needed for LOAD_PYTHON_ALIASES
#   [...]_Fits=""       -> Needed for LOAD_FIT_ALIASES
#
# where [...] is the whoami concatenated with hostname.

#============================================================================================================================#
#============================================================================================================================#

#Variable for setup which alias to source
LOAD_KAPPA_ALIASES="FALSE"
LOAD_MASS_ALIASES="FALSE"
LOAD_PYTHON_ALIASES="FALSE"
LOAD_FIT_ALIASES="FALSE"
LOAD_JOB_ALIASES="FALSE"
UNSET_USER_VARIABLES="FALSE"

#Parsing the command line argument
while [ "$1" != "" ]; do
    case $1 in
      -h | --help )
          printf "\n\e[0;32m"
          echo "Options to load bunches of aliases:"
          echo "  --loadKappa           ->    Creates aliases to go to volumes folder in kappa folders"
          echo "  --loadMass            ->    Creates aliases to go to volumes folder in kappa folders"
          echo "  --loadPython          ->    Creates aliases to call python functionalities"
          echo "  --loadFit             ->    Creates aliases to call fits functionalities"
          echo "  --loadJob             ->    Creates aliases to work with jobs"
          echo "  --unsetMyVariables    ->    Unset the variables the user has allocated him/herself"
          printf "\n\e[0m"
          [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit
          shift;;
      --loadKappa )           LOAD_KAPPA_ALIASES="TRUE"; shift ;;
      --loadMass )            LOAD_MASS_ALIASES="TRUE"; shift ;;
      --loadPython )          LOAD_PYTHON_ALIASES="TRUE"; shift ;;
      --loadFit )             LOAD_FIT_ALIASES="TRUE"; shift ;;
      --loadJob )             LOAD_JOB_ALIASES="TRUE"; shift ;;
      --unsetMyVariables )    UNSET_USER_VARIABLES="TRUE"; shift;;
      * ) printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1 ;;
    esac
done

#Variables for later indirect reference 
IDENTITY="$(whoami)_$(hostname)"
IDENTITY_WORK="${IDENTITY}_work"
IDENTITY_WILSON="${IDENTITY}_Wilson"
IDENTITY_STAGGERED="${IDENTITY}_Staggered"
IDENTITY_KAPPA_LIST="${IDENTITY}_kappaList"
IDENTITY_MASS_LIST="${IDENTITY}_massList"
IDENTITY_PYTHON="${IDENTITY}_Python"
IDENTITY_FITS="${IDENTITY}_Fits"
IDENTITY_JOBS="${IDENTITY}_Jobs"

#Checks on variables and directives
if [ $LOAD_KAPPA_ALIASES = "TRUE" ] &&
       [ ! ${!IDENTITY_WORK:+x} ] ||
       [ ! ${!IDENTITY_WILSON:+x} ] ||
       [ ! ${!IDENTITY_KAPPA_LIST:+x} ]; then printf "\n\e[0;31m Kappa aliases desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1
fi
if [ $LOAD_MASS_ALIASES = "TRUE" ] &&
       [ ! ${!IDENTITY_WORK:+x} ] ||
       [ ! ${!IDENTITY_STAGGERED:+x} ] ||
       [ ! ${!IDENTITY_MASS_LIST:+x} ]; then printf "\n\e[0;31m Mass aliases desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1
fi
if [ $LOAD_PYTHON_ALIASES = "TRUE" ] &&
       [ ! ${!IDENTITY_PYTHON:+x} ]; then printf "\n\e[0;31m Python aliases desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1
fi
if [ $LOAD_FIT_ALIASES = "TRUE" ] &&
       [ ! ${!IDENTITY_FITS:+x} ]; then printf "\n\e[0;31m Fit aliases desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1
fi
if [ $LOAD_JOB_ALIASES = "TRUE" ] &&
       [ ! ${!IDENTITY_WORK:+x} ]; then printf "\n\e[0;31m Job aliases desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1
fi

#============================================================================================================================#

#Aliases to run fit programs
if [ $LOAD_FIT_ALIASES = "TRUE" ]; then
    alias BinderFit='bash ${!IDENTITY_FITS}/muiPiT/fitScripts/BinderFit.sh'
    alias BruteForceFit='bash ${!IDENTITY_FITS}/muiPiT/fitScripts/BruteForceFit.sh'
    alias FilterFitResults='bash ${!IDENTITY_FITS}/muiPiT/fitScripts/FilterFitResults.sh'
    
    function PlotBestFits(){
        gnuplot -e "filenames='$*'" ${!IDENTITY_FITS}/muiPiT/fitScripts/PlotBestFits.plt
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
    function GetReweightingPbpCommand(){
        [ $# -eq 3 ] && local NUM_POINTS=$(bc <<< "($2-$1)/$3+1")
        echo "time PyReweighting --deactivatePlaq --deactivatePoly --activatePbp --deactivateMean --deactivateSusc -za --doNotUseSimulatedPointsAsNewPoints -r $1 $2 -p $NUM_POINTS"
    }
    function GetReweightingPolyImWithZeroMeanCommand(){
        [ $# -eq 3 ] && local NUM_POINTS=$(bc <<< "($2-$1)/$3+1")
        echo "time PyReweighting --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_sq --deactivateMean --deactivateSusc --deactivateSkew -za --doNotUseSimulatedPointsAsNewPoints -r $1 $2 -p $NUM_POINTS"
    }
    function GetFindBetaCPbpCommand(){
        echo "PyFindBetaC --deactivatePlaq --deactivatePoly --activatePbp --deactivateMean --deactivateSusc --deactivateBinder"
    }
    function GetFindBetaCPolySqCommand(){
        echo "PyFindBetaC --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivateMean --deactivateSkew"
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
        local FOLDERS_ARRAY=( $(ls -d */) )
        local NS_FOLDERS_ARRAY=()
        for INDEX in "${!FOLDERS_ARRAY[@]}"; do
            if [[ ${FOLDERS_ARRAY[$INDEX]} =~ ^ns[[:digit:]]+/$ ]]; then
                NS_FOLDERS_ARRAY+=( ${FOLDERS_ARRAY[$INDEX]} )
                unset -v 'FOLDERS_ARRAY[$INDEX]'
            fi
        done
        NS_FOLDERS_ARRAY=( $(echo ${NS_FOLDERS_ARRAY[@]} | grep -o "[[:digit:]]\+" | sort -n | awk '{print "ns"$1}') )
        NS_FOLDERS_ARRAY+=( ${FOLDERS_ARRAY[@]} )
        select FOLDER in ${NS_FOLDERS_ARRAY[@]}; do
            if [ ${FOLDER:+x} ] && [ -d $FOLDER ]; then
                cd $FOLDER
                break
            fi
        done
    }
fi


#Aliases to go to the kappa folders
if [ $LOAD_KAPPA_ALIASES = "TRUE" ]; then
    for KAPPA in ${!IDENTITY_KAPPA_LIST}; do
        NUM_FOLDER=( $(ls /lustre/nyx/lcsc/asciarra/WilsonProject/muiPiT/k$KAPPA/nt6 | grep "^ns[[:digit:]]\+") )
        if [ ${#NUM_FOLDER[@]} -eq 1 ]; then
    	    alias k${KAPPA}="cd /lustre/nyx/lcsc/asciarra/WilsonProject/muiPiT/k$KAPPA/nt6/${NUM_FOLDER[0]}"
        else
    	    alias k${KAPPA}="cd /lustre/nyx/lcsc/asciarra/WilsonProject/muiPiT/k$KAPPA/nt6; PickUpFolder"
        fi
    done && unset -v 'NUM_FOLDER' 'KAPPA'
fi


#Aliases to go to the mass folders
if [ $LOAD_MASS_ALIASES = "TRUE" ]; then
    for MASS in ${!IDENTITY_MASS_LIST}; do
	    NUM_FOLDER=( $(ls /lustre/nyx/lcsc/asciarra/StaggeredNf2Project/muiPiT/mass$MASS/nt6 | grep "^ns[[:digit:]]\+") )
	    if [ ${#NUM_FOLDER[@]} -eq 1 ]; then
	        alias mass${MASS}="cd /lustre/nyx/lcsc/asciarra/StaggeredNf2Project/muiPiT/mass$MASS/nt6/${NUM_FOLDER[0]}"
	    else
	        alias mass${MASS}="cd /lustre/nyx/lcsc/asciarra/StaggeredNf2Project/muiPiT/mass$MASS/nt6; PickUpFolder"
	    fi
    done && unset -v 'NUM_FOLDER' 'MASS'
fi

#============================================================================================================================#

#Aliases to work confortably on jobs

if [ $LOAD_JOB_ALIASES = "TRUE" ]; then
    alias cdw="cd ${!IDENTITY_WORK}" 
    alias JobInfo='${HOME}/Script/MonitorLoeweJobs.sh'
    alias Acceptance="awk '{ sum+=\$11} END {printf \"Accepted %d over %d (%lf%%)\n\", sum, NR, 100*sum/(NR)}'"
    alias LastAcceptance='bash ${HOME}/Script/AcceptanceLastTrajectories.sh'
    alias HandlerJobs='bash ${HOME}/Script/JobScriptAutomation/JobHandler.sh'

    #Function to easy calculate the walltime
    function Walltime(){
        [ $# -ne 2 ] && printf "\n\e[0;31m Call:    \e[1m$FUNCNAME <number_of_trajectory_to_do> <seconds_per_trajectory>\n\n\e[0m" && return
        local NUMBER_TR_TO_DO=$1
        local TIME_TR=$2
        local T=$(( ($NUMBER_TR_TO_DO) * $TIME_TR))
        local days=$(( $T/86400))
        local hours=$(( ($T - $days*86400)/3600 ))
        local minutes=$(( ($T - $days*86400 - $hours*3600)/60 ))
        local seconds=$( echo $T | awk 'END{print $1 % 60}')
        printf "\e[0;32m \n walltime = %d-%02d:%02d:%02d\n\n\e[0m" "${days}" "${hours}" "${minutes}" "${seconds}"
    }

    #Function to delete conf and prng not multiple of X trajectories
    function DeleteConfPrngNotEvery() {
        if [[ ! $1 =~ ^[[:digit:]]+$ ]]; then
	        echo "Invalid frequency or frequency not given as first parameter!"
	        return
        fi
        echo ''
        echo "Actual position: $(pwd)"
        echo -n "All conf.XXXXX and prng.XXXXX with XXXXX not multiple of $1 will be deleted. Proceed (Y/N)? "
        local CONFIRM="";
        while read CONFIRM; do
	        if [ "$CONFIRM" = "Y" ]; then break; elif [ "$CONFIRM" = "N" ]; then return; else  printf "\n\e[0;33m Please enter Y (yes) or N (no): \e[0m"; fi
        done
        
        for BETA in b5.*; do
	        echo $BETA
	        cd $BETA
	        for FILE in conf.????? conf.??????; do
	            NUM=$(grep -o "[[:digit:]]*" <<< $FILE)
                if [ ${NUM:+x} ]; then
                    [ $(awk -v freq="$1" '{print $1%freq}' <<< $NUM) -ne 0 ] && rm -f $FILE ${FILE/conf/prng}
                fi
            done
            cd ..
        done
    }

    #Static function useful later
    function FindLastStandardOutput(){
        if [ -d $1 ]; then
            local FOLDER="$1"
        else
            local SUFFIX=${1##*_}
            if [ $SUFFIX = "fH" ]; then
                local FOLDER=b${1%_*}_thermalizeFromHot
            elif [ $SUFFIX = "fC" ]; then
                local FOLDER=b${1%_*}_thermalizeFromConf
            else
                local FOLDER=b${1%_*}_continueWithNewChain
            fi
        fi
        if [ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ]; then
            local FILE="$(ls $FOLDER/rhmc_ref.*.out | sort -V | tail -n1)"
            FILE=${FILE/$FOLDER\//}
        elif [ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ]; then
            local FILE="$(ls $FOLDER/hmc_ref.*.out | sort -V | tail -n1)"
            FILE=${FILE/$FOLDER\//}
        else
            echo "Neither in Staggered nor in Wilson path!"
        fi
        echo "$FOLDER/$FILE"
    }


    #Function to estimate time per trajectory giving beta as input
    function TimeTr(){
        local PATH_TO_BE_USED=$(FindLastStandardOutput $1)
        printf "\n Calling:\n   ${HOME}/Script/TimeTrajectoryCL2QCD.sh $PATH_TO_BE_USED\n"
        ${HOME}/Script/TimeTrajectoryCL2QCD.sh $PATH_TO_BE_USED
    }

    #Function to show std output/error 
    function ShowStd(){
        if [[ $1 =~ ^b?[[:digit:]][.] ]]; then
            local FILE_NAME=$(FindLastStandardOutput $1)
        elif [[ $1 =~ ^[[:digit:]]+$ ]]; then
            local FILE_NAME="JobScripts/rhmc_ref.$1.out"
        else
            printf "\n\e[0;31m Unknown first parameter!\n\n\e[0m"
        fi
        if [ "$2" = "" ]; then
            less $FILE_NAME
        elif [ "$2" = "-e" ]; then
            less ${FILE_NAME/.out/.err}
        else
            printf "\n\e[0;31m Unknown second parameter!\n\n\e[0m"
        fi
    }

    #Function to eliminate conf.save* and prng.save*
    function rmSave(){
        if [ -d $1 ]; then
            local FOLDER="$1"
        else
            local SUFFIX=${1##*_}
            if [ $SUFFIX = "fH" ]; then
                local FOLDER=b${1%_*}_thermalizeFromHot
            elif [ $SUFFIX = "fC" ]; then
                local FOLDER=b${1%_*}_thermalizeFromConf
            else
                local FOLDER=b${1%_*}_continueWithNewChain
            fi
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
fi

#============================================================================================================================#
#============================================================================================================================#

#Unset user variables
if [ $UNSET_USER_VARIABLES = "TRUE" ]; then
    [ ${!IDENTITY_WORK+x} ] && unset -v $IDENTITY_WORK
    [ ${!IDENTITY_WILSON+x} ] && unset -v $IDENTITY_WILSON
    [ ${!IDENTITY_STAGGERED+x} ] && unset -v $IDENTITY_STAGGERED
    [ ${!IDENTITY_KAPPA_LIST+x} ] && unset -v $IDENTITY_KAPPA_LIST
    [ ${!IDENTITY_MASS_LIST+x} ] && unset -v $IDENTITY_MASS_LIST
    [ ${!IDENTITY_PYTHON+x} ] && unset -v $IDENTITY_PYTHON
    [ ${!IDENTITY_FITS+x} ] && unset -v $IDENTITY_FITS
    [ ${!IDENTITY_JOBS+x} ] && unset -v $IDENTITY_JOBS
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
unset -v IDENTITY_FITS
unset -v IDENTITY_JOBS




