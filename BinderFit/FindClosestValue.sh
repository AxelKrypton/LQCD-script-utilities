#!/bin/bash

FIND_LARGEST="FALSE"
FIND_CLOSEST_VALUE="FALSE"

while [ $# -gt 0 ];
do
    case $1 in
        -h | --help)
            printf "\e[1;32mName:\n\e[0m"
            printf "        \e[32m$(basename $0)\n\e[0m"
            printf "\n"
            printf "\e[1;32mDescription:\n\e[0m"
            printf "        \e[32mThis script is designed to process a file that represents a gathering of the best fit results of different volume combinations.\n\e[0m"
            printf "        \e[32mThe processing consists in either searching for a value that is next to a specified one or simply searching for the largest value.\n\e[0m" 
            printf "\n"
            printf "        \e[32m-h | --help\n\e[0m"  
            printf "                \e[32mprint this help message\n\e[0m"
            printf "\n"
            printf "        \e[32m-f | --filename\n\e[0m"
            printf "                \e[32mspecify file name\n\e[0m"
            printf "\n"
            printf "        \e[32m-c | --column-number\n\e[0m"
            printf "                \e[32mspecify column number of parameter to be processed\n\e[0m"
            printf "\n"
            printf "        \e[32m-l | --line [<line start>] [<line end>]\n\e[0m" 
            printf "                \e[32mspecify either first or last line or both if you only want to search a specific portion of the file\n\e[0m"
            printf "\n"
            printf "        \e[32m-m | --maximal-value\n\e[0m"
            printf "                \e[32msearches for the largest value of the parameter in the column specified by -c\n\e[0m"
            printf "\n"
            printf "        \e[32m-n | --next-value <value>\n\e[0m"
            printf "                \e[32msearches for the value closest to <value> of the parameter in the column specified by -c\n\e[0m"
            printf "\n"
            printf "\e[1;32mREMARK\e[24m:\n\e[0m"
            printf "        \e[32mwhen -m and -n are given at the same time only the latter one applies.\n\e[0m"
            printf "\n"
            exit
            ;;
        -f | --filename)        FILENAME=$2
                                shift
                                ;;
        -c | --column-nr)       COLUMN_NR=$2  
                                shift
                                ;;
        -l | --line)            LINE_START=$2
                                LINE_END=$3
                                shift
                                shift
                                ;;
        -m | --maximal-value)   FIND_LARGEST="TRUE"
                                FIND_CLOSEST_VALUE="FALSE"
                                ;;
        -n | --next-value)      VALUE_CLOSEST_TO=$2
                                FIND_CLOSEST_VALUE="TRUE"
                                FIND_LARGEST="FALSE"
                                shift
                                ;;
        -*)                     echo $0: $1: unrecognized option >&2
                                exit
                                ;;
        *)                      echo $0: $1: unrecognized option >&2
                                exit
                                ;;
    esac
    shift
done

awk -v volume_combination=$FIRST_VOLUME_COMBINATION -v line_start=$LINE_START -v line_end=$LINE_END -v column_nr=$COLUMN_NR -v find_largest=$FIND_LARGEST -v find_closest=$FIND_CLOSEST_VALUE -v value_closest_to=$VALUE_CLOSEST_TO '
BEGIN{
    largest_initialized=0
    closest_initialized=0 
    #print "first volume combination: " volume_combination
    counter=0
    #print "line_start: " line_start
    #print "line_end: " line_end
}
{  
    if(NR==1) print $0
        if((length(line_start) != 0 ? NR >= line_start : 1) && (length(line_end) != 0 ? NR <= line_end : 1))
    {
        #print "line nr: " NR
        if($1 ~ /^([[:digit:]]{2}\.){1,3}[[:digit:]]{2}$/ && volume_combination != $1)
        {
            if(volume_combination ~ /^([[:digit:]]{2}\.){1,3}[[:digit:]]{2}$/)
            {
                if(find_largest == "TRUE") print largest_value_line
                if(find_closest == "TRUE") print closest_value_line
                largest_initialized=0
                closest_initialized=0
            }
        }

        if($1 ~ /^([[:digit:]]{2}\.){1,3}[[:digit:]]{2}$/){volume_combination=$1} 

        if(find_largest == "TRUE")
        {
            if($1 ~ /^([[:digit:]]{2}\.){1,3}[[:digit:]]{2}$/)
            {
                if(largest_initialized==0)
                {
                    largest_value=$column_nr
                    largest_value_line=$0
                    largest_initialized=1
                }
                else if ($column_nr == largest_value)
                {
                    largest_value_line=largest_value_line"\n"$0
                }
                if($column_nr > largest_value)
                {
                    largest_value=$column_nr
                    largest_value_line=$0
                } 
            }    
        }
        else if(find_closest == "TRUE")
        {
            if($1 ~ /^([[:digit:]]{2}\.){1,3}[[:digit:]]{2}$/)
            {
                if(closest_initialized==0)
                {
                    closest_value=$column_nr
                    closest_value_line=$0
                    closest_initialized=1
                }
                else if(sqrt((value_closest_to-$column_nr)*(value_closest_to-$column_nr)) == sqrt((value_closest_to-closest_value)*(value_closest_to-closest_value)))
                {
                    closest_value_line=closest_value_line"\n"$0
                }
                if(sqrt((value_closest_to-$column_nr)*(value_closest_to-$column_nr)) < sqrt((value_closest_to-closest_value)*(value_closest_to-closest_value)))
                {
                    closest_value=$column_nr
                    closest_value_line=$0
                }
            }
        }

    }
}
END{
        if(find_largest == "TRUE") print largest_value_line
        if(find_closest == "TRUE") print closest_value_line
}
' $FILENAME
