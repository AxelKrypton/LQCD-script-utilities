# Paths on LOEWE using CL2QCD
#
#  Copyright (c) 2014,2015 Christopher Czaban
#  Copyright (c) 2019 Alessandro Sciarra
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

USER_MAIL="czaban@th.physik.uni-frankfurt.de"
HMC_BUILD_PATH="cl2qcd/build/RefExec"
SIMULATION_PATH="IntegratorTestWilson"
HOME_DIR="/lustre/lcsc/cczaban"
WORK_DIR="/lustre/lcsc/cczaban"
PRODUCEJOBSCRIPTSH="$HOME_DIR/Script/JobScriptAutomation/ProduceJobScript.sh"
PRODUCEINPUTFILESH="$HOME_DIR/Script/JobScriptAutomation/ProduceInputFile.sh"
HMC_FILENAME="hmc_ref"
HMC_GLOBALPATH="$HOME_DIR/$HMC_BUILD_PATH/$HMC_FILENAME"
INPUTFILE_NAME="hmc.input"
JOBSCRIPT_PREFIX="job.cl2qcd.Thermalize"
OUTPUTFILE_NAME="hmc_output"
THERMALIZED_CONFIGURATIONS_PATH="$HOME_DIR/$SIMULATION_PATH/Thermalized_Configurations"
GPU_PER_NODE=1
JOBSCRIPT_LOCALFOLDER="JobScripts"

#SCRIPT_DIR="$HOME_DIR/Script/tmLQCD_Juqueen"
