function CreateGnuplotFitWithHardCodedParameters(){
#
#  Copyright (c) 2015-2017 Alessandro Sciarra
#
#  This file is part of "Script utilities".
#
#  "Script utilities" is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  "Script utilities" is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with "Script utilities". If not, see <http://www.gnu.org/licenses/>.
#

    #Since the gnuplot fit syntax changed from version 4 to version 5, let's define here some handy variables
    local GNUPLOT_VERSION=$(gnuplot -V | awk '{print int($2)}')
    if [ $GNUPLOT_VERSION -le 4 ]; then
        local FIT_ERRORS_STRING=''
    else
        local FIT_ERRORS_STRING='zerrors'
    fi
    #Remove temporary file for gnuplot if existing
    rm -f $TMP_FILE_FOR_GNUPLOT_SCRIPT
    # Values of volumes
    for INDEX in ${!NSPACE[@]}; do
        echo "ns${INDEX}=${NSPACE[$INDEX]}" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    done
    # Starting values for fit params
    echo 'bc=5.5'    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'nu=0.5'    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'B4=1.604'  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'a1=-1'      >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    [ $FIT_TYPE = 'quadratic' ] && echo 'a2=0.005'  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    # Terminal get the fit in pdf
    if [ $TEX_PLOT = 'TRUE' ]; then
        echo 'set terminal lua tikz standalone solid preamble '"'"'\usepackage{amsmath, mathabx}'"'" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    else
        echo 'set term pdfcairo color enhanced' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        echo 'set encoding iso_8859_1 # for the pm symbol' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    fi
    echo 'set fit errorvariables  # to get the errors' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    # Fit function
    # linear model:    f(x) = B4 + a1*(x-bc)*Ns**1/nu                             with variables B4,a1,bc,nu independent of Ns
    # quadratic model: f(x) = B4 + a1*(x-bc)*Ns**1/nu + a2*((x-bc)*Ns**1/nu)**2   with variables B4,a1,a2,bc,nu independent of Ns
    if [ $FIT_TYPE = 'linear' ]; then
        for INDEX in ${!NSPACE[@]}; do
            echo "fns${INDEX}(x) = B4  + a1*(x-bc)*ns${INDEX}**(1./nu)" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        done
    elif [ $FIT_TYPE = 'quadratic' ]; then
        for INDEX in ${!NSPACE[@]}; do
            echo "fns${INDEX}(x) = B4  + a1*(x-bc)*ns${INDEX}**(1./nu) + a2*(x-bc)*ns${INDEX}**(2./nu)" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        done
    fi
    echo -n 'fit_data(x,y) = ' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    for INDEX in ${!NSPACE[@]}; do
        echo -n "y==$INDEX ? fns${INDEX}(x) : (" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    done
    echo  -n "1./0"  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    for INDEX in ${!NSPACE[@]}; do
        echo -n ")"  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    done
    echo '' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    # Fit range
    echo "fitrange_low = $FIT_LOWER_BOUND" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo "fitrange_high = $FIT_UPPER_BOUND" >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    [ $QUIET_MODE = 'TRUE' ] && echo 'set fit quiet' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    # Actual fit
    # ATTENTION: Here 'set yrange' fixes which data blocks to fit, since y is the index of the data block in the fit!!
    if [ $FIT_TYPE = 'linear' ]; then
        echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$TMP_FILE_FOR_DATA_TO_BE_FITTED'" u 1:-2:8:9 '$FIT_ERRORS_STRING' via B4, bc, a1, nu' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    elif [ $FIT_TYPE = 'quadratic' ]; then
        echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) "'$TMP_FILE_FOR_DATA_TO_BE_FITTED'" u 1:-2:8:9 '$FIT_ERRORS_STRING' via B4, bc, a1, a2, nu' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    fi
    #--------------------------------------------------------------------------------------------------------#
    # Prepare the plot surrounding information and save it as pdf
    # Just uncomment the desired of the following two lines
    if [ $COMMIT_MESSAGE = 'TRUE' ]; then
        echo 'commit=sprintf("\n\n")."\\footnotesize{'$COMMIT_ID'}"' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    else
        echo 'commit=sprintf("\n")' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    fi
    # Evaluate the goodness of the fit: probability that, given the fit, the data could have occurred with a chisquare greater than or equal to the value found
    echo 'ndf = FIT_NDF'                          >> $TMP_FILE_FOR_GNUPLOT_SCRIPT  # Number of degrees of freedom
    echo 'chisq = FIT_STDFIT**2 * ndf'            >> $TMP_FILE_FOR_GNUPLOT_SCRIPT  # chi-squared
    echo 'Q = 1 - igamma(0.5 * ndf, 0.5 * chisq)' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT  # the quality of fit parameter Q -> NOTE: From version 5.0 this is in the variable FIT_P (activated by "set fit errorscaling")
    # Plot information
    if [ $TEX_PLOT = 'FALSE' ]; then
        echo 'set xlabel "{/Symbol b}"'                                  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        echo 'set ylabel "B_4"'                                          >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        echo 'set key at graph 0.9, graph 0.95 spacing 1.25'             >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        echo 'set label "'$MASS_PREFIX'=0.'$MASS'" at screen 0.92,0.96 center textcolor lt 3 font "Times, 12"' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    else
        echo 'set xlabel "$\\beta$"   '                                  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        echo 'set ylabel "$B_4$"'                                        >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        echo 'set key at graph 0.96, graph 0.95 spacing 2'             >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        echo 'set label "\\textcolor{blue}{\\fbox{\\footnotesize{$'$MASS_PREFIX'=0.'$MASS'$}}}" at screen 0.1,0.95 center' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    fi
    echo 'set xrange[fitrange_low*0.9999 : fitrange_high*1.0001]'    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'set yrange[1 : 4.5]'                                       >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'set mxtics'                                                >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    #Set plot title in latex or not linear/quadratic
    if [ $TEX_PLOT = 'FALSE' ]; then
        if [ $FIT_TYPE = 'linear' ]; then
            echo 'fit_title = "Fit to B_4(L.Im) of form {/Symbol \256} B_4({/Symbol \245}) + a_1({/Symbol b} - {/Symbol b}_c){\267}N_{s}^{(1/{/Symbol n})}\n\n with "\'                 >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
            echo '.sprintf("B_4({/Symbol \245})=%.4f\261%.4f, a_1=%.4f\261%.4f, {/Symbol n}=%.4f\261%.4f\n{/Symbol b}_c=%.5f\261%.5f, {/Symbol c}^2_{/=7 /ndf=%d} = %f, Q=%5.2f%% %s"\' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
		    echo ',B4, B4_err/FIT_STDFIT, a1, a1_err/FIT_STDFIT, nu, nu_err/FIT_STDFIT, bc, bc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100, commit)'                                 >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        elif [ $FIT_TYPE = 'quadratic' ]; then
            echo 'fit_title = "Fit to B_4(L.im) of form {/Symbol \256} B_4({/Symbol \245}) + a_1({/Symbol b} - {/Symbol b}_c){\267}N_{s}^{(1/{/Symbol n})} + a_2({/Symbol b} - {/Symbol b}_c)^{(2/{/Symbol n})}\n\n with "\'   >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
		    echo '.sprintf("B_4({/Symbol \245})=%.4f\261%.4f, a_1=%.4f\261%.4f, a_2=%.4f\261%.4f \n {/Symbol n}=%.4f\261%.4f, {/Symbol b}_c=%.5f\261%.5f, {/Symbol c}^2_{/=7 /ndf=%d} = %f, Q=%5.2f%% %s"\'                    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
		    echo ',B4, B4_err/FIT_STDFIT, a1, a1_err/FIT_STDFIT, a2, a2_err/FIT_STDFIT, nu, nu_err/FIT_STDFIT, bc, bc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100, commit)'                                                 >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        fi
    else
        if [ $FIT_TYPE = 'linear' ]; then
            echo 'fit_title = "Fit to $B_4(L_{\\text{Im}})$ of form $\\to B_4(\\infty) + a\\:(\\beta - \\beta_c)\\cdot N_{s}^{(1/\\nu)}$\n\n with "\'                                       >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
            echo '            .sprintf("$B_4(\\infty)=%.4f\\pm%.4f\\quad a=%.4f\\pm%.4f\\quad \\nu=%.4f\\pm%.4f$\n\n$\\beta_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
            echo '            , B4, B4_err/FIT_STDFIT, a1, a1_err/FIT_STDFIT, nu, nu_err/FIT_STDFIT, bc, bc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                               >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
            echo '            .sprintf("%s", commit)'                                                                                                                                       >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        elif [ $FIT_TYPE = 'quadratic' ]; then
            echo 'fit_title = "Fit to $B_4(L_{\\text{Im}})$ of form $\\to B_4(\\infty) + a(\\beta - \\beta_c)\\cdot N_{s}^{(1/\\nu)}$\n\n with "\'                                                                >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
            echo '            .sprintf("$B_4(\\infty)=%.4f\\pm%.4f\\quad a_1=%.4f\\pm%.4f\\quad a_2=%.4f\\pm%.4f \n \\nu=%.4f\\pm%.4f$\n\n$\\beta_c=%.4f\\pm%.4f\\quad \\chi^2_{ndf=%d} = %f\\quad Q=%5.2f\\%$"\' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
            echo '            , B4, B4_err/FIT_STDFIT, a1, a1_err/FIT_STDFIT, a2, a2_err/FIT_STDFIT, nu, nu_err/FIT_STDFIT, bc, bc_err/FIT_STDFIT, FIT_NDF, FIT_STDFIT**2., Q*100)\'                              >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
            echo '            .sprintf("%s", commit)'                                                                                                                                                             >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        fi
    fi
    echo 'set title fit_title'                                            >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    #Set output name
    echo 'set output  "'$OUTPUT_FILENAME'"'                               >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    #Draw other stuff
    echo 'set style arrow 1 nohead lt 0 lc -1 lw .5'                      >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'if (bc >= fitrange_low && bc <= fitrange_high){'                >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo '  set arrow 1 from bc,graph(0,0) to bc,graph(1,1) arrowstyle 1' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo '}'                                                              >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    #Key titles
    for INDEX in ${!NSPACE[@]}; do
        if [ $TEX_PLOT = 'FALSE' ]; then
            echo 'title'$INDEX' = sprintf("{/=9 Ns=".ns'$INDEX'.", {/Symbol b} {/Symbol \316} ['${BETA_RANGES[$(($INDEX*2))]}','${BETA_RANGES[$(($INDEX*2+1))]}']}")' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        else
            echo 'title'$INDEX' = sprintf("\\small{$N_s=".ns'$INDEX'.", \\beta\\in ['${BETA_RANGES[$(($INDEX*2))]}','${BETA_RANGES[$(($INDEX*2+1))]}']$}")' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        fi
    done
    #Actual plot
    echo -n 'plot ' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    for INDEX in ${!NSPACE[@]}; do
        echo '"'$(GetDatafileGlobalpath ${NSPACE[$INDEX]})'" u 1:8:9 pt 1 lc '$INDEX' w e title title'$INDEX' \'  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        echo '     , "'$TMP_FILE_FOR_DATA_TO_BE_FITTED'" index '$INDEX' u 1:8:9 pt 5 ps 0.3 lc '$INDEX' notitle \'       >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        echo -n '     , fns'$INDEX'(x) notitle lt 1 lc '$INDEX                                                           >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        if [ $INDEX -ne $((${#NSPACE[@]} - 1)) ]; then
            echo ' \'          >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
            echo -n '     , '  >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        else
            echo '' >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
        fi
    done
    #Replot with different x range
    echo 'set autoscale x'                                                 >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'set output "'${OUTPUT_FILENAME/$OBSERVABLE/all_$OBSERVABLE}      >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'unset arrow'                                                     >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'set arrow 1 from bc,graph(0,0) to bc,graph(1,1) arrowstyle 1'    >> $TMP_FILE_FOR_GNUPLOT_SCRIPT
    echo 'replot'                                                          >> $TMP_FILE_FOR_GNUPLOT_SCRIPT

    unset -v 'INDEX'
}

#=====================================================================================================================================================================================#

function CreateGnuplotTemplateFitScriptWithoutPlotting(){
    #Since the gnuplot fit syntax changed from version 4 to version 5, let's define here some handy variables
    local GNUPLOT_VERSION=$(gnuplot -V | awk '{print int($2)}')
    if [ $GNUPLOT_VERSION -le 4 ]; then
        local FIT_ERRORS_STRING=''
    else
        local FIT_ERRORS_STRING='zerrors'
    fi
    #Remove temporary file for gnuplot if existing
    rm -f $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    #Checks on mandatory variables for the template
    echo '#Checks on mandatory variables for the script' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    echo 'if (!exists("nt")){'                                      >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    echo '  print "Mandatory variable nt not provided! Exiting..."' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
	echo '  q()'                                                    >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    echo '}'                                                        >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    for INDEX in ${!NSPACE[@]}; do
        echo 'if (!exists("b'$INDEX'l") || !exists("b'$INDEX'r")){'                           >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        echo '  print "Mandatory variable b'$INDEX'l or b'$INDEX'r not provided! Exiting..."' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
	    echo '  q()'                                                                          >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        echo '}'                                                                              >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    done
    echo 'if (!exists("obs")) obs='"'"'poly_im_withZeroMean'"'" >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    if [ $WILSON = 'TRUE' ]; then
        echo 'if (!exists("kappa")){'                                      >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        echo '  print "Mandatory variable kappa not provided! Exiting..."' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
	    echo '  q()'                                                       >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        echo '}'                                                           >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    elif [ $STAGGERED = 'TRUE' ]; then
        echo 'if (!exists("mass")){'                                      >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        echo '  print "Mandatory variable mass not provided! Exiting..."' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
	    echo '  q()'                                                      >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        echo '}'                                                          >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    fi
    for INDEX in ${!NSPACE[@]}; do
        echo 'if (!exists("ns'$INDEX'")){'                                      >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        echo '  print "Mandatory variable ns'$INDEX' not provided! Exiting..."' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
	    echo '  q()'                                                            >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        echo '}'                                                                >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    done
    echo '#==========================================================================================================='  >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    #Datafiles
    echo '#Datafiles with all data' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    for INDEX in ${!NSPACE[@]}; do
        if [ $WILSON = 'TRUE' ]; then
	        echo 'fn'$INDEX' = "'$DATA_PATH_PREFIX'/Nf2/muiPiT/k".kappa."/nt".nt."/ns".ns'$INDEX'."/Nf2_muiPiT_k".kappa."_nt".nt."_ns".ns'$INDEX'."_reweighting/Nf2_muiPiT_k".kappa."_nt".nt."_ns".ns'$INDEX'."_".obs."_reweighted.dat"' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        elif [ $STAGGERED = 'TRUE' ]; then
	        echo 'fn'$INDEX' = "'$DATA_PATH_PREFIX'/Nf2/muiPiT/mass".mass."/nt".nt."/ns".ns'$INDEX'."/Nf2_muiPiT_mass".mass."_nt".nt."_ns".ns'$INDEX'."_reweighting/Nf2_muiPiT_mass".mass."_nt".nt."_ns".ns'$INDEX'."_".obs."_reweighted.dat"' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        fi
    done
    echo '#Datafiles with only the data to be fitted: two empty lines are needed to separate the datasets...' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    echo 'system("echo \"\n\" > emptyfile")' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    for INDEX in ${!NSPACE[@]}; do
        echo 'fn'$INDEX'_f = "fn'$INDEX'_f"' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    done
    for INDEX in ${!NSPACE[@]}; do
	    echo 'system("awk '"'"'$1 >= ".b'$INDEX'l." && $1 <=".b'$INDEX'r." {print $0}'"'"' ".fn'$INDEX'." > ".fn'$INDEX'_f)' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    done
    echo -n 'data_all = "cat "' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    for INDEX in ${!NSPACE[@]}; do
        echo -n '.fn'$INDEX'_f." emptyfile "' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    done
    echo '' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
	echo 'foundEmptyDataBlock=system("".data_all." | awk '"'"'BEGIN{last=-1; num=0}/^$/{if(NR==last+1){num++; if(num>1){failed=1}}else{num=0}; last=NR}END{print failed}'"'"'")' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
	echo 'if (foundEmptyDataBlock == 1) {'                                                          >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
	echo '   system("rm emptyfile fn*")'                                                            >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
	echo '   print "\033[1;31mAn invalid range (containing no points) has been indicated!\033[0m"'  >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
	echo '   q()'                                                                                   >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
	echo '}'                                                                                        >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
	echo 'data_all="< ".data_all'                                                                   >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    echo '#==========================================================================================================='  >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    # Starting values for fit params
    echo '# Starting values for fit params' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    echo 'bc=5.5'    >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    echo 'nu=0.5'    >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    echo 'B4=1.604'  >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    echo 'a1=-1'     >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    [ $FIT_TYPE = 'quadratic' ] && echo 'a2=0.005'  >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    echo 'set fit errorvariables  # to get the errors' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    # Fit function
    # linear model:    f(x) = B4 + a1*(x-bc)*Ns**1/nu                             with variables B4,a1,bc,nu independent of Ns
    # quadratic model: f(x) = B4 + a1*(x-bc)*Ns**1/nu + a2*((x-bc)*Ns**1/nu)**2   with variables B4,a1,a2,bc,nu independent of Ns
    echo '# Fit function'  >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    if [ $FIT_TYPE = 'linear' ]; then
        echo '# linear model:    f(x) = B4 + a1*(x-bc)*Ns**1/nu     with variables B4,a1,bc,nu independent of Ns'    >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    elif [ $FIT_TYPE = 'quadratic' ]; then
        echo '# quadratic model: f(x) = B4 + a1*(x-bc)*Ns**1/nu + a2*((x-bc)*Ns**1/nu)**2   with variables B4,a1,a2,bc,nu independent of Ns' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    fi
    if [ $FIT_TYPE = 'linear' ]; then
        for INDEX in ${!NSPACE[@]}; do
            echo "fns${INDEX}(x) = B4  + a1*(x-bc)*ns${INDEX}**(1./nu)" >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        done
    elif [ $FIT_TYPE = 'quadratic' ]; then
        for INDEX in ${!NSPACE[@]}; do
            echo "fns${INDEX}(x) = B4  + a1*(x-bc)*ns${INDEX}**(1./nu) + a2*(x-bc)*ns${INDEX}**(2./nu)" >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        done
    fi
    echo -n 'fit_data(x,y) = ' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    for INDEX in ${!NSPACE[@]}; do
        echo -n "y==$INDEX ? fns${INDEX}(x) : (" >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    done
    echo  -n "1./0"  >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    for INDEX in ${!NSPACE[@]}; do
        echo -n ")"  >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    done
    echo '' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    # Determining Fit range
    echo '# Determining Fit range' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
	echo 'fitrange_low = (b1l<b0l) ? b1l : b0l' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    echo 'fitrange_high = (b1r>b0r) ? b1r : b0r' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    INDEX=2
    while [ $INDEX -lt ${#NSPACE[@]} ]; do
        echo 'fitrange_low = (b'$INDEX'l<fitrange_low) ? b'$INDEX'l : fitrange_low' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        echo 'fitrange_high = (b'$INDEX'r>fitrange_high) ? b'$INDEX'r : fitrange_high' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
        (( ++INDEX ))
    done
    echo 'set fit quiet' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    # Actual fit
    # ATTENTION: Here 'set yrange' fixes which data blocks to fit, since y is the index of the data block in the fit!!
    if [ $FIT_TYPE = 'linear' ]; then
        echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) data_all u 1:-2:8:9 '$FIT_ERRORS_STRING' via B4, bc, a1, nu' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    elif [ $FIT_TYPE = 'quadratic' ]; then
        echo 'fit [fitrange_low:fitrange_high] fit_data(x,y) data_all u 1:-2:8:9 '$FIT_ERRORS_STRING' via B4, bc, a1, a2, nu' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    fi
    #--------------------------------------------------------------------------------------------------------#
    # Evaluate the goodness of the fit: probability that, given the fit, the data could have occurred with a chisquare greater than or equal to the value found
    echo 'ndf = FIT_NDF'                          >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH  # Number of degrees of freedom
    echo 'chisq = FIT_STDFIT**2 * ndf'            >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH  # chi-squared
    echo 'Q = 1 - igamma(0.5 * ndf, 0.5 * chisq)' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH  # the quality of fit parameter Q -> NOTE: From version 5.0 this is in the variable FIT_P (activated by "set fit errorscaling")
    #Print to standard output some parameters from within gnuplot to make later a report
    local STRING_FOR_NSPACE_FORMAT=""
    local STRING_FOR_NSPACE=""
    local STRING_FOR_RANGES=""
    for INDEX in ${!NSPACE[@]}; do
        STRING_FOR_NSPACE_FORMAT="${STRING_FOR_NSPACE_FORMAT}.%d"
        STRING_FOR_NSPACE="${STRING_FOR_NSPACE}, ns$INDEX"
        STRING_FOR_RANGES=${STRING_FOR_RANGES}.b${INDEX}l.'" "'.b${INDEX}r.'"   "'
    done
    echo 'set print "-"' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    if [ $FIT_TYPE = 'linear' ]; then
        echo 'print sprintf("'${STRING_FOR_NSPACE_FORMAT:1}'\t\t%2d %f %5.2f\t\t%.5f %.5f\t\t%.5f %.5f\t\t%.5f %.5f\t\t%.6f %.6f\t\t"'"${STRING_FOR_RANGES}"${STRING_FOR_NSPACE}', FIT_NDF, FIT_STDFIT**2, Q*100, nu, nu_err, bc, bc_err, B4, B4_err, a1, a1_err)'                          >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    elif [ $FIT_TYPE = 'quadratic' ]; then
        echo 'print sprintf("'${STRING_FOR_NSPACE_FORMAT:1}'\t\t%2d %f %5.2f\t\t%.5f %.5f\t\t%.5f %.5f\t\t%.5f %.5f\t\t%.6f %.6f\t\t%.6f %.6f\t\t"'"${STRING_FOR_RANGES}"${STRING_FOR_NSPACE}', FIT_NDF, FIT_STDFIT**2, Q*100, nu, nu_err, bc, bc_err, B4, B4_err, a1, a1_err, a2, a2_err)' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    fi
    echo 'set print' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    # Removing auxiliary files
    echo '# Removing auxiliary files' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    echo 'system("rm emptyfile")'     >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    for INDEX in ${!NSPACE[@]}; do
        echo 'system("rm fn'$INDEX'_f")' >> $GNUPLOT_SCRIPT_TEMPLATE_GLOBALPATH
    done
    unset -v 'INDEX'
}
