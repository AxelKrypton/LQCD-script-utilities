#!/bin/awk
#
#  Copyright (c) 2015,2016 Alessandro Sciarra
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


#This script relies on a fixed format of the input file:
#   Fitted_Volumes   NDF chi2       Q          nu dnu          beta dbeta            B4 dB4           b db           Beta_Ranges
#or
#   Fitted_Volumes   NDF chi2       Q          nu dnu          beta dbeta            B4 dB4           b1 db1           b2 db2           Beta_Ranges

function CalculateXrange(){
    for(i in volumes){
        xMins[i]=(mins[i]-betaC)*volumes[i]^(1./nu)
        xMaxs[i]=(maxs[i]-betaC)*volumes[i]^(1./nu)
    }
}

function CalculateOverlap(a, b, c, d,     partNotInCommon){
    if(c>b || a>d)
    {
        return 0
    }
    else
    {
        partNotInCommon=sqrt((a-c)^2)+sqrt((b-d)^2)
        return 1.-(partNotInCommon/(sqrt((b-a)^2)+sqrt((d-c)^2)))
    }
}

#Symmetry of an interval [-a, b] with respect to zero can be defined as 1-abs(2b/(b-a)-1).
#Basically it is a function of the distance from zero of one of the two edges, let's call this x.
#Then x ranges from 0 to D=(b-a). If x==0 || x==D, then symmetry factor is 0. if x=D/2 then
#the symmetry factor is 1. For 0<x<D/2 the symmetry factor has to raise linearly to 1.
#For D/2<x<D the symmetry factor has to decrease linearly to 0.
function CalculateSymmetryWithRespectToZero(min, max,     D){
    if(min*max >= 0)
    {
        return 0
    }
    else
    {
        D=max-min
        return 1-sqrt((2*max/D - 1)*(2*max/D - 1))
    }
}

function CalculateWidthCommonIntervalInX(     maxOfMins, minOfMaxs){
    maxOfMins=xMins[1]
    minOfMaxs=xMaxs[1]
    for(i in volumes){
        if(xMins[i]>maxOfMins)
            maxOfMins=xMins[i]
        if(xMaxs[i]<minOfMaxs)
            minOfMaxs=xMaxs[i]
    }
    return minOfMaxs-maxOfMins
}

function CalculateWidthTotalIntervalInX(     minOfMins, maxOfMaxs){
    minOfMins=xMins[1]
    maxOfMaxs=xMaxs[1]
    for(i in volumes){
        if(xMins[i]<minOfMins)
            minOfMins=xMins[i]
        if(xMaxs[i]>maxOfMaxs)
            maxOfMaxs=xMaxs[i]
    }
    return maxOfMaxs-minOfMins
}


function SetCombinationsOfVolumes(){
    if(numberOfVolumes==2)
    {
        numberOfVolumesCombinations=1
        volumesCombinations[1]="1.2"
    }
    else if(numberOfVolumes==3)
    {
        numberOfVolumesCombinations=split("1.2_1.3_2.3", volumesCombinations, "_")
    }
    else if(numberOfVolumes==4)
    {
        numberOfVolumesCombinations=split("1.2_1.3_1.4_2.3_2.4_3.4", volumesCombinations, "_")
    }
}

NR==1{
    fitType="lin"
    for(i=1; i<=NF; i++){
        if($i == "b2"){
            fitType="quadr"
        }
        if($i == "nu"){
            columnNu=i
        }
        if($i == "betaC"){
            columnBetaC=i
        }
        if($i == "Beta_Ranges"){
            columnBetaRanges=i
        }
    }
    if(fitType == "lin"){
        printf "%-15s    %-22s    %-17s    %-17s    %-17s    %-17s     MinOv%  MinSymm%  MinDx  TotDx       Beta_Ranges_And_xRanges_And_Overlap_Percentages\n", $1, $2" "$3" "$4, $5" "$6, $7" "$8, $9" "$(10), $(11)" "$(12)
    }else{
        printf "%-15s    %-22s    %-17s    %-17s    %-17s    %-17s    %-17s     MinOv%  MinSymm%  MinDx  TotDx       Beta_Ranges_And_xRanges_And_Overlap_Percentages\n", $1, $2" "$3" "$4, $5" "$6, $7" "$8, $9" "$(10), $(11)" "$(12), $(13)" "$(14)
    }
    next
}
/^($|[#]+)/{next} #To skip empty lines or commented lines
{
    #print "------------------------"
    #Deleting arrays (all for caution)
    delete mins
    delete maxs
    delete xMins
    delete xMaxs
    delete volumesCombinations
    delete overlapPercentages
    delete symmetryPercentages

    numberOfVolumes=split($1, volumes, ".")
    nu=$columnNu
    betaC=$columnBetaC
    arraylength=0
    #print "nu="nu"   betaC="betaC"   numVols="numberOfVolumes"       columnBetaRanges="columnBetaRanges
    for(i=columnBetaRanges; i<=NF; i+=2){
        arraylength++ #Because split creates the array with indeces 1,2,3... and I want the same in mins and maxs
        mins[arraylength]=$i
        maxs[arraylength]=$(i+1)
    }
    #for(i in mins){
    #    print "mins["i"]="mins[i]"    maxs["i"]="maxs[i]
    #}
    CalculateXrange()
    SetCombinationsOfVolumes()
    for(i=1; i<=numberOfVolumesCombinations; i++){
        split(volumesCombinations[i], tmpArray, ".")
        overlapPercentages[i]=100*CalculateOverlap(xMins[tmpArray[1]], xMaxs[tmpArray[1]], xMins[tmpArray[2]], xMaxs[tmpArray[2]])
    }
    for(i=1; i<=numberOfVolumes; i++){
        symmetryPercentages[i]=100*CalculateSymmetryWithRespectToZero(xMins[i], xMaxs[i])
    }
    minimumOverlapPercentage=overlapPercentages[1]
    for(i in overlapPercentages){
        if(overlapPercentages[i]<minimumOverlapPercentage){
            minimumOverlapPercentage=overlapPercentages[i]
        }
    }
    minimumSymmetryPercentage=symmetryPercentages[1]
    for(i in symmetryPercentages){
        if(symmetryPercentages[i]<minimumSymmetryPercentage){
            minimumSymmetryPercentage=symmetryPercentages[i]
        }
    }

    #for(i=1; i<=numberOfVolumes; i++){
    #    print "i="i"   volume="volumes[i]"   xMin="xMins[i]"   xMax="xMaxs[i]"   "
    #}
    #for(i=1; i<=numberOfVolumesCombinations; i++){
    #    print "overlapPercentages["i"]="overlapPercentages[i]"%"
    #}
    #for(i=1; i<=numberOfVolumes; i++){
    #    print "symmetryPercentages["i"]="symmetryPercentages[i]"%"
    #}
    #print "minimumSymmetryPercentage="minimumSymmetryPercentage


    if(fitType == "lin"){
        printf "%-15s    %-22s    %-17s    %-17s    %-17s    %-17s", $1, $2" "$3" "$4, $5" "$6, $7" "$8, $9" "$(10), $(11)" "$(12)
    }else{
        printf "%-15s    %-22s    %-17s    %-17s    %-17s    %-17s    %-17s", $1, $2" "$3" "$4, $5" "$6, $7" "$8, $9" "$(10), $(11)" "$(12), $(13)" "$(14)
    }
    printf "    %.2f", minimumOverlapPercentage
    printf "   %.2f  ", minimumSymmetryPercentage
    printf "   %.5f  ", CalculateWidthCommonIntervalInX()
    printf "   %.5f  ", CalculateWidthTotalIntervalInX()
    for(i=0; i<numberOfVolumes; i++){
        printf "   %.6f %.6f", $(columnBetaRanges+2*i), $(columnBetaRanges+1+2*i)
    }
    for(i=1; i<=numberOfVolumes; i++){
        printf "   %.5f %.5f", xMins[i], xMaxs[i]
    }
    printf "   "
    for(i=1; i<=numberOfVolumesCombinations; i++){
        printf "%.2f ", overlapPercentages[i]
    }

    printf "\n"
}






