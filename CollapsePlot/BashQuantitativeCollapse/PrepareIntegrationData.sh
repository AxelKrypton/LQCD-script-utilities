# Here the structure of the input files is assumed to be [x, y, dy]
# without commented line. No check is performed since this file has been produced
# by this script and not by the user.
function PrepareIntegrationDataGivenPairOfFiles(){
    local FILE_I=$1
    local FILE_II=$2
    local RESOLUTION_TO_BE_USED=$3
    local OUTPUT_FILE=$4
    local SUFFIX=${SUFFIX_DATA_ON_GRID}

    #Find xmin, xmax of each file, assume that no commented line are in the file as it should be since we build ourselves the input file
    local XMIN=( $(head -n1 $FILE_I | cut -f1 -d' ') $(head -n1 $FILE_II | cut -f1 -d' ')  )
    local XMAX=( $(tail -n1 $FILE_I | cut -f1 -d' ') $(tail -n1 $FILE_II | cut -f1 -d' ')  )
    #Since I have to do the integral of square of difference of function, I need to have both functions defined. Consider overlap interval
    [ $(bc -l <<< "${XMIN[0]} < ${XMIN[1]}") -eq 1 ] && XMIN=${XMIN[1]} || XMIN=${XMIN[0]} 
    [ $(bc -l <<< "${XMAX[0]} > ${XMAX[1]}") -eq 1 ] && XMAX=${XMAX[1]} || XMAX=${XMAX[0]} 

    #Here, I filter the data keeping only the closest point to that of the grid for the numeric integration. I start at XMIN and stop at XMAX using RESOLUTION_TO_BE_USED.
    #In the output file, I write in the first column the grid value and I add in the end the closest x value so that later I can estimate the approximation done here.
    #Actually, in the end I add also the difference between the grid value and the actual x.
    #
    #Note that, if the given resolution is too high, the same data will result the closes to different grid points and therefore in the difference column there will
    #be values bigger than half of the given resolution. This information is used to make a check afterwards and, in case, to abort the program.
    for FILE in $FILE_I $FILE_II; do
        awk -v xmin="$XMIN" -v xmax="$XMAX" -v xres="$RESOLUTION_TO_BE_USED" \
            '
         function SetDxAndLineWithAdditionalInfoUsingActualLine(){
           dx=sqrt(($1-x)*($1-x))
           firstEntryLine=$1
           line=sprintf("%.12f %.12f %.12f %.12f %.12f", x, $2, $3, firstEntryLine, dx)
         }

         function SetDxAndLineWithAdditionalInfoUsingPreviousGoodLine(){
           dx=sqrt((firstEntryLine-x)*(firstEntryLine-x))
           line=sprintf("%.12f %.12f %.12f %.12f %.12f", x, $2, $3, firstEntryLine, dx)
         }
         
         BEGIN{x=xmin; printLineOnExit=1}
         
         NR==1{
           SetDxAndLineWithAdditionalInfoUsingActualLine()
         }

         NR>1{
           if(sqrt(($1-x)*($1-x))<dx){
             SetDxAndLineWithAdditionalInfoUsingActualLine()
           }else{
             print line
             while(1){
               x+=xres
               SetDxAndLineWithAdditionalInfoUsingPreviousGoodLine()
               if(x>xmax){
                 printLineOnExit=0 
                 exit
               }
               if(sqrt(($1-x)*($1-x))>dx){
                 print line
               }else{
                 SetDxAndLineWithAdditionalInfoUsingActualLine()
                 break
               }
             }
           }
         }
         END{if(printLineOnExit){print line}}' ${FILE} > ${FILE}${SUFFIX}
    done

    #Here I check for too high resolution. If this is the case, awk here above would print twice or more times the same real data (column 5) as the closest to different grid points!
    if ! $(cut -f4 -d' ' ${FILE_I}${SUFFIX} | sort --numeric-sort --check=silent -u) || ! $(cut -f4 -d' ' ${FILE_II}${SUFFIX} | sort --numeric-sort --check=silent -u); then
        printf "\n\e[0;31m Integration grid too fine for files\n   \"${FILE_I}\" \n   \"${FILE_II}\" \n with respect to real data resolution! Try to reduce resolution! Aborting...\n\n\e[0m" 1>&2; return 2
    fi

    if [ $(wc -l < ${FILE_I}${SUFFIX}) -lt 2 ] || [ $(wc -l < ${FILE_II}${SUFFIX}) -lt 2 ]; then
        printf "\e[33m Integration grid for files\n \"${FILE_I}\" \n \"${FILE_II}\" \n so coarse that only one point was resulting in files! Integral cannot be performed!\n\e[0m" 1>&2
    fi

    #Probably unnecessary check
    if [ $(wc -l < ${FILE_I}${SUFFIX}) -ne $(wc -l < ${FILE_II}${SUFFIX}) ]; then
        printf "\n\e[0;31m Something really bad happened, the two files with data on grid should have the same amount of lines!!\n" 1>&2
        printf "   File \"${FILE_I}${SUFFIX}\" has $(wc -l < ${FILE_I}${SUFFIX}) lines\n" 1>&2
        printf "   File \"${FILE_II}${SUFFIX}\" has $(wc -l < ${FILE_II}${SUFFIX}) lines\n" 1>&2
        printf " Maybe a bug!? Aborting...\n\n\e[0m" 1>&2
        return 1
    fi

    #Being sure that the files have the same number of lines, I can use the paste command to add the columns together and then use cut to keep only those I want.
    #The final file will have: x, (y yMin yMax)_fileI, (y yMin yMax)_fileII
    paste -d' ' ${FILE_I}${SUFFIX} ${FILE_II}${SUFFIX} | cut -d' ' -f1-3,7-8 > $OUTPUT_FILE

    #Probably unnecessary check
    if ! $(sort --numeric-sort --check=silent --key 1 $OUTPUT_FILE); then
        printf "\n\e[0;31m The file containing the data for integration seems to have the x-axis unsorted! Aborting...\n\n\e[0m" 1>&2; return 1
    fi

    return 0
}
