#!/bin/bash

function __static__PrintHelp(){
	echo ''
	echo '  Script to collect useful commands for working'
	echo '  Since each user could have different preferences, use the LOAD*'
	echo '  variables to decide which aliases to load.'
	echo ''
	echo '  ATTENTION: Each user should define the following variables (NOT here but where it is sourced)'
	echo '                XXX_work       -> global path to work directory (scratch on clusters, philconfigs locally)'
	echo '                XXX_Wilson     -> local path from work to Wilson simulation folder , i.e. to where the mu folder is'
	echo '                XXX_Staggered  -> local path from work to Staggered simulation folder, i.e. to where the mu folder is'
	echo '                XXX_kappaList  -> list of kappa values between "" separated by a space, e.g. "1575 1600 1625"'
	echo '                XXX_massList   -> list of  mass values between "" separated by a space, e.g. "0080 0090 1500"'
	echo '                XXX_Python     -> global path to Python git, i.e. to ImagMu folder included: "/.../ImagMu"'
	echo '                XXX_Fits       -> global path to fit git, i.e. git name folder included: "/.../gitNameFolder"'
	echo '             where XXX is the whoami concatenated with the hostname via underscore, e.g. smith_cluster1234'
	echo '             Once (some of) the variables above are defined, then source this script with any desired option.'
	echo ''
	echo '  Explanation of LOAD* variables:'
	echo '     LOAD_KAPPA_ALIASES  ->  Creates aliases to go to volumes folder in kappa folders'
	echo '     LOAD_MASS_ALIASES   ->  Creates aliases to go to volumes folder in mass folders'
	echo '     LOAD_PYTHON_ALIASES ->  Creates aliases to call python functionalities'
	echo '     LOAD_FIT_ALIASES    ->  Creates aliases to call fits functionalities'
	echo '     LOAD_JOB_ALIASES    ->  Creates aliases to work with jobs'
	echo ''
	echo ''
	echo '  Variable that the user should provide'
	echo ''
	echo '    [...]_work=""       -> Needed for LOAD_JOB_ALIASES - LOAD_KAPPA_ALIASES - LOAD_MASS_ALIASES'
	echo '    [...]_Wilson=""     -> Needed for LOAD_KAPPA_ALIASES'
	echo '    [...]_Staggered=""  -> Needed for LOAD_MASS_ALIASES'
	echo '    [...]_kappaList=""  -> Needed for LOAD_KAPPA_ALIASES'
	echo '    [...]_massList=""   -> Needed for LOAD_MASS_ALIASES'
	echo '    [...]_Python=""     -> Needed for LOAD_PYTHON_ALIASES'
	echo ''
	echo '  where [...] is the whoami concatenated with hostname.'
	echo ''
	echo ''
}

function AliasesHelper(){
    local availableFunctions index
    availableFunctions=( $(grep -E '^[[:space:]]*([[:alnum:]_]+[[:space:]]*\(\)|function[[:space:]]+[[:alnum:]_]+)' "${BASH_SOURCE[0]}" | sed -e 's/().*//g' -e 's/function \(.*\)/\1/') )
    for index in ${!availableFunctions[@]}; do
        if [[ ${availableFunctions[$index]} =~ ^__static__ ]]; then
            unset -v 'availableFunctions[$index]'
        fi
    done
    availableFunctions=( ${availableFunctions[@]} ) # Make array not sparse to use continuous index later
    (
		#Start a subshell in order to source "locally"
        source ${HOME}/Script/UtilityFunctions.sh
        if [ $# -eq 0 ]; then # Interactive selecion of function
            printf "\n Here a list of available function, distinguishing between \e[92malready loaded\e[0m and \e[96mnot yet loaded\e[0m:\n\n"
            local stringToBePrint tmpString
            tmpString=''
            for index in ${!availableFunctions[@]}; do
                if ElementInArray ${availableFunctions[$index]} ${DEFINED_FUNCTIONS[@]}; then
                    tmpString+="\e[92m"
                else
                    tmpString+="\e[96m"
                fi
                tmpString+="|$index)_${availableFunctions[$index]}\e[0m,"
            done
            local nCols=1
            while :
            do
                #Use the comma to split every nCols field and then replace spaces by \n and finally the _ by a space and | by spaces
                stringToBePrint="$(echo "$tmpString" | xargs -d"," -n$nCols | tr ' ' '\t' | tr '_' ' ' | tr '|' '    ')"
                if [ $(awk '{l=length($0); if(l>max){max=l}}END{print max}' <<< "${stringToBePrint}") -lt $((COLUMNS*6/10)) ]; then
                    (( nCols++ ))
                else
                    break
                fi
            done
            if [ "$stringToBePrint" = '' ]; then
                printf "\n \e[91mThe terminal is too small to contain even the name of a single function! Use larger terminal!  Unable to help!\e[0m\n\n"
                return -1
            fi
            printf "${stringToBePrint}\n" | column -t
            printf '\n \e[1;93mATTENTION:\e[21m Only help of loaded function can be obtained!\e[0m\n\n For which functions would you like to get help? Use a comma separated list of entries or ranges (e.g. \e[93m1,4-6,16\e[0m): \e[s'
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
                printf " \e[1;93m%${longestLabel}s\e[24m:\e[0m " "${availableFunctions[$index]}"
                if ElementInArray ${availableFunctions[$index]} ${DEFINED_FUNCTIONS[@]}; then
                    ${availableFunctions[$index]} ---h | fold -s -w $((COLUMNS*6/10)) | awk -v nSpc=${longestLabel} 'BEGIN{spaces=sprintf("%*s", nSpc, "")} NR==1{print $0} NR>1{print spaces "   " $0}' # https://stackoverflow.com/a/25408074
                else
                    echo "Function not loaded!"
                fi
                echo ''
            done
            echo ''
        else
            local func longestLabel=0
            for func in $@; do
                [ $longestLabel -lt ${#func} ] && longestLabel=${#func}
            done
            echo ''
            for func in $@; do
                printf " \e[1;93m%${longestLabel}s\e[24m:\e[21;36m " "${func}"
                if ElementInArray ${func} ${DEFINED_FUNCTIONS[@]}; then
                    ${func} ---h | fold -s -w $((COLUMNS*5/10)) | awk -v nSpc=${longestLabel} 'BEGIN{spaces=sprintf("%*s", nSpc, "")} NR==1{print $0} NR>1{print spaces "   " $0}' # https://stackoverflow.com/a/25408074
                else
                    echo "Function not loaded!"
                fi
                printf "\n\e[0m"
            done
            echo ''
        fi
    )
    return
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
          printf "\n\e[96m"
          __static__PrintHelp
          printf "\e[0;92m"
          echo "  Options to load bunches of aliases:"
          echo "    --loadKappa           ->    Creates aliases to go to volumes folder in kappa folders"
          echo "    --loadMass            ->    Creates aliases to go to volumes folder in kappa folders"
          echo "    --loadPython          ->    Creates aliases to call python functionalities"
          echo "    --loadFit             ->    Creates aliases to call fits functionalities"
          echo "    --loadJob             ->    Creates aliases to work with jobs"
          echo "    --loadRootHist        ->    Creates alias to access the 3D Root histogram program"
          echo "    --unsetMyVariables    ->    Unset the variables the user has allocated him/herself"
          echo ""
          printf "  Use the \e[96mAliasesHelper\e[92m function to get help about the loaded aliases. You can\n"
          printf "  run it as such or you can specify one or more functions to get help about them only.\n"
          printf "\n\e[0m"
          if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
              unset -v 'LOAD_KAPPA_ALIASES' 'LOAD_MASS_ALIASES' 'LOAD_PYTHON_ALIASES' 'LOAD_FIT_ALIASES' 'LOAD_JOB_ALIASES' 'LOAD_ROOTHIST_ALIASES' 'UNSET_USER_VARIABLES'
              unset -f __static__PrintHelp
              return # Script was sourced!
          else
              exit   # Script was run!
          fi
          shift ;;
      --loadKappa )           LOAD_KAPPA_ALIASES="TRUE"; shift ;;
      --loadMass )            LOAD_MASS_ALIASES="TRUE"; shift ;;
      --loadPython )          LOAD_PYTHON_ALIASES="TRUE"; shift ;;
      --loadFit )             LOAD_FIT_ALIASES="TRUE"; shift ;;
      --loadJob )             LOAD_JOB_ALIASES="TRUE"; shift ;;
      --loadRootHist )        LOAD_ROOTHIST_ALIASES="TRUE"; shift ;;
      --unsetMyVariables )    UNSET_USER_VARIABLES="TRUE"; shift ;;
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

#Auxiliary variables
DEFINED_FUNCTIONS=()

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
# Function to avoid a lot of code duplication in the following. Sure, it will be sourced as well,
# but it is probably worth for maintainibility as well.
function __static__WrapperToInvokeScript(){
    local scriptToBeInvoked
    scriptToBeInvoked="$1"; shift
    if [ "$1" = '---h' ]; then
        echo "Invoke \"${scriptToBeInvoked}\" script."
    else
        ${scriptToBeInvoked} "$@"
    fi
}
#============================================================================================================================#

#Aliases to run fit programs
if [ $LOAD_FIT_ALIASES = "TRUE" ]; then

    DEFINED_FUNCTIONS+=('BinderFit')
    function BinderFit(){
        __static__WrapperToInvokeScript "${HOME}/Script/FittingUtilities/BinderFitVSbeta.sh" "$@"
    }
    
    DEFINED_FUNCTIONS+=('BruteForceFit')
    function BruteForceFit(){
        __static__WrapperToInvokeScript "${HOME}/Script/FittingUtilities/BruteForceFit.sh" "$@"
    }

    DEFINED_FUNCTIONS+=('FilterFitResults')
    function FilterFitResults(){
        __static__WrapperToInvokeScript "${HOME}/Script/FittingUtilities/FilterFitResults.sh" "$@"
    }

    DEFINED_FUNCTIONS+=('SetUpForBruteForceFit')
    function SetUpForBruteForceFit(){
        __static__WrapperToInvokeScript "${HOME}/Script/FittingUtilities/SetUpForBruteForceFit.sh" "$@"
    }

    DEFINED_FUNCTIONS+=('SelectBestFits')
    function SelectBestFits(){
        __static__WrapperToInvokeScript "${HOME}/Script/FittingUtilities/FindClosestValue.sh" "$@"
    }

    DEFINED_FUNCTIONS+=('ChooseReweightingFolders')
    function ChooseReweightingFolders(){
        __static__WrapperToInvokeScript "${HOME}/Script/FittingUtilities/ChooseReweightingFoldersAndFindResolution.sh" "$@"
    }

    DEFINED_FUNCTIONS+=('QuantitativeCollapse')
    function QuantitativeCollapse(){  #TODO: Put this function somewhere else, it is not about fit
        __static__WrapperToInvokeScript "${HOME}/Script/CollapsePlot/MathematicaQuantitativeCollapse/PerformAnalyticCollapse.sh" "$@"
    }

    DEFINED_FUNCTIONS+=('PlotBestFits')
    function PlotBestFits(){
        if [ "$1" = '---h' ]; then
            echo "Correctly invoke the \"${HOME}/Script/PlottingUtilities/PlotBestFits.plt\" script via gnuplot using the given options as filenames."
        else
            gnuplot -e "filenames='$*'" ${HOME}/Script/PlottingUtilities/PlotBestFits.plt
        fi
    }

    DEFINED_FUNCTIONS+=('GetFilteringProcedure')
    function GetFilteringProcedure(){
        if [ "$1" = '---h' ]; then
            echo "Return command to filter the brute force fit results."
        else
            echo "FilterFitResults -f FitByBruteForce.dat -o -p a1 100 | FilterFitResults -p chi2 1 | FilterFitResults -p MinOv% g80 > FilteredResults_a1_100_chi2_1_MinOv%_g80"
        fi
    }

    DEFINED_FUNCTIONS+=('GetSelectingBestFitProcedure')
    function GetSelectingBestFitProcedure(){
        if [ "$1" = '---h' ]; then
            echo "Return command to smartly invoke the script to select the best fits out of the bunch created via the filtering procedure."
        else
            echo 'SelectBestFits <COMPLETE_WITH_OPTIONS> | awk '"'"'{ print length, $0 }'"'"' | sort -n -s | cut -d" " -f2-'
        fi
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

    #DEFINED_FUNCTIONS+=('PyAutocorrelation')
    #function PyAutocorrelation(){
    #    __static__WrapperToInvokeScript "python ${!IDENTITY_PYTHON}/ImagMuAutocorrelationAnalysis.py" "$@"
    #}
    #
    #DEFINED_FUNCTIONS+=('PyAnalysis')
    #function PyAnalysis(){
    #    __static__WrapperToInvokeScript "python ${!IDENTITY_PYTHON}/ImagMuAnalysis.py" "$@"
    #}
    #
    #DEFINED_FUNCTIONS+=('PySynchronization')
    #function PySynchronization(){
    #    __static__WrapperToInvokeScript "python ${!IDENTITY_PYTHON}/ImagMuSync.py" "$@"
    #}
    #
    #DEFINED_FUNCTIONS+=('PyReweighting')
    #function PyReweighting(){
    #    __static__WrapperToInvokeScript "python ${!IDENTITY_PYTHON}/ImagMuReweighting.py" "$@"
    #}
    #
    #DEFINED_FUNCTIONS+=('PyFindBetaC')
    #function PyFindBetaC(){
    #    __static__WrapperToInvokeScript "python ${!IDENTITY_PYTHON}/ImagMuFindBetaC.py" "$@"
    #}
    #
    #DEFINED_FUNCTIONS+=('PyPlotScaling')
    #function PyPlotScaling(){
    #    __static__WrapperToInvokeScript "python ${!IDENTITY_PYTHON}/ImagMuPlotScaling.py" "$@"
    #}

    DEFINED_FUNCTIONS+=('GetSynchronizationCommand')
    function GetSynchronizationCommand(){
        if [ "$1" = '---h' ]; then
            echo "Return standard invocation of \"PySynchronization\". Remote host name has to be passed as option."
        else
            echo "PySynchronization --betasFile=betasSync --remote=$1"
        fi
    }

    DEFINED_FUNCTIONS+=('GetAnalysisPbpCommand')
    function GetAnalysisPbpCommand(){
        if [ "$1" = '---h' ]; then
            echo "Return standard invokation of \"PyAnalysis\" to analise the chiral condensate."
        else
            echo "PyAnalysis --deactivatePlaq --deactivatePoly --activatePbp --inversionsPerConfig 8"
        fi
    }

    DEFINED_FUNCTIONS+=('GetAnalysisPolyImWithZeroMeanCommand')
    function GetAnalysisPolyImWithZeroMeanCommand(){
        if [ "$1" = '---h' ]; then
            echo "Return standard invokation of \"PyAnalysis\" to analise the Polyakov loop with zero mean."
        else
            echo "PyAnalysis --analyzeWithJackknife --analyzeSingleChains --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_sq"
        fi
    }

    DEFINED_FUNCTIONS+=('GetAnalysisPolySqCommand')
    function GetAnalysisPolySqCommand(){
        if [ "$1" = '---h' ]; then
            echo "Return standard invokation of \"PyAnalysis\" to analise the square norm of the Polyakov loop."
        else
            echo "PyAnalysis --analyzeWithJackknife --analyzeSingleChains --deactivatePlaq --deactivatePoly_re --deactivatePoly_im_withZeroMean --deactivatePoly_im --deactivatePoly_im_abs --deactivateSusc"
        fi
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

    DEFINED_FUNCTIONS+=('GetReweightingPbpCommand')
    function GetReweightingPbpCommand(){
        if [ "$1" = '---h' ]; then
            echo "Return standard invokation of \"PyReweighting\" to reweight the chiral condensate. It either needs betaMin, betaMax and the resolution in beta or just the latter (in this case betaMin and betaMax are the first and the last line of the file \"betas\")"
        else
            local BETA_MIN BETA_MAX RESOLUTION NUM_POINTS
            __static__DefineBetaMinMaxResAndCheck "$@" || return
            echo -n '[ $(ls Nf?_mui*_nt?_ns??_reweighting 2>/dev/null | wc -l) -eq 0 ]'
            echo -n ' && [ $(ls -d -1 Nf?_mui*_nt?_ns??_reweighting_pbp/ | wc -l) -eq 0 ]'
            echo -n " && time PyReweighting --deactivatePlaq --deactivatePoly --activatePbp --inversionsPerConfig 8 --deactivateMean --deactivateSusc --doNotUseSimulatedPointsAsNewPoints -r $BETA_MIN $BETA_MAX -p $NUM_POINTS"
            echo -n ' && [ $(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/ | wc -l) -eq 1 ]'
            echo -n ' && FOLDER="$(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/)"'
            echo -n ' && mv ${FOLDER%?} ${FOLDER%?}_pbp'
            echo    ' && unset -v '"'FOLDER'"
        fi
    }

    DEFINED_FUNCTIONS+=('GetReweightingPolyImWithZeroMeanCommand')
    function GetReweightingPolyImWithZeroMeanCommand(){
        if [ "$1" = '---h' ]; then
            echo "Return standard invokation of \"PyReweighting\" to reweight the Polyakov loop with zero mean. It either needs betaMin, betaMax and the resolution in beta or just the latter (in this case betaMin and betaMax are the first and the last line of the file \"betas\")"
        else
            local BETA_MIN BETA_MAX RESOLUTION NUM_POINTS
            __static__DefineBetaMinMaxResAndCheck "$@" || return
            echo -n '[ $(ls Nf?_mui*_nt?_ns??_reweighting 2>/dev/null | wc -l) -eq 0 ]'
            echo -n ' && time PyReweighting --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_sq --deactivateMean --deactivateSusc --deactivateSkew --printEstimatorsToFile'
            echo -n " --doNotUseSimulatedPointsAsNewPoints -r $BETA_MIN $BETA_MAX -p $NUM_POINTS"
            echo -n ' && [ $(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/ | wc -l) -eq 1 ]'
            echo -n ' && FOLDER="$(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/)"'
            echo -n ' && mv ${FOLDER%?} ${FOLDER%?}_dBeta'$RESOLUTION
            echo    ' && unset -v '"'FOLDER'"
        fi
    }

    DEFINED_FUNCTIONS+=('GetReweightingPolySqSkewCommand')
    function GetReweightingPolySqSkewCommand(){
        if [ "$1" = '---h' ]; then
            echo "Return standard invokation of \"PyReweighting\" to reweight the square norm of the Polyakov loop. It either needs betaMin, betaMax and the resolution in beta or just the latter (in this case betaMin and betaMax are the first and the last line of the file \"betas\")"
        else
            local BETA_MIN BETA_MAX RESOLUTION NUM_POINTS
            __static__DefineBetaMinMaxResAndCheck "$@" || return
            echo -n '[ $(ls Nf?_mui*_nt?_ns??_reweighting 2>/dev/null | wc -l) -eq 0 ]'
            echo -n ' && time PyReweighting --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_im_withZeroMean --deactivateMean --deactivateSusc'
            echo -n " --doNotUseSimulatedPointsAsNewPoints -r $BETA_MIN $BETA_MAX -p $NUM_POINTS"
            echo -n ' && [ $(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/ | wc -l) -eq 1 ]'
            echo -n ' && FOLDER="$(ls -d -1 Nf?_mui*_nt?_ns??_reweighting/)"'
            echo -n ' && mv ${FOLDER%?} ${FOLDER%?}_poly_sq'
            echo    ' && unset -v '"'FOLDER'"
        fi
    }

    DEFINED_FUNCTIONS+=('GetFindBetaCPbpCommand')
    function GetFindBetaCPbpCommand(){
        if [ "$1" = '---h' ]; then
            echo "Return standard invokation of \"PyFindBetaC\" to extract the critical beta from the chiral condensate."
        else
            echo "PyFindBetaC --deactivatePlaq --deactivatePoly --activatePbp --deactivateMean --deactivateSusc --deactivateBinder"
        fi
    }

    DEFINED_FUNCTIONS+=('GetFindBetaCPolySqCommand')
    function GetFindBetaCPolySqCommand(){
        if [ "$1" = '---h' ]; then
            echo "Return standard invokation of \"PyFindBetaC\" to extract the critical beta from the square norm of the Polyakov loop."
        else
            echo "PyFindBetaC --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_withZeroMean --deactivatePoly_im_abs --deactivateMean --deactivateSusc --doNotExtractFromRawData"
        fi
    }

    DEFINED_FUNCTIONS+=('GetPlotScalingPolySqCommand')
    function GetPlotScalingPolySqCommand(){
        if [ "$1" = '---h' ]; then
            echo "Return standard invokation of \"PyPlotScaling\" to create the scaling plots of the square norm of the Polyakov loop. It needs the ns values as arguments."
        else
            echo "PyPlotScaling --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_im_withZeroMean --nsArray $@ --doNotPlotRawData --doNotMakeCombinedPlots --deactivateMean --deactivateSkew --deactivateBinder"
        fi
    }

    DEFINED_FUNCTIONS+=('GetPlotScalingPbpCommand')
    function GetPlotScalingPbpCommand(){
        if [ "$1" = '---h' ]; then
            echo "Return standard invokation of \"PyPlotScaling\" to create the scaling plots of the chiral condensate. It needs the ns values as arguments."
        else
            echo "PyPlotScaling --deactivatePlaq --deactivatePoly --activatePbp --nsArray $@ --doNotPlotRawData --doNotMakeCombinedPlots --deactivateMean --deactivateSusc"
        fi
    }

    DEFINED_FUNCTIONS+=('GetPlotScalingPolyImWithZeroMeanCommand')
    function GetPlotScalingPolyImWithZeroMeanCommand(){
        if [ "$1" = '---h' ]; then
            echo "Return standard invokation of \"PyPlotScaling\" to create the scaling plots of the Polyakov loop with zero mean. It needs the critical beta as first argument and the ns values as following arguments."
        else
            local BETAC="$1"
            shift
            echo "PyPlotScaling --deactivatePlaq --deactivatePoly_re --deactivatePoly_im --deactivatePoly_im_abs --deactivatePoly_sq --nsArray $@ --doNotPlotRawData --deactivateMean --deactivateSusc --deactivateSkew --betaCForCollapsePlots $BETAC"
        fi
    }

    DEFINED_FUNCTIONS+=('HasFileDifferentNumberOfEntriesPerLine')
    function HasFileDifferentNumberOfEntriesPerLine(){
        if [ "$1" = '---h' ]; then
            echo "Boolean function. It returns true if the file given as argument has at least two lines with e different number of fields, false otherwise. Space(s) are used as field separator."
        else
            local filename
            filename="$1"
            if [ $(awk '{print NF}' "$filename" | sort | uniq | wc -l) -eq 1 ]; then
                return 1
            else
                return 0
            fi
        fi
    }

    DEFINED_FUNCTIONS+=('CheckNumberOfEntriesPerLine')
    function CheckNumberOfEntriesPerLine(){
        if [ "$1" = '---h' ]; then
            echo "Count the number of fields per line in the given file and make a summary. As second argument the expected number of entries can be specified to colour the summary accordingly. Space(s) are used as field separator."
        else
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
        fi
    }

    DEFINED_FUNCTIONS+=('RemoveLinesWithNumberOfColumnsDifferentFrom')
    function RemoveLinesWithNumberOfColumnsDifferentFrom(){
        if [ "$1" = '---h' ]; then
            echo "Given a number N and a file name as command line options, a backup of the file is created and the lines not with N fields are removed from the original file."
        else
            local filename expectedEntries
            filename="$2"; expectedEntries="$1"
            [[ ! $expectedEntries =~ ^[0-9]+$ ]] && printf "\e[91m\n Number of expected entries wrongly specified!\e[0m\n\n" 1>&2 && return
            [ ! -f "${filename}" ] && printf "\e[91m\n File \"${filename}\" not found!\e[0m\n\n" 1>&2 && return
            [ -f "${filename}_original" ] && printf "\e[91m\n File \"${filename}_original\" already existing!\e[0m\n\n" 1>&2 && return
            mv -i "$filename" "${filename}_original"
            awk -v "numberToMatch=$expectedEntries" 'NF==numberToMatch{print $0}' "${filename}_original" > "$filename"
        fi
    }

fi

#============================================================================================================================#

#Alias for choosing a folder where we are (displaying first ns[[:digit:]] folders sorted numerically)
if [ $LOAD_MASS_ALIASES = "TRUE" ] || [ $LOAD_KAPPA_ALIASES = "TRUE" ]; then
    function PickUpFolder(){
        if [ "$1" = '---h' ]; then
            echo "Given an optional prefix, all folders (matching the given prefix) are listed. The user has to select one to cd into."
        else
            local FOLDERS_ARRAY=( $(ls -d ${1}*/) )
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
            else
                select FOLDER in ${ORDERED_FOLDERS_ARRAY[@]%?}; do
                    if [ ${FOLDER:+x} ] && [ -d $FOLDER ]; then
                        cd $FOLDER
                        break
                    fi
                done
            fi
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
    
    DEFINED_FUNCTIONS+=('cdw')
    function cdw(){
        if [ "$1" = '---h' ]; then
            echo "Move into the work directory (scratch on clusters, phil-configs locally)."
        else
            cd ${!IDENTITY_WORK}
        fi
    }

    DEFINED_FUNCTIONS+=('JobInfo')
    function JobInfo(){
        __static__WrapperToInvokeScript "${HOME}/Script/MonitorSlurmJobs.sh" "$@"
    }

    DEFINED_FUNCTIONS+=('Acceptance')
    function Acceptance(){
        if [ "$1" = '---h' ]; then
            echo "Calculate the average of the 9th field of a given file (meant to be a Monte Carlo acceptance)."
        else
            awk '{ sum+=\$9} END {printf \"Accepted %d over %d (%lf%%)\n\", sum, NR, 100*sum/(NR)}' "$1"
        fi
    }

    DEFINED_FUNCTIONS+=('LastAcceptance')
    function LastAcceptance(){
        __static__WrapperToInvokeScript "${HOME}/Script/AcceptanceLastTrajectories.sh" "$@"
    }

    DEFINED_FUNCTIONS+=('FillInMissingLines')
    function FillInMissingLines(){
        __static__WrapperToInvokeScript "${HOME}/Script/FillInMissingLinesOutputFile.sh" "$@"
    }

    DEFINED_FUNCTIONS+=('ClusterUsage')
    function ClusterUsage(){
        if [ "$1" = '---h' ]; then
            echo "Invoke the \"${HOME}/Script/ClusterUsage.sh\" script. with the \"--doNotUpdateFiles\" option."
        else
            ${HOME}/Script/ClusterUsage.sh --doNotUpdateFiles
        fi
    }

    DEFINED_FUNCTIONS+=('ReportOnCorrelatorFiles')
    function ReportOnCorrelatorFiles(){
        if [ "$1" = '---h' ]; then
            echo "Count number of \"conf.*corr\" files in \"b?.????_s*Chain\" folders and make a report."
        else
            echo
            for b in b?.????_s*Chain; do
                printf "%+38s: %3d correlator files\n" $b $(ls $b/conf.*corr 2>>/dev/null| wc -l)
            done && unset -v 'b'
            echo
        fi
    }

    DEFINED_FUNCTIONS+=('ReportOnScaleSettingFiles')
    function ReportOnScaleSettingFiles(){
        if [ "$1" = '---h' ]; then
            echo "Count number of \"conf.*.nersc\" and \"flow.conf.*.nersc\" files in \"b?.????_s*Chain\" folders and make a report."
        else
            echo
            for b in b?.????_s*Chain; do
                printf "%+38s: %3d nersc confs, %3d flow files\n" $b $(ls $b/conf.*.nersc 2>>/dev/null| wc -l) $(ls $b/flow.conf.*.nersc 2>>/dev/null| wc -l)
            done && unset -v 'b'
            echo
        fi
    }

    DEFINED_FUNCTIONS+=('CountJobs')
    function CountJobs(){
        if [ "$1" = '---h' ]; then
            echo "Parse submitted jobs using the jobname and counting those with the same calue of the specified fields. Fields are specified as a comma-separated list without spaces, e.g. \"1,2,3\". Several strings can be specified."
        else
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
        fi
    }

    DEFINED_FUNCTIONS+=('OverviewJobs')
    function OverviewJobs(){
        if [ "$1" = '---h' ]; then
            echo "RUNNING and PENDING jobs on a specified partition are counted and a report with the amount of jobs per user is printed."
        else
            if [ $# -ne 1 ]; then
                printf "\e[0;91m \n Only the name of a cluster partition is needed as argument!\n\n\e[0m" 1>&2
                return
            else
                if [ $(sinfo -h --format "%R" | grep -c "$1") -eq 0 ]; then
                    printf "\e[0;31m \n Partition \"$1\" seems not to be existing!\n\n\e[0m"
                else
                    echo
                    for f in RUNNING PENDING; do
                        echo "${f}:"
                        squeue -h -p $1 -t $f | awk '{print $4}' | sort | uniq -c
                        echo
                    done && unset -v 'f'
                fi
            fi
        fi
    }

    DEFINED_FUNCTIONS+=('Walltime')
    function Walltime(){
        if [ "$1" = '---h' ]; then
            echo "Given the number of trajectories to be done and the seconds required to do one trajectory, the total walltime is calculated and printed."
        else
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
        fi
    }

    DEFINED_FUNCTIONS+=('CalculateGapsInTrajectoriesBetweenStoredConfigurations')
    function CalculateGapsInTrajectoriesBetweenStoredConfigurations(){
        if [ "$1" = '---h' ]; then
            echo "A summary about frequency of stored configurations is constructed, considering the beta folders given as command line arguments."
        else
            local BETA_ARRAY=( $@ )
            for INDEX in ${!BETA_ARRAY[@]}; do [ ! -d ${BETA_ARRAY[$INDEX]} ] && unset -v "BETA_ARRAY[$INDEX]"; done && unset -v 'INDEX'
            local LONGEST_BETA_STRING=$(tr ' ' '\n' <<< "${BETA_ARRAY[@]}" | awk '{print length}' | sort -n | tail -n1)
            printf "\n"; printf "%0.s " $(seq 1 $LONGEST_BETA_STRING); printf "      \e[1;38;5;129mGap [nr. of times]\n"
            for BETA in ${BETA_ARRAY[@]}; do
                printf "\n  \e[38;5;129m\e[1m%${LONGEST_BETA_STRING}s\e[0m\e[38;5;199m" "$BETA"
                ls $BETA | grep "conf.[[:digit:]]\+" | grep -o "[[:digit:]]\+" | sort -n | \
                    awk 'BEGIN{printf "    "}NR==1{tr=$1}NR>1{countGaps[$1-tr]++; tr=$1}END{for(i in countGaps){printf "%d [%d]   ", i, countGaps[i]}; printf"\n"}'
            done && unset -v 'BETA'
            echo ''
        fi
    }

    DEFINED_FUNCTIONS+=('DeleteConfPrngNotEvery')
    function DeleteConfPrngNotEvery() {
        if [ "$1" = '---h' ]; then
            echo "The first argument is mandatory and it has to be an integer which determines which checkpoints will be kept (those whose trajectory number is multiple of the given number). A second integer specifies how many last checkpoints to keep. From the third argument on, beta folder can be specified, otherwise all \"b{5,6}*\" folder are considered."
        else
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
        fi
    }

    DEFINED_FUNCTIONS+=('ListOfTrashFolders')
    function ListOfTrashFolders(){
        if [ "$1" = '---h' ]; then
            echo "Find down in the tree from the invoking position all the \"Trash*\" folders and print their global paths."
        else
            find $(pwd) -name "Trash*" -type d
        fi
    }

    DEFINED_FUNCTIONS+=('ListOfTrashFoldersWithSizes')
    function ListOfTrashFoldersWithSizes(){
        if [ "$1" = '---h' ]; then
            echo "Find down in the tree from the invoking position all the \"Trash*\" folders and print their global paths with their sizes."
        else
            ListOfTrashFolders | xargs du -sh --apparent-size | awk '{print $2 "      " $1}'
        fi
    }

    DEFINED_FUNCTIONS+=('SizeOfTrashFolders')
    function SizeOfTrashFolders(){
        if [ "$1" = '---h' ]; then
            echo "Find down in the tree from the invoking position all the \"Trash*\" folders and print their total size."
        else
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
        fi
    }

    DEFINED_FUNCTIONS+=('CompleteFolderName')
    function CompleteFolderName(){
        if [ "$1" = '---h' ]; then
            echo "Given one or more beta string(s) of the BaHaMAS simulation status output, the folder name(s) is(are) reconstructed."
        else
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
        fi
    }

    DEFINED_FUNCTIONS+=('GetOutputFilePath')
    function GetOutputFilePath(){
        if [ "$1" = '---h' ]; then
            echo "Given a beta folder (possibly specified as beta string of the BaHaMAS simulation status output), the CL2QCD output filename is returned with the folder in front. The output file is hmc_output or rhmc_output depending if \"[wW]ilson\" or \"[sS]taggered\" is present in the path, respectively."
        else
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
        fi
    }

    DEFINED_FUNCTIONS+=('FindLastStandardOutput')
    function FindLastStandardOutput(){
        if [ "$1" = '---h' ]; then
            echo "Given a beta folder (possibly specified as beta string of the BaHaMAS simulation status output), the last \"?hmc.*[.]out\" file in that folder is found. The \"?\" is empty or it is a \"r\" if \"[wW]ilson\" or \"[sS]taggered\" is present in the path, respectively."
        else
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
        fi
    }

    DEFINED_FUNCTIONS+=('FindMissingTrajectories')
    function FindMissingTrajectories(){
        if [ "$1" = '---h' ]; then
            echo "The \"${EDITOR:-default}\" is opened at the (R)HMC-output-file missing lines waiting for completion. This is done for all the specified folders (possibly specified as beta string of the BaHaMAS simulation status output) and for all the missing line points in the file. The output file is hmc_output or rhmc_output depending if \"[wW]ilson\" or \"[sS]taggered\" is present in the path, respectively."
        else
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
        fi
    }

    DEFINED_FUNCTIONS+=('TimeTr')
    function TimeTr(){
        if [ "$1" = '---h' ]; then
            echo "Given a beta folder (possibly specified as beta string of the BaHaMAS simulation status output) and using the time column (10) of the (R)HMC output file, the average time per trajectory is calculated and printed with some typical simulation duration estimates. The output file is hmc_output or rhmc_output depending if \"[wW]ilson\" or \"[sS]taggered\" is present in the path, respectively. Trajectories with 0s as time are not considered in the mean."
        else
            local OUTPUT_FILE; OUTPUT_FILE=$(GetOutputFilePath "$1") #To be able to check error code, local keyword sweeps it away!
            [ $? -ne 0 ] && printf "\n \e[91mError in \"$FUNCNAME\" function, unable to reconstruct output filename!\e[0m\n\n"  1>&2 && return -1
            local TIME_AND_NUMBER_TR=( $(awk '{ time=$10; if(time!=0){sum+=time; counter+=1}} END {if(counter!=0){printf "%d", sum/counter}else{printf "%d", 0}; printf " %d", counter}' "$OUTPUT_FILE") )
            printf "\n \e[92mAmount of trajectories with non-zero time: %d   Time per trajectory: %ds\n\n" ${TIME_AND_NUMBER_TR[1]} ${TIME_AND_NUMBER_TR[0]}
            for INDEX in 1000 5000 10000 25000 50000; do
                local WALLTIME=$(Walltime $INDEX ${TIME_AND_NUMBER_TR[0]} | grep -oE "[[:digit:]]+-[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}")
                printf "\e[38;5;202m%8s\e[0m  --->  \e[38;5;39m%12s\e[0m\n" "$INDEX" "$WALLTIME"
            done
            echo ''
        fi
    }

    DEFINED_FUNCTIONS+=('ShowStd')
    function ShowStd(){
        if [ "$1" = '---h' ]; then
            echo "Given a beta folder (possibly specified as beta string of the BaHaMAS simulation status output), the last CL2QCD standard output file is displayed (it is found using the \"FindLastStandardOutput\" function). If instead a job-ID number is given as first argument the standard output of the jobscript is shown. The jobscript output must be called \"?hmc.<job-ID>.out\" and the folder with jobscripts must be \"Jobscripts\". The \"?\" is empty or it is a \"r\" if \"[wW]ilson\" or \"[sS]taggered\" is present in the path, respectively. If \"-e\" is given as second argument, the same actions are performed for the standard error."
        else
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
            else
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
        fi
    }

    DEFINED_FUNCTIONS+=('FindHighestDH')
    function FindHighestDH(){
        if [ "$1" = '---h' ]; then
            echo "Given a beta folder (possibly specified as beta string of the BaHaMAS simulation status output), the 30 trajectories with largest DH are printed in order of trajectory number. If an integer N is specified as second argument, the N trajectories with largest DH are considered. The output file is obtained using the \"GetOutputFilePath\" function."
        else
            local FOLDER_FILE; FOLDER_FILE=$(GetOutputFilePath "$1")
            [ $? -ne 0 ] && printf "\n \e[91mError in \"$FUNCNAME\" function, unable to reconstruct output filename!\e[0m\n\n"  1>&2 && return -1
            local NUMBER_TR=30
            if [[ $2 =~ ^[0-9]+$ ]]; then
                NUMBER_TR=$2
            fi
            echo ''
            awk '{printf "%8d    %g\n", $1, sqrt($8*$8)}' $FOLDER_FILE | sort -n -k2g | tail -n $NUMBER_TR | sort -k1n
            echo ''
        fi
    }

    DEFINED_FUNCTIONS+=('CheckCl2qcdOutput')
    function CheckCl2qcdOutput(){
        if [ "$1" = '---h' ]; then
            echo "Given a beta folder (possibly specified as beta string of the BaHaMAS simulation status output), the CL2QCD output file is checked using the \"${HOME}/Script/CheckCorrectnessCl2qcdOutputFile.sh\" script. The output file is obtained using the \"GetOutputFilePath\" function."
        else
            local FOLDER_FILE; FOLDER_FILE=$(GetOutputFilePath "$1")
            [ $? -ne 0 ] && printf "\n \e[91mError in \"$FUNCNAME\" function, unable to reconstruct output filename!\e[0m\n\n"  1>&2 && return -1
            printf "\e[38;5;129m\n Calling:\e[38;5;117m ${HOME}/Script/CheckCorrectnessCl2qcdOutputFile.sh $FOLDER_FILE\n\e[0m"
            bash ${HOME}/Script/CheckCorrectnessCl2qcdOutputFile.sh $FOLDER_FILE
        fi
    }
    
fi

#============================================================================================================================#
#Aliases to call the Root 3D histogram program
if [ $LOAD_ROOTHIST_ALIASES = "TRUE" ]; then
    
    function CreateRootHistograms(){
        if [ "$1" = '---h' ]; then
            echo "Help not available!"
        else
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
        fi
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
unset -f __static__PrintHelp
