function PlotRescaledDataAndDifferences(){
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


    local SCREEN_DIMENSTIONS=$(xdpyinfo  | grep dimensions | awk '{print $2}' | sed 's/x/,/g')

    gnuplot <<-EOFMarker
    set term wxt 0 size $SCREEN_DIMENSTIONS
    files="${DATA_FILENAMES[@]}"
    volumes="${VOLUMES[@]}"
    differences=""
    pairs=""
    do for [i=1:words(volumes)] {
      do for [j=i+1:words(volumes)] {
        differences=differences." ${FILENAME_DATA_FOR_INTEGRATION}${BETA_C_NU_STRING}_ns".word(volumes, i)."_ns".word(volumes, j)."${SUFFIX_SQUARE_DIFFERENCE}"
        pairs=pairs." ns".word(volumes, i)."_ns".word(volumes, j)
      }
    }
    set xlabel "x=(beta-betaC)*L^(1/nu)"
    set ylabel "B4"
    set y2label "Distance between functions"
    set ytics nomirror
    set y2tics nomirror
    set title "Rescaled data (betaC=${BETA_C[0]}, nu=${NU[0]}) and distance between pairs of volumes"
    plot for [i=1:words(files)] word(files, i)."${BETA_C_NU_STRING}${SUFFIX_RESCALED_DATA}" using 1:2:3 w e title "Ns=".word(volumes, i) axes x1y1
    replot for [i=1:words(differences)] word(differences, i) using 1:2:(\$4-\$2) w e title "Distance_".word(pairs, i) axes x1y2
    pause mouse button1
    q()
EOFMarker
}
