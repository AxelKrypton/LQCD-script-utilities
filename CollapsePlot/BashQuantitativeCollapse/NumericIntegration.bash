#Function to integrate numerically a function.
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

#Inputs argument are the file, the x-column and
#the function column
function IntegrateNumericallyWithTrapezoidalRule(){
    local INPUT_FILE=$1
    local X_AXIS_COLUMN=$2
    local Y_AXIS_COLUMN=$3

    awk -v xCol="$X_AXIS_COLUMN" -v fCol="$Y_AXIS_COLUMN" \
        'NR==1{
          xPrev=$xCol
          yPrev=$fCol
        }
        NR>1{
          sum+=($fCol+yPrev)*($xCol-xPrev)/2
          xPrev=$xCol
          yPrev=$fCol
        }
        END{printf "%.12f", sum}' $INPUT_FILE
}



# Here the square distance of two functions is calculated using two given columns as
# function values in the given file (the x-axis is also in a given column of the file).
# The square distance of two functions is [f(x)-g(x)]^2.
# After the integration, the integral result is normalized dividing by the integration interval extent.
# Here we suppose the file to be sorted according to the x-axis values.
#
# NOTE: At first the square distance is calculated point after point
#       evaluating the error on it by standard derivation.
#       After that integration routine above is used on different columns.
#
# ERROR PROPAGATION: h = (f-g)^2
#              sigma_h = sqrt[(de_h/de_f)^2*sigma_f^2+(de_h/de_g)^2*sigma_g^2]
#                      = 2*|f-g|*sqrt(sigma_f^2+sigma_g^2)
#
# NOTE: The function should return the distance between the functions, not the square. This
#       is given by the sqrt(integral((f-g)^2)) and therefore another small error propagation
#       is needed. d = sqrt(I)  =>  sigma_d = sigma_I/(2*sqrt(I))
#
function CalculateDistanceBetweenFunctionsNormalizedWithIntervalExtent(){
    local INPUT_FILE=$1
    local X_AXIS_COLUMN=$2
    local F_COLUMN=$3
    local G_COLUMN=$4
    local TEMPORARY_FILE=${INPUT_FILE}${SUFFIX_SQUARE_DIFFERENCE}

    awk -v xCol="$X_AXIS_COLUMN" -v fCol="$F_COLUMN" -v gCol="$G_COLUMN" \
        '
        {
          y=($fCol-$gCol)^2
          yErr=sqrt(4*($fCol-$gCol)^2*($(fCol+1)^2+$(gCol+1)^2))
          printf "%.12f %.12f %.12f %.12f\n", $xCol, y, y-yErr, y+yErr
        }
        ' $INPUT_FILE > $TEMPORARY_FILE

    local INTEGRAL=$(IntegrateNumericallyWithTrapezoidalRule $TEMPORARY_FILE 1 2)    #Integral of y      value
    local ERROR_LEFT=$(IntegrateNumericallyWithTrapezoidalRule $TEMPORARY_FILE 1 3)  #Integral of y-yErr value
    local ERROR_RIGHT=$(IntegrateNumericallyWithTrapezoidalRule $TEMPORARY_FILE 1 4) #Integral of y+yErr value
    local SMALLEST_X=$(head -n1 $TEMPORARY_FILE | cut -f$X_AXIS_COLUMN -d' ')
    local LARGEST_X=$(tail  -n1 $TEMPORARY_FILE | cut -f$X_AXIS_COLUMN -d' ')
    #Normalize by total width x interval and put in ERRORS the true errors
    if [ $SMALLEST_X != $LARGEST_X ]; then
        INTEGRAL=$(awk '{printf "%.12f", $1/($2-$3)}'    <<< "$INTEGRAL $LARGEST_X $SMALLEST_X")
        ERROR_LEFT=$(awk '{printf "%.12f", $1 - $2/($3-$4)}' <<< "$INTEGRAL $ERROR_LEFT $LARGEST_X $SMALLEST_X")
        ERROR_RIGHT=$(awk '{printf "%.12f",$2/($3-$4) -$1}' <<< "$INTEGRAL $ERROR_RIGHT $LARGEST_X $SMALLEST_X")
    fi
    #Check asymmetry
    if [ $(awk '{print (sqrt(($1-$2)^2)>1.e-6)}' <<< "$ERROR_ON_INTEGRAL_RIGHT $ERROR_ON_INTEGRAL_LEFT") -eq 1 ]; then
        printf "\n\e[33m WARNING: asymmetry of error on integral bigger than 1.e-6 -> error_left - error_right = $(awk '{printf "%e", sqrt(($1-$2)^2)}' <<< "$ERROR_ON_INTEGRAL_LEFT $ERROR_ON_INTEGRAL_RIGHT")\e[0m\n\n" 1>&2
    fi
    #The integral calculated above gives the square of the distance between functions, while we want the distance
    #So: d=sqrt(I) err_d=err_I/(2*sqrt(I))
    local DISTANCE=$(awk '{printf "%.12f", sqrt($1)}' <<< "$INTEGRAL")
    local ERROR_ON_DISTANCE=$(awk '{printf "%.12f", ($1<1.e-16) ? "inf" : $2/(2*sqrt($1))}' <<< "$INTEGRAL $ERROR_RIGHT")

    echo $DISTANCE $ERROR_ON_DISTANCE
}



