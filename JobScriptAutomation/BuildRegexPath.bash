
#
#  Copyright (c) 2014 Christopher Czaban
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

function BuildRegexPath(){

	PARAMETER_REGEX_ARRAY=([$MASS_POSITION]=$MASS_PREFIX$MASS_REGEX [$NTIME_POSITION]=$NTIME_PREFIX$NTIME_REGEX [$NSPACE_POSITION]=$NSPACE_PREFIX$NSPACE_REGEX)

	for i in ${PARAMETER_REGEX_ARRAY[@]}; do

		REGEX_PATH=$REGEX_PATH"/$i"
	done

	local REGEX_PATH='.*'$REGEX_PATH

	FIND_LOCATION_PATH=$HOME_DIR'/'$SIMULATION_PATH'/'$CHEMPOT_PREFIX$CHEMPOT'/'

	DIRECTORY_ARRAY=( $(find $FIND_LOCATION_PATH -regextype grep -regex $REGEX_PATH) )
}

