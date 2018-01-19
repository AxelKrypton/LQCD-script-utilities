#!/bin/bash

function ElementInArray() {
    #Remember in BASH 0 means true and >0 means false
    local ELEMENT
    for ELEMENT in "${@:2}"; do [[ "$ELEMENT" == "$1" ]] && return 0; done
    return 1
}

function ParseCommandLineOption(){
    while [ "$1" != "" ]; do
        case $1 in
            -h | --help )
                printf "\n\e[0;91m"
                echo " This script will rewrite the history of your git repository on all branches,"
                echo " therefore use it with care (from great powers comes great responsibilities)!" 
                printf "\n\e[0;36m"
                echo " Running the script, the history of the repository from where the script is run will"
                echo " be analysed, running the given sed command on each commit message. This implies that"
                echo " the whole history on ALL branches will change!"
                echo ""
                printf "\n\e[0;32m"
                echo " Call the script $0 with the following optional arguments:"
                echo "   --help"
                echo "   --capitalizeInitialOfFirstLine"
                echo "   --removePeriodEndOfFirstLine"
                echo "   --removeHashSymbolsIfFollowedByDigits"
                echo "   --replaceWrittenEndlineWithTrueEndline"
                echo "   --insertTwoEndlinesIntoFirstLineAfterCharacterNumber (default 50)"
                echo "   --foldExceptFirstTwoLinesAfterCharacterNumber        (default 70)"
                echo "   --all          ->    Executes all commands above in the order above"
                echo "   --command      ->    Customized command (use '' to avoid shell conflicts)"
                printf  "\n\e[1;33m NOTE:\e[21;36m"
                echo " The option above can be combined and if several are provided,"
                echo "       they are considered in the given order!"
                echo "       "
                echo "       The --command option can be used for any goal. For example, to"
                echo "       remove the hash in front of any numeric label larger than 20, use"
                printf "\n\e[1m"
                echo "         --command" "'"'sed "s/#\([2-9][0-9]\+\|[1-9][0-9]\{2,\}\)/\1/g"'"'"
                echo "       "
                printf "\n\e[0m"
                exit
                shift ;;
            --capitalizeInitialOfFirstLine )
                COMMAND+=( 'sed "1s/^\(.\)/\U\1/"')
                shift ;;
            --removePeriodEndOfFirstLine )
                COMMAND+=( 'sed "1s/[.!]\+$//g"' )
                shift ;;
            --insertTwoEndlinesIntoFirstLineAfterCharacterNumber )
                if [ "$2" != '' ] && [[ ! $2 =~ ^- ]]; then
                    VALUE_OF_OPTION=$2
                    NUMBER_OF_SHIFT=2
                else
                    VALUE_OF_OPTION=50
                    NUMBER_OF_SHIFT=1
                fi
                COMMAND+=( 'sed "1s/\(.\{'${VALUE_OF_OPTION}'\}[^[:space:]]*\) /\1\n\n/"' )
                shift $NUMBER_OF_SHIFT ;;
            --foldExceptFirstTwoLinesAfterCharacterNumber )
                if [ "$2" != '' ] && [[ ! $2 =~ ^- ]]; then
                    VALUE_OF_OPTION=$2
                    NUMBER_OF_SHIFT=2
                else
                    VALUE_OF_OPTION=70
                    NUMBER_OF_SHIFT=1
                fi
                COMMAND+=( 'sed "1,2{P;D} ; :a ; N ; \$!ba ; s/\n/ /g ; s/[[:space:]]\+/ /g" | fold -s -w '${VALUE_OF_OPTION} )
                # Using references
                #    https://www.gnu.org/software/sed/manual/html_node/Multiline-techniques.html#Multiline-techniques
                #    https://www.gnu.org/software/sed/manual/html_node/Branching-and-flow-control.html
                # one can understand the command above.
                # In short:
                #  1,2{P;D}                print the first two lines
                #  :a ; N ; \$!ba          load all the rest of the file into the pattern space
                #  s/\n/ /g                remove endlines replacing them with spaces
                #  s/[[:space:]]\+/ /g     remove multiple spaces into one (they are put by
                #                          the previous command if many endlines are present)
                shift $NUMBER_OF_SHIFT ;;
            --removeHashSymbolsIfFollowedByDigits )
                COMMAND+=( 'sed "s/#\([0-9]\+\)/\1/g"' )
                shift ;;
            --replaceWrittenEndlineWithTrueEndline )
                COMMAND+=( 'sed "s/\\\\n/\n/g"' )
                shift ;;
            --command )
                COMMAND+=( "$2" )
                shift 2 ;;
            * ) printf "\n\e[0;31m Option \e[1m$1\e[21m not recognized! Aborting...\n\n\e[0m" ; exit -1 ;;
        esac
    done
}

function RunGitCommand(){
    local COMMAND_TO_BE_RUN="git filter-branch -f --msg-filter '"$@"' --tag-name-filter cat -- --all"
    printf "\n\e[35m ===== Executing \e[1m"
    echo -n "'${COMMAND_TO_BE_RUN}'"
    printf "\e[21m =====\n\n\e[0m"
    eval $(echo $COMMAND_TO_BE_RUN)
}

function ExecuteCleaningOfRepository(){
    #Ensure all old/backup refs are fully removed
    printf "\n\e[36m Ensure all old refs are fully removed...\n"
    if [ $(git for-each-ref --format="%(refname)" refs/original/ | wc -l) -ne 0 ]; then
        git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d
    fi
    rm -Rf .git/logs .git/refs/original

    #Git repository state before cleaning
    printf "\n\e[36m Git repository state before cleaning:\n\n\e[0m"
    git count-objects -vH

    #Cleaning
    printf "\n\e[36m Cleaning...\n\n\e[0m"
    git gc --prune=all --aggressive

    #Git repository state after cleaning
    printf "\n\e[36m Git repository state after cleaning:\n\n\e[0m"
    git count-objects -vH
}


#===================================================================================================================================#
#Script variables
COMMAND=()
UNTIL_DATE=''

#ParseCommandLineOption
SPECIFIED_COMMAND_LINE_OPTIONS=( "$@" )
if ElementInArray "-h" ${SPECIFIED_COMMAND_LINE_OPTIONS[@]} || ElementInArray "--help" ${SPECIFIED_COMMAND_LINE_OPTIONS[@]}; then
    SPECIFIED_COMMAND_LINE_OPTIONS=( "--help" )
elif ElementInArray "--all" ${SPECIFIED_COMMAND_LINE_OPTIONS[@]}; then
    for INDEX in ${!SPECIFIED_COMMAND_LINE_OPTIONS[@]}; do
        [ ${SPECIFIED_COMMAND_LINE_OPTIONS[$INDEX]} = '--all' ] && unset -v 'SPECIFIED_COMMAND_LINE_OPTIONS[$INDEX]'
    done
    SPECIFIED_COMMAND_LINE_OPTIONS+=( "--capitalizeInitialOfFirstLine"
                                      "--removePeriodEndOfFirstLine"
                                      "--removeHashSymbolsIfFollowedByDigits"
                                      "--replaceWrittenEndlineWithTrueEndline"
                                      "--insertTwoEndlinesIntoFirstLineAfterCharacterNumber" "50"
                                      "--foldExceptFirstTwoLinesAfterCharacterNumber" "70" )
fi
ParseCommandLineOption "${SPECIFIED_COMMAND_LINE_OPTIONS[@]}"

#Rewrite history!
if [ ${#COMMAND[@]} -eq 0 ]; then
    printf "\n\e[91m At least one command must be provided to run this script (see help menu)! Aborting...\n\n\e[0m"
    exit -1
fi

#Run each single command and then clean
for SINGLE_COMMAND in "${COMMAND[@]}"; do
    RunGitCommand "$SINGLE_COMMAND"
done
ExecuteCleaningOfRepository
