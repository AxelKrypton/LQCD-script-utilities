#!/bin/bash

# This fit script is suited to perform a multi-branch LINEAR fit of some data contained in
# the file FILE_WITH_DATA_TO_BE_FITTED. It is in particular fitting the Binder linearly
# at different masses. The finite size scaling form used in the fit for the Binder Cumulant reads
# 
#          B4(m,ns) = B4(m,ns=inf) + a*(m-mc)*ns^(1/nu) + ...  :=  a0 + a1*x + ...
#
# It is quite general, due to the command line parameters.

#--------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source "${HOME}/Script/PathManagement.sh" || exit -2
#--------------------------------------------------------------------------------#

rm -f $NAME_OF_TMP_FILE

#FIT PARAMETERS
CRITICAL_MASS="0.1"
CRITICAL_EXPONENT="0.6301"
B4INFINITY="1.604"
LINEAR_COEFFICIENT="1"
CUBIC_COEFFICIENT="1"
ytminusyh="-0.894"
bfactor="-1"
FIT_LOWER_BOUND="" 
FIT_UPPER_BOUND=""
SET_Y_RANGE="FALSE"

#FIT OPTIONS
FIT_TYPE="linear"
FIXB4="TRUE"
FIXNU="TRUE"
USECORRECTIONTERM="FALSE"
QUIET_MODE="FALSE"
SUPPRESS_TITLE="FALSE"
PLOT_ONLY_DATA='FALSE'
PRINTCOMMIT="FALSE"

#VARIABLES FOR THE SCRIPT
NAME_OF_TMP_FILE="tmpFileWithDataToBePlotted.tmp"
TMP_FILE_FOR_GNUPLOT="FileThatHopefullyDoesNotExist.plt"
SEPERATE_MASS_VALUES="FALSE"
MIN_SHIFT="0.0001"
OBSERVABLE=""
NFLAVOUR=""


#Parse command line parameters
function ElementInArray() {
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

if ElementInArray "--help" $@ || ElementInArray "-h" $@; then
    printf "\n\t\e[38;5;202m"
    printf "This fit script is suited to perform a multi-branch LINEAR fit of the kurtosis vs mass.\n\t"
    printf "The finite size scaling form used in the fit for the Binder Cumulant reads\n\t"
    printf "B4(m,ns) = B4(m,ns=inf) + a*(m-mc)*ns^(1/nu) + ...  :=  a0 + a1*x + ...\n\t"
    printf "Initial values for the fit can be provided for all fit parameters.\n\t"
    printf "By default B4(m,ns=inf) and nu are fixed to their expected values of 1.604 and 0.6301 respectively.\n\t"
    printf "The user can use the options --nu and --a0 to fix them at different values or a combination of the\n\t"
    printf "options --doNotFixB4, --doNotfixNu (and --nu, --a0) to extract also B4(m,ns=inf) and/or nu as fit\n\t"
    printf "parameters (and specify different starting values for them).\n\t"
    printf "\n\t\e[38;5;13m\e[1m\e[4m"
    printf "Further option to the script\e[24m:\e[21m\n\n\t\e[38;5;4m"
    printf "    -q   | --quietMode                                                                                                         \n\t"
    printf "   --st  | --suppressTitle           -> Suppresses title of the fit in case the plot is needed for a publication.              \n\t"
    printf "    -p   | --postfix                 -> Appends the specified postfix to the title.                                            \n\t"
    printf "   --nf  | --numberOfFlavours        -> If given, an N_f label is added to the plot                                            \n\t"
    printf "   --mc  | --criticalMass            -> default: 0.1                                                                           \n\t"
    printf "   --nu  | --criticalExponent        -> default: 0.6301                                                                        \n\t"
    printf "   --a0  | --B4infinity              -> default: 1.604                                                                         \n\t"
    printf "   --a1  | --linearCoefficient       -> default: 1                                                                             \n\t"
    printf "   --a2  | --cubicCoefficient        -> default: 1                                                                             \n\t"
    printf "    -f   | --dataFilename            -> default: poly_sq_BinderCumulantAtBetaC.dat                                             \n\t"
    printf "    -o   | --outputFilename          -> default: BinderCumulant_poly_sq_Fit.pdf                                                \n\t"
    printf "    -l   | --fitLowerBound           -> If not given, the lower bound will be determined to be 95%% of the minimal mass.       \n\t"
    printf "    -u   | --fitUpperBound           -> If not given, the upper bound will be determined to be 105%% of the maximal mass.      \n\t"
    printf "   --yr  | --fityRange               -> Sets y-range of fit. Option expects two numbers: yrange-low yrange-high                \n\t"
    printf "   --obs | --observable              -> default: poly_sq                                                                       \n\t"
    printf "    -s   | --seperateMassValues      -> Specify a value by which the points of the mass values will be shifted such that       \n\t"
    printf "                                     -> their error bars do not overlap. E.g. \"-s 0.05\" for 5%% of the whole fitting range.  \n\t"
    printf "                                     -> This is just for readability and the shifted mass values will not be used for the fit. \n\t"
    printf "    -c | --useCorrectionTerm         -> If given, the correction term (1+BN^(yt-yh)) is multiplied to correct for              \n\t"
    printf "                                        finite volume effects at large N_tau.                                                  \n\t"
    printf "   --cubic                           -> Produces cubic fit                                                                     \n\t"
    printf "   --doNotFixB4                      -> If given, B4(m,ns=inf) is extracted as fit parameters.                                 \n\t"
    printf "                                        The initial value for the fit is set by --a0.                                          \n\t"
    printf "   --doNotfixNu                      -> If given, nu is extracted as fit parameters.                                           \n\t"
    printf "                                        The initial value for the fit is set by --nu.                                          \n\t"
    printf "   --plotOnlyData                    -> If given, the fit result are not displayed in the plot.                                \n\t"
    printf "   --printCommitID                                                                                                             \n\t"
    printf "\n\e[0m"
    exit 3
fi

while [ $# -gt 0 ]; do
    case $1 in
        --nf | --numberOfFlavours)
            NFLAVOUR=$2
            shift
            ;;
        --mc | --criticalMass)
            CRITICAL_MASS=$2
            shift
            ;;
        --nu | --criticalExponent)
            CRITICAL_EXPONENT=$2
            shift
            ;;
        --a0 | --B4infinity)
            B4INFINITY=$2
            shift
            ;;
        --a1 | --linearCoefficient)
            LINEAR_COEFFICIENT=$2
            shift
            ;;
        --a2 | --linearCoefficient)
            CUBIC_COEFFICIENT=$2
            shift
            ;;
        --cubic)
            FIT_TYPE="cubic"
            ;;
        -l | --fitLowerBound)
            FIT_LOWER_BOUND=$2
            shift
            ;;
        -u | --fitUpperBound)
            FIT_UPPER_BOUND=$2
            shift
            ;;
        --yr | --fityRange)
            SET_Y_RANGE="TRUE"
            FIT_Y_RANGE_LOW=$2
            shift
            FIT_Y_RANGE_HIGH=$2
            shift
            ;;
        -s | --seperateMassValues)
            SEPERATE_MASS_VALUES="TRUE"
            RELATIVE_SHIFT=$2
            FILE_WITH_DATA_TO_BE_PLOTTED=$NAME_OF_TMP_FILE
            shift
            ;;
        -q | --quietMode)
            QUIET_MODE="TRUE"
            ;;
        --st | --suppressTitle)
            SUPPRESS_TITLE="TRUE"
            ;;
        --printCommitID)
            PRINTCOMMIT="TRUE"
            ;;
        -f | --dataFilename)
            FILE_WITH_DATA_TO_BE_FITTED=$2
            shift
            ;;
        --doNotFixB4)
            FIXB4="FALSE"
            ;;
        --doNotfixNu)
            FIXNU="FALSE"
            ;;
        --plotOnlyData)
            PLOT_ONLY_DATA='TRUE'
            ;;
        -c | --useCorrectionTerm)
            USECORRECTIONTERM="TRUE"
            ;;
        -o | --outputFilename) 
            OUTPUT_FILENAME=$2
            shift
            ;;
        -p | --prefix) 
            PREFIX=$2
            shift
            ;;
        --obs | --observable)
            OBSERVABLE=$2
            shift
            ;;
	    * ) printf "\n\e[0;31m Invalid option \e[1m$1\e[0;31m (see help for further information)! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
    shift
done

[ "$OBSERVABLE" = "" ] && echo "No observable specified - using poly_sq..."
OBSERVABLE=${OBSERVABLE:-"poly_sq"}

if [ "$FIT_TYPE" = "linear" ]; then
    OUTPUT_FILENAME="BinderCumulant_${OBSERVABLE}_Fit"
elif [ "$FIT_TYPE" = "cubic" ]; then
    OUTPUT_FILENAME="BinderCumulant_${OBSERVABLE}_cubic_Fit"
fi

if [ "$USECORRECTIONTERM" = "TRUE" ]; then
    OUTPUT_FILENAME="${OUTPUT_FILENAME}_correction"
fi

if [ "$SUPPRESS_TITLE" = "TRUE" ]; then
    OUTPUT_FILENAME="${OUTPUT_FILENAME}_notitle"
fi

if [ "$PREFIX" = "" ]; then
    OUTPUT_FILENAME="${OUTPUT_FILENAME}.tex"
else
    OUTPUT_FILENAME="${OUTPUT_FILENAME}$PREFIX.tex"
fi


echo $FILE_WITH_DATA_TO_BE_FITTED
[ "$FILE_WITH_DATA_TO_BE_FITTED" = "" ] && echo "No data filename specified - using ${OBSERVABLE}_BinderCumulantAtBetaC.dat"
FILE_WITH_DATA_TO_BE_FITTED=${FILE_WITH_DATA_TO_BE_FITTED:-"${OBSERVABLE}_BinderCumulantAtBetaC.dat"}

[ ! -f "$FILE_WITH_DATA_TO_BE_FITTED" ] && echo "Specified data file ${FILE_WITH_DATA_TO_BE_FITTED} does NOT exist...exiting" && exit

if [ $SEPERATE_MASS_VALUES = "FALSE" ]; then
    FILE_WITH_DATA_TO_BE_PLOTTED=$FILE_WITH_DATA_TO_BE_FITTED
fi

function ReadDataFile(){
    VOLUMES=( $(awk '$0 !~ /^([[:space:]]*#|$)/ {print $2}' $FILE_WITH_DATA_TO_BE_FITTED | sort -un) ) 
    MASS_PARAMETER_VALUES=( $(awk '$0 !~ /^([[:space:]]*#|$)/ {print $1}' $FILE_WITH_DATA_TO_BE_FITTED | sort -un) ) 
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
    echo "mc=$CRITICAL_MASS" >> $TMP_FILE_FOR_GNUPLOT
    echo "nu=$CRITICAL_EXPONENT"  >> $TMP_FILE_FOR_GNUPLOT
    echo "a=$B4INFINITY"  >> $TMP_FILE_FOR_GNUPLOT
    echo "b=$LINEAR_COEFFICIENT"      >> $TMP_FILE_FOR_GNUPLOT
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
                echo "fns${INDEX}(x) = (a  + b*(x-mc)*ns${INDEX}**(1./nu) + b2*(x-mc)*ns${INDEX}**(3./nu))*(1+bfactor*ns${INDEX}**(ny))" >> $TMP_FILE_FOR_GNUPLOT
            fi
        else
            if [ "$FIT_TYPE" = "linear" ]; then
                echo "fns${INDEX}(x) = a  + b*(x-mc)*ns${INDEX}**(1./nu)" >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo "fns${INDEX}(x) = a  + b*(x-mc)*ns${INDEX}**(1./nu) + b2*(x-mc)*ns${INDEX}**(3./nu)" >> $TMP_FILE_FOR_GNUPLOT
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

    if [ "$FIXB4" = "FALSE" ] && [ "$FIXNU" = "FALSE" ]; then 
        if [ "$USECORRECTIONTERM" = "TRUE" ]
        then
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, nu, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, b2, nu, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            fi
        else
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, nu' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, b2, nu' >> $TMP_FILE_FOR_GNUPLOT
            fi
        fi
    elif [ "$FIXB4" = "TRUE" ] && [ "$FIXNU" = "FALSE" ]; then
    # Fit with B4 fixed to true value
        echo 'a_err=0' >> $TMP_FILE_FOR_GNUPLOT
        if [ "$USECORRECTIONTERM" = "TRUE" ]
        then
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, nu, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, b2, nu, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            fi
        else
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, nu' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, b2, nu' >> $TMP_FILE_FOR_GNUPLOT
            fi
        fi
    elif [ "$FIXB4" = "FALSE" ] && [ "$FIXNU" = "TRUE" ]; then
        if [ "$USECORRECTIONTERM" = "TRUE" ]
        then
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, b2, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            fi
        else
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  a, mc, b, b2' >> $TMP_FILE_FOR_GNUPLOT
            fi
        fi
        echo 'nu_err=0' >> $TMP_FILE_FOR_GNUPLOT
    elif [ "$FIXB4" = "TRUE" ] && [ "$FIXNU" = "TRUE" ]; then
        echo 'a_err=0' >> $TMP_FILE_FOR_GNUPLOT
        echo 'nu_err=0' >> $TMP_FILE_FOR_GNUPLOT
        if [ "$USECORRECTIONTERM" = "TRUE" ]
        then
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, b2, bfactor' >> $TMP_FILE_FOR_GNUPLOT
            fi
        else
            if [ "$FIT_TYPE" = "linear" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b' >> $TMP_FILE_FOR_GNUPLOT
            elif [ "$FIT_TYPE" = "cubic" ]; then
                echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 '$FIT_ERRORS_STRING' via  mc, b, b2' >> $TMP_FILE_FOR_GNUPLOT
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
    [ "$NFLAVOUR" != "" ] && echo 'set label "$N_f = '${NFLAVOUR}'$" at graph 0.85,0.1 center'           >> $TMP_FILE_FOR_GNUPLOT
    echo 'set xrange[fitrange_low : fitrange_high]'         >> $TMP_FILE_FOR_GNUPLOT
    echo 'set mxtics'                                       >> $TMP_FILE_FOR_GNUPLOT

    if [ "$FIT_TYPE" = "linear" ]; then
        [ $WILSON = 'TRUE' ] &&    FIT_FORM='B_4(\\infty) + a(\\kappa - \\kappa_{c})\\cdot N_{s}^{(1/\\nu)}'
        [ $STAGGERED = 'TRUE' ] && FIT_FORM='B_4(\\infty) + a(m - m_{c})\\cdot N_{s}^{(1/\\nu)}'
    elif [ "$FIT_TYPE" = "cubic" ]; then
        FIT_FORM='B_4(\\infty) + a(\\kappa - \\kappa_{c})\\cdot N_{s}^{(1/\\nu)} + b(\\kappa - \\kappa_{c})\\cdot N_{s}^{(3/\\nu)}'
    fi

    [ "$OBSERVABLE" = "pbp" ] && echo 'fit_title = "Fit to $B_4( \\langle\\bar\\Psi\\Psi\\rangle )$ of form $\\to B_4(\\infty) + a(m - m_c)\\cdot N_{s}^{(1/\\nu)}$\n\n"\'         >> $TMP_FILE_FOR_GNUPLOT
    if [ "$USECORRECTIONTERM" = "TRUE" ]
    then
        [ "$OBSERVABLE" = "poly_sq" ] && echo 'fit_title = "Fit to $B_4( \\langle L_{sq}\\rangle )$ of form $\\to ('$FIT_FORM')(1+BN_{s}^{y_{t}-y_{h}})$\n\n $y_{t}-y_{h}='$ytminusyh'\\quad$ "\'             >> $TMP_FILE_FOR_GNUPLOT
    else
        [ "$OBSERVABLE" = "poly_sq" ] && echo 'fit_title = "Fit to $B_4( \\langle L_{sq}\\rangle )$ of form $\\to '$FIT_FORM'$\n\n "\'             >> $TMP_FILE_FOR_GNUPLOT
    fi
    [ "$FIXB4" = "TRUE" ] && [ "$FIXNU" = "FALSE" ] && echo '            .sprintf("$B_4(\\infty)=%.3f\\; \\text{(fixed)}\\quad a=%.3f\\pm%.3f\\quad b=%.3f\\pm%.3f$\n\n $\\nu=%.4f\\pm%.4f\\quad m_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\'          >> $TMP_FILE_FOR_GNUPLOT
    [ "$FIXB4" = "FALSE" ] && [ "$FIXNU" = "FALSE" ] && echo '            .sprintf("$B_4(\\infty)=%.4f\\pm%.4f\\quad a=%.3f\\pm%.3f\\quad b=%.3f\\pm%.3f$\n\n $\\nu=%.4f\\pm%.4f\\quad m_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\'          >> $TMP_FILE_FOR_GNUPLOT
    [ "$FIXB4" = "FALSE" ] && [ "$FIXNU" = "FALSE" ] && echo '            , a, a_err/FIT_STDFIT, b, b_err/FIT_STDFIT, b2, b2_err/FIT_STDFIT, nu, nu_err/FIT_STDFIT, mc, mc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                                       >> $TMP_FILE_FOR_GNUPLOT
    [ "$FIXB4" = "TRUE" ] && [ "$FIXNU" = "FALSE" ] && echo '            , a, b, b_err/FIT_STDFIT, b2, b2_err/FIT_STDFIT, nu, nu_err/FIT_STDFIT, mc, mc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                              >> $TMP_FILE_FOR_GNUPLOT

    [ "$FIXB4" = "TRUE" ] && [ "$FIXNU" = "TRUE" ] && echo '            .sprintf("$B_4(\\infty)=%.3f\\; \\text{(fixed)}\\quad a=%.3f\\pm%.3f\\quad b=%.3f\\pm%.3f$\n\n $\\nu=%.4f\\; \\text{(fixed)}\\quad m_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\'          >> $TMP_FILE_FOR_GNUPLOT
    [ "$FIXB4" = "FALSE" ] && [ "$FIXNU" = "TRUE" ] && echo '            .sprintf("$B_4(\\infty)=%.4f\\pm%.4f\\quad a=%.3f\\pm%.3f\\quad b=%.3f\\pm%.3f$\n\n $\\nu=%.4f\\; \\text{(fixed)}\\quad m_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\'          >> $TMP_FILE_FOR_GNUPLOT
    [ "$FIXB4" = "FALSE" ] && [ "$FIXNU" = "TRUE" ] && echo '            , a, a_err/FIT_STDFIT, b, b_err/FIT_STDFIT, b2, b2_err/FIT_STDFIT, nu, mc, mc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                                       >> $TMP_FILE_FOR_GNUPLOT
    [ "$FIXB4" = "TRUE" ] && [ "$FIXNU" = "TRUE" ] && echo '            , a, b, b_err/FIT_STDFIT, b2, b2_err/FIT_STDFIT, nu, mc, mc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                              >> $TMP_FILE_FOR_GNUPLOT
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
    cp $FILE_WITH_DATA_TO_BE_FITTED $FILE_WITH_DATA_TO_BE_PLOTTED
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
