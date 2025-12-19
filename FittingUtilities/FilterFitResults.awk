#!/bin/awk
#
#  Copyright (c) 2015 Alessandro Sciarra
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


function filter_Q_chi2(value)
{
    if(chi2_passed)
    {
        if(length(perc)==0 ? 1 : value > 1.-perc/100.){if( length(perc)==0 ? 1 : value < 1.+perc/100. ){if( length(min)==0 ? 1 : value > min ){ if (length(max)==0 ? 1 : value < max){ print $0 }}}}
    }
    else if(q_passed)
    {
        if(length(perc)==0 ? 1 : value > 50.-perc){if( length(perc)==0 ? 1 : value < 50.+perc ){ if( length(min)==0 ? 1 : value > min){ if( length(max)==0 ? 1 : value < max) {print $0}}}}
    }
}

function filter_value(value, error)
{
    #The multiplication by (1/sqrt($(column_chi2)) corrects for the wrong estimation of the error when chi2 is different from 1
    if(value==0){print $0; return}
    if(length(perc)==0 ? 1 : error/sqrt(value*value)*(1/sqrt($(column_chi2))) < perc/100.){if(length(min)==0 ? 1 : value >= min){if( length(max)==0 ? 1 : value <= max) {print $0}}}
}

function skip_if_betaC_not_in_ranges(value, mins, maxs)
{
    for(i in mins)
    {
        if(value < mins[i]){next}
    }
    for(i in maxs)
    {
        if(value > maxs[i]){next}
    }
}

BEGIN{
    value_field=column
    error_field=column+1
    criteria_header_string="#Filtering-options:"
}
NR == 1{ print $0; next}
#To skip empty lines or commented lines
$1 == criteria_header_string {filtering_criteria=$2; next;}
NR > 1 && /^($|[#]+)/{next}
#Exclude fits for which the betaC is not in the fitted beta ranges
NR > 1{
    array_length=0
    delete betas_min
    delete betas_max
    delete volumes
    numberOfVolumes=split($1, volumes, ".")
    for(i = column_Ranges; i < column_Ranges+2*numberOfVolumes; i+=2)
    {
        betas_min[array_length]=$i
        betas_max[array_length]=$(i+1)
        array_length++
     }
    skip_if_betaC_not_in_ranges($column_betaC, betas_min, betas_max)
}
{
    if(NR > 1)
    {
        if(chi2_passed == 1 || q_passed == 1)
        {
            filter_Q_chi2($value_field)
        }
        else
        {
            filter_value($value_field, $error_field)
        }
    }
}
END{

   print criteria_header_string " " filtering_criteria "_" criteria_string
}
