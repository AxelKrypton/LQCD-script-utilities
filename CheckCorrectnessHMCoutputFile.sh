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
    echo Hello | awk -v obsColumns="${AUX1%?}" \
	-v obsNames="${AUX2%?}" \
        'BEGIN{
           split(obsNames, namesArray, ","); 
           split(obsColumns, columnsArray, ",");
           for(i in namesArray){
             observables[namesArray[i]]=columnsArray[i];
           }
        }
        { if($(observables["Accepted"]) == 0){ 
            for(obs in observables){
              if(obs=="TrajectoryNr" || obs=="Accepted"){continue};
              if($(observables[obs]) != oldObservables[obs]){
                if(changedObs == ""){changedObs=obs}
                else{changedObs=(changedObs ", " obs)}
              }
            }
            if(changedObs != ""){ 
              print "\033[38;5;9m Trajectory\033[38;5;11m", $(observables["TrajectoryNr"]) "\033[38;5;9m -> configuration regected but\033[38;5;11m", changedObs, "\033[38;5;9mchanged!\033[0m"
              changedObs=""
              wrongLines++
            }
          }
          for(obs in observables){
             oldObservables[obs]=$(observables[obs])
          }
        }
        END{
          if(wrongLines==0){
            printf "\033[38;5;10m No wrong lines have been detected! The file seems to be correct!\033[0m\n\n"; exit 0
          }else{
            printf "\n\033[38;5;9m In total \033[38;5;11m%d\033[38;5;9m wrong lines!\033[0m\n\n", wrongLines; exit 1
          }
       }' $HMC_OUTPUT 
ERROR_CODE=$?
fi

exit $ERROR_CODE
