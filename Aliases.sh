#!/bin/bash

function __static__PrintHelp(){
    printf "\e[96m"
    printf '\n'
    printf '  Script to collect useful commands for working more comfortably. Since each user could\n'
    printf '  have different preferences, use the --load* options to decide which aliases to load.\n'
    printf '\n'
    printf "\e[0;92m"
    printf '  Options to load bunches of aliases:\n'
    printf '    --loadGo              ->    Creates aliases to easily move in the tree of data\n'
    printf '    --loadPython          ->    Creates aliases to call python functionalities\n'
    printf '    --loadFit             ->    Creates aliases to call fits functionalities\n'
    printf '    --loadJob             ->    Creates aliases to work with jobs\n'
    printf '    --loadRootHist        ->    Creates alias to access the 3D Root histogram program \e[91m <== BROKEN\e[92m\n'
    printf '    --unsetMyVariables    ->    Unset the variables the user has allocated him/herself\n'
    printf '\n'
    printf "\e[93m"
    printf "  Use the \e[1;4;96mAliasesHelper\e[21;24;93m function to get help about the loaded aliases. You can\n"
    printf "  run it as such or you can specify one or more functions to get help about them only.\n"
    printf '\n'
    printf "\e[96m"
    printf '  NOTE: Each user should define the following variables (NOT here but where it is sourced)\n'
    printf ''
    printf '           [...]_work       -> global path to work directory (scratch on clusters, philconfigs locally)\n'
    printf '           [...]_Wilson     -> local path from work to Wilson simulation folder , i.e. to where the first parameters folder is\n'
    printf '           [...]_Staggered  -> local path from work to Staggered simulation folder, i.e. to where the first parameters folder is\n'
    printf '           [...]_Python     -> global path to Python git, i.e. to ImagMu folder included: "/.../ImagMu"\n'
    printf '\n'
    printf '        where \e[92m[...]\e[96m is the whoami concatenated with the hostname via underscore, e.g. \e[92msmith_cluster1234\e[96m.\n'
    printf '        Please, note that shell variables names can only contain the underscore as symbol and, hence, all other symbols\n'
    printf '        must be replaced by "_". You can use \e[92mdeclare $(whoami)_$(hostname | sed '"'"'s/[^a-zA-Z0-9_]/_/g'"'"')_suffix=...\e[96m to\n'
    printf '        declare variables in your shell configuration file (where suffix completes the variable name). In this way you\n'
    printf '        are maximally versatile. Of course, whoami should not contain symbols, but in case you can act in a similar way.\n'
    printf '        Once (some of) the variables above are defined, then source this script with any desired option.\n'
    printf '\n'
    printf "\e[92m"
    printf '  Variable(s) that the user must provide:\n'
    printf ''
    printf '    --loadGo           requires    [...]_{work,Wilson,Staggered}\n'
    printf '    --loadPython       requires    [...]_Python\n'
    printf '    --loadJob          requires    [...]_work\n'
    printf '    --loadRootHist     requires    [...]_RootHist\n'
    printf '\n'
    printf '  where [...] is the whoami concatenated with hostname.\n'
    printf '\n'
    printf "\e[0m"
}

function AliasesHelper(){
    declare -A functionsHelp groupColors groupedFunctions
    functionsHelp=(
        [$FUNCNAME]='This function. Give usage of available functionality.'
        ["BinderFit"]="Invoke \"${HOME}/Script/FittingUtilities/BinderFitVSbeta.sh\" script."
        ["BruteForceFit"]="Invoke \"${HOME}/Script/FittingUtilities/BruteForceFit.sh\" script."
        ["FilterFitResults"]="Invoke \"${HOME}/Script/FittingUtilities/FilterFitResults.sh\" script."
        ["SetUpForBruteForceFit"]="Invoke \"${HOME}/Script/FittingUtilities/SetUpForBruteForceFit.sh\" script."
        ["SelectBestFits"]="Invoke \"${HOME}/Script/FittingUtilities/FindClosestValue.sh\" script."
        ["ChooseReweightingFolders"]="Invoke \"${HOME}/Script/FittingUtilities/ChooseReweightingFoldersAndFindResolution.sh\" script."
        ["QuantitativeCollapse"]="Invoke \"${HOME}/Script/CollapsePlot/MathematicaQuantitativeCollapse/PerformAnalyticCollapse.sh\" script."
        ["PlotBestFits"]="Correctly invoke the \"${HOME}/Script/PlottingUtilities/PlotBestFits.plt\" script via gnuplot using the given options as filenames."
        ["GetFilteringProcedure"]="Return command to filter the brute force fit results."
        ["GetSelectingBestFitProcedure"]="Return command to smartly invoke the script to select the best fits out of the bunch created via the filtering procedure."
        ["PyAnalysis"]="Run PLASMA in analysis mode"
        ["PyAutocorrelation"]="Run PLASMA in autocorrelation mode"
        ["PyFindBetaC"]="Run PLASMA in find critical beta mode"
        ["PyPlotScaling"]="Run PLASMA in plot scaling mode"
        ["PyReweighting"]="Run PLASMA in reweighting mode"
        ["PySynchronization"]="Run PLASMA in synchronisation mode"
        ["GetSynchronizationCommand"]="Return standard invocation of \"PySynchronization\". Remote host name has to be passed as option."
        ["GetAnalysisPbpCommand"]="Return standard invokation of \"PyAnalysis\" to analise the chiral condensate."
        ["GetAnalysisPolyImWithZeroMeanCommand"]="Return standard invokation of \"PyAnalysis\" to analise the Polyakov loop with zero mean."
        ["GetAnalysisPolySqCommand"]="Return standard invokation of \"PyAnalysis\" to analise the square norm of the Polyakov loop."
        ["GetReweightingPbpCommand"]="Return standard invokation of \"PyReweighting\" to reweight the chiral condensate. It either needs betaMin, betaMax and the resolution in beta or just the latter (in this case betaMin and betaMax are the first and the last line of the file \"betas\")"
        ["GetReweightingPolyImWithZeroMeanCommand"]="Return standard invokation of \"PyReweighting\" to reweight the Polyakov loop with zero mean. It either needs betaMin, betaMax and the resolution in beta or just the latter (in this case betaMin and betaMax are the first and the last line of the file \"betas\")"
        ["GetReweightingPolySqSkewCommand"]="Return standard invokation of \"PyReweighting\" to reweight the square norm of the Polyakov loop. It either needs betaMin, betaMax and the resolution in beta or just the latter (in this case betaMin and betaMax are the first and the last line of the file \"betas\")"
        ["GetFindBetaCPbpCommand"]="Return standard invokation of \"PyFindBetaC\" to extract the critical beta from the chiral condensate."
        ["GetFindBetaCPolySqCommand"]="Return standard invokation of \"PyFindBetaC\" to extract the critical beta from the square norm of the Polyakov loop."
        ["GetPlotScalingPolySqCommand"]="Return standard invokation of \"PyPlotScaling\" to create the scaling plots of the square norm of the Polyakov loop. It needs the ns values as arguments."
        ["GetPlotScalingPbpCommand"]="Return standard invokation of \"PyPlotScaling\" to create the scaling plots of the chiral condensate. It needs the ns values as arguments."
        ["GetPlotScalingPolyImWithZeroMeanCommand"]="Return standard invokation of \"PyPlotScaling\" to create the scaling plots of the Polyakov loop with zero mean. It needs the critical beta as first argument and the ns values as following arguments."
        ["HasFileDifferentNumberOfEntriesPerLine"]="Boolean function. It returns true if the file given as argument has at least two lines with e different number of fields, false otherwise. Space(s) are used as field separator."
        ["CheckNumberOfEntriesPerLine"]="Count the number of fields per line in the given file and make a summary. As second argument the expected number of entries can be specified to colour the summary accordingly. Space(s) are used as field separator."
        ["RemoveLinesWithNumberOfColumnsDifferentFrom"]="Given a number N and a file name as command line options, a backup of the file is created and the lines not with N fields are removed from the original file."
        ["PickUpFolder"]="Given an optional prefix, all folders (matching the given prefix) are listed. The user has to select one to cd into. If the prefix terminates with \"/\" then it is intended as a full folder name (still pattern matching is performed)."
        ['goStaggered']="Move to staggered folder"
        ['goWilson']="Move to Wilson folder"
        ["go"]="Interactive function to move to data folder. It goes either to staggered or to Wilson folders and explores the tree asking to which folder to cd. Parameters different from \"s\" or \"S\" and \"w\" or \"W\" (which can be used to choose between staggered and Wilson, respectively) are interpred as prefix of folder names. If they identify unanbiguous folders at a given step, then such a folder is chosen at that step and such a prefix is not used any more."
        ["cdw"]="Move into the work directory (scratch on clusters, phil-configs locally) -> $(alias cdw)."
        ["JobInfo"]="Invoke \"${HOME}/Script/MonitorSlurmJobs.sh\" script (DEPRECATED, use BaHaMAS if possible)."
        ["Acceptance"]="Calculate the average of the 9th field of a given file (meant to be a Monte Carlo acceptance)."
        ["LastAcceptance"]="Invoke \"${HOME}/Script/AcceptanceLastTrajectories.sh\" script."
        ["FillInMissingLines"]="Invoke \"${HOME}/Script/FillInMissingLinesOutputFile.sh\" script."
        ["ClusterUsage"]="Invoke the \"${HOME}/Script/ClusterUsage.sh\" script with the \"--doNotUpdateFiles\" option."
        ["ReportOnCorrelatorFiles"]="Count number of \"conf.*corr\" files in \"b?.????_s*Chain\" folders and make a report."
        ["ReportOnScaleSettingFiles"]="Count number of \"conf.*.nersc\" and \"flow.conf.*.nersc\" files in \"b?.????_s*Chain\" folders and make a report."
        ["CountJobs"]="Parse submitted jobs using the jobname and counting those with the same calue of the specified fields. Fields are specified as a comma-separated list without spaces, e.g. \"1,2,3\". Several strings can be specified."
        ["OverviewJobs"]="RUNNING and PENDING jobs on a specified partition are counted and a report with the amount of jobs per user is printed."
        ["Walltime"]="Given the number of trajectories to be done and the seconds required to do one trajectory, the total walltime is calculated and printed."
        ["CalculateGapsInTrajectoriesBetweenStoredConfigurations"]="A summary about frequency of stored configurations is constructed, considering the beta folders given as command line arguments."
        ["DeleteConfPrngNotEvery"]="The first argument is mandatory and it has to be an integer which determines which checkpoints will be kept (those whose trajectory number is multiple of the given number). A second integer specifies how many last checkpoints to keep. From the third argument on, beta folder can be specified, otherwise all \"b{5,6}*\" folder are considered."
        ["ListOfTrashFolders"]="Find down in the tree from the invoking position all the \"Trash*\" folders and print their global paths."
        ["ListOfTrashFoldersWithSizes"]="Find down in the tree from the invoking position all the \"Trash*\" folders and print their global paths with their sizes."
        ["SizeOfTrashFolders"]="Find down in the tree from the invoking position all the \"Trash*\" folders and print their total size."
        ["CompleteFolderName"]="Given one or more beta string(s) of the BaHaMAS simulation status output, the folder name(s) is(are) reconstructed."
        ["GetOutputFilePath"]="Given a beta folder (possibly specified as beta string of the BaHaMAS simulation status output), the CL2QCD output filename is returned with the folder in front. The output file is hmc_output or rhmc_output depending if \"[wW]ilson\" or \"[sS]taggered\" is present in the path, respectively."
        ["FindLastStandardOutput"]="Given a beta folder (possibly specified as beta string of the BaHaMAS simulation status output), the last \"?hmc.*[.]out\" file in that folder is found. The \"?\" is empty or it is a \"r\" if \"[wW]ilson\" or \"[sS]taggered\" is present in the path, respectively."
        ["FindMissingTrajectories"]="The \"${EDITOR:-default}\" is opened at the (R)HMC-output-file missing lines waiting for completion. This is done for all the specified folders (possibly specified as beta string of the BaHaMAS simulation status output) and for all the missing line points in the file. The output file is hmc_output or rhmc_output depending if \"[wW]ilson\" or \"[sS]taggered\" is present in the path, respectively."
        ["TimeTr"]="Given a beta folder (possibly specified as beta string of the BaHaMAS simulation status output) and using the time column (10) of the (R)HMC output file, the average time per trajectory is calculated and printed with some typical simulation duration estimates. The output file is hmc_output or rhmc_output depending if \"[wW]ilson\" or \"[sS]taggered\" is present in the path, respectively. Trajectories with 0s as time are not considered in the mean."
        ["ShowStd"]="Given a beta folder (possibly specified as beta string of the BaHaMAS simulation status output), the last CL2QCD standard output file is displayed (it is found using the \"FindLastStandardOutput\" function). If instead a job-ID number is given as first argument the standard output of the jobscript is shown. The jobscript output must be called \"?hmc.<job-ID>.out\" and the folder with jobscripts must be \"Jobscripts\". The \"?\" is empty or it is a \"r\" if \"[wW]ilson\" or \"[sS]taggered\" is present in the path, respectively. If \"-e\" is given as second argument, the same actions are performed for the standard error."
        ["FindHighestDH"]="Given a beta folder (possibly specified as beta string of the BaHaMAS simulation status output), the 30 trajectories with largest DH are printed in order of trajectory number. If an integer N is specified as second argument, the N trajectories with largest DH are considered. The output file is obtained using the \"GetOutputFilePath\" function."
        ["CheckCl2qcdOutput"]="Given a beta folder (possibly specified as beta string of the BaHaMAS simulation status output), the CL2QCD output file is checked using the \"${HOME}/Script/CheckCorrectnessCl2qcdOutputFile.sh\" script. The output file is obtained using the \"GetOutputFilePath\" function."
    )

    groupColors=( ['GENERAL']='\e[39m' ['FIT_ALIASES']='\e[92m' ['PYTHON_ALIASES']='\e[93m' ['JOB_ALIASES']='\e[96m' ['GO_ALIASES']='\e[95m' ['ROOTHIST_ALIASES']='\e[94m' )
    groupedFunctions=(
        ['GENERAL']='AliasesHelper'
        ['FIT_ALIASES']='BinderFit BruteForceFit FilterFitResults SetUpForBruteForceFit SelectBestFits ChooseReweightingFolders QuantitativeCollapse PlotBestFits GetFilteringProcedure GetSelectingBestFitProcedure'
        ['PYTHON_ALIASES']='PyAnalysis PyAutocorrelation PyFindBetaC PyPlotScaling PyReweighting PySynchronization GetSynchronizationCommand GetAnalysisPbpCommand GetAnalysisPolyImWithZeroMeanCommand GetAnalysisPolySqCommand GetReweightingPbpCommand GetReweightingPolyImWithZeroMeanCommand GetReweightingPolySqSkewCommand GetFindBetaCPbpCommand GetFindBetaCPolySqCommand GetPlotScalingPolySqCommand GetPlotScalingPbpCommand GetPlotScalingPolyImWithZeroMeanCommand HasFileDifferentNumberOfEntriesPerLine CheckNumberOfEntriesPerLine RemoveLinesWithNumberOfColumnsDifferentFrom'
        ['GO_ALIASES']='PickUpFolder goStaggered goWilson go'
        ['JOB_ALIASES']='cdw JobInfo Acceptance LastAcceptance FillInMissingLines ClusterUsage ReportOnCorrelatorFiles ReportOnScaleSettingFiles CountJobs OverviewJobs Walltime CalculateGapsInTrajectoriesBetweenStoredConfigurations DeleteConfPrngNotEvery ListOfTrashFolders ListOfTrashFoldersWithSizes SizeOfTrashFolders CompleteFolderName GetOutputFilePath FindLastStandardOutput FindMissingTrajectories TimeTr ShowStd FindHighestDH CheckCl2qcdOutput'
        ['ROOTHIST_ALIASES']='CreateRootHistograms'
    )

    local availableFunctions index
    (
		#Start a subshell in order to source "locally" and unalias locally
        source ${HOME}/Script/UtilityFunctions.sh
        #Find all function or aliases defined in this file (very ugly but the only way AFAIK)
        if [ "$(type -t grep)" = 'alias' ]; then
            unalias grep #if grep was aliased to always report line number
        fi
        availableFunctions=( $(grep -E '^[[:space:]]*([[:alnum:]_]+[[:space:]]*\(\)|function[[:space:]]+[[:alnum:]_]+|alias[[:space:]]+[[:alnum:]_]+=)' "${BASH_SOURCE[0]}" | sed -e 's/\(()\|=\).*//g' -e 's/function \(.*\)/\1/' -e 's/alias \(.*\)/\1/') )
        for index in ${!availableFunctions[@]}; do
            if [[ ${availableFunctions[$index]} =~ ^__static__ ]]; then
                unset -v 'availableFunctions[$index]'
            fi
        done
        availableFunctions=( ${availableFunctions[@]} ) # Make array not sparse to use continuous index later

        if [ $# -eq 0 ]; then # Interactive selecion of function
            printf "\n Here a list of available function. Those with the number \e[4munderlined\e[24m have been loaded.\n\n"
            printf " Use the options ${groupColors[FIT_ALIASES]}--loadFit ${groupColors[PYTHON_ALIASES]}--loadPython ${groupColors[JOB_ALIASES]}--loadJob ${groupColors[GO_ALIASES]}--loadMass|--loadKappa ${groupColors[ROOTHIST_ALIASES]}--loadRootHist\e[0m to load groups of aliases.\n\n"
            local stringToBePrint tmpString colorString
            tmpString=''
            for index in ${!availableFunctions[@]}; do
                if ElementInArray ${availableFunctions[$index]} ${DEFINED_FUNCTIONS[@]}; then
                    tmpString+="\e[4m"
                else
                    tmpString+="\e[0m"
                fi
                colorString='\e[39m' # default
                for group in ${!groupedFunctions[@]}; do
                    if [ $(grep -c "${availableFunctions[$index]}" <<< "${groupedFunctions[$group]}") -ne 0 ]; then
                        colorString="${groupColors[$group]}"
                        break
                    fi
                done
                tmpString+="$colorString$index\e[24m)_${availableFunctions[$index]}\e[0m,"
            done
            local nCols=1
            while :
            do
                #Use the comma to split every nCols field and then replace spaces by \n and finally the _ by a space and | by spaces
                stringToBePrint="$(echo "$tmpString" | xargs -d"," -n$nCols | tr ' ' '\t' | tr '_' ' ')"
                if [ $(awk '{l=length($0); if(l>max){max=l}}END{print max}' <<< "${stringToBePrint}") -lt $((COLUMNS*7/10)) ]; then
                    (( nCols++ ))
                else
                    break
                fi
            done
            if [ "$stringToBePrint" = '' ]; then
                printf "\n \e[91mThe terminal is too small to contain even the name of a single function! Use larger terminal!  Unable to help!\e[0m\n\n"
                return -1
            fi
            printf "${stringToBePrint}\n" | column -t | sed 's/^/     /'
            printf '\n For which functions would you like to get help? Use a comma separated list of entries or ranges (e.g. \e[93m1,4-6,16\e[0m): \e[s'
            local selectedIndices
            while read selectedIndices; do #Here selectedIndices is a variable
                [ "${selectedIndices}" = '' ] && printf "\e[u\e[1A" && continue
                if [[ ! ${selectedIndices} =~ ^[0-9]+([,\-][0-9]+)*$ ]]; then
                    printf "\n\e[1;91m Invalid input!\e[21;96m Please, insert the function numbers: \e[0m\e[s"; continue
                fi
                #Here selectedIndices becomes an array!
                selectedIndices=( $(awk 'BEGIN{RS=","}/\-/{split($0, res, "-"); if(res[1]<=res[2]){for(i=res[1]; i<=res[2]; i++){printf "%d\n", i}}else{for(i=res[1]; i>=res[2]; i--){printf "%d\n", i}}; next}{printf "%d\n", $0}' <<< "${selectedIndices}") )
                break
            done
            local longestLabel=0
            for index in ${selectedIndices[@]}; do
                [ $longestLabel -lt ${#availableFunctions[$index]} ] && longestLabel=${#availableFunctions[$index]}
            done
            echo ''
            for index in ${selectedIndices[@]}; do
                printf " \e[1;93m%${longestLabel}s\e[24m:\e[21;36m " "${availableFunctions[$index]}"
                if ElementInArray ${availableFunctions[$index]} ${!functionsHelp[@]}; then
                    echo ${functionsHelp["${availableFunctions[$index]}"]} | fold -s -w $((COLUMNS*7/10)) | awk -v nSpc=${longestLabel} 'BEGIN{spaces=sprintf("%*s", nSpc, "")} NR==1{print $0} NR>1{print spaces "   " $0}' # https://stackoverflow.com/a/25408074
                else
                    echo "Help not available!"
                fi
                printf '\n\e[0m'
            done
        else
            local func longestLabel=0
            for func in $@; do
                [ $longestLabel -lt ${#func} ] && longestLabel=${#func}
            done
            echo ''
            for func in $@; do
                printf " \e[1;93m%${longestLabel}s\e[24m:\e[21;36m " "${func}"
                if ElementInArray ${func} ${!functionsHelp[@]}; then
                    echo ${functionsHelp["${func}"]} | fold -s -w $((COLUMNS*5/10)) | awk -v nSpc=${longestLabel} 'BEGIN{spaces=sprintf("%*s", nSpc, "")} NR==1{print $0} NR>1{print spaces "   " $0}' # https://stackoverflow.com/a/25408074
                else
                    echo "Help not available!"
                fi
                printf "\n\e[0m"
            done
        fi
    )
    return
}

#============================================================================================================================#
#============================================================================================================================#

#Variable for setup which alias to source
LOAD_GO_ALIASES="FALSE"
LOAD_PYTHON_ALIASES="FALSE"
LOAD_FIT_ALIASES="FALSE"
LOAD_JOB_ALIASES="FALSE"
LOAD_ROOTHIST_ALIASES="FALSE"
UNSET_USER_VARIABLES="FALSE"

#Parsing the command line argument
while [ "$1" != "" ]; do
    case $1 in
      -h | --help )
          __static__PrintHelp
          if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
              unset -v 'LOAD_GO_ALIASES' 'LOAD_PYTHON_ALIASES' 'LOAD_FIT_ALIASES' 'LOAD_JOB_ALIASES' 'LOAD_ROOTHIST_ALIASES' 'UNSET_USER_VARIABLES'
              unset -f __static__PrintHelp
              return # Script was sourced!
          else
              exit   # Script was run!
          fi
          shift ;;
      --loadGo )              LOAD_GO_ALIASES="TRUE"; shift ;;
      --loadPython )          LOAD_PYTHON_ALIASES="TRUE"; shift ;;
      --loadFit )             LOAD_FIT_ALIASES="TRUE"; shift ;;
      --loadJob )             LOAD_JOB_ALIASES="TRUE"; shift ;;
      --loadRootHist )        LOAD_ROOTHIST_ALIASES="TRUE"; shift ;;
      --unsetMyVariables )    UNSET_USER_VARIABLES="TRUE"; shift ;;
      * ) printf "\n\e[91mError parsing the options! Aborting...\n\n\e[0m" ; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1 ;;
    esac
done

#If the script is executed, exit
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit

#Variables for later indirect reference 
IDENTITY="$(whoami | sed 's/[^a-zA-Z0-9_]/_/g')_$(hostname | sed 's/[^a-zA-Z0-9_]/_/g')"
IDENTITY_WORK="${IDENTITY}_work"
IDENTITY_WILSON="${IDENTITY}_Wilson"
IDENTITY_STAGGERED="${IDENTITY}_Staggered"
IDENTITY_PYTHON="${IDENTITY}_Python"
IDENTITY_JOBS="${IDENTITY}_Jobs"
IDENTITY_ROOTHIST="${IDENTITY}_RootHist"

#Auxiliary variables
DEFINED_FUNCTIONS=( 'AliasesHelper' ) # This is always defined, the others depend on loading settings

#Checks on variables and directives
if [ $LOAD_GO_ALIASES = "TRUE" ] && {
       [ ! ${!IDENTITY_WORK:+x} ] ||
       [ ! ${!IDENTITY_STAGGERED:+x} ] ||
       [ ! ${!IDENTITY_WILSON:+x} ]; }; then printf "\n\e[91m Mass aliases desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1
fi
if [ $LOAD_PYTHON_ALIASES = "TRUE" ] &&
       [ ! ${!IDENTITY_PYTHON:+x} ]; then printf "\n\e[91m Python aliases desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1
fi
if [ $LOAD_JOB_ALIASES = "TRUE" ] &&
       [ ! ${!IDENTITY_WORK:+x} ]; then printf "\n\e[91m Job aliases desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1
fi
if [ $LOAD_ROOTHIST_ALIASES = "TRUE" ] && 
       [ ! ${!IDENTITY_ROOTHIST:+x} ]; then printf "\n\e[91m Root 3D histogram program alias desired, but missing information! No alias will be created...\n\n\e[0m"; [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return || exit -1 
fi

#============================================================================================================================#

#Aliases to run fit programs
if [ $LOAD_FIT_ALIASES = "TRUE" ]; then

    DEFINED_FUNCTIONS+=( 'BinderFit' )
    function BinderFit(){
        ${HOME}/Script/FittingUtilities/BinderFitVSbeta.sh "$@"
    }

    DEFINED_FUNCTIONS+=( 'BruteForceFit' )
    function BruteForceFit(){
        ${HOME}/Script/FittingUtilities/BruteForceFit.sh "$@"
    }

    DEFINED_FUNCTIONS+=( 'FilterFitResults' )
    function FilterFitResults(){
        ${HOME}/Script/FittingUtilities/FilterFitResults.sh "$@"
    }

    DEFINED_FUNCTIONS+=( 'SetUpForBruteForceFit' )
    function SetUpForBruteForceFit(){
        ${HOME}/Script/FittingUtilities/SetUpForBruteForceFit.sh "$@"
    }

    DEFINED_FUNCTIONS+=( 'SelectBestFits' )
    function SelectBestFits(){
        ${HOME}/Script/FittingUtilities/FindClosestValue.sh "$@"
    }

    DEFINED_FUNCTIONS+=( 'ChooseReweightingFolders' )
    function ChooseReweightingFolders(){
        ${HOME}/Script/FittingUtilities/ChooseReweightingFoldersAndFindResolution.sh "$@"
    }

    DEFINED_FUNCTIONS+=( 'QuantitativeCollapse' )
    function QuantitativeCollapse(){  #TODO: Put this function somewhere else, it is not about fit
        ${HOME}/Script/CollapsePlot/MathematicaQuantitativeCollapse/PerformAnalyticCollapse.sh "$@"
    }

    DEFINED_FUNCTIONS+=( 'PlotBestFits' )
    function PlotBestFits(){
        gnuplot -e "filenames='$*'" ${HOME}/Script/PlottingUtilities/PlotBestFits.plt
    }

    DEFINED_FUNCTIONS+=( 'GetFilteringProcedure' )
    function GetFilteringProcedure(){
        echo "FilterFitResults -f FitByBruteForce.dat -o -p a1 100 | FilterFitResults -p chi2 1 | FilterFitResults -p MinOv% g80 > FilteredResults_a1_100_chi2_1_MinOv%_g80"
    }

    DEFINED_FUNCTIONS+=( 'GetSelectingBestFitProcedure' )
    function GetSelectingBestFitProcedure(){
        echo 'SelectBestFits <COMPLETE_WITH_OPTIONS> | awk '"'"'{ print length, $0 }'"'"' | sort -n -s | cut -d" " -f2-'
    }

fi

#============================================================================================================================#

#Aliases to work with the python code analysis
if [ $LOAD_PYTHON_ALIASES = "TRUE" ]; then

    #alias PLASMA="python ${!IDENTITY_PYTHON}/PLASMA.py"

    alias PyAutocorrelation="python ${!IDENTITY_PYTHON}/ImagMuAutocorrelationAnalysis.py"
    alias PyAnalysis="python ${!IDENTITY_PYTHON}/ImagMuAnalysis.py"
    alias PySynchronization="python ${!IDENTITY_PYTHON}/ImagMuSync.py"
    alias PyReweighting="python ${!IDENTITY_PYTHON}/ImagMuReweighting.py"
    alias PyFindBetaC="python ${!IDENTITY_PYTHON}/ImagMuFindBetaC.py"
    alias PyPlotScaling="python ${!IDENTITY_PYTHON}/ImagMuPlotScaling.py"

    DEFINED_FUNCTIONS+=( 'GetSynchronizationCommand' )
    function GetSynchronizationCommand(){
        echo "PySynchronization --betasFile=betasSync --remote=$1"
    }

    DEFINED_FUNCTIONS+=( 'GetAnalysisPbpCommand' )
    function GetAnalysisPbpCommand(){
        echo "PyAnalysis --deactivatePlaq --deactivatePoly --activatePbp --inversionsPerConfig 8"
    }

    DEFINED_FUNCTIONS+=( 'GetAnalysisPolyImWithZeroMeanCommand' )
    function GetAnalysisPolyImWithZeroMeanCommand(){
        echo "PyAnalysis --analyzeWithJackknife --analyzeSingleChains --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_sq"
    }

    DEFINED_FUNCTIONS+=( 'GetAnalysisPolySqCommand' )
    function GetAnalysisPolySqCommand(){
        echo "PyAnalysis --analyzeWithJackknife --analyzeSingleChains --deactivatePlaq --deactivatePoly_re --deactivatePoly_im_withZeroMean --deactivatePoly_im --deactivatePoly_im_abs --deactivateSusc"
    }

    function __static__DefineBetaMinMaxResAndCheck(){
        if [ $# -eq 1 ]; then
            BETA_MIN=$(head -n1 betas | cut -f1)
            BETA_MAX=$(tail -n1 betas | cut -f1)
            RESOLUTION=$1
        elif [ $# -eq 3 ]; then
            BETA_MIN=$1
            BETA_MAX=$2
            RESOLUTION=$3
        else
            printf "\n\e[91m One or three arguments needed to reweight!\e[0m\n\n" 1>&2
            return 1
        fi
        if [[ ! $BETA_MIN =~ [0-9][.][0-9]+ ]] || [[ ! $BETA_MAX =~ [0-9][.][0-9]+ ]]; then 
            printf "\n\e[91m Wrong format of beta min and beta max!\e[0m\n\n" 1>&2
            return 1
        fi
        NUM_POINTS=$(bc <<< "($BETA_MAX-$BETA_MIN)/$RESOLUTION+1")
        return 0
    }

    DEFINED_FUNCTIONS+=( 'GetReweightingPbpCommand' )
    function GetReweightingPbpCommand(){
        local BETA_MIN BETA_MAX RESOLUTION NUM_POINTS
        __static__DefineBetaMinMaxResAndCheck "$@" || return
        echo -n '[ $(ls Nf?_mui*_nt?_ns??_reweighting 2>/dev/null | wc -l) -eq 0 ]'
        echo -n ' && [ $(ls -d -1 Nf?_mui*_nt?_ns??_reweighting_pbp/ | wc -l) -eq 0 ]'
        echo -n " && time PyReweighting --deactivatePlaq --deactivatePoly --activatePbp --inversionsPerConfig 8 --deactivateMean --deactivateSusc --doNotUseSimulatedPointsAsNewPoints -r $BETA_MIN $BETA_MAX -p $NUM_POINTS"
        echo -n ' && [ $(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/ | wc -l) -eq 1 ]'
        echo -n ' && FOLDER="$(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/)"'
        echo -n ' && mv ${FOLDER%?} ${FOLDER%?}_pbp'
        echo    ' && unset -v '"'FOLDER'"
    }

    DEFINED_FUNCTIONS+=( 'GetReweightingPolyImWithZeroMeanCommand' )
    function GetReweightingPolyImWithZeroMeanCommand(){
        local BETA_MIN BETA_MAX RESOLUTION NUM_POINTS
        __static__DefineBetaMinMaxResAndCheck "$@" || return
        echo -n '[ $(ls Nf?_mui*_nt?_ns??_reweighting 2>/dev/null | wc -l) -eq 0 ]'
        echo -n ' && time PyReweighting --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_sq --deactivateMean --deactivateSusc --deactivateSkew --printEstimatorsToFile'
        echo -n " --doNotUseSimulatedPointsAsNewPoints -r $BETA_MIN $BETA_MAX -p $NUM_POINTS"
        echo -n ' && [ $(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/ | wc -l) -eq 1 ]'
        echo -n ' && FOLDER="$(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/)"'
        echo -n ' && mv ${FOLDER%?} ${FOLDER%?}_dBeta'$RESOLUTION
        echo    ' && unset -v '"'FOLDER'"
    }

    DEFINED_FUNCTIONS+=( 'GetReweightingPolySqSkewCommand' )
    function GetReweightingPolySqSkewCommand(){
        local BETA_MIN BETA_MAX RESOLUTION NUM_POINTS
        __static__DefineBetaMinMaxResAndCheck "$@" || return
        echo -n '[ $(ls Nf?_mui*_nt?_ns??_reweighting 2>/dev/null | wc -l) -eq 0 ]'
        echo -n ' && time PyReweighting --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_im_withZeroMean --deactivateMean --deactivateSusc'
        echo -n " --doNotUseSimulatedPointsAsNewPoints -r $BETA_MIN $BETA_MAX -p $NUM_POINTS"
        echo -n ' && [ $(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/ | wc -l) -eq 1 ]'
        echo -n ' && FOLDER="$(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/)"'
        echo -n ' && mv ${FOLDER%?} ${FOLDER%?}_poly_sq'
        echo    ' && unset -v '"'FOLDER'"
    }

    DEFINED_FUNCTIONS+=( 'GetFindBetaCPbpCommand' )
    function GetFindBetaCPbpCommand(){
        echo "PyFindBetaC --deactivatePlaq --deactivatePoly --activatePbp --deactivateMean --deactivateSusc --deactivateBinder"
    }

    DEFINED_FUNCTIONS+=( 'GetFindBetaCPolySqCommand' )
    function GetFindBetaCPolySqCommand(){
        echo "PyFindBetaC --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_withZeroMean --deactivatePoly_im_abs --deactivateMean --deactivateSusc --doNotExtractFromRawData"
    }

    DEFINED_FUNCTIONS+=( 'GetPlotScalingPolySqCommand' )
    function GetPlotScalingPolySqCommand(){
        echo "PyPlotScaling --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_im_withZeroMean --nsArray $@ --doNotPlotRawData --doNotMakeCombinedPlots --deactivateMean --deactivateSkew --deactivateBinder"
    }

    DEFINED_FUNCTIONS+=( 'GetPlotScalingPbpCommand' )
    function GetPlotScalingPbpCommand(){
        echo "PyPlotScaling --deactivatePlaq --deactivatePoly --activatePbp --nsArray $@ --doNotPlotRawData --doNotMakeCombinedPlots --deactivateMean --deactivateSusc"
    }

    DEFINED_FUNCTIONS+=( 'GetPlotScalingPolyImWithZeroMeanCommand' )
    function GetPlotScalingPolyImWithZeroMeanCommand(){
        local BETAC="$1"
        shift
        echo "PyPlotScaling --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_sq --nsArray $@ --doNotPlotRawData --deactivateMean --deactivateSusc --deactivateSkew --betaCForCollapsePlots $BETAC"
    }

    DEFINED_FUNCTIONS+=( 'HasFileDifferentNumberOfEntriesPerLine' )
    function HasFileDifferentNumberOfEntriesPerLine(){
        local filename
        filename="$1"
        if [ $(awk '{print NF}' "$filename" | sort | uniq | wc -l) -eq 1 ]; then
            return 1
        else
            return 0
        fi
    }

    DEFINED_FUNCTIONS+=( 'CheckNumberOfEntriesPerLine' )
    function CheckNumberOfEntriesPerLine(){
        local filename expectedEntries frequencyNumberOfEntries pair numberOfEntries
        filename="$1"; expectedEntries="$2"
        frequencyNumberOfEntries=()
        while read pair; do
            frequencyNumberOfEntries[$(awk '{print $2}' <<< "$pair")]=$(awk '{print $1}' <<< "$pair")
        done < <(awk '{print NF}' $filename | sort | uniq -c)
        echo ''
        for numberOfEntries in "${!frequencyNumberOfEntries[@]}"; do
            if [[ $expectedEntries =~ ^[0-9]+$ ]]; then
                if [ $numberOfEntries -eq $expectedEntries ]; then
                    printf "\e[92m"
                else
                    printf "\e[93m"
                fi
            fi
            printf " Found  %2d  fields on %6d lines\n\e[0m" "$numberOfEntries" "${frequencyNumberOfEntries[$numberOfEntries]}"
        done
        echo ''
    }

    DEFINED_FUNCTIONS+=( 'RemoveLinesWithNumberOfColumnsDifferentFrom' )
    function RemoveLinesWithNumberOfColumnsDifferentFrom(){
        local filename expectedEntries
        filename="$2"; expectedEntries="$1"
        [[ ! $expectedEntries =~ ^[0-9]+$ ]] && printf "\e[91m\n Number of expected entries wrongly specified!\e[0m\n\n" 1>&2 && return
        [ ! -f "${filename}" ] && printf "\e[91m\n File \"${filename}\" not found!\e[0m\n\n" 1>&2 && return
        [ -f "${filename}_original" ] && printf "\e[91m\n File \"${filename}_original\" already existing!\e[0m\n\n" 1>&2 && return
        mv -i "$filename" "${filename}_original"
        awk -v "numberToMatch=$expectedEntries" 'NF==numberToMatch{print $0}' "${filename}_original" > "$filename"
    }

fi

#============================================================================================================================#

#Alias for choosing a folder where we are (displaying first ns[[:digit:]] folders sorted numerically)
if [ $LOAD_GO_ALIASES = "TRUE" ]; then

    DEFINED_FUNCTIONS+=( 'PickUpFolder' )
    function PickUpFolder(){
        local FOLDERS_ARRAY actualPosition
        actualPosition=$(pwd)
        if [[ $1 =~ /$ ]]; then
            FOLDERS_ARRAY=( $(ls -d ${1} 2>>/dev/null) )
        else
            FOLDERS_ARRAY=( $(ls -d ${1}*/ 2>>/dev/null) )
        fi
        if [ ${#FOLDERS_ARRAY[@]} -eq 0 ]; then
            return -1
        fi
        local ORDERED_FOLDERS_ARRAY=()
        for INDEX in "${!FOLDERS_ARRAY[@]}"; do
            if [[ ${FOLDERS_ARRAY[$INDEX]} =~ ^n[ts][[:digit:]]+/$ ]]; then
                ORDERED_FOLDERS_ARRAY+=( ${FOLDERS_ARRAY[$INDEX]} )
                unset -v 'FOLDERS_ARRAY[$INDEX]'
            fi
        done
        local OLD_IFS=$IFS  # save the field separator
        IFS=$'\n'           # new field separator, the end of line
        ORDERED_FOLDERS_ARRAY=( $(sort -V <<< "${ORDERED_FOLDERS_ARRAY[*]}") )
        IFS=$OLD_IFS        # restore default field separator
        ORDERED_FOLDERS_ARRAY+=( ${FOLDERS_ARRAY[@]} )
        if [ ${#ORDERED_FOLDERS_ARRAY[@]} -eq 1 ]; then
            cd ${ORDERED_FOLDERS_ARRAY[0]}
            echo
        else
            printf "\n\e[96mActual position: \e[1m$(pwd)\n\e[0m"
            if [ "${FUNCNAME[1]}" = go ]; then # Invoking funtion was go
                PS3='Please enter your choice ("q" to abort and go back to initial position, "s" to stop here): '
            else
                PS3='#?'
            fi
            local FOLDER
            select FOLDER in ${ORDERED_FOLDERS_ARRAY[@]%?}; do
                if [ "${REPLY}" = 'q' ]; then
                    echo; return 1
                elif [ "${REPLY}" = 's' ]; then
                    echo; return 2
                elif [ ${FOLDER:+x} ] && [ -d $FOLDER ]; then
                    cd $FOLDER
                    echo; break
                fi
            done
        fi
        return 0
    }

    alias goStaggered="cd ${!IDENTITY_WORK}${!IDENTITY_STAGGERED}"
    alias goWilson="cd ${!IDENTITY_WORK}${!IDENTITY_WILSON}"

    function __static__GiveWarningIfUnusedParameters(){
        if [ ${#givenParameters[@]} -gt 0 ]; then
            printf "\e[93m \e[1;4mWARNING\e[24m:\e[21m Some given parameters were not used: \e[95m%s\n\n\e[0m"  "${givenParameters[*]}"
        fi
    }

    DEFINED_FUNCTIONS+=( 'go' )
    function go(){
        printf "\e[92m\nInitial position: \e[1m$(pwd)\n\e[0m"
        local initialPosition givenParameters index availableFolders
        initialPosition=$(pwd); givenParameters=( "$@" )
        for index in ${!givenParameters[@]}; do
            if [[ ${givenParameters[$index]} =~ ^[sS]$ ]]; then
                eval goStaggered; unset -v 'givenParameters[$index]'; break #https://stackoverflow.com/a/30993227
            elif [[ ${givenParameters[$index]} =~ ^[wW]$ ]]; then
                eval goWilson; unset -v 'givenParameters[$index]'; break #https://stackoverflow.com/a/30993227
            fi
        done
        if [ $# -eq ${#givenParameters[@]} ]; then
            local FORMULATION
            PS3='Please enter your choice: '
            select FORMULATION in "Staggered" "Wilson"; do
                if [ "${FORMULATION}" =  "Staggered" ]; then
                    eval goStaggered; break #https://stackoverflow.com/a/30993227
                elif [ "${FORMULATION}" =  "Wilson" ]; then
                    eval goWilson; break #https://stackoverflow.com/a/30993227
                fi
            done
        fi
        givenParameters=( "${givenParameters[@]}" ) #Make array not sparse
        while [ ${#givenParameters[@]} -gt 0 ] || [ $(ls -d !(b*|JobScripts)/ 2>>/dev/null | wc -l) -gt 0 ]; do
            if [ $(ls -d !(b*)/ 2>>/dev/null | wc -l) -eq 0 ]; then
                if [ ${#givenParameters[@]} -gt 0 ]; then
                    printf "\e[93m\n No sub-folders in the present directory, while ${#givenParameters[@]} given parameter(s) where unused (${givenParameters[@]}).\n\n\e[0m"
                fi
                return
            fi
            for index in ${!givenParameters[@]}; do
                PickUpFolder ${givenParameters[$index]}
                case $? in
                    0)
                        printf "\e[1A" #Move one line up to avoid too many blank lines
                        unset -v 'givenParameters[$index]'
                        givenParameters=( "${givenParameters[@]}" ) #Make array not sparse
                        continue 2
                        ;;
                    1)
                        cd "$initialPosition"
                        __static__GiveWarningIfUnusedParameters; return 1
                        ;;
                    2)
                        __static__GiveWarningIfUnusedParameters; return 2
                        ;;
                esac
            done
            PickUpFolder '!(b*|JobScripts)/'
            case $? in
                1)
                    cd "$initialPosition"
                    __static__GiveWarningIfUnusedParameters; return 1
                    ;;
                2)
                    __static__GiveWarningIfUnusedParameters; return 2
                    ;;
                0)
                    printf "\e[1A"
                    ;;
                *)
                    ;;
            esac
        done
        echo
        return 0
    }

fi

#============================================================================================================================#

#Aliases to work confortably on jobs
if [ $LOAD_JOB_ALIASES = "TRUE" ]; then
    
    DEFINED_FUNCTIONS+=( 'cdw' )
    alias cdw="cd ${!IDENTITY_WORK}"

    DEFINED_FUNCTIONS+=( 'JobInfo' )
    function JobInfo(){
        ${HOME}/Script/MonitorSlurmJobs.sh "$@"
    }

    DEFINED_FUNCTIONS+=( 'Acceptance' )
    function Acceptance(){
        awk '{ sum+=\$9} END {printf \"Accepted %d over %d (%lf%%)\n\", sum, NR, 100*sum/(NR)}' "$1"
    }

    DEFINED_FUNCTIONS+=( 'LastAcceptance' )
    function LastAcceptance(){
        ${HOME}/Script/AcceptanceLastTrajectories.sh "$@"
    }

    DEFINED_FUNCTIONS+=( 'FillInMissingLines' )
    function FillInMissingLines(){
        ${HOME}/Script/FillInMissingLinesOutputFile.sh "$@"
    }

    DEFINED_FUNCTIONS+=( 'ClusterUsage' )
    function ClusterUsage(){
        ${HOME}/Script/ClusterUsage.sh --doNotUpdateFiles
    }

    DEFINED_FUNCTIONS+=( 'ReportOnCorrelatorFiles' )
    function ReportOnCorrelatorFiles(){
        echo
        for b in b?.????_s*Chain; do
            printf "%+38s: %3d correlator files\n" $b $(ls $b/conf.*corr 2>>/dev/null| wc -l)
        done && unset -v 'b'
        echo
    }

    DEFINED_FUNCTIONS+=( 'ReportOnScaleSettingFiles' )
    function ReportOnScaleSettingFiles(){
        echo
        for b in b?.????_s*Chain; do
            printf "%+38s: %3d nersc confs, %3d flow files\n" $b $(ls $b/conf.*.nersc 2>>/dev/null| wc -l) $(ls $b/flow.conf.*.nersc 2>>/dev/null| wc -l)
        done && unset -v 'b'
        echo
    }

    DEFINED_FUNCTIONS+=( 'CountJobs' )
    function CountJobs(){
        if [ $# -eq 0 ]; then
            printf "\e[0;91m \n Number of desired chunck of jobname to be used to count jobs needed as argument (e.g. 1,2,3)!\n\n\e[0m" 1>&2
            return
        else
            for COLUMNS in $@; do
                if [[ ! ${COLUMNS} =~ ^[1-9][0-9]*(,[1-9][0-9]*)*$ ]]; then
                    printf "\e[0;91m \n Fields specification \"${COLUMNS}\" is invalid! Use a comma-separated list without spaces, e.g. \"1,2,3\".\n\n\e[0m"
                else
                    echo
                    squeue -u $(whoami) -h -t RUNNING,PENDING --format '%j' | cut -d'_' -f$COLUMNS | sort | uniq -c | awk '{sum+=$1; print $0} END{printf "\n Total number of jobs (RUNNING or PENDING): %d\n\n", sum}'
                fi
            done && unset -v 'COLUMNS'
        fi
    }

    DEFINED_FUNCTIONS+=( 'OverviewJobs' )
    function OverviewJobs(){
        if [ $# -ne 1 ]; then
            printf "\e[0;91m \n Only the name of a cluster partition is needed as argument!\n\n\e[0m" 1>&2
            return
        else
            if [ $(sinfo -h --format "%R" | grep -c "$1") -eq 0 ]; then
                printf "\e[91m \n Partition \"$1\" seems not to be existing!\n\n\e[0m"
            else
                echo
                for f in RUNNING PENDING; do
                    echo "${f}:"
                    squeue -h -p $1 -t $f | awk '{print $4}' | sort | uniq -c
                    echo
                done && unset -v 'f'
            fi
        fi
    }

    DEFINED_FUNCTIONS+=( 'Walltime' )
    function Walltime(){
        if [ $# -ne 2 ] || [[ ! $1 =~ ^[0-9]+$ ]] || [[ ! $2 =~ ^[0-9]+$ ]]; then
            printf "\n\e[0;91m Call:  \e[1m$FUNCNAME <number_of_trajectory_to_do> <seconds_per_trajectory>\n\n\e[0m" 1>&2 && return
        fi
        local NUMBER_TR_TO_DO=$(bc -l <<< "$1")
        local TIME_TR="$2"
        local T=$(bc -l <<< "$NUMBER_TR_TO_DO * $TIME_TR" )
        local days=$(bc -l <<< "$T/86400" | awk '{printf "%f", $0}')
        local hours=$(bc -l <<< "($T - ${days%.*}*86400)/3600" | awk '{printf "%f", $0}' )
        local minutes=$(bc -l <<< "($T - ${days%.*}*86400 - ${hours%.*}*3600)/60" | awk '{printf "%f", $0}')
        local seconds=$(awk 'END{print int($1) % 60}' <<< "$T")
        printf "\e[0;32m \n walltime = %d-%02d:%02d:%02d\n\n\e[0m" "${days%.*}" "${hours%.*}" "${minutes%.*}" "${seconds}"
    }

    DEFINED_FUNCTIONS+=( 'CalculateGapsInTrajectoriesBetweenStoredConfigurations' )
    function CalculateGapsInTrajectoriesBetweenStoredConfigurations(){
        local BETA_ARRAY=( $@ )
        for INDEX in ${!BETA_ARRAY[@]}; do [ ! -d ${BETA_ARRAY[$INDEX]} ] && unset -v "BETA_ARRAY[$INDEX]"; done && unset -v 'INDEX'
        local LONGEST_BETA_STRING=$(tr ' ' '\n' <<< "${BETA_ARRAY[@]}" | awk '{print length}' | sort -n | tail -n1)
        printf "\n"; printf "%0.s " $(seq 1 $LONGEST_BETA_STRING); printf "      \e[1;38;5;129mGap [nr. of times]\n"
        for BETA in ${BETA_ARRAY[@]}; do
            printf "\n  \e[38;5;129m\e[1m%${LONGEST_BETA_STRING}s\e[0m\e[38;5;199m" "$BETA"
            ls $BETA | grep "^conf.[[:digit:]]\+" | grep -o "[[:digit:]]\+" | sort -n | \
                awk 'BEGIN{printf "    "}NR==1{tr=$1}NR>1{countGaps[$1-tr]++; tr=$1}END{for(i in countGaps){printf "%d [%d]   ", i, countGaps[i]}; printf"\n"}'
        done && unset -v 'BETA'
        echo ''
    }

    DEFINED_FUNCTIONS+=( 'DeleteConfPrngNotEvery' )
    function DeleteConfPrngNotEvery() {
		local REMAINING_NR="4"
		local USAGE_STRING="\e[31m Usage: $0 <value of which multiples will be deleted> <number of last checkpoints to keep> <beta directories ... >\e[0m\n"
        if [[ ! $1 =~ ^[1-9][0-9]*$ ]]; then
	        echo "Invalid frequency or frequency not given as first parameter!" 1>&2
			echo -e $USAGE_STRING 1>&2
	        return
        fi
		local FREQUENCY=$1 && shift
		if [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
            if [ "$1" -eq 0 ]; then
                printf "\n\e[91m Please specify a valid POSITIVE number as second argument ...\e[0m\n\n" 1>&2 && return
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
                    source ${HOME}/Script/UtilityFunctions.sh
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

    DEFINED_FUNCTIONS+=( 'ListOfTrashFolders' )
    function ListOfTrashFolders(){
        find $(pwd) -name "Trash*" -type d
    }

    DEFINED_FUNCTIONS+=( 'ListOfTrashFoldersWithSizes' )
    function ListOfTrashFoldersWithSizes(){
        ListOfTrashFolders | xargs du -sh --apparent-size | awk '{print $2 "      " $1}'
    }

    DEFINED_FUNCTIONS+=( 'SizeOfTrashFolders' )
    function SizeOfTrashFolders(){
        local LIST_OF_TRASH_FOLDERS=( $(ListOfTrashFolders) )
        if [ ${#LIST_OF_TRASH_FOLDERS[@]} -eq 0 ]; then
            printf "\n\e[92m No \"Trash*\" folder has been found down in the tree from \"$PWD\".\e[0m\n\n"
        else
            local SIZE_ARRAY_IN_BYTES=()
            for FOLDER in ${LIST_OF_TRASH_FOLDERS[@]}; do
                SIZE_ARRAY_IN_BYTES+=( $(du --apparent-size -B1 $FOLDER | cut -f1) )
            done && unset -v 'FOLDER'
            local TOTAL_SIZE=$(tr ' ' '\n' <<< "${SIZE_ARRAY_IN_BYTES[@]}" | awk '{sum+=$1}END{print sum}')
            (
				#Start a subshell in order to source "locally"
                source ~/Script/UtilityFunctions.sh
                TOTAL_SIZE=$(ConvertFromBytesToHumanReadable $TOTAL_SIZE)
                TOTAL_SIZE=$(sed 's/\([[:alpha:]]\)/ \1/' <<< "$TOTAL_SIZE") #Put space before unit
                printf "\n\e[91m Found ${#LIST_OF_TRASH_FOLDERS[@]} \"Trash\*\" folders. Total size: ${TOTAL_SIZE}.\e[0m\n\n"
            )
        fi
    }

    DEFINED_FUNCTIONS+=( 'CompleteFolderName' )
    function CompleteFolderName(){
        local FOLDERS_ARRAY=()
        for ARGUMENT in $@; do
            if [[ ! $ARGUMENT =~ ^[[:digit:]][.][[:digit:]]{4}_s[[:digit:]]{4}_[[:alpha:]]{2}$ ]]; then
                printf "\n\e[91m Unable to complete \"${ARGUMENT}\" name.\e[0m\n\n" 1>&2 && return -1
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

    DEFINED_FUNCTIONS+=( 'GetOutputFilePath' )
    function GetOutputFilePath(){
        local FOLDER
        if [ -d "$1" ]; then
            FOLDER="$1"
        else
            FOLDER=$(CompleteFolderName "$1") || return -1
            [ ! -d $FOLDER ] && printf "\n\e[0;91m Folder \"$FOLDER\" not found!\n\e[0m" 1>&2 && return -1
        fi
        if [ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ]; then
            local FOLDER_FILE="${FOLDER}/rhmc_output"
        elif [ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ]; then
            local FOLDER_FILE="${FOLDER}/hmc_output"
        else
            echo "Neither in Staggered nor in Wilson path!"  1>&2 && return -1
        fi
        echo "$FOLDER_FILE"
    }

    DEFINED_FUNCTIONS+=( 'FindLastStandardOutput' )
    function FindLastStandardOutput(){
        local FOLDER
        if [ -d "$1" ]; then
            FOLDER="$1"
        else
            FOLDER=$(CompleteFolderName "$1") || return -1
            [ ! -d $FOLDER ] && printf "\n\e[0;91m Folder \"$FOLDER\" not found!\n\n\e[0m"  1>&2 && return -1
        fi
        [ $(find $FOLDER -regex ".*/?hmc.*[.]out" | wc -l) -eq 0 ] && printf "\n\e[0;91m No standard output file found in \"$FOLDER\"!\n\n\e[0m"  1>&2 && return -1
        if [ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ]; then
            local FOLDER_FILE="$(ls -rt1 $FOLDER/rhmc*.*.out | tail -n1)"
        elif [ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ]; then
            local FOLDER_FILE="$(ls -rt1 $FOLDER/hmc*.*.out | tail -n1)"
        else
            echo "Neither in Staggered nor in Wilson path!"  1>&2 && return -1
        fi
        echo "$FOLDER_FILE"
    }

    DEFINED_FUNCTIONS+=( 'FindMissingTrajectories' )
    function FindMissingTrajectories(){
        for ARGUMENT in $@; do
            if [ -d $ARGUMENT ]; then
                local FOLDER="$ARGUMENT"
            else
                local FOLDER=$(CompleteFolderName "$ARGUMENT")
                [ ! -d $FOLDER ] && printf "\n \e[31mSkipping folder \"$ARGUMENT\" which has not been found!\e[0m\n" && continue
            fi
            if [ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ]; then
                local FOLDER_FILE="${FOLDER}/rhmc_output"
            elif [ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ]; then
                local FOLDER_FILE="${FOLDER}/hmc_output"
            else
                echo "Neither in Staggered nor in Wilson path!" 1>&2 && return
            fi
            printf "\n\e[38;5;32m Checking file \e[36m$FOLDER_FILE"
            [ ! -f $FOLDER_FILE ] && printf "\n \e[31mFile \"$FOLDER_FILE\" not found! Skipping it...\n" && continue
            local TRAJ=( $(awk '
                           NR==1{last=$1}
                           NR>1{if($1>last+1){missTraj[arraylength++]=$1}; last=$1}
                           END{if(arraylength==0){exit 0}
                               else{for(i in missTraj){print missTraj[i]}; exit 1}}' "$FOLDER_FILE") )
            if [ "${#TRAJ[@]}" -eq 0 ]; then
                printf "\e[32m ...no missing trajectory found!\e[0m\n\n"
            else
                printf "\e[38;5;202m ...found ${#TRAJ[@]} bunch(es) of missing trajectory(ies)!\e[0m\n"
                for VALUE in ${TRAJ[@]}; do
                    local LINE_NUMBER=$(grep -n "^$VALUE[[:space:]]" "$FOLDER_FILE" | cut -f1 -d':')
                    if [ -z ${EDITOR:+x} ]; then
                        vim +$LINE_NUMBER $FOLDER_FILE
                    else
                        $EDITOR +$LINE_NUMBER $FOLDER_FILE
                    fi
                done && unset -v 'VALUE'
                printf "\n"
            fi
        done && unset -v 'ARGUMENT'
    }

    DEFINED_FUNCTIONS+=( 'TimeTr' )
    function TimeTr(){
        local OUTPUT_FILE; OUTPUT_FILE=$(GetOutputFilePath "$1") #To be able to check error code, local keyword sweeps it away!
        [ $? -ne 0 ] && printf "\n \e[91mError in \"$FUNCNAME\" function, unable to reconstruct output filename!\e[0m\n\n"  1>&2 && return -1
        local TIME_AND_NUMBER_TR=( $(awk '{ time=$10; if(time!=0){sum+=time; counter+=1}} END {if(counter!=0){printf "%d", sum/counter}else{printf "%d", 0}; printf " %d", counter}' "$OUTPUT_FILE") )
        printf "\n \e[92mAmount of trajectories with non-zero time: %d   Time per trajectory: %ds\n\n" ${TIME_AND_NUMBER_TR[1]} ${TIME_AND_NUMBER_TR[0]}
        for INDEX in 1000 5000 10000 25000 50000; do
            local WALLTIME=$(Walltime $INDEX ${TIME_AND_NUMBER_TR[0]} | grep -oE "[[:digit:]]+-[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}")
            printf "\e[38;5;202m%8s\e[0m  --->  \e[38;5;39m%12s\e[0m\n" "$INDEX" "$WALLTIME"
        done
        echo ''
    }

    DEFINED_FUNCTIONS+=( 'ShowStd' )
    function ShowStd(){
        if [[ $1 =~ ^b?[[:digit:]][.] ]]; then
            local FOLDER_FILE=$(FindLastStandardOutput "$1")
        elif [[ $1 =~ ^[[:digit:]]+$ ]]; then
            if [ $(grep "[sS]taggered" <<< "$PWD" | wc -l) -gt 0 ]; then
                local FOLDER_FILE="JobScripts/rhmc*.$1.out"
            elif [ $(grep "[wW]ilson" <<< "$PWD" | wc -l) -gt 0 ]; then
                local FOLDER_FILE="JobScripts/hmc*.$1.out"
            else
                echo "Neither in Staggered nor in Wilson path!"
            fi
        else
            printf "\n\e[0;91m Unknown first command line parameter!\n\n\e[0m" 1>&2 && return -1
        fi
        if [ "$2" = "-e" ]; then
            FOLDER_FILE=${FOLDER_FILE/.out/.err}
        elif [ "$2" != '' ]; then
            printf "\n\e[0;91m Unknown second command line parameter!\n\n\e[0m" 1>&2 && return -1
        fi
        if [ ! -f $FOLDER_FILE ]; then
            printf "\n\e[0;91m File \"$FOLDER_FILE\" not found!\n\n\e[0m" 1>&2 && return -1
        fi
        less $FOLDER_FILE
        #Print jobid and node to screen
        local JOBID=$(grep -o "[[:digit:]]\+" <<< "${FOLDER_FILE##*hmc}")
        printf "\n\e[0;36m Job ID: ${JOBID}   "
        printf "$(grep "Host" JobScripts/*hmc*.${JOBID}.out)\n\n\e[0m"
    }

    DEFINED_FUNCTIONS+=( 'FindHighestDH' )
    function FindHighestDH(){
        local FOLDER_FILE; FOLDER_FILE=$(GetOutputFilePath "$1")
        [ $? -ne 0 ] && printf "\n \e[91mError in \"$FUNCNAME\" function, unable to reconstruct output filename!\e[0m\n\n"  1>&2 && return -1
        local NUMBER_TR=30
        if [[ $2 =~ ^[0-9]+$ ]]; then
            NUMBER_TR=$2
        fi
        echo ''
        awk '{printf "%8d    %g\n", $1, sqrt($8*$8)}' $FOLDER_FILE | sort -n -k2g | tail -n $NUMBER_TR | sort -k1n
        echo ''
    }

    DEFINED_FUNCTIONS+=( 'CheckCl2qcdOutput' )
    function CheckCl2qcdOutput(){
        local FOLDER_FILE; FOLDER_FILE=$(GetOutputFilePath "$1")
        [ $? -ne 0 ] && printf "\n \e[91mError in \"$FUNCNAME\" function, unable to reconstruct output filename!\e[0m\n\n"  1>&2 && return -1
        printf "\e[38;5;129m\n Calling:\e[38;5;117m ${HOME}/Script/CheckCorrectnessCl2qcdOutputFile.sh $FOLDER_FILE\n\e[0m"
        bash ${HOME}/Script/CheckCorrectnessCl2qcdOutputFile.sh $FOLDER_FILE
    }
    
fi

#============================================================================================================================#
#Aliases to call the Root 3D histogram program
if [ $LOAD_ROOTHIST_ALIASES = "TRUE" ]; then
    
    DEFINED_FUNCTIONS+=( 'CreateRootHistograms' )
    function CreateRootHistograms(){
        local BETA_ARRAY=()
        local ROOT_INPUT_FILE="hmc_output"
        local TMP_ROOT_PATH_INPUT_FILE="tmpFileForRoot"
        local PATH_PREFIX="/home/phil-configs/wilson_nf2_muipi4/ImagMu"
        local ROOT_PRGOGRAM="/home/czaban/3DPolyLoopHist/3DPolyLoopHist"
        while [ $# -gt 0 ];do
            case $1 in
                -b)
                    while [[ $2 =~ ^[[:digit:]]\.[[:digit:]]{4}$ ]] || [[ $2 =~ ^b[[:digit:]]\.[[:digit:]]{4}_s[[:digit:]]{4}_continueWithNewChain$ ]];do
                        BETA_ARG=$2
                        if [[ $2 =~ ^b[[:digit:]]\.[[:digit:]]{4}_s[[:digit:]]{4}_continueWithNewChain$ ]]; then
                            BETA_ARG=${BETA_ARG#b}
                        fi
                        BETA_ARRAY+=( $BETA_ARG )
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
            BETA_ARG=$BETA
            if [[ $BETA_ARG =~ ^[[:digit:]]\.[[:digit:]]{4}_s[[:digit:]]{4}_continueWithNewChain$ ]]; then
                BETA_ARG=ss${BETA_ARG#*_s}
                BETA_ARG=${BETA_ARG%_*}
            fi
            BETA_PATH_ARRAY+=( "$BETA_ARG	$CURRENT_PATH/b$BETA/$ROOT_INPUT_FILE" )
            echo "$BETA_ARG	$CURRENT_PATH/b$BETA/$ROOT_INPUT_FILE"
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
    [ ${!IDENTITY_PYTHON+x} ] && unset -v $IDENTITY_PYTHON
    [ ${!IDENTITY_JOBS+x} ] && unset -v $IDENTITY_JOBS
    [ ${!IDENTITY_ROOTHIST+x} ] && unset -v $IDENTITY_ROOTHIST
fi

#Unsetting remaining variables
unset -v LOAD_GO_ALIASES
unset -v LOAD_PYTHON_ALIASES
unset -v LOAD_FIT_ALIASES
unset -v LOAD_JOB_ALIASES
unset -v IDENTITY
unset -v IDENTITY_WORK
unset -v IDENTITY_WILSON
unset -v IDENTITY_STAGGERED
unset -v IDENTITY_PYTHON
unset -v IDENTITY_JOBS
unset -v IDENTITY_ROOTHIST
unset -f __static__PrintHelp
