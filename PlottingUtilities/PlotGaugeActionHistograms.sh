#!/bin/bash


add_stats() {
    local INPUT_FILE=${INPUT_FILES_ARRAY[$INDEX]}
    local BETA=$(echo $INPUT_FILE | grep -o "[[:digit:]]\.[[:digit:]]\{4\}")
    #echo "stats \"$DIR_WITH_INPUT_FILES/$INPUT_FILE\" using $COLUMN_X_AXIS name \"beta$INDEX\" nooutput" >> $GNUPLOT_TEMP_SCRIPT
    echo 'stats "'$DIR_WITH_INPUT_FILES/$INPUT_FILE'" using ($'$COLUMN_X_AXIS') name "beta'$INDEX'" nooutput' >> $GNUPLOT_TEMP_SCRIPT
}

set_xtics_for_pdf_version() {
    if [ $INDEX -eq 0 ]; then
        echo 'set xtics (beta'${INDEX}'_mean,\' >> $GNUPLOT_TEMP_SCRIPT 
    elif [ $INDEX -eq $last_index ]; then 
        echo 'beta'${INDEX}'_mean)' >> $GNUPLOT_TEMP_SCRIPT
    else
        echo 'beta'${INDEX}'_mean,\' >> $GNUPLOT_TEMP_SCRIPT
    fi
}

add_plot() {

    local INPUT_FILE=${INPUT_FILES_ARRAY[$INDEX]}
    local BETA=$(echo $INPUT_FILE | grep -o "[[:digit:]]\.[[:digit:]]\{4\}")

    if [ $INDEX -eq 0 ]; then

        if [ $CREATE_PDF = true ]; then
            echo 'plot "'$DIR_WITH_INPUT_FILES/$INPUT_FILE'" u ('$BIN_FUNCTION'($'$COLUMN_X_AXIS','$BOXWIDTH')):(1./('$BOXWIDTH'*beta'${INDEX}'_records)) smooth frequency with boxes title gprintf("$\\beta=$'$BETA': Mean $=%.2E$", beta'${INDEX}'_mean) \' >> $GNUPLOT_TEMP_SCRIPT
            #echo 'plot "'$DIR_WITH_INPUT_FILES/$INPUT_FILE'" u ('$BIN_FUNCTION'($'$COLUMN_X_AXIS','$BIN_WIDTH')):(1./('$BIN_WIDTH'*beta'${INDEX}'_records)) smooth frequency with boxes title gprintf("$\\beta=$'$BETA': Mean $=%.2E$", beta'${INDEX}'_mean) \' >> $GNUPLOT_TEMP_SCRIPT
        else
            echo "plot \"$DIR_WITH_INPUT_FILES/$INPUT_FILE\" u ($BIN_FUNCTION(\$$COLUMN_X_AXIS,$BOXWIDTH)):(1./($BOXWIDTH*beta${INDEX}_records)) smooth frequency with boxes title gprintf(\"$BETA ---> Mean = %6.5f \", beta${INDEX}_mean)" >> $GNUPLOT_TEMP_SCRIPT
        fi
    else
        if [ $CREATE_PDF = true ]; then
                echo ', "'$DIR_WITH_INPUT_FILES/$INPUT_FILE'" u ('$BIN_FUNCTION'($'$COLUMN_X_AXIS','$BOXWIDTH')):(1./('$BOXWIDTH'*beta'${INDEX}'_records)) smooth frequency with boxes title gprintf("$\\beta=$'$BETA': Mean $=%.2E$", beta'${INDEX}'_mean) \' >> $GNUPLOT_TEMP_SCRIPT
                #echo ', "'$DIR_WITH_INPUT_FILES/$INPUT_FILE'" u ('$BIN_FUNCTION'($'$COLUMN_X_AXIS','$BIN_WIDTH')):(1./('$BIN_WIDTH'*beta'${INDEX}'_records)) smooth frequency with boxes title gprintf("$\\beta=$'$BETA': Mean $=%.2E$", beta'${INDEX}'_mean) \' >> $GNUPLOT_TEMP_SCRIPT
        else
            echo "replot \"$DIR_WITH_INPUT_FILES/$INPUT_FILE\" u ($BIN_FUNCTION(\$$COLUMN_X_AXIS,$BOXWIDTH)):(1./($BOXWIDTH*beta${INDEX}_records)) smooth frequency with boxes title gprintf(\"$BETA ---> Mean = % 6.5f \", beta${INDEX}_mean)" >> $GNUPLOT_TEMP_SCRIPT
        fi
    fi
}

#Source PathManagement in order to have functionalities
source ${HOME}/Script/PathManagement.sh || exit -2

ReadParametersFromPath $(pwd) #To set PARAMETERS_STRING

BETA_ARRAY=()
DIR_WITH_INPUT_FILES="${PARAMETERS_STRING}_reweighting"
if [ ! -d "$DIR_WITH_INPUT_FILES" ]; then
    echo "Directory \"${DIR_WITH_INPUT_FILES}\" not found! ...exiting"
    exit -1
fi

COLUMN_X_AXIS="1"
BOXWIDTH="10"
#BOXWIDTH="0.03"
#BIN_WIDTH=0.001
GNUPLOT_TEMP_SCRIPT="temporaryScriptForGnuplotThatHopefullyDoesNotExist.plt"
rm -f $GNUPLOT_TEMP_SCRIPT
BIN_FUNCTION="bin"
CREATE_PDF=false

while [ "$#" -gt 0 ]; do
    case $1 in
        -b)
            while [[ "$2" =~ ^[[:digit:]]\.[[:digit:]]{4}$ ]]
            do
                BETA_ARRAY+=( $2 )    
                shift
            done
            ;;
        -w) 
            BOXWIDTH=$2
            shift
            ;;
        -c)
            BIN_FUNCTION="binc"
            ;;
        -p) CREATE_PDF=true
            ;;
        -h)
            printf '\n\e[32m'
            echo " Possible options:"
            echo "   -b (Specify beta value, e.g. -b x.xxxx y.yyyy. If -b is not given the script will take alle available files."
            echo "   -w (Specifiy boxwidth for the histograms, default is 10.)"
            echo "   -c (Provide if the bins should be centered.)"
            printf '\n\e[0m'
            exit
            ;;
        -*)
            echo $0: $1: unrecognized option...exiting. >&2
            exit
            ;;
        *)
            echo $0: $1: unrecognized option...exiting. >&2
            exit
            ;;
    esac
    shift
done

TEX_OUTPUT_FILENAME="gauge_action_overlap.tex"

[[ ! $BOXWIDTH =~ ^[[:digit:]]+$ ]] && echo "Specified boxwidth invalid - setting it to 10" && BOXWIDTH=10

if [ $CREATE_PDF = true ]; then
    echo 'set term lua tikz latex createstyle' >> $GNUPLOT_TEMP_SCRIPT
    echo 'set terminal lua tikz standalone preamble '"'"'\usepackage{amsmath, mathabx}'"'" >> $GNUPLOT_TEMP_SCRIPT
fi

echo "$BIN_FUNCTION(x,s) = s*int(x/s)" >> $GNUPLOT_TEMP_SCRIPT
echo "set boxwidth $BOXWIDTH absolute" >> $GNUPLOT_TEMP_SCRIPT

if [ $CREATE_PDF = true ]; then
    echo 'set xlabel "$S_G/\\beta$"' >> $GNUPLOT_TEMP_SCRIPT
    echo 'set ylabel "$\\#$"' >> $GNUPLOT_TEMP_SCRIPT
else
    echo "set title \"Histogram(s) of the gauge action\"" >> $GNUPLOT_TEMP_SCRIPT
    echo "set xlabel \"gauge action\"" >> $GNUPLOT_TEMP_SCRIPT
    echo "set ylabel \"\#\"" >> $GNUPLOT_TEMP_SCRIPT
fi

if [ ${#BETA_ARRAY[@]} -eq 0 ]; then
    INPUT_FILES_ARRAY=( $(ls $DIR_WITH_INPUT_FILES | grep "rawDataForReweighting_b[[:digit:]]\.[[:digit:]]\{4\}$") )
else
    for BETA in ${BETA_ARRAY[@]}; do
        if [ -f "$DIR_WITH_INPUT_FILES/rawDataForReweighting_b$BETA" ]; then
            INPUT_FILES_ARRAY+=( "rawDataForReweighting_b$BETA" )
        fi
    done
fi

if [ ${#INPUT_FILES_ARRAY[@]} -eq 0 ]; then
    echo "No input files found...exiting"
    rm $GNUPLOT_TEMP_SCRIPT
    exit
fi

for INDEX in ${!INPUT_FILES_ARRAY[@]}; do
    add_stats
done

last_index=$(awk '{print $1-1}' <<< "${#INPUT_FILES_ARRAY[@]}")

if [ $CREATE_PDF = true ]; then
    echo '' >> $GNUPLOT_TEMP_SCRIPT
    echo 'set format x "%.2E' >> $GNUPLOT_TEMP_SCRIPT
    #for INDEX in ${!INPUT_FILES_ARRAY[@]}; do
    #    set_xtics_for_pdf_version
    #done
    echo 'set tics front' >> $GNUPLOT_TEMP_SCRIPT
    echo 'set tics font ",5"' >> $GNUPLOT_TEMP_SCRIPT
    echo 'set tics nomirror' >> $GNUPLOT_TEMP_SCRIPT
    #echo 'set xtics rotate by 20' >> $GNUPLOT_TEMP_SCRIPT
    #echo 'set xtics offset 0,graph -0.1' >> $GNUPLOT_TEMP_SCRIPT
    echo '' >> $GNUPLOT_TEMP_SCRIPT
    echo 'show xtics' >> $GNUPLOT_TEMP_SCRIPT
fi

if [ $CREATE_PDF = true ]; then
    echo '' >> $GNUPLOT_TEMP_SCRIPT
    echo 'set key at graph 0.6, graph 0.99 spacing 1.25 font ",8"' >> $GNUPLOT_TEMP_SCRIPT
fi

if [ $CREATE_PDF = true ]; then
    echo 'set output "'$TEX_OUTPUT_FILENAME'"' >> $GNUPLOT_TEMP_SCRIPT
fi

for INDEX in ${!INPUT_FILES_ARRAY[@]}; do
    add_plot
done

if [ $CREATE_PDF = true ]; then
    echo '' >> $GNUPLOT_TEMP_SCRIPT
    echo 'MAX=GPVAL_Y_MAX' >> $GNUPLOT_TEMP_SCRIPT
    echo 'MIN=GPVAL_Y_MIN' >> $GNUPLOT_TEMP_SCRIPT
    echo 'set yrange [MIN:MAX+(MAX-MIN)*0.2]' >> $GNUPLOT_TEMP_SCRIPT
fi


#for INDEX in ${!INPUT_FILES_ARRAY[@]}; do
#    add_plot
#done


if [ $CREATE_PDF = false ]; then
    echo "pause -1 \"Press enter to quit (all plots will be closed)\"" >> $GNUPLOT_TEMP_SCRIPT
fi

echo "" >> $GNUPLOT_TEMP_SCRIPT
echo "q" >> $GNUPLOT_TEMP_SCRIPT
gnuplot $GNUPLOT_TEMP_SCRIPT #1>/dev/null

if [ $CREATE_PDF = true ]; then
    sed -i s/.*gpsetdashtype.*// $TEX_OUTPUT_FILENAME #WARNING: DIRTY TRICK 
    #pdflatex $TEX_OUTPUT_FILENAME 2>/dev/null 1>&2
    pdflatex $TEX_OUTPUT_FILENAME 1>/dev/null
    echo pdflatex $TEX_OUTPUT_FILENAME
fi

echo
rm $GNUPLOT_TEMP_SCRIPT

if [ $CREATE_PDF = true ]; then
    rm $TEX_OUTPUT_FILENAME
    rm ${TEX_OUTPUT_FILENAME%.tex}.aux
    rm ${TEX_OUTPUT_FILENAME%.tex}.log
    rm gnuplot-lua-tikz-common.tex
    rm gnuplot-lua-tikz.tex
    rm t-gnuplot-lua-tikz.tex
    rm gnuplot-lua-tikz.sty
fi
