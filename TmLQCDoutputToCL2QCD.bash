#!/bin/bash
#
#  Copyright (c) 2014 Alessandro Sciarra
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


# This script is supposed to convert the output files of tmLQCD to that of CL2QCD.
# It is not so trivial because tmLQCD saves polyakov loop and history data in
# separate files. Moreover we cannot deduce the temporal and spatial plaquette
# from the total plaquette in the output of tmLQCD runs. Then we will write
# some nan in the produced files.
#
# At commit 512125fafd0056a1aeba8113603e46b414b49a20 of CL2QCD the output of hmc
# has hmc_output as standard name and the columns are:
#
# Traj_num - Plaq_tot - Plaq_t - Plaq_s - Poly_re - Poly_im - Poly_abs - dH - exp(dH) - Acc_prob - Acc - 0 - 0
#     1          2        3        4        5         6          7       8      9          10       11   12  13
#
# While for tmLQCD we have, in output.data:
#
# Traj_num - Plaq_tot - dS - exp(dS) - CG_iter - CG_iter - Acc - Traj_time
#     1          2       3      4         5         6       7        8
#
# and in polyakovloop_dir0
#
# Traj_num - dir - Poly_real - Poly_imag
#     1       2        3           4
#
#
# Here we produce a file called "hmc_output" using "output.data" and "polyakovloop_dir0".
# Each file has to be where the script is run and the new file will be there produced as well.

if [ ! -f output.data ]; then
    printf "\n\e[0;31m File \"output.data\" not found! Aborting...\n\n\e[0m"
    exit -1
fi

if [ ! -f polyakovloop_dir0 ]; then
    printf "\n\e[0;31m File \"output.data\" not found! Aborting...\n\n\e[0m"
    exit -1
fi

awk 'FNR==NR{a[FNR]=$3 "   " $4 ; next}{ printf "%d \t %.15f \t %s \t %s \t %s \t %s \t %.15f \t %g \t %g \t %d\t%d\t%d\n", \
                                                                      $1, $2, "nan", "nan", \
                                                                      a[FNR], "polysqnorm", \
                                                                      -$3, exp(-$3), (-$3 < 0) ? (exp(-$3)) : (1), \
                                                                      $7, 0, 0}' polyakovloop_dir0 output.data > fileThatHopefullyDoesNotExist

awk -v CONVFMT=%.15g 'BEGIN{OFS=" \t "}{$7=sqrt($5*$5+$6*$6); print $0}' fileThatHopefullyDoesNotExist > hmc_output
rm -f fileThatHopefullyDoesNotExist
