#!/usr/bin/env bash
#   Copyright 2018-2023 The University of Birmingham
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

##############################################################
##############################################################
#   FROM HERE ALL THE ELEMENTS FOR THE LOGGER
#   Guillermo Loustau
##############################################################
##############################################################

## @var DEBUG_VERBOSE
#  @brief Global variable 
#
export DEBUG_VERBOSE=""
HOG_LOG_EN=0
HOG_COLOR_EN=0
export clrschselected="dark"
export fail_when_error=0
error_failing=0

# export

if [ -v $tempfolder ]; then
  tmptimestamp=$(date +%s)
  tempfolder="/dev/shm/$USER/hog$tmptimestamp"
  if mkdir -p $tempfolder 2>/dev/null ; then
    temp_i_cnt_file="$tempfolder/hog_i_cnt"
    temp_d_cnt_file="$tempfolder/hog_d_cnt"
    temp_w_cnt_file="$tempfolder/hog_w_cnt"
    temp_c_cnt_file="$tempfolder/hog_c_cnt"
    temp_e_cnt_file="$tempfolder/hog_e_cnt"
  else
    echo " Warning : Could not create /dev/shm/$USER/hog$tmptimestamp will try /tmp/$USER/hog$tmptimestamp "
    tempfolder="/tmp/$USER/hog$tmptimestamp"
    if mkdir -p $tempfolder; then
      temp_i_cnt_file="$tempfolder/hog_i_cnt"
      temp_d_cnt_file="$tempfolder/hog_d_cnt"
      temp_w_cnt_file="$tempfolder/hog_w_cnt"
      temp_c_cnt_file="$tempfolder/hog_c_cnt"
      temp_e_cnt_file="$tempfolder/hog_e_cnt"
    else
      echo " *** ERROR Could not create /tmp/$USER/hog$tmptimestamp"
      exit 0
    fi
  fi
fi

function update_cnt () {
  if [[ -e "$1" ]]; then
    while read line ; do local_cnt=$(($line+1)); done < "$1"
    echo "$local_cnt" > "$1"
  fi
  echo "$local_cnt"
}
function read_tmp_cnt () {
  if [[ -e "$1" ]]; then
    while read line ; do local_cnt=$line; done < "$1"
  fi
  echo "$local_cnt"
}


function msg_counter () {
 case "$1" in
  init)
    echo "0" > "$temp_i_cnt_file"
    echo "0" > "$temp_d_cnt_file"
    echo "0" > "$temp_w_cnt_file"
    echo "0" > "$temp_c_cnt_file"
    echo "0" > "$temp_e_cnt_file"
  ;;
  iw) update_cnt $temp_i_cnt_file ;;
  ir) read_tmp_cnt $temp_i_cnt_file ;;
  dw) update_cnt $temp_d_cnt_file ;;
  dr) read_tmp_cnt $temp_d_cnt_file ;;
  ww) update_cnt $temp_w_cnt_file ;;
  wr) read_tmp_cnt $temp_w_cnt_file ;;
  cw) update_cnt $temp_c_cnt_file ;;
  cr) read_tmp_cnt $temp_c_cnt_file ;;
  ew) update_cnt $temp_e_cnt_file ;;
  er) read_tmp_cnt $temp_e_cnt_file ;;
  *) Msg Error "counter update doesn't exist" ;;
 esac
}

echo_info=1
echo_warnings=1
echo_errors=1

export LOG_INFO_FILE=""
export LOG_WAR_ERR_FILE=""

#Define colours
# declare -A colorsDark
txtblk='\e[0;30m' # Black - Regular
txtred='\e[0;31m' # Red
txtgrn='\e[0;32m' # Green
txtylw='\e[0;93m' # Yellow
txtorg='\e[0;33m' # Yellow
txtblu='\e[0;34m' # Blue
txtpur='\e[0;35m' # Purple
txtcyn='\e[0;36m' # Cyan
txtwht='\e[0;37m' # White

vldColorSchemes=("dark" "clear")

declare -A darkColorScheme
darkColorScheme[error]="$txtred   ERROR :$txtwht"
darkColorScheme[critical]="${txtylw}CRITICAL :$txtwht"
darkColorScheme[warning]="$txtylw WARNING :$txtwht"
darkColorScheme[debug]="$txtgrn   DEBUG :$txtwht"
darkColorScheme[info]="$txtblu    INFO :$txtwht"
darkColorScheme[vcom]="$txtblu    VCOM :$txtwht"
declare -A clearColorScheme
clearColorScheme[error]="$txtred   ERROR :$txtblk"
clearColorScheme[critical]="${txtylw}CRITICAL :$txtblk"
clearColorScheme[warning]="$txtylw WARNING :$txtblk"
clearColorScheme[debug]="$txtgrn   DEBUG :$txtblk"
clearColorScheme[info]="$txtblu    INFO :$txtblk"
clearColorScheme[vcom]="$txtblu    VCOM :$txtblk"

clrschselected="dark"

declare -A msgHeadBW
msgHeadBW[error]="   ERROR :"
msgHeadBW[critical]=" :"
msgHeadBW[warning]=" WARNING :"
msgHeadBW[debug]="   DEBUG :"
msgHeadBW[info]="    INFO :"
msgHeadBW[vcom]="    VCOM :"

declare -A simpleColor
simpleColor[error]="$txtred"
simpleColor[critical]="$txtorg"
simpleColor[warning]="$txtcyn"
simpleColor[debug]="$txtgrn"
simpleColor[info]="$txtwht"
simpleColor[vcom]="$txtwht"

declare -A msgCounter
msgCounter[error]="ew"
msgCounter[critical]="cw"
msgCounter[warning]="ww"
msgCounter[debug]="dw"
msgCounter[info]="iw"
msgCounter[vcom]="iw"

declare -A msgDbgLvl
msgDbgLvl[error]=0
msgDbgLvl[critical]=1
msgDbgLvl[warning]=2
msgDbgLvl[debug]=4
msgDbgLvl[info]=3
msgDbgLvl[vcom]=3

declare -A msgRemove
msgRemove[error]="*@(ERROR:|Error:)"
msgRemove[critical]="*@(WARNING: |Warning: |warning: )"
msgRemove[warning]="*@(WARNING: |Warning: |warning: )"
msgRemove[debug]="DEBUG: "
msgRemove[info]="INFO: "
msgRemove[vcom]="INFO: "

declare -A errorOverload
declare -A criticalOverload
declare -A warningOverload
declare -A infoOverload
declare -A debugOverload

## @function log_stdout()
# 
# @brief parsers the output of the executed program ( Vivado, Questa,...) 
# 
# @param[in] execution line to process
next_is_err=0
shopt -s extglob

line_type=""


function log_stdout(){
  if [ -n "${2}" ]; then
    IN_out="${2}"
  else
    while read -r IN_out # This reads a string from stdin and stores it in a variable called IN_out
    do
      if [[ $next_is_err == 0 ]]; then
        line="${IN_out}"
      else
        line="ERROR:${IN_out}"
        next_is_err=$(($next_is_err-1))
      fi
      if [ "${1}" == "stdout" ]; then
        # echo " :::::: $line"
        dataLine=$line
        # for value in $dataLine
        # do
        #     echo $value
        # done
        # echo "  ************************************ "
        case "$line" in
          *'ERROR:'* | *'Error:'* | *':Error'* | *'error:'* | *'Error '* | *'FATAL ERROR'* | *'Fatal'*)
            if [[ "$line" == *'Fatal'* ]]; then
              next_is_err=1
            fi
            msgType="error"
            # msgType=$(msgTypeOverload "error" "$dataLine")
          ;;
          *'CRITICAL:'* | *'CRITICAL WARNING:'* ) 
            # msgTypeOverload msgType "critical" "$dataLine"
            msgType="critical"
          ;;
          *'WARNING:'* | *'Warning:'* | *'warning:'*)
            # msgTypeOverload msgType "warning" "$dataLine"
            msgType="warning"
          ;;
          *'INFO:'*)
            # msgTypeOverload msgType "info" $dataLine
            msgType="info"
          ;;
          *'DEBUG:'*)
            # msgTypeOverload msgType "debug" "$dataLine"
            msgType="debug"
            ;;
          *'vcom'*)
            # msgTypeOverload msgType "vcom" "$dataLine"
            msgType="vcom"
            ;;
          *)
            # msgType=$(msgTypeOverload "info" "$dataLine")
            msgType="info"
            # echo " Jodeeeeeeeeeeeeeeeeeeer : $msgType"
            ;;
        esac
      elif [ "${1}" == "stderr" ]; then
        stderr_line=$dataLine
        msgType="error"
      else
       Msg Error "Error in logger" 
      fi  
      #######################################
      # Overwriting
      #######################################
      case "$msgType" in
        "error")
          # echo "inside error"
          for key in "${!errorOverload[@]}"; do
            # echo "key :-: $key"
            if [[ "$line" == *"$key"* ]]; then
              Msg Debug "Message level Override: Key < '$key' > exists in the string < $line > with value '${errorOverload[$key]}'"
              msgType="${errorOverload[$key]}"
            fi
          done
        ;;
        "critical") 
          # echo "inside c"
          for key in "${!criticalOverload[@]}"; do
            if [[ "$line" == *"$key"* ]]; then
              Msg Debug "Message level Override: Key < '$key' > exists in the string < $line > with value '${criticalOverload[$key]}'"
              msgType="${criticalOverload[$key]}"
            fi
          done
        ;;
        "warning") 
          # echo "inside w"
          for key in "${!warningOverload[@]}"; do
            if [[ "$line+" == *"$key"* ]]; then
              Msg Debug "Message level Override: Key < '$key' > exists in the string < $line > with value '${warningOverload[$key]}'"
              msgType="${warningOverload[$key]}"
            fi
          done
        ;;
        "info") 
          # echo "inside i - $line"
          for key in "${!infoOverload[@]}"; do
            echo " joder que meirda"
            if [[ "$line" == *"$key"* ]]; then
              Msg Debug "Message level Override: Key < '$key' > exists in the string < $line > with value '${infoOverload[$key]}'"
              msgType="${infoOverload[$key]}"
            fi
          done
          # echo "inside i - msgTypeOut -:-: $msgTypeOut"

        ;;
        "vcom") 
          # echo "inside v"
          for key in "${!infoOverload[@]}"; do
            if [[ "$line" == *"$key"* ]]; then
              Msg Debug "Message level Override: Key < '$key' > exists in the string < $line > with value '${infoOverload[$key]}'"
              msgType="${infoOverload[$key]}"
            fi
          done
        ;;
        "debug") 
          # echo "inside d"
          for key in "${!debugOverload[@]}"; do
            if [[ "$line" == *"$key"* ]]; then
              Msg Debug "Message level Override: Key < '$key' > exists in the string < $line > with value '${debugOverload[$key]}'"
              msgType="${debugOverload[$key]}"
            fi
          done
        ;;
      esac
      #######################################
        # The writing will be done here
      #######################################
  # echo "HOG_COLOR_EN = $HOG_COLOR_EN"
      # echo "msgType :-: $msgType"
      if [[ $DEBUG_VERBOSE -gt 5 ]]; then
        printf "%d : %d :" $BASHPID "$(msg_counter ${msgCounter[$msgType]})"  
      else
        msg_counter "${msgCounter[$msgType]}" >> /dev/null
      fi;
      if [[ $DEBUG_VERBOSE -gt ${msgDbgLvl[$msgType]} ]]; then
        if [[ $HOG_COLOR_EN -gt 1 ]]; then
          case "${clrschselected}" in
            "dark")
              echo -e "${darkColorScheme[$msgType]} ${dataLine#${msgRemove[$msgType]}} " 
            ;;
            "clear")
              echo -e "${clearColorScheme[$msgType]} ${dataLine#${msgRemove[$msgType]}} " 
            ;;
          esac
        elif [[ $HOG_COLOR_EN -gt 0 ]]; then
          echo -e "${simpleColor[$msgType]} $dataLine $txtwht"
        else
          echo -e "$dataLine"
        fi
      fi
      if [[ $HOG_LOG_EN -gt 0 ]]; then
        if [[ -n $LOG_WAR_ERR_FILE ]] && [[ 3 -gt ${msgDbgLvl[$msgType]} ]]; then 
          echo "${msgHeadBW[$msgType]} ${dataLine#${msgRemove[$msgType]}} "  >> $LOG_WAR_ERR_FILE
        fi
        if [[ -n $LOG_INFO_FILE ]]; then 
          echo "${msgHeadBW[$msgType]} ${dataLine#${msgRemove[$msgType]}} "  >> $LOG_INFO_FILE; 
        fi
      fi
      if [[ "$msgType" == "error" ]]; then
        # echo "The two strings are the same -- $msgType"
        if (( $fail_when_error > 0 )); then
          # echo "fail_when_error -- $error_failing -- $fail_when_error"
          error_failing=$fail_when_error
          failing_en=1
        fi
      fi
      if [[ $failing_en -gt 0 ]];then
        if [[ $error_failing -gt 1 ]]; then
          # echo "error_failing -- $error_failing"
          error_failing=$(($error_failing - 1))
        else
          # echo "exitaaaando"
          exit -1
        fi
      fi
      
      
      
      
    done    
  fi
}

## @function Hog_exit()
  # 
  # @brief Prints a resum of the messages types
function Hog_exit () {
  echo "================ RESUME ================ "
  echo " # of Info messages: $(msg_counter ir)"
  echo " # of debug messages : $(msg_counter dr)"
  echo " # of warning messages : $(msg_counter wr)"
  echo " # of critical warning messages : $(msg_counter cr)"
  echo " # of Errors messages : $(msg_counter er)"
  echo "======================================== "
  if [[ $(msg_counter er) -gt 0 ]]; then
    echo -e "$txtred *** Hog finished with errors *** $txtwht"
    exit 1
  else
    echo -e "$txtgrn *** Hog finished  without errors *** $txtwht"
    exit 0
  fi
}

## @function Log_capture()
  # 
  # @brief creates output files and pipelines stdout and stderr to 
  # 
  # @param[in] execution line to process
function Log_capture(){

  Msg Debug "Logger args : $*"
  $* > >(log_stdout "stdout") 2> >(log_stdout "stderr" >&2) &
  # $* > >(test1 "stdout") 2> >(test2 "stderr") &
  tcl_pid=$!
  Msg Debug "pid = $tcl_pid"
  while kill -0 $tcl_pid 2>/dev/null; do
    sleep 1
  done
}

## @function Log_capture()
  # 
  # @brief creates output files and pipelines stdout and stderr to 
  # 
  # @param[in] execution line to process
function Logger () {
  # echo "$@"
  if [[ "$HOG_LOG_EN" -gt 0 ]] || [[  "$HOG_COLOR_EN" -gt 0 ]]; then
    Log_capture "$@"
  else
    "$@"
  fi
  if [[  "$HOG_COLOR_EN" -gt 0 ]]; then
    Hog_exit
  else
    exit $?
  fi
}

# @function Msg
  #
  # @param[in] messageLevel: it can be Info, Warning, CriticalWarning, Error
  # @param[in] message: the error message to be printed
  #
  # @return  '1' if missing arguments else '0'
function Msg() {
  if [ "a$1" == "a" ]; then
    Msg Error "messageLevel not set!"
    return 1
  fi

  if [ "a$2" == "a" ]; then
    text=""
  else
    text="$2"
  fi

  local print_msg=0

  case $1 in
    "Error") msgType="error" ;;
    "CriticalWarning") msgType="critical" ;;
    "Warning") msgType="warning" ;;
    "Info") msgType="info" ;;
    "Debug") msgType="debug" ;;
    *) Msg Error "messageLevel: $1 not supported! Use Info, Warning, CriticalWarning, Error" ;;
  esac
  ####### The printing
  # echo "HOG_COLOR_EN = $HOG_COLOR_EN"
  if [[ $DEBUG_VERBOSE -gt 5 ]]; then
    printf "%d : %d :" $BASHPID "$(msg_counter dw)" 
  else
    msg_counter dw >> /dev/null
  fi;
  
  if [[ $DEBUG_VERBOSE -gt ${msgDbgLvl[$msgType]} ]]; then
    if [[ $HOG_COLOR_EN -gt 1 ]]; then
      case "${clrschselected}" in
        "dark")
          echo -e "${darkColorScheme[$msgType]} HOG:$1[${FUNCNAME[1]}] $text" 
        ;;
        "clear")
          echo -e "${clearColorScheme[$msgType]} HOG:$1[${FUNCNAME[1]}] $text " 
        ;;
      esac
    elif [[ $HOG_COLOR_EN -gt 0 ]]; then
        echo -e "${simpleColor[$msgType]} HOG:$1[${FUNCNAME[1]}] $text $txtwht"
    else
        echo -e " HOG:$1[${FUNCNAME[1]}] $text"
    fi
  fi
  if [[ $HOG_LOG_EN -gt 0 ]]; then
    if [[ -n $LOG_WAR_ERR_FILE ]] && [[ 3 -gt ${msgDbgLvl[$msgType]} ]]; then 
      echo "${msgHeadBW[$msgType]} HOG [${FUNCNAME[1]}] : $text " >> $LOG_INFO_FILE; 
      # echo "${msgHeadBW[$msgType]} ${dataLine#${msgRemove[$msgType]}} "  >> $LOG_WAR_ERR_FILE
    fi
    if [[ -n $LOG_INFO_FILE ]]; then 
      echo "${msgHeadBW[$msgType]} HOG [${FUNCNAME[1]}] : $text " >> $LOG_INFO_FILE; 
      # echo "${msgHeadBW[$msgType]} ${dataLine#${msgRemove[$msgType]}} "  >> $LOG_INFO_FILE; 
    fi
  fi
  return 0
}

declare -A Hog_Prj_dict  
declare -A Hog_Usr_dict  

process_toml_file() {
  local file_path=$1
  local dict_name=$2
  declare -n toml_dict=$dict_name
  while IFS= read -r line; do
    echo " ######################### "
    echo $line
    # line="${line%%#*}"
    line=$(echo "$line" | sed -E 's/#.*$|("[^"]*")|('\''[^'\'']*'\'')/\1/g')
    echo $line
    if [[ $line =~ ^\[.*\] ]]; then
      # echo "1 - $line"
      section_name=$(echo "$line" | sed 's/[[:space:]]*$//' | sed 's/\[\(.*\)\]/\1/' | sed 's/ /_/g' )
      echo "section_name :-: $section_name"
    elif [[ $line =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
      echo "2 - $line"
      # key=$(echo "$line" | cut -d'=' -f1 | xargs)  # Trim leading/trailing whitespace
      key=$(echo "$line" | sed 's/=.*//')
      echo "2 - key - $key"
      if ! [[ $(echo "$line" | sed 's/.*=//') =~ [\[\],] ]]; then
        value=$(echo "$line" | sed -n 's/.*=\(.*\)/\1/p' | sed 's/\[\|\]//g') 
        echo "21 - value - $value"
        if [[ $value == *,* ]]; then
          index=0
          # Loop over all the elements separated by a comma
          IFS=',' read -ra elements <<< "$value"
          for element in "${elements[@]}"; do
            echo "211 - Element: $element"
            toml_dict["$section_name.$key_$index"]="$value"
            ((index++))
          done
        else
          echo "212 - value - $value"
          toml_dict["$section_name.$key"]="$value"
        fi
        
      else
        if [[ $(echo "$line" | sed 's/.*=//') =~ ^[A-Za-z0-9_]+$ ]]; then
        if [[ $(echo "$line" | sed 's/.*=//') =~ \[[^\]] ]]; then
          echo "open array"
        else
          value=$(echo "$line" | sed -n 's/.*=\(.*\)/\1/p')
          echo "22 - value - $value"
          toml_dict["$section_name.$key"]="$value"
        fi
      fi
      fi
      # Check if the content after = contains only numbers, characters, or underscores
      

      # value=$(echo "$line" | cut -d'=' -f2- | xargs)  # Trim leading/trailing whitespace
    else
      echo "3 - $line"
    fi
  done < $1  # Replace with the actual path to your TOML file
}

## @function Logger_Init()
  # 
  # @brief creates output files and pipelines stdout and stderr to 
  # 
  # @param[in] execution line to process
function Logger_Init() {
  # shellcheck disable=SC1087
  DEBUG_VERBOSE=4
  if [[ "$@" =~ "-verbose" ]]; then
    DEBUG_VERBOSE=5
  fi
  
  ROOT_PROJECT_FOLDER=$(pwd)
  LOG_INFO_FILE=$ROOT_PROJECT_FOLDER"/hog_info.log"
  LOG_WAR_ERR_FILE=$ROOT_PROJECT_FOLDER"/hog_warning_errors.log"
  msg_counter init

  declare -A CONF
  CONF[test]="on"

  # declare -A yaml_dict
  current_user=$(whoami)
  hog_proj_cfg=$(pwd)"/HogEnv.conf"
  hog_user_cfg=$(eval echo "~$USER")"/HogEnv.conf"
  if test -f $hog_proj_cfg; then
    Msg Info "Hog project configuration file $hog_proj_cfg exists."
    process_toml_file $hog_proj_cfg "Hog_Prj_dict"
    for key in "${!Hog_Prj_dict[@]}"; do
      echo "First File - Key: $key, Value: ${Hog_Prj_dict[$key]}"
    done
    
  else
    Msg Debug "Hog project configuration file $hog_proj_cfg doesn't exists."
  fi
  if test -f $hog_user_cfg; then
    Msg Info "Hog user configuration file $hog_user_cfg exists."
  else
    Msg Debug "Hog user configuration file $hog_user_cfg doesn't exists."
  fi
  #   eval $(parse_yaml $hog_prj_cfg "CONF_")
  #   size=${#CONF[@]}
  #   Msg Debug  " --------------- The size of the dictionary is $size"
  #   for key in "${!CONF[@]}"; do
  #       Msg Debug "CONF[$key] --- ${CONF[$key]}"
  #   done
  # else
  #     Msg Warning "Configuration file does not exist."
  # fi

  
  # echo "Current user: $current_user"


  exit

  # SETTING DEBUG_VERBOSE
  hog_user_td="${current_user}_terminal_debug"
  # HOG_LOG_EN=0
  # echo "$hog_user_tc"
  if [[ -v CONF["$hog_user_td"] ]]; then
    if [[ ${CONF["$hog_user_td"]} =~ ^[0-9]$ ]]; then
      Msg Debug "The variable $hog_user_td is ${CONF['$hog_user_td']}"
      DEBUG_VERBOSE=${CONF["$hog_user_td"]}
    else
      Msg Warning "The variable $hog_user_td is not a one-digit number, Defaulting to 0"
    fi
  else
    if [[ -v CONF[global_terminal_debug] ]]; then
      if [[ ${CONF["global_terminal_debug"]} =~ ^[0-9]$ ]]; then
        Msg Debug "The variable global_terminal_debug is a one-digit number"
        DEBUG_VERBOSE=${CONF["global_terminal_debug"]}
      else 
        Msg Warning "The variable global_terminal_debug is not a one-digit number, Defaulting to 0, Defaulting to 0"
      fi
    # else
    fi
  fi
  if [[ "$@" =~ "-verbose" ]]; then
    if (( $DEBUG_VERBOSE < int2 )); then
      DEBUG_VERBOSE=5
    fi
  fi
  Msg Debug "DEBUG_VERBOSE -- $DEBUG_VERBOSE"

  # SETTING LOGGER
  hog_user_tl="${current_user}_terminal_logger"
  HOG_LOG_EN=0
  # echo "$hog_user_tc"
  if [[ -v CONF["$hog_user_tl"] ]]; then
    if [[ ${CONF["$hog_user_tl"]} =~ ^[01]$ ]]; then
      Msg Debug "The variable $hog_user_tl is ${CONF['$hog_user_tl']}"
      HOG_LOG_EN=${CONF["$hog_user_tl"]}
    else
      Msg Warning "The variable $hog_user_tl is not 1 or 0, Default to 0"
    fi
  else
    if [[ -v CONF[global_terminal_logger] ]]; then
      if [[ ${CONF["global_terminal_logger"]} =~ ^[01]$ ]]; then
        Msg Debug "The variable global_terminal_logger is a one-digit number"
        HOG_LOG_EN=${CONF["global_terminal_logger"]}
      else 
        Msg Warning "The variable global_terminal_logger is not a one-digit number, Defaulting to 0"
      fi
    else
      if [[ -v HOG_LOGGER && $HOG_LOGGER == ENABLED ]]; then
        HOG_LOG_EN=1
      fi
    fi
  fi
  Msg Debug "HOG_LOG_EN -- $HOG_LOG_EN"

  # SETTING COLORS
  HOG_COLOR_EN=0
  hog_user_tc="${current_user}_terminal_colored"
  # echo "$hog_user_tc"
  if [[ -v CONF["$hog_user_tc"] ]]; then
    if [[ ${CONF["$hog_user_tc"]} =~ ^[0-9]$ ]]; then
      Msg Debug "The variable $hog_user_tc is a one-digit number"
      HOG_COLOR_EN=${CONF["$hog_user_tc"]}
    else
      Msg Warning "The variable $hog_user_tc is not a one-digit number, Defaulting to 0"
    fi
  else
    if [[ -v CONF[global_terminal_colored] ]]; then
      if [[ ${CONF["global_terminal_colored"]} =~ ^[0-9]$ ]]; then
        Msg Debug "The variable global_terminal_colored is a one-digit number"
        HOG_COLOR_EN=${CONF["global_terminal_colored"]}
      else 
        Msg Warning "The variable global_terminal_colored is not a one-digit number, Defaulting to 0"
      fi
    else
      if [[ -v HOG_COLORED && $HOG_COLORED == ENABLED ]]; then
        HOG_COLOR_EN=1
      fi
    fi
  fi
  Msg Debug "HOG_COLOR_EN -- $HOG_COLOR_EN"

  hog_user_cs="${current_user}_terminal_colorscheme"
  # echo $hog_user_cs
  if [[ -v CONF["$hog_user_cs"] ]]; then
    clrschselected=${CONF["$hog_user_cs"]}
  elif  [[ -v CONF[global_terminal_colorscheme] ]]; then
    clrschselected="${CONF['global_terminal_colorscheme']}"
  else
    clrschselected="dark"
  fi
  if [[ " ${vldColorSchemes[*]} " =~ " $clrschselected " ]]; then
    Msg Info "Color Scheme set to $clrschselected"
  else
    Msg Warning "Invalid color scheme $clrschselected ; Color scheme set to dark"
    clrschselected="dark"
  fi
  Msg Debug "color terminal = $clrschselected"

  # error fail
  hog_user_fwe="${current_user}_fail_when_error_enabled"
  hog_user_dfwe="${current_user}_fail_when_error_delay"
  if [[ -v CONF["$hog_user_fwe"] ]]; then
    if [[ -v CONF["$hog_user_dfwe"] ]]; then
      fail_when_error=$((1 + ${CONF["$hog_user_dfwe"]}))
    else
      fail_when_error=1
    fi
  elif  [[ -v CONF[global_fail_when_error_enabled] ]]; then
    if [[ -v CONF["global_fail_when_error_delay"] ]]; then
      fail_when_error=$((1 + ${CONF["global_fail_when_error_delay"]}))
    else
      fail_when_error=1
    fi
  else
    fail_when_error=0
  fi
  Msg Debug "fail_when_error = $fail_when_error"

  


  
  hog_user_eo="${current_user}_overloads"
  use_user_ol=0
  use_glob_ol=1
  for key in "${!CONF[@]}"; do
    if [[ $key == *"$hog_user_eo"* ]]; then
      # echo "key $key"
      if [[ $key == *"include_global"* ]]; then
        use_glob_ol=${CONF["${hog_user_eo}_include_global"]}
      fi
      if [[ $key =~ _[a-z]2[a-z]_ ]]; then
          # echo "aaaaa"
          case "${key}" in
            *"2e"*) destination="error" ;;
            *"2c"*) destination="critical" ;;
            *"2w"*) destination="warning" ;;
            *"2i"*) destination="info" ;;
            *"2d"*) destination="debug" ;;
          esac
          case "${key}" in
            *"e2"*) errorOverload["${CONF[$key]}"]=$destination ;;
            *"c2"*) criticalOverload["${CONF[$key]}"]=$destination ;;
            *"w2"*) warningOverload["${CONF[$key]}"]=$destination ;;
            *"e2"*) infoOverload["${CONF[$key]}"]=$destination ;;
            *"e2"*) debugOverload["${CONF[$key]}"]=$destination ;;
          esac
        fi
    fi
  done

  # echo "use_glob_ol : $use_glob_ol"

  if (( $use_glob_ol == 1 )); then
    for key in "${!CONF[@]}"; do
      if [[ $key == *"global_overloads"* ]]; then
        # echo "key--- $key"
        if [[ $key =~ _[a-z]2[a-z]_ ]]; then
          # echo "aaaaa"
          case "${key}" in
            *"2e"*) destination="error" ;;
            *"2c"*) destination="critical" ;;
            *"2w"*) destination="warning" ;;
            *"2i"*) destination="info" ;;
            *"2d"*) destination="debug" ;;
          esac
          case "${key}" in
            *"e2"*) errorOverload["${CONF[$key]}"]=$destination ;;
            *"c2"*) criticalOverload["${CONF[$key]}"]=$destination ;;
            *"w2"*) warningOverload["${CONF[$key]}"]=$destination ;;
            *"e2"*) infoOverload["${CONF[$key]}"]=$destination ;;
            *"e2"*) debugOverload["${CONF[$key]}"]=$destination ;;
          esac
        fi
      fi
    done
  fi
  for key in "${!errorOverload[@]}"; do
    Msg Debug "::: errorOverload[$key] --- ${errorOverload[$key]}"
  done
  for key in "${!criticalOverload[@]}"; do
    Msg Debug "::: criticalOverload[$key] --- ${criticalOverload[$key]}"
  done
  for key in "${!warningOverload[@]}"; do
    Msg Debug "::: warningOverload[$key] --- ${warningOverload[$key]}"
  done
  for key in "${!infoOverload[@]}"; do
    Msg Debug "::: infoOverload[$key] --- ${infoOverload[$key]}"
  done
  for key in "${!debugOverload[@]}"; do
    Msg Debug "::: debugOverload[$key] --- ${debugOverload[$key]}"
  done


  custom_timestamp=$(date +"%Y-%m-%d_%H:%M:%S")

  if [ "$HOG_LOG_EN" -eq 1 ]; then
    {
      # print_log_hog $HOG_GIT_VERSION
      echo "-----------------------------------------------"
      echo " HOG INFO LOG "
      echo " CMD : ${1} "
      echo " Timestamp: $custom_timestamp"
      echo "-----------------------------------------------"
    } > $LOG_INFO_FILE
    {
      # print_log_hog $HOG_GIT_VERSION
      echo "-----------------------------------------------"
      echo " HOG WARNINGS AND ERRORS"
      echo " CMD : ${1} "
      echo " Timestamp: $custom_timestamp"
      echo "-----------------------------------------------"
    } > $LOG_WAR_ERR_FILE

    Msg Debug "LogColorVivado : $*"
    log_stdout "stdout" "LogColorVivado : $*"
    log_stdout "stderr" "LogColorVivado : $*"
  fi
}



