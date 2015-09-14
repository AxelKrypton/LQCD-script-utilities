# Paths on LOEWE using CL2QCD
USER_MAIL="czaban@th.physik.uni-frankfurt.de"
HMC_BUILD_PATH="cl2qcd/build/RefExec"
SIMULATION_PATH="IntegratorTestWilson"
HOME_DIR="/lustre/nyx/lcsc/cczaban" 
WORK_DIR="/lustre/nyx/lcsc/cczaban" 
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
