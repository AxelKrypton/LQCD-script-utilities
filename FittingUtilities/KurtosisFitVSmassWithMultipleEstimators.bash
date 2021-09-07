#!/usr/bin/env bash

#--------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source "${HOME}/Script/PathManagement.sh" || exit -2
#--------------------------------------------------------------------------------#

function CleanAuxiliaryFiles()
{
    cd "${invokingDirectory}"
    if [[ -d "${temporaryWorkingDirectory}" ]]; then
        rm -r "${temporaryWorkingDirectory}"
    fi
}

trap 'CleanAuxiliaryFiles; echo' EXIT

# Fit parameters
criticalMass='0.1'
criticalExponent='0.6301'
kurtosisInfinity='1.604'
linearCoefficient='1'

# Fit options
fixKurtosisInfinity='TRUE'
fixCriticalExponent='TRUE'

# Variables for the script
readonly reweightedDataDiskPath='/home/phil-configs/Staggered'
readonly invokingDirectory="${PWD}"
readonly temporaryDataForFit='dataToBeFitted.dat'
readonly temporaryGnuplotScript='gnuplotFitScript.plt'
readonly observable='pbp'
temporaryWorkingDirectory=''
fileWithGatheredKurtosisData="${observable}_KurtosisAtBetaC.dat"
volumes=()
massParameterValues=()
massVolumesPairs=()
fitLowerBound=''
fitUpperBound=''
nfValue=''
muValue='0'
ntValue=''
declare -A bootstrapEstimatorsFiles

# Output utilities
function FatalAndExit()
{
    printf "\n  \e[1;91mFATAL:\e[22m $@\e[0m\n" 1>&2
    exit 1
}

function Error()
{
    printf "\n  \e[1;91mERROR:\e[22m $@\e[0m\n" 1>&2
}

function Warning()
{
    printf "\n  \e[1;93mWARNING:\e[22m $@\e[0m\n" 1>&2
}

function Info()
{
    printf "\n  \e[1;92mINFO:\e[22m $@\e[0m\n"
}


#Parse command line parameters
function ElementInArray()
{
    local element
    for element in "${@:2}"; do [[ "$element" == "$1" ]] && return 0; done
    return 1
}

if ElementInArray "--help" $@ || ElementInArray "-h" $@; then
    printf "\n  \e[38;5;202m%s\e[0m"\
           "This fit script is suited to perform a multi-branch LINEAR fit of the kurtosis VS mass"\
           "for multiple data set in order to obtain estimators from each fit parameter. In this"\
           "way the error on parameters obtained in each fit is discarded and all the estimators"\
           "are then used to obtain a more solid error on each parameter. Two approaches are possible."\
           ''\
           "JACKKNIFE:"\
           "  Given the N kurtosis values with error, N fits are done to obtain Jackknife estimators,"\
           "  each leaving out a kurtosis point. Jackknife estimators are then used in the standard"\
           "  way to obtain the central value of the fit parameters with Jackknife errors. See e.g."\
           "  equations (2.160) and (2.161) of Berg's book."\
           ''\
           "BOOTSTRAP:"\
           "  Assuming that each kurtosis value is coming from a reweighting, the bootstrap estimators"\
           "  files are looked for and used to extract the kurtosis value at the zero of the skewness."\
           "  In this sense skewness and kurtosis of the observable must have been reweighted together"\
           "  using PLASMA. For each bootstrap estimator at each mass and volume, a kurtosis value without"\
           "  error is gathered and to it the error of the complete reweighting is associated. In this"\
           "  way it is possible to perform a fit obtaining a bootstrap estimator for each parameter."\
           "  These are in the end combined in the standard way, e.g. with eq. (3.41) of Barkema's book." ""
    printf "\n  \e[38;5;11m\e[1m%s:\e[22m\n"\
           "Further option to the script"
    printf "\n  \e[38;5;14m%s\e[0m"\
           " -j   | --jackknife               -> Use Jackknife approach                                "\
           " -b   | --bootstrap               -> Use bootstrap approach                                "\
           " -f   | --dataFilename            -> default: ${fileWithGatheredKurtosisData}              "\
           "--mc  | --criticalMass            -> default: ${criticalMass}                              "\
           "--nu  | --criticalExponent        -> default: ${criticalExponent}                          "\
           "--a0  | --B4infinity              -> default: ${kurtosisInfinity}                          "\
           "--a1  | --linearCoefficient       -> default: ${linearCoefficient}                         "\
           "--obs | --observable              -> default: ${observable}                                "\
           "--doNotFixB4                      -> If given, B4(m,ns=inf) is extracted as fit parameters."\
           "                                     The initial value for the fit is set by --a0.         "\
           "--doNotfixNu                      -> If given, nu is extracted as fit parameters.          "\
           "                                     The initial value for the fit is set by --nu.         "\
           ''
    printf "\n  \e[38;5;229m%s\e[0m"\
           "--nf  | --nFlavour                -> mandatory for bootstrap                               "\
           "--nt  | --nTime                   -> mandatory for bootstrap                               "
    printf "\n"
    exit 3
fi

# Gnuplot fit syntax changed from version 4 to version 5 but version 5 should be available, support only this!
if [[ $(gnuplot -V | awk '{print int($2)}') -lt 5 ]]; then
    FatalAndExit 'At least v5.0 of gnuplot is required to run this script.'
fi

while [ $# -gt 0 ]; do
    case $1 in
        -j | --jackknife)
            useJackknife='TRUE'
            ;;
        -b | --bootstrap) 
            useBootstrap='TRUE'
            ;;
        -f | --dataFilename)
            fileWithGatheredKurtosisData="$2"
            shift
            ;;
       --mc | --criticalMass)
            criticalMass="$2"
            shift
            ;;
        --nu | --criticalExponent)
            criticalExponent="$2"
            shift
            ;;
        --a0 | --B4infinity)
            kurtosisInfinity="$2"
            shift
            ;;
        --a1 | --linearCoefficient)
            linearCoefficient="$2"
            shift
            ;;
        --doNotFixB4)
            fixKurtosisInfinity="FALSE"
            ;;
        --doNotfixNu)
            fixCriticalExponent="FALSE"
            ;;
        --obs | --observable)               
            observable="$2"
            shift
            ;;
        --nf | --nFlavour)
            if [[ $2 =~ ^[0-9]([.][0-9])?$ ]]; then
                nfValue="$2"
            else
                FatalAndExit "Value of option $1 wrongly specified."
            fi
            shift
            ;;
        --nt | --nTime)
            if [[ $2 =~ ^[1-9][0-9]*$ ]]; then
                ntValue="$2"
            else
                FatalAndExit "Value of option $1 wrongly specified."
            fi
            shift
            ;;
	    * )
            FatalAndExit "Invalid option \e[1m$1\e[0;91m (see help for further information)."
            ;;
    esac
    shift
done

if [[ ${observable} != 'pbp' ]]; then
    FatalAndExit 'Only the pbp is implemented as observable at the moment.'
fi

outputFilename="${invokingDirectory}/KurtosisFit"
if [[ ${useJackknife} = ${useBootstrap} ]]; then
    FatalAndExit 'Either the -b or the -j option must be given.'
elif [[ ${useJackknife} = 'TRUE' ]]; then
    outputFilename+='_JackknifeEstimators.dat'
elif [[ ${useBootstrap} = 'TRUE' ]]; then
    outputFilename+='_BootstrapEstimators.dat'
    if [[ ${nfValue} = '' || ${muValue} = '' || ${ntValue} = '' ]]; then
        FatalAndExit 'Options --nf and --nt must be specified for booststrap method.'
    fi
fi
outputResultFilename="${outputFilename/%Estimators.dat/.dat}"
if [[ -f "${outputFilename}" ]]; then
    FatalAndExit "Output data file \"${outputFilename}\" already existing."
fi
if [[ -f "${outputResultFilename}" ]]; then
    FatalAndExit "Output data file \"${outputResultFilename}\" already existing."
fi

if [[ ! ${fileWithGatheredKurtosisData} =~ ^/ ]]; then
    fileWithGatheredKurtosisData="${invokingDirectory}/${fileWithGatheredKurtosisData}"
fi
if [[ ! -f "${fileWithGatheredKurtosisData}" ]]; then
    FatalAndExit "Data file \"${fileWithGatheredKurtosisData}\" NOT found."
fi

#=============================================================================================================================#

function DetermineFitRanges()
{
    fitLowerBound=$(awk -v value="${massParameterValues[ 0]}" 'BEGIN{print value*0.95}')
    fitUpperBound=$(awk -v value="${massParameterValues[-1]}" 'BEGIN{print value*1.05}')
}

function ReadDataFile()
{
    volumes=(             $(awk '$0 !~ /^([[:space:]]*#|$)/ {print $2}'      "${fileWithGatheredKurtosisData}" | sort -n | uniq) ) 
    massParameterValues=( $(awk '$0 !~ /^([[:space:]]*#|$)/ {print $1}'      "${fileWithGatheredKurtosisData}" | sort -n | uniq) ) 
    massVolumesPairs=(    $(awk '$0 !~ /^([[:space:]]*#|$)/ {print $1"_"$2}' "${fileWithGatheredKurtosisData}" | sort -V | uniq) ) 
}

# NOTE: Here we assume that the data-to-be-fitted file exists!
function CreateGnuplotFit() # Version 5 or later assumed!
{
    local fileWithDataToBeFitted index fitCommand
    fileWithDataToBeFitted="$1"

    # Redirect stdout to gnuplot file
    exec 3>&1 1>"${temporaryGnuplotScript}"

    # Values of volumes as gnuplot variables
    for index in ${!volumes[@]}; do
        printf "ns$index=${volumes[index]}\n"
    done

    # Starting values for fit parameters and fit range
    printf '%s\n'\
           "mc=${criticalMass}"\
           "nu=${criticalExponent}"\
           "a=${kurtosisInfinity}"\
           "b=${linearCoefficient}"\
           "fitrange_low = $fitLowerBound"\
           "fitrange_high = $fitUpperBound"

    # From version 5.0 to get the errors correct and not to divide them by the sqrt of chi2. See https://sourceforge.net/p/gnuplot/bugs/1511/
    printf 'set fit noerrorscaling\n'

    # Fit function: f(x) = a + b*(x-mc)*Ns**1/nu     with variables a,b,mc,nu independent of Ns
    for index in ${!volumes[@]}; do
        printf "f_ns${index}(x) = a  + b*(x-mc)*ns${index}**(1./nu)\n"
    done
    # Multi-branch fit achieved using a nan (1/0) on a branch in gnuplot
    printf 'fit_data(x,y) = '
    for index in ${!volumes[@]}; do
        printf "y==$index ? f_ns${index}(x) : ("
    done
    printf "1./0"
    for index in ${!volumes[@]}; do
        printf ")"
    done
    printf '\n\n'

    # Actual fit
    printf 'set fit quiet\n'
    fitCommand="fit [fitrange_low:fitrange_high] fit_data(x,y) \"${fileWithDataToBeFitted}\" u 1:-2:6:7 zerrors via  mc, b"

    if [[ ${fixKurtosisInfinity} = 'FALSE' ]]; then
        fitCommand+=', a'
    else
        printf 'a_err=0\n'
    fi
    if [ ${fixCriticalExponent} = 'FALSE' ]; then
        fitCommand+=', nu'
    else
        printf 'nu_err=0\n'
    fi
    printf "${fitCommand}\n"

    # Evaluate the goodness of the fit: probability that, given the fit, the data could have occurred with a chisquare greater than or equal to the value found
    printf '%s\n'\
           'ndf = FIT_NDF'\
           'chisq = FIT_STDFIT**2 * ndf'\
           'Q = FIT_P'\
           ''

    # Print result of the fit from within gnuplot to standard output
    printf '%s\n'\
           'set print "-"'\
           'print sprintf("%.6e %.6e    %.6e %.6e    %.6e %.6e    %.6e %.6e    %2d    %6.3f    %5.2f", a, a_err,   b, b_err,    mc, mc_err,   nu, nu_err,   ndf, chisq/ndf, 100*Q)'

    # Restore standard output redirection to terminal
    exec 1>&3 3>&-
}

function CreateAndMoveTotemporaryWorkingDirectory()
{
    if temporaryWorkingDirectory=$(mktemp -d "Tmp_fit_dir.XXXXXXXX"); then
        cd "${temporaryWorkingDirectory}"
    else
        FatalAndExit 'Unable to create a temporary working directory'
    fi
}

function PrintHeaderToOutputFile()
{
    printf '#%11s %-12s    %12s %-12s    %12s %-12s    %12s %-12s   %3s   %8s   %-5s\n'\
           'B4' 'B4_error'\
           'a' 'a_error'\
           'm_c' 'm_c_error'\
           'nu' 'nu_error'\
           'NDF'\
           'chi2/ndf'\
           'Q' > "${outputFilename}"
}

function PrintResultToOutputAndToOutputFile()
{
    printf '%s' "$1" >> "${outputFilename}"
    printf '\e[92m%s\e[0m' "$1"
}

#=============================================================================================================================#

function CountNotEmptyUncommentedLines() # use '#' as comment symbol
{
    local filename="$1"
    if [[ ! -f "${filename}" ]]; then
        FatalAndExit "File \"${filename}\" not found in function \"${FUNCNAME}\"."
    fi
    awk '$0 !~ /^([[:space:]]*#|$)/{count++} END{print count}' "${filename}"
}

function CommentNthNotEmptyUncommentedLines() # use '#' as comment symbol
{
    local filename number
    filename="$1"
    number="$2"
    if [[ ! -f "${filename}" ]]; then
        FatalAndExit "File \"${filename}\" not found in function \"${FUNCNAME}\"."
    fi
    if [[ ! ${number} =~ ^[1-9][0-9]*$ ]]; then
        FatalAndExit "Invalid number passed to function \"${FUNCNAME}\"."
    fi
    awk -i inplace -v num="${number}"\
        '
        BEGIN{found=0}
        $0 !~ /^([[:space:]]*#|$)/ {
            count++
            if(count==num){
                print "#"$0
                found=1
            }else{
                print $0
            }
            next
        }
        {
            print $0
        }
        END{if(found==0){exit 1}}' "${filename}" || FatalAndExit "Asked to comment out not existing data-line ${number} in file \"${filename}\"."
}

function CalculateJaccknifeMeanAndErrorOfColumn()
{
    local filename column mean
    filename="$1"
    column="$2"
    if [[ ! -f "${filename}" ]]; then
        FatalAndExit "File \"${filename}\" not found in function \"${FUNCNAME}\"."
    fi
    if [[ ! ${column} =~ ^[1-9][0-9]*$ ]]; then
        FatalAndExit "Invalid column number passed to function \"${FUNCNAME}\"."
    fi
    mean=$(awk -v col="${column}" 'NR>1{sum+=$col; counter++} END{printf "%.6e", sum/counter}' "${filename}")
    awk -v col="${column}"\
        -v mean="${mean}"\
        '
        NR>1 {
            sum+=($col - mean)^2
            counter++
        }
        END{ printf "%.6e %.6e", mean, sqrt(sum*(counter-1)/counter)}' "${filename}"
}

#=============================================================================================================================#

function GetEstimatorFileGlobalpathAndCheckIfItExists()
{
    local mass volume fileGlobalPath
    mass="${1#0.}"
    volume="$2"
    fileGlobalPath="${reweightedDataDiskPath}/Nf${nfValue}/mui0/mass${mass}/nt${ntValue}/ns${volume}/Nf${nfValue}_mui0_mass${mass}_nt${ntValue}_ns${volume}_reweighting/Nf${nfValue}_mui0_mass${mass}_nt${ntValue}_ns${volume}_${observable}_reweighted_estimators.dat"
    printf "${fileGlobalPath}"
    if [[ -f "${fileGlobalPath}" ]]; then
        return 0
    else
        return 1
    fi
}

function BuildListOfReweightingBootstrapEstimatorsFiles()
{
    local index pair file mass volume filesNotFound
    filesNotFound=()
    for index in "${!massVolumesPairs[@]}"; do
        pair="${massVolumesPairs[index]}"
        mass="${pair%_*}"
        volume="${pair#*_}"
        file=$(GetEstimatorFileGlobalpathAndCheckIfItExists "${mass}" "${volume}")
        if [[ $? -eq 0 ]]; then
            bootstrapEstimatorsFiles["${pair}"]="${file}"
        else
            filesNotFound+=( "${file}" )
            # TODO (?): unset pair and implement skipping mechanism if files are not found.
        fi
    done
    if [[ ${#filesNotFound[@]} -ne 0 ]]; then
        Error 'The following estimators files were not found:'
        printf '\t\e[38;5;202m %s\e[0m\n' "${filesNotFound[@]}"
        FatalAndExit 'Impossible to continue.'
    fi
}

function GetNumberOfBootstrapEstimators()
{
    local file estimatorNumbers number
    estimatorNumbers=()
    for file in "${bootstrapEstimatorsFiles[@]}"; do
        estimatorNumbers+=( $(tail -n1 "${file}" | awk 'END{print $1}' ) )
    done
    readarray -d $'\0' -t estimatorNumbers < <(printf '%s\0' "${estimatorNumbers[@]}" | sort -z | uniq -z)
    if [[ ${#estimatorNumbers[@]} -gt 1 ]]; then
        Warning " Different numer of bootstrap estimators found, using minimum one (last discarded)."
        for number in "${estimatorNumbers[@]}"; do
            if [[ ${number} < ${estimatorNumbers[0]} ]]; then
                estimatorNumbers[0]=${number}
            fi
        done
    fi
    printf "$((estimatorNumbers[0] + 1))"
}

function GetKurtosisAtZeroSkewnessForEstimator()
{
    local number pair file
    number="$1"
    pair="$2"
    file="${bootstrapEstimatorsFiles[${pair}]}"
    awk -v estimator="${number}" '
        function abs(v) {return v < 0 ? -v : v}
        BEGIN{lastB3=0; found=0}
        $1 == estimator{
            if(lastB3*$7<0)
            {
                B4 = (abs(lastB3)<abs($7)) ? lastB4 : $9
                found++
            }
            lastB3=$7
            lastB4=$9
        }
        END{print B4; if(found==1){exit 0}else{exit 1}}' "${file}"
    # The return value of the function is that of awk (last executed command)
}

function ReplaceKurtosisInTemporaryFileToBeFitted()
{
    local fileWithDataToBeFitted pair newKurtosis
    fileWithDataToBeFitted="$1"
    pair="$2"
    newKurtosis="$3"
    awk -i inplace\
        -v mass="${pair%_*}"\
        -v volume="${pair#*_}"\
        -v newB4="${newKurtosis}"\
        '
        $0 ~ /^([[:space:]]*#|$)/ { print $0; next }
        {
            if($1 == mass && $2 == volume)
                $6=newB4
            print $0
        }
        ' "${fileWithDataToBeFitted}"
}

function DrawProgressBarHeader()
{
    local index
    printf '\n   0%%'
    for((index=20; index<100; index+=20)); do
        printf '%0.s ' {1..17}
        printf '%d%%' "${index}"
    done
    printf '%0.s ' {1..17}
    printf '100%%\n'
}

# This function relies on the caller variable 'progressBarUpdatePercentage'
function DrawProgressBar()
{
    local doneNumber totalNumber donePercentage doneString remainingTimeEstimate
    doneNumber="$1"
    totalNumber="$2"
    if [[ ! -v startTime ]]; then
        startTime=$(date +'%s')
    fi
    donePercentage=$(( doneNumber * 100 / totalNumber ))
    doneString="   ($(printf "%${#totalNumber}d" "${doneNumber}" )/${totalNumber})"
    if [[ ${donePercentage} -ge ${progressBarUpdatePercentage} ]]; then
        (( progressBarUpdatePercentage++ ))
        if [[ ${donePercentage} -eq 0 ]]; then
            progressBar="   [$(printf '%0.s.' {1..100})]${doneString}\r"
        elif [[ ${donePercentage} -eq 100 ]]; then
            progressBar="   [$(printf '%0.s=' {1..100})]${doneString}\r"
        else
			remainingTimeEstimate=$(bc -l <<< "($(date +%s) - ${startTime})/${donePercentage}*(100-${donePercentage})" | awk '{printf "%5d", $1}')
            progressBar="   [$(printf '%0.s=' $(seq 1 ${donePercentage}))$(printf '%0.s.' $(seq 1 $((100-${donePercentage}))))]${doneString}   ${remainingTimeEstimate} sec. to end\e[K\r"
        fi
        printf "${progressBar}"
    fi
}

function CalculateBootstrapErrorOfColumn()
{
    local filename column
    filename="$1"
    column="$2"
    if [[ ! -f "${filename}" ]]; then
        FatalAndExit "File \"${filename}\" not found in function \"${FUNCNAME}\"."
    fi
    if [[ ! ${column} =~ ^[1-9][0-9]*$ ]]; then
        FatalAndExit "Invalid column number passed to function \"${FUNCNAME}\"."
    fi
    awk -v col="${column}"\
        '
        NR>1 {
            sum+=$col
            sumsq+=($col)^2
            counter++
        }
        END{ printf "%.6e", sqrt(sumsq/counter-(sum/counter)^2)}' "${filename}"
}

#=============================================================================================================================#

CreateAndMoveTotemporaryWorkingDirectory
ReadDataFile
DetermineFitRanges
PrintHeaderToOutputFile

if [[ ${useJackknife} = 'TRUE' ]]; then
    numberOfJackknifeEstimators=$(CountNotEmptyUncommentedLines "${fileWithGatheredKurtosisData}")
    CreateGnuplotFit "${temporaryDataForFit}"
    for((index=1; index<=numberOfJackknifeEstimators; index++)); do
        cp "${fileWithGatheredKurtosisData}" "${temporaryDataForFit}"
        CommentNthNotEmptyUncommentedLines "${temporaryDataForFit}" ${index}
        gnuplot "${temporaryGnuplotScript}" >> "${outputFilename}"
        if [[ $? -ne 0 ]]; then
            FatalAndExit "Error in fit to produce Jackknife estimator number ${index}."
        fi
    done
    mcResult=(   $(CalculateJaccknifeMeanAndErrorOfColumn "${outputFilename}" 5)  ) # Use word splitting to split value and error
    chi2Result=( $(CalculateJaccknifeMeanAndErrorOfColumn "${outputFilename}" 10) )
    QResult=(    $(CalculateJaccknifeMeanAndErrorOfColumn "${outputFilename}" 11) )
    printf -v resultString\
           "\n# Jackknife analysis result:\n#\n#%12s = %s ± %s\n#%12s = %s ± %s\n#%12s = %s ± %s\n#\n"\
           'm_c' "${mcResult[0]}" "${mcResult[1]}"\
           'chi2/ndf' "${chi2Result[0]}" "${chi2Result[1]}"\
           'Q' "${QResult[0]}" "${QResult[1]}"
fi

if [[ ${useBootstrap} = 'TRUE' ]]; then
    startTime=$(date +'%s')
    CreateGnuplotFit "${temporaryDataForFit}"
    BuildListOfReweightingBootstrapEstimatorsFiles
    numberOfBootstrapEstimators=$(GetNumberOfBootstrapEstimators)
    progressBarUpdatePercentage=0
    declare -A problematicBootstrapEstimators
    numberOfProblematicBootstrapEstimators=0
    DrawProgressBarHeader
    for((index=0; index<numberOfBootstrapEstimators; index++)); do
        skipFit='FALSE'
        cp "${fileWithGatheredKurtosisData}" "${temporaryDataForFit}"
        for pair in "${massVolumesPairs[@]}"; do
            newKurtosis=$(GetKurtosisAtZeroSkewnessForEstimator "${index}" "${pair}")
            if [[ $? -ne 0 ]]; then
                problematicBootstrapEstimators["${pair}"]+="${index} "
                skipFit='TRUE'
            fi
            ReplaceKurtosisInTemporaryFileToBeFitted "${temporaryDataForFit}" "${pair}" "${newKurtosis}"
        done
        if [[ ${skipFit} = 'TRUE' ]]; then
            (( numberOfProblematicBootstrapEstimators++ ))
            continue
        fi
        gnuplot "${temporaryGnuplotScript}" >> "${outputFilename}"
        if [[ $? -ne 0 ]]; then
            FatalAndExit "Error in fit to produce bootstrap estimator number ${index}."
        fi
        DrawProgressBar "${index}" "${numberOfBootstrapEstimators}"
    done
    DrawProgressBar "${numberOfBootstrapEstimators}" "${numberOfBootstrapEstimators}"
    printf "\n\n\e[96m Bootstrap estimators produced in $(( $(date +'%s') - startTime )) seconds!\n\e[0m"

    # Fit original data for central value
    cp "${fileWithGatheredKurtosisData}" "${temporaryDataForFit}"
    centralValuesFit=( $(gnuplot "${temporaryGnuplotScript}") ) # use word splitting to split results
    mcResult=(   "${centralValuesFit[4]}"  $(CalculateBootstrapErrorOfColumn "${outputFilename}" 5)  )
    chi2Result=( "${centralValuesFit[9]}"  $(CalculateBootstrapErrorOfColumn "${outputFilename}" 10) )
    QResult=(    "${centralValuesFit[10]}" $(CalculateBootstrapErrorOfColumn "${outputFilename}" 11) )
    a0Result=(   "${centralValuesFit[2]}"  $(CalculateBootstrapErrorOfColumn "${outputFilename}" 3) )
    B4Result=( "${kurtosisInfinity}" '0.000000' )
    nuResult=( "${criticalExponent}" '0.000000' )
    if [[ ${fixKurtosisInfinity} = 'FALSE' ]]; then
        B4Result=( "${centralValuesFit[0]}" $(CalculateBootstrapErrorOfColumn "${outputFilename}" 1) )
    fi
    if [[ ${fixCriticalExponent} = 'FALSE' ]]; then
        nuResult=( "${centralValuesFit[6]}" $(CalculateBootstrapErrorOfColumn "${outputFilename}" 7) )
    fi

    # Report about broken estimators
    reportString="Unable to find kurtosis at zero of the skewness for ${numberOfProblematicBootstrapEstimators} bootstrap estimators in reweighted data:"
    if [[ ${numberOfProblematicBootstrapEstimators} -ne 0 ]]; then
        printf "\n\n# ${reportString}\n" >> "${outputFilename}"
        Error "${reportString}"
        for pair in "${!problematicBootstrapEstimators[@]}"; do
            printf "%10s\e[93m${pair}  ->  ${problematicBootstrapEstimators[${pair}]}\e[0m\n" ''
            printf "#    ${pair}  ->  ${problematicBootstrapEstimators[${pair}]}\n" '' >> "${outputFilename}"
        done
    fi

    # Report about result
    printf -v resultString\
           "\n# Bootstrap analysis result ($((numberOfBootstrapEstimators - numberOfProblematicBootstrapEstimators)) estimators):\n#\n#%12s = %s ± %s\n#%12s = %s ± %s\n#%12s = %s ± %s\n#\n"\
           'm_c' "${mcResult[0]}" "${mcResult[1]}"\
           'chi2/ndf' "${chi2Result[0]}" "${chi2Result[1]}"\
           'Q' "${QResult[0]}" "${QResult[1]}"
    printf '%1s%-5s %-5s %12s %-12s    %12s %-12s    %12s %-12s    %12s %-12s    %12s %-18s   %8s %-s\n'\
           '#' 'nf' 'nt' 'B4' 'B4_error' 'nu' 'nu_error' 'a0' 'a0_error'\
           'm_c' 'm_c_error'   'chi2/ndf' 'chi2/ndf_error'  'Q' 'Q_error'\
           ' ' "${nfValue}" "${ntValue}"\
           "${B4Result[0]}" "${B4Result[1]}"\
           "${nuResult[0]}" "${nuResult[1]}"\
           "${a0Result[0]}" "${a0Result[1]}"\
           "${mcResult[0]}" "${mcResult[1]}"\
           "${chi2Result[0]}" "${chi2Result[1]}"\
           "${QResult[0]}" "${QResult[1]}" > "${outputResultFilename}"
fi

PrintResultToOutputAndToOutputFile "${resultString}"
