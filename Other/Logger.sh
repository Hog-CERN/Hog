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
export HOG_LOG_EN=""
export HOG_COLOR_EN=""
export clrschselected="dark"

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
# colorsDark[txtblk]='\e[0;30m' # Black - Regular
# colorsDark[txtred]='\e[0;31m' # Red
# colorsDark[txtgrn]='\e[0;32m' # Green
# colorsDark[txtylw]='\e[0;93m' # Yellow
# colorsDark[txtorg]='\e[0;33m' # Yellow
# colorsDark[txtblu]='\e[0;34m' # Blue
# colorsDark[txtpur]='\e[0;35m' # Purple
# colorsDark[txtcyn]='\e[0;36m' # Cyan
# colorsDark[txtwht]='\e[0;37m' # White

declare -A msgHeadBW
msgHeadBW[error]="   ERROR :"
msgHeadBW[critical]=" :"
msgHeadBW[warning]=" WARNING :"
msgHeadBW[debug]="   DEBUG :"
msgHeadBW[info]="    INFO :"
msgHeadBW[vcom]="    VCOM :"

# declare -A msgHeadC
# msgHeadBW[info]="    INFO :"

# msgHeadC[dark]=darkColorScheme

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
        line=${IN_out}
      else
        line="ERROR:${IN_out}"
        next_is_err=$(($next_is_err-1))
      fi
      if [ "${1}" == "stdout" ]; then
        # echo " :::::: $line"
        dataLine=$line
        case "$line" in
          *'ERROR:'* | *'Error:'* | *':Error'* | *'error:'* | *'Error '* | *'FATAL ERROR'* | *'Fatal'*)
            if [[ "$line" == *'Fatal'* ]]; then
              next_is_err=1
            fi
            error_line=$line
            msgType="error"
          ;;
          *'CRITICAL:'* | *'CRITICAL WARNING:'* )
            critical_line=$line
            msgType="critical"
          ;;
          *'WARNING:'* | *'Warning:'* | *'warning:'*)
            warning_line=$line
            msgType="warning"
          ;;
          *'INFO:'*)
            info_line=$line
            msgType="info"
          ;;
          *'DEBUG:'*)
            debug_line=$line
            msgType="debug"
            ;;
          *'vcom'*)
            vcom_line=$line
            msgType="vcom"
            ;;
          *)
            info_line=$line
            msgType="info"
            ;;
        esac
      elif [ "${1}" == "stderr" ]; then
        stderr_line=$line
        msgType="error"
      else
       Msg Error "Error in logger" 
      fi  
      #######################################
        # The writing will be done here
      #######################################
      if [[ $DEBUG_VERBOSE -gt 5 ]]; then
        printf "%d : %d :" $BASHPID "$(msg_counter ${msgCounter[$msgType]})"  
      else
        msg_counter "${msgCounter[$msgType]}" >> /dev/null
      fi;
      if [[ $DEBUG_VERBOSE -gt ${msgDbgLvl[$msgType]} ]]; then
        if [[ $HOG_COLOR_EN -gt 0 ]]; then
          case "${clrschselected}" in
            "dark")
              echo -e "${darkColorScheme[$msgType]} ${dataLine#${msgRemove[$msgType]}} " 
            ;;
            "clear")
              echo -e "${clearColorScheme[$msgType]} ${dataLine#${msgRemove[$msgType]}} " 
            ;;
          esac
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
  if [[ "$HOG_LOG_EN" -eq 1 ]] || [[  "$HOG_COLOR_EN" -eq 1 ]]; then
    Log_capture "$@"
  else
    "$@"
  fi
  if [[  "$HOG_COLOR_EN" -eq 1 ]]; then
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
    "Error")
      msgType="error"
      # if [[ $DEBUG_VERBOSE -gt 5 ]]; then
      #   printf "%d : %d :" $BASHPID "$(msg_counter ew)"  
      # else
      #   msg_counter ew >> /dev/null
      # fi;
      # if [[ $DEBUG_VERBOSE -gt 0 ]]; then
      #   print_msg=1
      #   if [[ -n "$HOG_COLORED" ]]; then
      #     echo -e "$txtred   ERROR $txtwht: HOG [${FUNCNAME[1]}] : $text "; 
      #   else
          Colour=$txtred
      #   fi
      # fi
      # if [[ -n $HOG_LOGGER ]]; then
      #   if [[ -n $LOG_INFO_FILE ]]; then 
      #     echo "   ERROR : HOG [${FUNCNAME[1]}] : $text " >> $LOG_INFO_FILE; 
      #     echo "   ERROR : HOG [${FUNCNAME[1]}] : $text " >> $LOG_WAR_ERR_FILE; 
      #   fi
      # fi
      ;;
    "CriticalWarning")
      msgType="critical"
      # if [[ $DEBUG_VERBOSE -gt 5 ]]; then
      #   printf "%d : %d :" $BASHPID "$(msg_counter cw)"
      # else
      #   msg_counter cw >> /dev/null 
      # fi;
      # if [[ $DEBUG_VERBOSE -gt 1 ]]; then
      #   print_msg=1
      #   if [[ -n "$HOG_COLORED" ]]; then
      #     echo -e "${txtblu}CRITICAL $txtwht: HOG [${FUNCNAME[1]}] : $text "; 
      #   else
          Colour=$txtorg
      #   fi
      # fi
      # if [[ -n $HOG_LOGGER ]]; then
      #   if [[ -n $LOG_INFO_FILE ]]; then 
      #     echo "CRITICAL : HOG [${FUNCNAME[1]}] : $text " >> $LOG_INFO_FILE; 
      #     echo "CRITICAL : HOG [${FUNCNAME[1]}] : $text " >> $LOG_WAR_ERR_FILE; 
      #   fi
      # fi
      ;;
    "Warning")
      msgType="warning"
      # if [[ $DEBUG_VERBOSE -gt 5 ]]; then
      #   printf "%d : %d :" $BASHPID "$(msg_counter ww)"
      # else
      #   msg_counter ww >> /dev/null
      # fi;
      # if [[ $DEBUG_VERBOSE -gt 2 ]]; then
      #   print_msg=1
      #   if [[ -n "$HOG_COLORED" ]]; then
      #     echo -e "$txtylw WARNING $txtwht: HOG [${FUNCNAME[1]}] : $text "; 
      #   else
          Colour=$txtcyn
      #   fi
      # fi
      # if [[ -n $HOG_LOGGER ]]; then
      #   if [[ -n $LOG_INFO_FILE ]]; then 
      #     echo "WARNING : HOG [${FUNCNAME[1]}] : $text" >> $LOG_INFO_FILE; 
      #     echo "WARNING : HOG [${FUNCNAME[1]}] : $text" >> $LOG_WAR_ERR_FILE; 
      #   fi
      # fi
      ;;
    "Info")
      msgType="info"
      # if [[ $DEBUG_VERBOSE -gt 5 ]]; then
      #   printf "%d : %d :" $BASHPID "$(msg_counter iw)"
      # else
      #   msg_counter iw >> /dev/null
      # fi;
      # if [[ $DEBUG_VERBOSE -gt 3 ]]; then
      #   print_msg=1
      #   if [[ -n "$HOG_COLORED" ]]; then
      #     echo -e "$txtblu    INFO $txtwht: HOG [${FUNCNAME[1]}] : $text "; 
      #   else
          Colour=$txtwht
      #   fi
      # fi
      # if [[ -n $HOG_LOGGER ]]; then
      #   if [[ -n $LOG_INFO_FILE ]]; then 
      #     echo "    INFO : HOG [${FUNCNAME[1]}] : $text" >> $LOG_INFO_FILE; 
      #   fi
      # fi
      ;;
    "Debug")
      msgType="debug"
      # if [[ $DEBUG_VERBOSE -gt 5 ]]; then
      #   printf "%d : %d :" $BASHPID "$(msg_counter dw)" 
      # else
      #   msg_counter dw >> /dev/null
      # fi;
      # if [[ $DEBUG_VERBOSE -gt 4 ]]; then
      #   print_msg=1
      #   if [[ -n "$HOG_COLORED" ]]; then
      #       echo -e "${txtgrn}   DEBUG${txtwht} : HOG [${FUNCNAME[1]}] : $text "; 
      #   else
          Colour=$txtgrn
      #   fi
      # fi
      # if [[ -n $HOG_LOGGER ]]; then
      #   if [[ -n $LOG_INFO_FILE ]]; then 
      #     echo "   DEBUG : HOG [${FUNCNAME[1]}] : $text " >> $LOG_INFO_FILE; 
      #   fi
      # fi
      ;;
    *)
      Msg Error "messageLevel: $1 not supported! Use Info, Warning, CriticalWarning, Error"
      ;;
  esac
  ####### The printing
  if [[ $DEBUG_VERBOSE -gt 5 ]]; then
    printf "%d : %d :" $BASHPID "$(msg_counter dw)" 
  else
    msg_counter dw >> /dev/null
  fi;
  # if [[ $DEBUG_VERBOSE -gt ${msgDbgLvl[$msgType]} ]]; then
  #   print_msg=1
  #   if [[ -n "$HOG_COLORED" ]]; then
  #       echo -e "${txtgrn}   DEBUG${txtwht} : HOG [${FUNCNAME[1]}] : $text "; 
  #   else
  #     Colour=$txtgrn
  #   fi
  # fi
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
        echo -e "${Colour} HOG:$1[${FUNCNAME[1]}] $text $txtwht"
    else
        echo -e " HOG:$1[${FUNCNAME[1]}] $text"
    fi
  fi
  # if [[ -n $HOG_LOGGER ]]; then
    # if [[ -n $LOG_INFO_FILE ]]; then 
    #   echo "   DEBUG : HOG [${FUNCNAME[1]}] : $text " >> $LOG_INFO_FILE; 
    # fi
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
  # fi
  # if [[ $print_msg == 1 ]]; then
  #   if [[ -z $HOG_COLORED ]] ; then
  #     if [[ "$1" != "Debug" ]]; then
  #       echo -e "${Colour}HOG:$1[${FUNCNAME[1]}] $text $txtwht"
  #     else
  #       if [[ $DEBUG_VERBOSE -gt 0 ]]; then
  #         echo -e "${Colour}HOG:$1[${FUNCNAME[1]}] $text $txtwht"
  #       fi
  #     fi
  #   fi
  # fi
  
  
  return 0
}

## @function Logger_Init()
# 
# @brief creates output files and pipelines stdout and stderr to 
# 
# @param[in] execution line to process
function Logger_Init() {

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
  function parse_yaml {
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|,$s\]$s\$|]|" \
          -e ":1;s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1\2: [\3]\n\1  - \4|;t1" \
          -e "s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s\]|\1\2:\n\1  - \3|;p" $1 | \
    sed -ne "s|,$s}$s\$|}|" \
          -e ":1;s|^\($s\)-$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1- {\2}\n\1  \3: \4|;t1" \
          -e    "s|^\($s\)-$s{$s\(.*\)$s}|\1-\n\1  \2|;p" | \
    sed -ne "s|^\($s\):|\1|" \
          -e "s|^\($s\)-$s[\"']\(.*\)[\"']$s\$|\1$fs$fs\2|p" \
          -e "s|^\($s\)-$s\(.*\)$s\$|\1$fs$fs\2|p" \
          -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
          -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" | \
    awk -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]; idx[i]=0}}
        if(length($2)== 0){  vname[indent]= ++idx[indent] };
        if (length($3) > 0) {
          vn=""; for (i=0; i<indent; i++) { vn=(vn)(vname[i])("_")}
          printf("CONF[%s%s]=\"%s\"\n",vn, vname[indent], $3);
        }
    }'
  }
  # printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, vname[indent], $3);

  # declare -A yaml_dict
  yaml_file=$(pwd)"/hog_conf.yml"
  if test -f $yaml_file; then
    Msg Info "Hog configuration file $yaml_file exists."
    eval $(parse_yaml $yaml_file "CONF_")
    size=${#CONF[@]}
    Msg Debug  " --------------- The size of the dictionary is $size"
    for key in "${!CONF[@]}"; do
        Msg Debug "CONF[$key] --- ${CONF[$key]}"
    done
  else
      Msg Warning "Configuration file does not exist."
  fi

  current_user=$(whoami)
  # echo "Current user: $current_user"

  # SETTING DEBUG_VERBOSE
  hog_user_td="${current_user}_terminal_debug"
  HOG_LOG_EN=0
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
  if [[ " ${vldColorSchemes[@]} " =~ " $clrschselected " ]]; then
    Msg Info "Color Scheme set to $clrschselected"
  else
    Msg Warning "Invalid color scheme $clrschselected ; Color scheme set to dark"
    clrschselected="dark"
  fi
  # Msg Debug "color terminal = $clrschselected"
# exit
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






























































