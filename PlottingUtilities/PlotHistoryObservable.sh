#!/bin/bash

# This script is intended to plot the history of any observable
# of a data file. Run it with -h | --help to see the command line
# options.

#-----------------------------------------------------------------------------------------------------------------#
# Load auxiliary bash files that will be used.
source $HOME/Script/UtilityFunctions.sh || exit -2
#-----------------------------------------------------------------------------------------------------------------#


#-----------------------------------------------------------------------------------------------------------------#
# Auxiliary functions

asksave() {
while true; do
    read -p "Save the plot just closed? (y/n) " -n 1 -r yn
    case $yn in
        [Yy]* ) retval=0; break;;
        [Nn]* ) retval=1; break;;
        * ) echo ;;
    esac
done
echo # just a final linefeed, optics...
return $retval
}

add_plot() {
    echo "set title \"Beta $BETA\"" >> $GNUPLOT_TEMP_SCRIPT
    [ $COLUMN_X_AXIS = "1" ] && echo "set xlabel \"Trajectory number\"" >> $GNUPLOT_TEMP_SCRIPT
    [ $COLUMN_Y_AXIS = "6" ] && echo "set ylabel \"Im(L)\"" >> $GNUPLOT_TEMP_SCRIPT
	[ "$USE_ABSVALUES" = "TRUE" ] && COLUMN_Y_AXIS="(abs(\$${COLUMN_Y_AXIS}))"
    BETA_FOLDERS=(${BETA_FOLDERS[@]}) #Make BETA_FOLDERS not sparse
    for INDEX in "${!BETA_FOLDERS[@]}"; do
	local FILENAME="${BETA_FOLDERS[$INDEX]}/$DATAFILE_NAME"
	echo "stats \"$FILENAME\" using $COLUMN_Y_AXIS name \"beta$INDEX\" nooutput" >> $GNUPLOT_TEMP_SCRIPT
	if [ $INDEX -eq 0 ]; then
		echo "plot \"$FILENAME\" u ${COLUMN_X_AXIS}:${COLUMN_Y_AXIS} title gprintf(\"${BETA_FOLDERS[$INDEX]} ---> Mean = % 6.5f \", beta${INDEX}_mean)" >> $GNUPLOT_TEMP_SCRIPT
	else
		echo "replot \"$FILENAME\" u ${COLUMN_X_AXIS}:${COLUMN_Y_AXIS} title gprintf(\"${BETA_FOLDERS[$INDEX]} ---> Mean = % 6.5f \", beta${INDEX}_mean)" >> $GNUPLOT_TEMP_SCRIPT
	fi
    done
    #echo "ykey=A_mean*0.8" >> $GNUPLOT_TEMP_SCRIPT
    #echo "set key at 2e6,ykey" >> $GNUPLOT_TEMP_SCRIPT
    #echo "set label gprintf(\"Mean = %g GB/s\", A_mean) at first 1.5e6, first A_mean*0.9 font \"Helvetica,9\" textcolor lt 3" >> $GNUPLOT_TEMP_SCRIPT
    #echo "set label gprintf(\"Mean = %g GFLOPS\", B_mean) at first 1.5e6, first B_mean*1.25 font \"Helvetica,9\" textcolor lt 1" >> $GNUPLOT_TEMP_SCRIPT
}

#-----------------------------------------------------------------------------------------------------------------#

COLUMN_X_AXIS="1"
COLUMN_Y_AXIS="6"
if [ $(echo $PWD | grep "Staggered") ]; then
    DATAFILE_NAME="rhmc_output"
else
    DATAFILE_NAME="hmc_output"
fi
BETAVALUES=()
FOLDER_SUFFIX=""
USE_ABSVALUES="FALSE"

# extract options and their arguments into variables.
while [ "$1" != "" ]; do
    case $1 in
      -h | --help )
	  printf "\n\e[0;32m"
	  echo "Call the script $0 with the following optional arguments:"
	  echo "  -h | --help"
	  echo "  -a | --useAbsoluteValue ->    plot absolute value of y-column"
	  echo "  -x | --columnXaxis      ->    default value = $COLUMN_X_AXIS"
	  echo "  -y | --columnYaxis      ->    default value = $COLUMN_Y_AXIS"
	  echo "  -b | --betaValues       ->    Space-separated list of beta values"
	  echo "  -s | --suffix           ->    Beta folder ending string (default = \"${FOLDER_SUFFIX}\")"
	  echo -e "\n\e[0;35mNOTE: The values given to each option has to be put after the option separated by a space."
	  printf "\n\e[0m"
	  exit
	  shift;;
      -x | --columnXaxis )
          COLUMN_X_AXIS=$2
          shift ;;
      -y | --columnYaxis )
          COLUMN_Y_AXIS=$2
          shift ;;
      -b | --betaValues )  
          while [[ $2 =~ [[:digit:]]\.[[:digit:]]+ ]]; do
              BETAVALUES+=( $2 )
              shift
          done
          ;;
  	  -a | --useAbsoluteValue )
  		  USE_ABSVALUES="TRUE"
          shift ;;
      -s |--suffix )
          FOLDER_SUFFIX=$2
          shift ;;
      * )
          printf "\n\e[0;31mError parsing the options! Aborting...\n\n\e[0m" ; exit -1 ;;
    esac
    shift
done

if [ ${#BETAVALUES[@]} -eq 0 ]; then
    printf "\n\e[0;31m No beta specified (see --help for further info)! Aborting...\n\n\e[0m"
    exit -1
fi

GNUPLOT_TEMP_SCRIPT="temporaryScriptForGnuplotThatHopefullyDoesNotExist.plt"
INDEX_WINDOW=0
echo ""

for BETA in ${BETAVALUES[@]}; do
    BETA=$(echo $BETA | awk '{printf "%5.4f", $1}')
    #Gather folder names in an array and check for data file inside
    BETA_FOLDERS=( $(ls | grep "b${BETA}_s.*${FOLDER_SUFFIX}\$") )
    for INDEX in "${!BETA_FOLDERS[@]}"; do
	if [ ! -d ${BETA_FOLDERS[$INDEX]} ] || [ ! -f ${BETA_FOLDERS[$INDEX]}/$DATAFILE_NAME ]; then
	    unset -v 'BETA_FOLDERS[$INDEX]'
	    BETA_FOLDERS=(${BETA_FOLDERS[@]}) #Make BETA_FOLDERS not sparse
	fi
    done
    if [ ${#BETA_FOLDERS[@]} -eq 0 ]; then
	printf "\e[0;33m Any multiple chain found for beta = $BETA - looking for single chain...\e[0m"
	BETA_FOLDERS=( $(ls | grep "^b${BETA}\$") )
	if [ ! -d ${BETA_FOLDERS[$INDEX]} ] || [ ! -f ${BETA_FOLDERS[$INDEX]}/$DATAFILE_NAME ]; then
            unset -v 'BETA_FOLDERS[$INDEX]'
            BETA_FOLDERS=(${BETA_FOLDERS[@]}) #Make BETA_FOLDERS not sparse
        fi
	if [ ${#BETA_FOLDERS[@]} -eq 0 ]; then
	    printf "\e[0;31m any directory found for beta = $BETA - skipping such a beta!\n\e[0m"
	    continue
	else
	    echo ""
	fi
    fi

    printf "\e[0;32m Found ${#BETA_FOLDERS[@]} datafile to plot for beta = ${BETA}  ( ${BETA_FOLDERS[*]} )\n\e[0m"
    #printf "\e[0;32m Found ${#BETA_FOLDERS[@]} datafile to plot for beta = ${BETA}  ( ${BETA_FOLDERS[@]} )\n\e[0m"

    SCREEN_DIMENSTIONS=$(xdpyinfo  | grep dimensions | awk '{print $2}' | sed 's/x/,/g')
    echo "set term wxt $INDEX_WINDOW size $SCREEN_DIMENSTIONS" >> $GNUPLOT_TEMP_SCRIPT
    add_plot 
    INDEX_WINDOW=$(($INDEX_WINDOW + 1))
done
echo ""
#Add last lines and run gnuplot
echo "pause -1 \"Press enter to quit (all plots will be closed)\"" >> $GNUPLOT_TEMP_SCRIPT
echo "q" >> $GNUPLOT_TEMP_SCRIPT
gnuplot $GNUPLOT_TEMP_SCRIPT
echo
rm $GNUPLOT_TEMP_SCRIPT

