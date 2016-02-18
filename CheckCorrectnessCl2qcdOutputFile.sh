#!/bin/bash

# The idea of this script is to check that in case a trajectory in the HMC has been
# rejected, then all the observables are the same in the two trajectories.
#
# For the moment it is ad hoc for the CL2QCD output file format.

#Columns here below ranges from 1 on, since they are used in awk
declare -A OBSERVABLES_COLUMNS
OBSERVABLES_COLUMNS[TrajectoryNr]=1
OBSERVABLES_COLUMNS[Plaquette]=2
OBSERVABLES_COLUMNS[PlaquetteSpatial]=3
OBSERVABLES_COLUMNS[PlaquetteTemporal]=4
OBSERVABLES_COLUMNS[PolyakovLoopRe]=5
OBSERVABLES_COLUMNS[PolyakovLoopIm]=6
OBSERVABLES_COLUMNS[PolyakovLoopSq]=7
OBSERVABLES_COLUMNS[Accepted]=11

#########################################################################

if [ $# -ne 1 ]; then
    printf "\n\e[0;34mPlease use the following syntax:\n"
    printf "\t\e[0;32m $(basename $0)   <CL2QCD output file>\e[0m\n\n"
    exit -1
else
    HMC_OUTPUT="$1"
    if [ ! -f $HMC_OUTPUT ]; then
	printf "\n\e[0;31m File \"$HMC_OUTPUT\" not found! Aborting...\e[0m\n\n"
	exit -1
    fi

    echo ""
    AUX1=$(printf "%s," "${OBSERVABLES_COLUMNS[@]}")
    AUX2=$(printf "%s," "${!OBSERVABLES_COLUMNS[@]}")

    awk -v obsColumns="${AUX1%?}" -v obsNames="${AUX2%?}" -v printReport=1 -f ${HOME}/Script/JobScriptAutomation/CheckCorrectnessCl2qcdOutputFile.awk $HMC_OUTPUT

    ERROR_CODE=$?
fi

exit $ERROR_CODE
