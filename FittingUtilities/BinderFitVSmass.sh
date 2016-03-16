#!/bin/bash

# This fit script is suited to perform a multi-branch LINEAR fit of some data contained in
# the file FILE_WITH_DATA_TO_BE_FITTED. It is in particular fitting the Binder linearly
# at different masses. The finite size scaling form used in the fit for the Binder Cumulant reads
# 
#          B4(m,ns) = B4(m,ns=inf) + a*(m-mc)*ns^(1/nu) + ...  :=  a0 + a1*x + ...
#
# It is quite general, due to the command line parameters.


#TODO: 1) write command line parser
#      2) command line options: --mc | --criticalMass      (starting value for fit)
#                               --nu | --criticalExponent  (starting value for fit) 
#                               --a0 | --B4infinity        (starting value for fit) 
#                               --a1 | --linearCoefficient (starting value for fit) 
#                               --dataFilename | -f
#                               --doNotFixB4 (in this case also B4 should be fitted)
#                               --outputFilename | -o
#      3) adjust code accordingly (basically only CreateGnuplotFit function)
#         NOTE: the fit with B4 not fixed is commented below, just add if cases also
#               in the printing information in fit_title


source $HOME/Script/PathManagement.sh || exit -2

rm -f $NAME_OF_TMP_FILE

#FIT PARAMETERS
CRITICAL_MASS="0.1"
CRITICAL_EXPONENT="0.5"
B4INFINITY="1.604"
LINEAR_COEFFICIENT="1"
FIT_LOWER_BOUND="" 
FIT_UPPER_BOUND=""

#FIT OPTIONS
FIXB4="TRUE"
QUIET_MODE="FALSE"


#VARIABLES FOR THE SCRIPT
NAME_OF_TMP_FILE="tmpFileWithDataToBePlotted.tmp"
TMP_FILE_FOR_GNUPLOT="FileThatHopefullyDoesNotExist.plt"
FILE_WITH_DATA_TO_BE_FITTED="poly_sq_BinderCumulantAtBetaC.dat"
FILE_WITH_DATA_TO_BE_PLOTTED=$FILE_WITH_DATA_TO_BE_FITTED
OUTPUT_FILENAME="BinderCumulant_poly_sq_Fit.tex"
SEPERATE_MASS_VALUES="FALSE"
MIN_SHIFT="0.0001"
OBSERVABLE="poly_sq"

while [ $# -gt 0 ]; do
    case $1 in
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
        -l | --fitLowerBound) #make not mandatory
            FIT_LOWER_BOUND=$2
            shift
            ;;
        -u | --fitUpperBound) #make not mandatory
            FIT_UPPER_BOUND=$2
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
        -f | --dataFilename)
            FILE_WITH_DATA_TO_BE_FITTED=$2
            shift
            ;;
        --doNotFixB4)
            FIXB4="FALSE"
            ;;
        -o | --outputFilename) 
            OUTPUT_FILENAME=$2
            shift
            ;;
        --obs | --observable)
            OBSERVABLE=$2
            shift
            ;;
        -h)
            echo "--mc | --criticalMass"
            echo "--nu | --criticalExponent"
            echo "--a0 | --B4infinity"
            echo "--a1 | --linearCoefficient"
            echo "--dataFilename | -f               -> Mandatory option - Specify the name of the file containing the data to be fitted."
            echo "--doNotFixB4"
            echo "--outputFilename | -o"
            echo "-l | --fitLowerBound              -> If not given, the lower bound will be determined to be 95% of the minimal kappa."
            echo "-u | --fitUpperBound              -> If not given, the upper bound will be determined to be 1.05% of the maximal kappa."
            echo "-s | --seperateMassValues         -> Specify a value by which the points of the mass values will be shifted such that their error bars do not overlap."
            echo "                                  -> E.g. -s 0.05 for 5% of the whole fitting range."
            echo "                                  -> This is just for readability of the plot and the shifted mass values will not be used for the fit."
            echo "-q | --quietMode"
            echo "--obs | --observable              -> default: poly_sq"
            echo "--tfn | --texFileName"
            exit
            ;;
    esac
    shift
done

[ "$FILE_WITH_DATA_TO_BE_FITTED" = "" ] && echo "No data filename given - specify via -f | --dataFilename option...exiting" && exit

function ReadDataFile(){
    VOLUMES=( $(awk '$0 !~ /^([[:space:]]*#|$)/ {print $2}' $FILE_WITH_DATA_TO_BE_FITTED | sort -un) ) 
    MASS_PARAMETER_VALUES=( $(awk '$0 !~ /^([[:space:]]*#|$)/ {print $1}' $FILE_WITH_DATA_TO_BE_FITTED | sort -un) ) 
}

function CreateGnuplotFit(){
    if [ -f $TMP_FILE_FOR_GNUPLOT ]; then
        printf "\n\e[38;5;9m Temporary file for gnuplot already existing, aborting!\n\n\e[0m"
        exit -1;
    fi
    # Values of volumes
    for INDEX in ${!VOLUMES[@]}
    do
        echo ns$INDEX=${VOLUMES[$INDEX]} >> $TMP_FILE_FOR_GNUPLOT
    done
    # Starting values for fit params
    echo "mc=$CRITICAL_MASS" >> $TMP_FILE_FOR_GNUPLOT
    echo "nu=$CRITICAL_EXPONENT"  >> $TMP_FILE_FOR_GNUPLOT
    echo "a=$B4INFINITY"  >> $TMP_FILE_FOR_GNUPLOT
    echo "b=$LINEAR_COEFFICIENT"      >> $TMP_FILE_FOR_GNUPLOT
    # Terminal get the fit in .tex
    echo 'set terminal lua tikz standalone solid preamble '"'"'\usepackage{amsmath, mathabx}'"'" >> $TMP_FILE_FOR_GNUPLOT
    echo 'set fit errorvariables  # to get the errors' >> $TMP_FILE_FOR_GNUPLOT
    # Fit function
    # linear model: f(x) = a + b*(x-mc)*Ns**1/nu     with variables a,b,mc,nu independent of Ns
    for INDEX in ${!VOLUMES[@]}; do
        echo "fns${INDEX}(x) = a  + b*(x-mc)*ns${INDEX}**(1./nu)" >> $TMP_FILE_FOR_GNUPLOT
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
    if [ "$FIXB4" = "FALSE" ]; then 
        echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 via  a, mc, b, nu' >> $TMP_FILE_FOR_GNUPLOT
    elif [ "$FIXB4" = "TRUE" ]; then
    # Fit with B4 fixed to true value
        echo 'a_err=0' >> $TMP_FILE_FOR_GNUPLOT
        echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 via  mc, b, nu' >> $TMP_FILE_FOR_GNUPLOT
    fi
    #--------------------------------------------------------------------------------------------------------#
    # Prepare the plot surrounding information and save it as pdf
    # Just uncomment the desired of the following two lines

    ###############################################################################################################################################################################TO-DO: Generalize the following line to staggered and wilson!
    #echo 'commit=system('"'"'printf "\n\ncommit $(git log --pretty=format:"%H" -n 1 -- ${PWD%%StaggeredNf3Test/*}/fitPbpBinder.plt)"'"'"')' >> $TMP_FILE_FOR_GNUPLOT
    echo 'commit="commit msg"' >> $TMP_FILE_FOR_GNUPLOT
    # Evaluate the goodness of the fit: probability that, given the fit, the data could have occurred with a chisquare greater than or equal to the value found
    echo 'ndf = FIT_NDF'                          >> $TMP_FILE_FOR_GNUPLOT  # Number of degrees of freedom
    echo 'chisq = FIT_STDFIT**2 * ndf'            >> $TMP_FILE_FOR_GNUPLOT  # chi-squared
    echo 'Q = 1 - igamma(0.5 * ndf, 0.5 * chisq)' >> $TMP_FILE_FOR_GNUPLOT  # the quality of fit parameter Q -> NOTE: From version 5.0 this is in the variable FIT_P (activated by "set fit errorscaling")
    # Plot information
    [ "$STAGGERED" = "TRUE" ] && echo 'set xlabel "$m$"'    >> $TMP_FILE_FOR_GNUPLOT 
    [ "$WILSON" = "TRUE" ] && echo 'set xlabel "$\\kappa$"'       >> $TMP_FILE_FOR_GNUPLOT 
    echo 'set ylabel "$B_4$"'                               >> $TMP_FILE_FOR_GNUPLOT  
    echo 'set key at graph 0.3, graph 0.95 spacing 1.75'    >> $TMP_FILE_FOR_GNUPLOT 
    echo 'set xrange[fitrange_low : fitrange_high]'         >> $TMP_FILE_FOR_GNUPLOT
    echo 'set mxtics'                                       >> $TMP_FILE_FOR_GNUPLOT
    [ "$OBSERVABLE" = "Pbp" ] && echo 'fit_title = "Fit to $B_4( \\langle\\bar\\Psi\\Psi\\rangle )$ of form $\\to B_4(\\infty) + a(m - m_c)\\cdot N_{s}^{(1/\\nu)}$\n\n with "\'         >> $TMP_FILE_FOR_GNUPLOT
    [ "$OBSERVABLE" = "poly_sq" ] && echo 'fit_title = "Fit to $B_4( \\langle L_{sq}\\rangle )$ of form $\\to B_4(\\infty) + a(m - m_c)\\cdot N_{s}^{(1/\\nu)}$\n\n with "\'             >> $TMP_FILE_FOR_GNUPLOT
    [ "$FIXB4" = "TRUE" ] && echo '            .sprintf("$B_4(\\infty)=%.3f\\; fixed\\quad a=%.4f\\pm%.4f\\quad \\nu=%.4f\\pm%.4f$\n\n$m_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\'          >> $TMP_FILE_FOR_GNUPLOT
    [ "$FIXB4" = "FALSE" ] && echo '            .sprintf("$B_4(\\infty)=%.4f\\pm%.4f\\quad a=%.4f\\pm%.4f\\quad \\nu=%.4f\\pm%.4f$\n\n$m_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\'          >> $TMP_FILE_FOR_GNUPLOT
    [ "$FIXB4" = "FALSE" ] && echo '            , a, a_err/FIT_STDFIT, b, b_err/FIT_STDFIT, nu, nu_err/FIT_STDFIT, mc, mc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                                       >> $TMP_FILE_FOR_GNUPLOT
    [ "$FIXB4" = "TRUE" ] && echo '            , a, b, b_err/FIT_STDFIT, nu, nu_err/FIT_STDFIT, mc, mc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                              >> $TMP_FILE_FOR_GNUPLOT
    echo '            .sprintf("\n\n%s", commit)'                                                                                                                                  >> $TMP_FILE_FOR_GNUPLOT
    echo 'set title fit_title'                                        >> $TMP_FILE_FOR_GNUPLOT
    echo 'set output "'$OUTPUT_FILENAME'"'                              >> $TMP_FILE_FOR_GNUPLOT 
    echo 'set style arrow 1 filled head lt 0 lc -1 lw .5'             >> $TMP_FILE_FOR_GNUPLOT
    #TO-DO: GENERALIZE THE FOLLOWING LINE
   # echo 'set arrow from mc,fns1(mc) to mc,graph(0,0) arrowstyle 1'   >> $TMP_FILE_FOR_GNUPLOT
    echo -n 'plot   '                                                  >> $TMP_FILE_FOR_GNUPLOT
    for INDEX in ${!VOLUMES[@]}; do
        echo '"'$FILE_WITH_DATA_TO_BE_PLOTTED'"' index $INDEX u 1:6:7 pt 1 lc $(($INDEX+1)) w e title '"$N_s=$ "'.ns$INDEX '\' >> $TMP_FILE_FOR_GNUPLOT   #pt = pointtype
        echo -n ', fns'$INDEX'(x) notitle lt 1 lc '$(($INDEX+1))                                                     >> $TMP_FILE_FOR_GNUPLOT  #lt = linetype; lc = linecolor
       [ $INDEX -lt $((${#VOLUMES[@]}-1)) ] && echo -n ' ,'                                                          >> $TMP_FILE_FOR_GNUPLOT
       [ $INDEX -lt $((${#VOLUMES[@]}-1)) ] && echo ' \'                                                          >> $TMP_FILE_FOR_GNUPLOT
    done
    echo >> $TMP_FILE_FOR_GNUPLOT
    #echo 'plot   "'$FILE_WITH_DATA_TO_BE_FITTED'" index 0 u 1:6:7 pt 1 lc 0 w e title "$N_s=$ ".ns1 \'>> $TMP_FILE_FOR_GNUPLOT 
    #echo '     , fns1(x) notitle lt 1 lc 0 \'                                                         >> $TMP_FILE_FOR_GNUPLOT
    #echo '     , "'$FILE_WITH_DATA_TO_BE_FITTED'" index 1 u 1:6:7 pt 1 lc 1 w e title "$N_s=$".ns2 \' >> $TMP_FILE_FOR_GNUPLOT 
    #echo '     , fns2(x) notitle lt 1 lc 1 \'                                                         >> $TMP_FILE_FOR_GNUPLOT
    #echo '     , "'$FILE_WITH_DATA_TO_BE_FITTED'" index 2 u 1:6:7 pt 1 lc 2 w e title "$N_s=$".ns3 \' >> $TMP_FILE_FOR_GNUPLOT
    #echo '     , fns3(x) notitle lt 1 lc 2'                                                           >> $TMP_FILE_FOR_GNUPLOT
    #echo 'unset arrow' >> $TMP_FILE_FOR_GNUPLOT
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
