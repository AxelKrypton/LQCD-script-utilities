#!/usr/bin/env bash

#--------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source "${HOME}/Script/PathManagement.sh" || exit -2
#--------------------------------------------------------------------------------#

rm -f $temporaryDataForFit

# Fit parameters
criticalMass='0.1'
criticalExponent='0.6301'
kurtosisInfinity='1.604'
linearCoefficient='1'

# Fit options
fixKurtosisInfinity='TRUE'
fixCriticalExponent='TRUE'

# Variables for the script
fileWithGatheredKurtosisData='pbp_BinderCumulantAtBetaC.dat'
temporaryDataForFit='tmpFileWithDataToBePlotted.tmp'
TMP_FILE_FOR_GNUPLOT='FileThatHopefullyDoesNotExist.plt'
observable='pbp'
numberFlavours=''

# Output utilities
function FatalAndExit()
{
    printf "\n  \e[1;91mERROR:\e[22m $@\e[0m\n\n"
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

while [ $# -gt 0 ]; do
    case $1 in
        -j | --jackknife)
            useJackknife='TRUE'
            shift
            ;;
        -b | --bootstrap) 
            useBootstrap='TRUE'
            shift
            ;;
        -f | --dataFilename)
            fileWithGatheredKurtosisData=$2
            shift
            ;;
        --nf | --numberOfFlavours)
            numberFlavours=$2
            shift
            ;;
        --mc | --criticalMass)
            criticalMass=$2
            shift
            ;;
        --nu | --criticalExponent)
            criticalExponent=$2
            shift
            ;;
        --a0 | --B4infinity)
            kurtosisInfinity=$2
            shift
            ;;
        --a1 | --linearCoefficient)
            linearCoefficient=$2
            shift
            ;;
        --doNotFixB4)
            fixKurtosisInfinity="FALSE"
            ;;
        --doNotfixNu)
            fixCriticalExponent="FALSE"
            ;;
        --obs | --observable)               
            observable=$2
            shift
            ;;
	    * ) printf "\n\e[0;31m Invalid option \e[1m$1\e[0;31m (see help for further information)! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
    shift
done

if [[ ${observable} != 'pbp' ]]; then
    FatalAndExit 'Only the pbp is implemented as observable at the moment.'
    exit 1
fi

OUTPUT_FILENAME='KurtosisFit'
if [[ ${useJackknife} = ${useBootstrap} ]]; then
    FatalAndExit 'Either the -b or the -j option must be given.'
    exit 1
elif [[ ${useJackknife} = 'TRUE' ]]; then
    OUTPUT_FILENAME+='_JackknifeEstimators.dat'
elif [[ ${useBootstrap} = 'TRUE' ]]; then
    OUTPUT_FILENAME+='_BootstrapEstimators.dat'
fi

if [[ "${fileWithGatheredKurtosisData}" = '' ]]; then
    fileWithGatheredKurtosisData="${observable}_BinderCumulantAtBetaC.dat"
    Info "No data filename specified - using \"${fileWithGatheredKurtosisData}\""
fi
if [[ ! -f "${fileWithGatheredKurtosisData}" ]]; then
    FatalAndExit "Data file \"${fileWithGatheredKurtosisData}\" NOT found."
    exit 1
fi

FatalAndExit 'Script still to be implemented!'; exit 1
















function ReadDataFile(){
    VOLUMES=( $(awk '$0 !~ /^([[:space:]]*#|$)/ {print $2}' $fileWithGatheredKurtosisData | sort -un) ) 
    MASS_PARAMETER_VALUES=( $(awk '$0 !~ /^([[:space:]]*#|$)/ {print $1}' $fileWithGatheredKurtosisData | sort -un) ) 
}

function CreateGnuplotFit(){
    if [ -f $TMP_FILE_FOR_GNUPLOT ]; then
        printf "\n\e[38;5;9m Temporary file for gnuplot already existing, aborting!\n\n\e[0m"
        exit -1;
    fi
    #Since the gnuplot fit syntax changed from version 4 to version 5, let's define here some handy variables
    local GNUPLOT_VERSION=$(gnuplot -V | awk '{print int($2)}')
    if [ $GNUPLOT_VERSION -le 4 ]; then
        local FIT_ERRORS_STRING=''
    else
        local FIT_ERRORS_STRING='zerrors'
    fi
    # Values of volumes
    for INDEX in ${!VOLUMES[@]}
    do
        echo ns$INDEX=${VOLUMES[$INDEX]} >> $TMP_FILE_FOR_GNUPLOT
    done
    # Starting values for fit params
    #echo "set fit noerrorscaling" >> $TMP_FILE_FOR_GNUPLOT # From version 5.0 to get the errors correct and not to divide them by the sqrt of chi2. See https://sourceforge.net/p/gnuplot/bugs/1511/
    echo "mc=$criticalMass" >> $TMP_FILE_FOR_GNUPLOT
    echo "nu=$criticalExponent"  >> $TMP_FILE_FOR_GNUPLOT
    echo "a=$kurtosisInfinity"  >> $TMP_FILE_FOR_GNUPLOT
    echo "b=$linearCoefficient"      >> $TMP_FILE_FOR_GNUPLOT
    if [ "$FIT_TYPE" = "linear" ]; then
        echo "b2=0"      >> $TMP_FILE_FOR_GNUPLOT
        echo "b2_err=0"      >> $TMP_FILE_FOR_GNUPLOT
    elif [ "$FIT_TYPE" = "cubic" ]; then
        echo "b2=$CUBIC_COEFFICIENT"      >> $TMP_FILE_FOR_GNUPLOT
    fi
    echo "ny=$ytminusyh"      >> $TMP_FILE_FOR_GNUPLOT
    echo "bfactor=$bfactor"      >> $TMP_FILE_FOR_GNUPLOT

    # Terminal get the fit in .tex
    #
    # ATTENTION: Gnuplot has some support files for the lua tikz terminal that should be installed
    #            somewhere in the tex distribution when gnuplot gets installed. If these are missing
    #            or present but produced with a different version of gnuplot than that in use, there
    #            could be problems in the later compilation of the .tex file. This happens, for example,
    #            using gnuplot 5.0 and having the support files of gnuplot 4.6. 
    #            Reading http://tex.stackexchange.com/questions/267031/tikz-problem-since-texlive-2015-update
    #            and in particular the comment of Akira Kakuto to the answer of egreg, it is possible to
    #            create the support files locally from where the gnuplot script is run and be sure that
    #            the latex compilations finds the correct support files. That is what we do here!
    #
    echo 'set term lua tikz latex createstyle' >> $TMP_FILE_FOR_GNUPLOT #Creates support files locally
    echo 'set terminal lua tikz standalone preamble '"'"'\usepackage{amsmath, mathabx}'"'" >> $TMP_FILE_FOR_GNUPLOT
    echo 'set fit errorvariables  # to get the errors' >> $TMP_FILE_FOR_GNUPLOT
    # Fit function
    # linear model: f(x) = a + b*(x-mc)*Ns**1/nu     with variables a,b,mc,nu independent of Ns
    for INDEX in ${!VOLUMES[@]}; do
        if [ "$USECORRECTIONTERM" = "TRUE" ]
        then
            if [ "$FIT_TYPE" = "linear" ]; then
                echo "fns${INDEX}(x) = (a  + b*(x-mc)*ns${INDEX}**(1./nu))*(1+bfactor*ns${INDEX}**(ny))" >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo "fns${INDEX}(x) = (a  + b*(x-mc)*ns${INDEX}**(1./nu) + b2*(x-mc)**3*ns${INDEX}**(3./nu))*(1+bfactor*ns${INDEX}**(ny))" >> $TMP_FILE_FOR_GNUPLOT
            fi
        else
            if [ "$FIT_TYPE" = "linear" ]; then
                echo "fns${INDEX}(x) = a  + b*(x-mc)*ns${INDEX}**(1./nu)" >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo "fns${INDEX}(x) = a  + b*(x-mc)*ns${INDEX}**(1./nu) + b2*(x-mc)**3*ns${INDEX}**(3./nu)" >> $TMP_FILE_FOR_GNUPLOT
            fi
        fi
    done
    echo -n 'fit_data(x,y) = ' >> $TMP_FILE_FOR_GNUPLOT
    for INDEX in ${!VOLUMES[@]}; do
        echo -n "y==$INDEX ? fns${INDEX}(x) : (" >> $TMP_FILE_FOR_GNUPLOT
    done
    echo  -n "1./0"  >> $TMP_FILE_FOR_GNUPLOT
    for INDEX in ${!VOLUMES[@]}; do
        echo -n ")"  >> $TMP_FILE_FOR_GNUPLOT
    done
    echo '' >> $TMP_FILE_FOR_GNUPLOT
    # Fit range
    echo "fitrange_low = $FIT_LOWER_BOUND" >> $TMP_FILE_FOR_GNUPLOT
    echo "fitrange_high = $FIT_UPPER_BOUND" >> $TMP_FILE_FOR_GNUPLOT

    # Actual fit
    [ "$QUIET_MODE" = "TRUE" ] && echo 'set fit quiet' >> $TMP_FILE_FOR_GNUPLOT

    if [ "$fixKurtosisInfinity" = "FALSE" ] && [ "$fixCriticalExponent" = "FALSE" ]; then 
        if [ "$USECORRECTIONTERM" = "TRUE" ]
        then
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, nu, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, b2, nu, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            fi
        else
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, nu' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, b2, nu' >> $TMP_FILE_FOR_GNUPLOT
            fi
        fi
    elif [ "$fixKurtosisInfinity" = "TRUE" ] && [ "$fixCriticalExponent" = "FALSE" ]; then
    # Fit with B4 fixed to true value
        echo 'a_err=0' >> $TMP_FILE_FOR_GNUPLOT
        if [ "$USECORRECTIONTERM" = "TRUE" ]
        then
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, nu, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, b2, nu, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            fi
        else
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, nu' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, b2, nu' >> $TMP_FILE_FOR_GNUPLOT
            fi
        fi
    elif [ "$fixKurtosisInfinity" = "FALSE" ] && [ "$fixCriticalExponent" = "TRUE" ]; then
        if [ "$USECORRECTIONTERM" = "TRUE" ]
        then
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, b2, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            fi
        else
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, b2' >> $TMP_FILE_FOR_GNUPLOT
            fi
        fi
        echo 'nu_err=0' >> $TMP_FILE_FOR_GNUPLOT
    elif [ "$fixKurtosisInfinity" = "TRUE" ] && [ "$fixCriticalExponent" = "TRUE" ]; then
        echo 'a_err=0' >> $TMP_FILE_FOR_GNUPLOT
        echo 'nu_err=0' >> $TMP_FILE_FOR_GNUPLOT
        if [ "$USECORRECTIONTERM" = "TRUE" ]
        then
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, b2, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            fi
        else
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$fileWithGatheredKurtosisData'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, b2' >> $TMP_FILE_FOR_GNUPLOT
            fi
        fi
    fi
    #--------------------------------------------------------------------------------------------------------#
    # Prepare the plot surrounding information and save it as pdf
    #TODO: Generalize the following line to staggered and wilson!
    local ABSOLUTE_PATH_TO_DIR_OF_THIS_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local THIS_FILENAME=$(basename "${BASH_SOURCE[0]}")
    local GIT_COMMIT_OF_LAST_MODIFICATION_TO_THIS_FILE=$(git -C $ABSOLUTE_PATH_TO_DIR_OF_THIS_FILE log --pretty=format:"%H" -n 1 -- $THIS_FILENAME)
    echo 'commit="\ncommit '$GIT_COMMIT_OF_LAST_MODIFICATION_TO_THIS_FILE'"' >> $TMP_FILE_FOR_GNUPLOT
    #echo 'commit="commit msg"' >> $TMP_FILE_FOR_GNUPLOT
    # Evaluate the goodness of the fit: probability that, given the fit, the data could have occurred with a chisquare greater than or equal to the value found
    echo 'ndf = FIT_NDF'                          >> $TMP_FILE_FOR_GNUPLOT  # Number of degrees of freedom
    echo 'chisq = FIT_STDFIT**2 * ndf'            >> $TMP_FILE_FOR_GNUPLOT  # chi-squared
    echo 'Q = 1 - igamma(0.5 * ndf, 0.5 * chisq)' >> $TMP_FILE_FOR_GNUPLOT  # the quality of fit Q -> NOTE: From version 5.0 this is in the variable FIT_P (and the option "set fit noerrorscaling" gives correct errors!)
    # Plot information
    [ "$STAGGERED" = "TRUE" ] && echo 'set xlabel "$m$"'    >> $TMP_FILE_FOR_GNUPLOT 
    [ "$WILSON" = "TRUE" ] && echo 'set xlabel "$\\kappa$"'    >> $TMP_FILE_FOR_GNUPLOT
    [ "$STAGGERED" = "TRUE" ] && echo 'set ylabel "$B_4(\\beta_c,m,N_\\sigma)$"'    >> $TMP_FILE_FOR_GNUPLOT
    [ "$WILSON" = "TRUE" ] && echo 'set ylabel "$B_4(\\beta_c,\\kappa,N_\\sigma)$"'    >> $TMP_FILE_FOR_GNUPLOT
    echo 'set key at graph 0.4, graph 0.95 spacing 1.75'    >> $TMP_FILE_FOR_GNUPLOT
    [ "$numberFlavours" != "" ] && echo 'set label "$N_f = '${numberFlavours}'$" at graph 0.85,0.1 center'           >> $TMP_FILE_FOR_GNUPLOT
    echo 'set xrange[fitrange_low : fitrange_high]'         >> $TMP_FILE_FOR_GNUPLOT
    echo 'set mxtics'                                       >> $TMP_FILE_FOR_GNUPLOT

    if [ "$FIT_TYPE" = "linear" ]; then
        [ $WILSON = 'TRUE' ] &&    FIT_FORM='B_4(\\infty) + a(\\kappa - \\kappa_{c})\\cdot N_{s}^{(1/\\nu)}'
        [ $STAGGERED = 'TRUE' ] && FIT_FORM='B_4(\\infty) + a(m - m_{c})\\cdot N_{s}^{(1/\\nu)}'
    elif [ "$FIT_TYPE" = "cubic" ]; then
        [ $WILSON = 'TRUE' ] &&    FIT_FORM='B_4(\\infty) + a(\\kappa - \\kappa_{c})\\cdot N_{s}^{(1/\\nu)} + b(\\kappa - \\kappa_{c})^3\\cdot N_{s}^{(3/\\nu)}'
        [ $STAGGERED = 'TRUE' ] && FIT_FORM='B_4(\\infty) + a(m - m_{c})\\cdot N_{s}^{(1/\\nu)} + b(m - m_{c})^3\\cdot N_{s}^{(3/\\nu)}'
    fi

    [ "$observable" = "pbp" ] && echo 'fit_title = "Fit to $B_4( \\langle\\bar\\Psi\\Psi\\rangle )$ of form $\\to B_4(\\infty) + a(m - m_c)\\cdot N_{s}^{(1/\\nu)}$\n\n"\'         >> $TMP_FILE_FOR_GNUPLOT
    if [ "$USECORRECTIONTERM" = "TRUE" ]
    then
        [ "$observable" = "poly_sq" ] && echo 'fit_title = "Fit to $B_4( \\langle L_{sq}\\rangle )$ of form $\\to ('$FIT_FORM')(1+BN_{s}^{y_{t}-y_{h}})$\n\n $y_{t}-y_{h}='$ytminusyh'\\quad$ "\'             >> $TMP_FILE_FOR_GNUPLOT
    else
        [ "$observable" = "poly_sq" ] && echo 'fit_title = "Fit to $B_4( \\langle L_{sq}\\rangle )$ of form $\\to '$FIT_FORM'$\n\n "\'             >> $TMP_FILE_FOR_GNUPLOT
    fi
    [ "$fixKurtosisInfinity" = "TRUE" ] && [ "$fixCriticalExponent" = "FALSE" ] && echo '            .sprintf("$B_4(\\infty)=%.3f\\; \\text{(fixed)}\\quad a=%.3f\\pm%.3f\\quad b=%.3f\\pm%.3f$\n\n $\\nu=%.4f\\pm%.4f\\quad m_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\'          >> $TMP_FILE_FOR_GNUPLOT
    [ "$fixKurtosisInfinity" = "FALSE" ] && [ "$fixCriticalExponent" = "FALSE" ] && echo '            .sprintf("$B_4(\\infty)=%.4f\\pm%.4f\\quad a=%.3f\\pm%.3f\\quad b=%.3f\\pm%.3f$\n\n $\\nu=%.4f\\pm%.4f\\quad m_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\'          >> $TMP_FILE_FOR_GNUPLOT
    [ "$fixKurtosisInfinity" = "FALSE" ] && [ "$fixCriticalExponent" = "FALSE" ] && echo '            , a, a_err/FIT_STDFIT, b, b_err/FIT_STDFIT, b2, b2_err/FIT_STDFIT, nu, nu_err/FIT_STDFIT, mc, mc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                                       >> $TMP_FILE_FOR_GNUPLOT
    [ "$fixKurtosisInfinity" = "TRUE" ] && [ "$fixCriticalExponent" = "FALSE" ] && echo '            , a, b, b_err/FIT_STDFIT, b2, b2_err/FIT_STDFIT, nu, nu_err/FIT_STDFIT, mc, mc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                              >> $TMP_FILE_FOR_GNUPLOT

    [ "$fixKurtosisInfinity" = "TRUE" ] && [ "$fixCriticalExponent" = "TRUE" ] && echo '            .sprintf("$B_4(\\infty)=%.3f\\; \\text{(fixed)}\\quad a=%.3f\\pm%.3f\\quad b=%.3f\\pm%.3f$\n\n $\\nu=%.4f\\; \\text{(fixed)}\\quad m_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\'          >> $TMP_FILE_FOR_GNUPLOT
    [ "$fixKurtosisInfinity" = "FALSE" ] && [ "$fixCriticalExponent" = "TRUE" ] && echo '            .sprintf("$B_4(\\infty)=%.4f\\pm%.4f\\quad a=%.3f\\pm%.3f\\quad b=%.3f\\pm%.3f$\n\n $\\nu=%.4f\\; \\text{(fixed)}\\quad m_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\'          >> $TMP_FILE_FOR_GNUPLOT
    [ "$fixKurtosisInfinity" = "FALSE" ] && [ "$fixCriticalExponent" = "TRUE" ] && echo '            , a, a_err/FIT_STDFIT, b, b_err/FIT_STDFIT, b2, b2_err/FIT_STDFIT, nu, mc, mc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                                       >> $TMP_FILE_FOR_GNUPLOT
    [ "$fixKurtosisInfinity" = "TRUE" ] && [ "$fixCriticalExponent" = "TRUE" ] && echo '            , a, b, b_err/FIT_STDFIT, b2, b2_err/FIT_STDFIT, nu, mc, mc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                              >> $TMP_FILE_FOR_GNUPLOT
    if [ "$USECORRECTIONTERM" = "TRUE" ]
    then
        echo '      .sprintf("\n\n $B=%.2f\\pm%.2f$",bfactor,bfactor_err/FIT_STDFIT)\' >> $TMP_FILE_FOR_GNUPLOT
        for VOLUME in ${VOLUMES[@]}; do
            echo '.sprintf("$\\quad C(%d)=%.2f\\pm%.2f$",'$VOLUME',bfactor*'$VOLUME'**ny,(bfactor_err/FIT_STDFIT)*'$VOLUME'**ny)\'  >> $TMP_FILE_FOR_GNUPLOT
        done
        echo '.sprintf("\n\n")\'  >> $TMP_FILE_FOR_GNUPLOT
        for VOLUME in ${VOLUMES[@]}; do
            echo '.sprintf("$\\quad B_4(\\infty,%d)=%.2f\\pm%.2f$",'$VOLUME',a*(1+bfactor*'$VOLUME'**ny),a*(bfactor_err/FIT_STDFIT)*'$VOLUME'**ny)\'  >> $TMP_FILE_FOR_GNUPLOT
        done
    fi
    if [ "$PRINTCOMMIT" = "TRUE" ]
    then
        echo '            .sprintf("\n%s", commit)'                                                                                                                                  >> $TMP_FILE_FOR_GNUPLOT
    else
        echo '            .sprintf("\n")'                                                                                                                                  >> $TMP_FILE_FOR_GNUPLOT
    fi
    [ "$SUPPRESS_TITLE" = "FALSE" ] && echo 'set title fit_title'                                        >> $TMP_FILE_FOR_GNUPLOT
    echo 'set output "'$OUTPUT_FILENAME'"'                              >> $TMP_FILE_FOR_GNUPLOT 
    echo 'set style arrow 1 filled head lt 0 lc -1 lw .5'             >> $TMP_FILE_FOR_GNUPLOT
    #TODO: GENERALIZE THE FOLLOWING LINE
    # echo 'set arrow from mc,fns1(mc) to mc,graph(0,0) arrowstyle 1'   >> $TMP_FILE_FOR_GNUPLOT
    if [ "$SET_Y_RANGE" = "TRUE" ]; then
        echo "set yrange [$FIT_Y_RANGE_LOW:$FIT_Y_RANGE_HIGH]"      >> $TMP_FILE_FOR_GNUPLOT
    fi
    if [ ${PLOT_ONLY_DATA} = 'TRUE' ]; then
        echo -n 'plot  a lw 0.1 lc 0 notitle, '                           >> $TMP_FILE_FOR_GNUPLOT
    else
        echo -n 'plot    '                           >> $TMP_FILE_FOR_GNUPLOT
    fi
    for INDEX in ${!VOLUMES[@]}; do
        echo '"'$FILE_WITH_DATA_TO_BE_PLOTTED'"' index $INDEX u 1:6:7 pt 1 lt 1 lc $(($INDEX+1)) w e title '"$N_\\sigma=$ "'.ns$INDEX '\' >> $TMP_FILE_FOR_GNUPLOT   #pt = pointtype
        if [ ${PLOT_ONLY_DATA} = 'FALSE' ]; then
            echo -n ', fns'$INDEX'(x) notitle lt 1 lc '$(($INDEX+1))                                                                      >> $TMP_FILE_FOR_GNUPLOT   #lt = linetype; lc = linecolor
        fi
        [ $INDEX -lt $((${#VOLUMES[@]}-1)) ] && echo -n ' ,'                                                                              >> $TMP_FILE_FOR_GNUPLOT
        [ $INDEX -lt $((${#VOLUMES[@]}-1)) ] && echo ' \'                                                                                 >> $TMP_FILE_FOR_GNUPLOT
    done
    echo >> $TMP_FILE_FOR_GNUPLOT
    echo 'unset arrow' >> $TMP_FILE_FOR_GNUPLOT

    if [ "$USECORRECTIONTERM" = "TRUE" ]
    then
        echo 'print " "' >> $TMP_FILE_FOR_GNUPLOT
        for VOLUME in ${VOLUMES[@]}; do
            echo 'print sprintf("%.3f*%d^(%.4f)=%.3f",bfactor,'$VOLUME',ny,bfactor*'$VOLUME'**ny)'  >> $TMP_FILE_FOR_GNUPLOT
        done
    fi
    echo 'set print "-"' >> $TMP_FILE_FOR_GNUPLOT
    TMP_VAR1='print sprintf("Script & $%.6g \pm %.6g$ & $%.6g \pm %.6g$ '
    TMP_VAR2='mc, mc_err/FIT_STDFIT, b, b_err/FIT_STDFIT'
    if [ $FIT_TYPE = "cubic" ]; then
	    TMP_VAR1="${TMP_VAR1}& $%.6g "'\pm'" %.6g$"
	    TMP_VAR2="${TMP_VAR2}, b2, b2_err/FIT_STDFIT"
    fi
    if [ "$USECORRECTIONTERM" = "TRUE" ]; then
	    echo "bfactor if succeeded"
	    TMP_VAR1="${TMP_VAR1}& $%.6g "'\pm'" %.6g$"
	    TMP_VAR2="${TMP_VAR2}, bfactor, bfactor_err/FIT_STDFIT"
    fi
    TMP_VAR1="${TMP_VAR1}& $%.6g$\","
    TMP_VAR2="${TMP_VAR2}, FIT_STDFIT**2)"
    echo "$TMP_VAR1$TMP_VAR2" >> $TMP_FILE_FOR_GNUPLOT    
}

function RunGnuplotScriptAndProducePdf(){
    gnuplot $TMP_FILE_FOR_GNUPLOT 1>> /dev/null
    pdflatex $OUTPUT_FILENAME 1>> /dev/null
}

function CleanAuxiliaryFiles(){
    rm $TMP_FILE_FOR_GNUPLOT
    rm $OUTPUT_FILENAME
    rm fit.log
    rm ${OUTPUT_FILENAME/.tex/.log}
    rm ${OUTPUT_FILENAME/.tex/.aux}
    local SUPPORT_GNUPLOT_LUATEX_FILES=("gnuplot-lua-tikz-common.tex"  "gnuplot-lua-tikz.sty"  "gnuplot-lua-tikz.tex"  "t-gnuplot-lua-tikz.tex")
    rm ${SUPPORT_GNUPLOT_LUATEX_FILES[@]}
}

function ReplaceMassValueInFile(){
    
  awk -v oldMassValue=$1 -v shiftValue=$2 'BEGIN{
        counter=0;
        newMassValue=oldMassValue
        regexString="^"oldMassValue
    }
    $0 ~ regexString{newMassValue=oldMassValue+shiftValue*counter; replaceString=sprintf("%.4f",newMassValue); counter++;}
    {
        gsub(regexString,replaceString);
        print;
    }' $FILE_WITH_DATA_TO_BE_PLOTTED > AwkFile.tmp && mv AwkFile.tmp $FILE_WITH_DATA_TO_BE_PLOTTED
}

ReadDataFile

[ "$FIT_LOWER_BOUND" = "" ] && FIT_LOWER_BOUND=$(awk -v value=${MASS_PARAMETER_VALUES[0]} 'BEGIN{print value*0.95}')
[ "$FIT_UPPER_BOUND" = "" ] && FIT_UPPER_BOUND=$(awk -v value=${MASS_PARAMETER_VALUES[-1]} 'BEGIN{print value*1.05}')

if [ "$SEPERATE_MASS_VALUES" = "TRUE" ]; then
    TOTAL_SHIFT=$(awk -v relShift=$RELATIVE_SHIFT -v value1=${MASS_PARAMETER_VALUES[0]} -v value2=${MASS_PARAMETER_VALUES[-1]} 'BEGIN{print relShift*(value2-value1)}')
    $(awk -v totalShift=$TOTAL_SHIFT -v minShift=$MIN_SHIFT 'BEGIN{if(totalShift < minShift){print "true"}else{print "false"}}') &&  BELOW_MIN_SHIFT="TRUE" && OLD_TOTAL_SHIFT=$TOTAL_SHIFT && TOTAL_SHIFT=$MIN_SHIFT
    cp $fileWithGatheredKurtosisData $FILE_WITH_DATA_TO_BE_PLOTTED
    for MASS in ${MASS_PARAMETER_VALUES[@]}; do
        ReplaceMassValueInFile $MASS $TOTAL_SHIFT
    done
fi

CreateGnuplotFit
RunGnuplotScriptAndProducePdf
CleanAuxiliaryFiles
evince ${OUTPUT_FILENAME/.tex/.pdf} &

if [ "$SEPERATE_MASS_VALUES" = "TRUE" ] && [ "$BELOW_MIN_SHIFT" = "TRUE" ]; then
    echo 
    echo "Warning: Specified relativ shift results in a smaller total shift ($OLD_TOTAL_SHIFT) than then the minimal allowed shift with $MIN_SHIFT. Setting total shift to minimal allowed shift $MIN_SHIFT."
    echo
fi
