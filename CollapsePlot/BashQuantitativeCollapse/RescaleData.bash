#At the moment hard code the function according which to rescale.
#
#  Copyright (c) 2016 Alessandro Sciarra
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
