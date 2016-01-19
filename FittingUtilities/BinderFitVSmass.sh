#!/bin/bash

#######################################################################################
#
#   This fit script is suited to perform a multi-branch fit of some data contained in
#   the file FILE_WITH_DATA_TO_BE_FITTED. It is in particular fitting the Binder linearly
#   at different masses (staggered simulations at mu=0) in the chiral sector of the
#   Columbia plot (nf=3 and pbp as observable). The finite size scaling form used in
#   the fit for the Binder Cumulant reads
#   
#                B4(m,ns) = B4(m,ns=inf) + a*(m-mc)*ns^(1/nu) + ...
#
#######################################################################################

TMP_FILE_FOR_GNUPLOT="FileThatHopefullyDoesNotExist.plt"
FILE_WITH_DATA_TO_BE_FITTED="PbpBinderCumulantAtBetaC.dat"
TEX_FILE_NAME="BinderCumulantPbpFit.tex"

function CreateGnuplotFit(){
    if [ -f $TMP_FILE_FOR_GNUPLOT ]; then
        printf "\n\e[38;5;9m Temporary file for gnuplot already existing, aborting!\n\n\e[0m"
        exit -1;
    fi
    # Values of volumes
    echo 'ns1=8'  >> $TMP_FILE_FOR_GNUPLOT
    echo 'ns2=12' >> $TMP_FILE_FOR_GNUPLOT
    echo 'ns3=16' >> $TMP_FILE_FOR_GNUPLOT
    # Starting values for fit params
    echo 'mc=0.026' >> $TMP_FILE_FOR_GNUPLOT
    echo 'nu=0.63'  >> $TMP_FILE_FOR_GNUPLOT
    echo 'a=1.604'  >> $TMP_FILE_FOR_GNUPLOT
    echo 'b=1'      >> $TMP_FILE_FOR_GNUPLOT
    # Terminal get the fit in .tex
    echo 'set terminal lua tikz standalone solid preamble '"'"'\usepackage{amsmath, mathabx}'"'" >> $TMP_FILE_FOR_GNUPLOT
    echo 'set fit errorvariables  # to get the errors' >> $TMP_FILE_FOR_GNUPLOT
    # Fit function
    # linear model: f(x) = a + b*(x-mc)*Ns**1/nu     with variables a,b,mc,nu independent of Ns
    echo 'fns1(x) = a  + b*(x-mc)*ns1**(1/nu)' >> $TMP_FILE_FOR_GNUPLOT
    echo 'fns2(x) = a  + b*(x-mc)*ns2**(1/nu)' >> $TMP_FILE_FOR_GNUPLOT
    echo 'fns3(x) = a  + b*(x-mc)*ns3**(1/nu)' >> $TMP_FILE_FOR_GNUPLOT
    echo 'fit_data(x,y) = y==0 ?  fns1(x) : (y==1 ? fns2(x) : fns3(x))' >> $TMP_FILE_FOR_GNUPLOT
    # Fit range
    echo 'fitrange_low = 0.0200' >> $TMP_FILE_FOR_GNUPLOT
    echo 'fitrange_high = 0.045' >> $TMP_FILE_FOR_GNUPLOT
    # Actual fit
    echo 'set fit quiet' >> $TMP_FILE_FOR_GNUPLOT
    #echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 via  a, mc, b, nu' >> $TMP_FILE_FOR_GNUPLOT
    # Fit with B4 fixed to true value
    echo 'a_err=0'  >> $TMP_FILE_FOR_GNUPLOT
    echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$FILE_WITH_DATA_TO_BE_FITTED'" u 1:-2:6:7 via  mc, b, nu' >> $TMP_FILE_FOR_GNUPLOT
    #--------------------------------------------------------------------------------------------------------#
    # Prepare the plot surrounding information and save it as pdf
    # Just uncomment the desired of the following two lines
    echo 'commit=system('"'"'printf "\n\ncommit $(git log --pretty=format:"%H" -n 1 -- ${PWD%%StaggeredNf3Test/*}/fitPbpBinder.plt)"'"'"')' >> $TMP_FILE_FOR_GNUPLOT
    # Evaluate the goodness of the fit: probability that, given the fit, the data could have occurred with a chisquare greater than or equal to the value found
    echo 'ndf = FIT_NDF'                          >> $TMP_FILE_FOR_GNUPLOT  # Number of degrees of freedom
    echo 'chisq = FIT_STDFIT**2 * ndf'            >> $TMP_FILE_FOR_GNUPLOT  # chi-squared
    echo 'Q = 1 - igamma(0.5 * ndf, 0.5 * chisq)' >> $TMP_FILE_FOR_GNUPLOT  # the quality of fit parameter Q -> NOTE: From version 5.0 this is in the variable FIT_P (activated by "set fit errorscaling")
    # Plot information
    echo 'set xlabel "$m$"'                              >> $TMP_FILE_FOR_GNUPLOT 
    echo 'set ylabel "$B_4$"'                            >> $TMP_FILE_FOR_GNUPLOT  
    echo 'set key at graph 0.3, graph 0.95 spacing 1.75' >> $TMP_FILE_FOR_GNUPLOT 
    echo 'set xrange[fitrange_low : fitrange_high]'      >> $TMP_FILE_FOR_GNUPLOT
    echo 'set mxtics'                                    >> $TMP_FILE_FOR_GNUPLOT
    echo 'fit_title = "Fit to $B_4( \\langle\\bar\\Psi\\Psi\\rangle )$ of form $\\to B_4(\\infty) + a(m - m_c)\\cdot N_{s}^{(1/\\nu)}$\n\n with "\'                                          >> $TMP_FILE_FOR_GNUPLOT
    echo '            .sprintf("$B_4(\\infty)=%.3f\\; fixed\\quad a=%.4f\\pm%.4f\\quad \\nu=%.4f\\pm%.4f$\n\n$m_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\' >> $TMP_FILE_FOR_GNUPLOT
    #echo '            .sprintf("$B_4(\\infty)=%.4f\\pm%.4f\\quad a=%.4f\\pm%.4f\\quad \\nu=%.4f\\pm%.4f$\n\n$m_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\' >> $TMP_FILE_FOR_GNUPLOT
    #echo '            , a, a_err/FIT_STDFIT, b, b_err/FIT_STDFIT, nu, nu_err/FIT_STDFIT, mc, mc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                              >> $TMP_FILE_FOR_GNUPLOT
    echo '            , a, b, b_err/FIT_STDFIT, nu, nu_err/FIT_STDFIT, mc, mc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                              >> $TMP_FILE_FOR_GNUPLOT
    echo '            .sprintf("%s", commit)'                                                                                                                                  >> $TMP_FILE_FOR_GNUPLOT
    echo 'set title fit_title'                                        >> $TMP_FILE_FOR_GNUPLOT
    echo 'set output "'$TEX_FILE_NAME'"'                              >> $TMP_FILE_FOR_GNUPLOT 
    echo 'set style arrow 1 filled head lt 0 lc -1 lw .5'             >> $TMP_FILE_FOR_GNUPLOT
    echo 'set arrow from mc,fns1(mc) to mc,graph(0,0) arrowstyle 1'   >> $TMP_FILE_FOR_GNUPLOT
    echo 'plot   "'$FILE_WITH_DATA_TO_BE_FITTED'" index 0 u 1:6:7 pt 1 lc 0 w e title "$N_s=$ ".ns1 \'>> $TMP_FILE_FOR_GNUPLOT 
    echo '     , fns1(x) notitle lt 1 lc 0 \'                                                         >> $TMP_FILE_FOR_GNUPLOT
    echo '     , "'$FILE_WITH_DATA_TO_BE_FITTED'" index 1 u 1:6:7 pt 1 lc 1 w e title "$N_s=$".ns2 \' >> $TMP_FILE_FOR_GNUPLOT 
    echo '     , fns2(x) notitle lt 1 lc 1 \'                                                         >> $TMP_FILE_FOR_GNUPLOT
    echo '     , "'$FILE_WITH_DATA_TO_BE_FITTED'" index 2 u 1:6:7 pt 1 lc 2 w e title "$N_s=$".ns3 \' >> $TMP_FILE_FOR_GNUPLOT
    echo '     , fns3(x) notitle lt 1 lc 2'                                                           >> $TMP_FILE_FOR_GNUPLOT
    echo 'unset arrow' >> $TMP_FILE_FOR_GNUPLOT
}


function RunGnuplotScriptAndProducePdf(){
    gnuplot $TMP_FILE_FOR_GNUPLOT 1>> /dev/null
    pdflatex $TEX_FILE_NAME 1>> /dev/null
}


function CleanAuxiliaryFiles(){
    rm $TMP_FILE_FOR_GNUPLOT
    rm $TEX_FILE_NAME
    rm fit.log
    rm ${TEX_FILE_NAME/.tex/.log}
    rm ${TEX_FILE_NAME/.tex/.aux}    
}

CreateGnuplotFit
RunGnuplotScriptAndProducePdf
CleanAuxiliaryFiles
evince ${TEX_FILE_NAME/.tex/.pdf} &
