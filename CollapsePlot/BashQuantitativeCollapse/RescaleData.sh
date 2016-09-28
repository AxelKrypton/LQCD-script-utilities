#At the moment hard code the function according which to rescale.
#If desired to generalise, then one should put the function in a bash variable 
#and make awk parse it via an here doc syntax (look at http://askubuntu.com/questions/523085/evaluate-expression-within-awk )

#Rescale data:
#  COLUMN 1 OUTPUT: (x - betaC)*ns^{1/nu}
#  COLUMN 2 OUTPUT: y
#  COLUMN 3 OUTPUT: dy
function RescaleDataForGivenFile(){
    local INPUT_FILENAME=$1
    local BETA_C_GIVEN_AS_INPUT=$2
    local NU_GIVEN_AS_INPUT=$3
    local VOLUME_GIVEN_AS_INPUT=$4
    local OUTPUT_FILENAME=$5

    awk -v xCol="$X_COLUMN" -v "xMin=${X_MIN[$VOLUME_GIVEN_AS_INPUT]}" -v "xMax=${X_MAX[$VOLUME_GIVEN_AS_INPUT]}" \
        -v yCol="$Y_COLUMN" -v dyCol="$(($Y_COLUMN + 1))" -v betaC="$BETA_C_GIVEN_AS_INPUT" -v nu="$NU_GIVEN_AS_INPUT" -v ns="$VOLUME_GIVEN_AS_INPUT" \
        '
           /^($|[#]+)/{next}
           {
               if( ((xMin == "notGiven") || ($xCol >= xMin)) && ((xMax == "notGiven") || ($xCol <= xMax)) )
               {
                   printf "%.12f %.12f %.12f\n", ($xCol-betaC)*(ns^(1./nu)), $yCol, $dyCol
               }
           }
        ' $INPUT_FILENAME > ${OUTPUT_FILENAME}
}
