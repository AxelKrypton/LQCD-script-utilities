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
readonly invokingDirectory="${PWD}"
readonly temporaryDataForFit='dataToBeFitted.dat'
readonly temporaryGnuplotScript='gnuplotFitScript.plt'
readonly observable='pbp'
temporaryWorkingDirectory=''
fileWithGatheredKurtosisData='pbp_BinderCumulantAtBetaC.dat'
numberFlavours=''
volumes=()
massParameterValues=()
fitLowerBound=''
fitUpperBound=''

# Output utilities
function FatalAndExit()
{
    printf "\n  \e[1;91mERROR:\e[22m $@\e[0m\n" 1>&2
    exit 1
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
    printf "\n  \e[38;5;14m%s"\
           " -j   | --jackknife               -> Use Jackknife approach                                "\
           " -b   | --bootstrap               -> Use bootstrap approach                                "\
           "--nf  | --numberOfFlavours        -> The number of flavours to which data refers           "\
           " -f   | --dataFilename            -> default: ${fileWithGatheredKurtosisData}              "\
           "--mc  | --criticalMass            -> default: ${criticalMass}                              "\
           "--nu  | --criticalExponent        -> default: ${criticalExponent}                          "\
           "--a0  | --B4infinity              -> default: ${kurtosisInfinity}                          "\
           "--a1  | --linearCoefficient       -> default: ${linearCoefficient}                         "\
           "--obs | --observable              -> default: ${observable}                                "\
           "--doNotFixB4                      -> If given, B4(m,ns=inf) is extracted as fit parameters."\
           "                                     The initial value for the fit is set by --a0.         "\
           "--doNotfixNu                      -> If given, nu is extracted as fit parameters.          "\
           "                                     The initial value for the fit is set by --nu.         "
    printf "\e[0m\n\n"
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
        --nf | --numberOfFlavours)
            numberFlavours="$2"
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
fi
if [[ -f "${outputFilename}" ]]; then
    FatalAndExit "Output data file \"${outputFilename}\" already existing."
fi

if [[ "${fileWithGatheredKurtosisData}" = '' ]]; then
    fileWithGatheredKurtosisData="${observable}_BinderCumulantAtBetaC.dat"
    Info "No data filename specified - using \"${fileWithGatheredKurtosisData}\""
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
    volumes=( $(awk '$0 !~ /^([[:space:]]*#|$)/ {print $2}' "${fileWithGatheredKurtosisData}" | sort -un) ) 
    massParameterValues=( $(awk '$0 !~ /^([[:space:]]*#|$)/ {print $1}' "${fileWithGatheredKurtosisData}" | sort -un) ) 
}

function CreateGnuplotFit() # Version 5 or later assumed!
{
    local fileWithDataToBeFitted index fitCommand
    fileWithDataToBeFitted="$1"

    if [[ ! -f "${fileWithDataToBeFitted}" ]]; then
        FatalAndExit "Temporary data-to-be-fitted file \"${fileWithDataToBeFitted}\" not found."
    fi

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

CreateAndMoveTotemporaryWorkingDirectory
ReadDataFile
DetermineFitRanges
PrintHeaderToOutputFile

if [[ ${useJackknife} = 'TRUE' ]]; then
    numberOfJackknifeEstimators=$(CountNotEmptyUncommentedLines "${fileWithGatheredKurtosisData}")
    for((index=1; index<=numberOfJackknifeEstimators; index++)); do
        cp "${fileWithGatheredKurtosisData}" "${temporaryDataForFit}"
        CommentNthNotEmptyUncommentedLines "${temporaryDataForFit}" ${index}
        CreateGnuplotFit "${temporaryDataForFit}"
        gnuplot "${temporaryGnuplotScript}" >> "${outputFilename}"
    done
    mcResult=(   $(CalculateJaccknifeMeanAndErrorOfColumn "${outputFilename}" 5)  ) # Use word splitting to split value and error
    chi2Result=( $(CalculateJaccknifeMeanAndErrorOfColumn "${outputFilename}" 10) )
    QResult=(    $(CalculateJaccknifeMeanAndErrorOfColumn "${outputFilename}" 11) )
    printf -v resultString\
           "\n# Jackknife analysis result:\n#\n#%12s = %s ± %s\n#%12s = %s ± %s\n#%12s = %s ± %s\n#\n"\
           'm_c' "${mcResult[0]}" "${mcResult[1]}"\
           'chi2/ndf' "${chi2Result[0]}" "${chi2Result[1]}"\
           'Q' "${QResult[0]}" "${QResult[1]}"
    printf '%s' "${resultString}" >> "${outputFilename}"
    printf '\e[92m%s\e[0m' "${resultString}"
fi

if [[ ${useBootstrap} = 'TRUE' ]]; then
    FatalAndExit 'Bootstrap method not yet implemented'
fi

