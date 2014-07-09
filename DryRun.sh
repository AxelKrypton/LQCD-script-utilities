#!/bin/bash

#function to display commands
exe() { 
    if [[ $DRY_RUN = yes ]]; then
	echo " $@"
    else
	"$@"
    fi
}

DRY_RUN="yes"

exe echo $(pwd)
exe echo $PWD

