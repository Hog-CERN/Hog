#!/usr/bin/env bash
#   Copyright 2018-2025 The University of Birmingham
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
#   any question contact: guillermo.ldl@cern.ch
##############################################################
##############################################################

## @var VERBOSE_LEVEL
#  @brief Global variable

hog_user_cfg_exists=0
hog_prj_cfg_exists=0

VERBOSE_LEVEL=4
EN_SHOW_PID=0
ENABLE_LINE_NUMBER=0
ENABLE_MSG_TYPE_CNT=0
HOG_LOG_EN=0
HOG_COLOR_EN=0
LOGGER_LEVEL=4

BUFFERING=true
BUFFER_FILE=$(mktemp)

clrschselected="dark"

ENABLE_FWE=0
hog_sh_pid=""
hog_pid=""
error_pid=""
tcl_pid=""
launch_tcl_pid=""
fail_when_error=0
fwe_failing=0
fwe_delay=0
error_fail=0
failing_en=0
fwe_fail_trig=0

HOG_DEBUG_MODE=0
LOG_INFO_FILE=""
LOG_WAR_ERR_FILE=""
TEMP_LOG_INFO_FILE=""
TEMP_LOG_WAR_ERR_FILE=""

declare -A Hog_Prj_dict
declare -A Hog_Usr_dict

tempfolder=""

# if [ -n "$tempfolder" ]; then
  tmptimestamp=$(date +%s)
  tempfolder="/dev/shm/$USER/hog$tmptimestamp"
  if mkdir -p $tempfolder 2>/dev/null ; then
    temp_g_cnt_file="$tempfolder/hog_g_cnt"
    temp_i_cnt_file="$tempfolder/hog_i_cnt"
    temp_d_cnt_file="$tempfolder/hog_d_cnt"
    temp_w_cnt_file="$tempfolder/hog_w_cnt"
    temp_c_cnt_file="$tempfolder/hog_c_cnt"
    temp_e_cnt_file="$tempfolder/hog_e_cnt"
    # TEMP_LOG_INFO_FILE="$tempfolder/hog_log_info"
    # TEMP_LOG_WAR_ERR_FILE="$tempfolder/hog_log_war_err"
    # touch $TEMP_LOG_INFO_FILE
    # touch $TEMP_LOG_WAR_ERR_FILE
  else
    echo " Warning : Could not create /dev/shm/$USER/hog$tmptimestamp will try /tmp/$USER/hog$tmptimestamp "
    tempfolder="/tmp/$USER/hog$tmptimestamp"
    if mkdir -p $tempfolder; then
      temp_g_cnt_file="$tempfolder/hog_g_cnt"
      temp_i_cnt_file="$tempfolder/hog_i_cnt"
      temp_d_cnt_file="$tempfolder/hog_d_cnt"
      temp_w_cnt_file="$tempfolder/hog_w_cnt"
      temp_c_cnt_file="$tempfolder/hog_c_cnt"
      temp_e_cnt_file="$tempfolder/hog_e_cnt"
      # TEMP_LOG_INFO_FILE="$tempfolder/hog_log_info"
      # TEMP_LOG_WAR_ERR_FILE="$tempfolder/hog_log_war_err"
      # touch $TEMP_LOG_INFO_FILE
      # touch $TEMP_LOG_WAR_ERR_FILE
    else
      echo " *** ERROR Could not create /tmp/$USER/hog$tmptimestamp"
      exit 0
    fi
  fi
# fi

function update_cnt () {
  if [[ -e "$temp_g_cnt_file" ]]; then
    while read line ; do glob_cnt=$(($line+1)); done < "$temp_g_cnt_file"
    echo "$glob_cnt" > "$temp_g_cnt_file"
  fi
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
  # echo "msg_counter $1 $2"
  case "$1" in
    init)
      echo "0" > "$temp_g_cnt_file"
      echo "0" > "$temp_i_cnt_file"
      echo "0" > "$temp_d_cnt_file"
      echo "0" > "$temp_w_cnt_file"
      echo "0" > "$temp_c_cnt_file"
      echo "0" > "$temp_e_cnt_file"
    ;;
    read|r)
    case "$2" in
      g) read_tmp_cnt $temp_g_cnt_file ;;
      i) read_tmp_cnt $temp_i_cnt_file ;;
      d) read_tmp_cnt $temp_d_cnt_file ;;
      w) read_tmp_cnt $temp_w_cnt_file ;;
      c) read_tmp_cnt $temp_c_cnt_file ;;
      e) read_tmp_cnt $temp_e_cnt_file ;;
      *) Msg Error "counter <$2> doesn't exist" ;;
    esac
    ;;
    update|w)
    # update_cnt $temp_g_cnt_file
    case "$2" in
      i) update_cnt $temp_i_cnt_file ;;
      d) update_cnt $temp_d_cnt_file ;;
      w) update_cnt $temp_w_cnt_file ;;
      c) update_cnt $temp_c_cnt_file ;;
      e) update_cnt $temp_e_cnt_file ;;
      *) Msg Error "counter <$2> doesn't exist" ;;
    esac
    ;;
    *) Msg Error "counter action <$1> doesn't exist" ;;
  esac
}

echo_info=1
echo_warnings=1
echo_errors=1


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
txtrst='\e[0m' # rst
txtbln='\e[5m' # Blink

vldColorSchemes=("dark" "clear")

declare -A darkColorScheme
darkColorScheme[error]="$txtred   ERROR :$txtrst"
darkColorScheme[critical]="${txtylw}CRITICAL :$txtrst"
darkColorScheme[warning]="$txtylw WARNING :$txtrst"
darkColorScheme[debug]="$txtgrn   DEBUG :$txtrst"
darkColorScheme[info]="$txtblu    INFO :$txtrst"
darkColorScheme[vcom]="$txtblu    VCOM :$txtrst"
declare -A clearColorScheme
clearColorScheme[error]="$txtred   ERROR :$txtrst"
clearColorScheme[critical]="${txtylw}CRITICAL :$txtrst"
clearColorScheme[warning]="$txtylw WARNING :$txtrst"
clearColorScheme[debug]="$txtgrn   DEBUG :$txtrst"
clearColorScheme[info]="$txtblu    INFO :$txtrst"
clearColorScheme[vcom]="$txtblu    VCOM :$txtrst"

clrschselected="dark"

declare -A msgHeadBW
msgHeadBW[error]="   ERROR :"
msgHeadBW[critical]="CRITICAL :"
msgHeadBW[warning]=" WARNING :"
msgHeadBW[debug]="   DEBUG :"
msgHeadBW[info]="    INFO :"
msgHeadBW[vcom]="    VCOM :"

declare -A simpleColor
simpleColor[error]="$txtred"
simpleColor[critical]="$txtorg"
simpleColor[warning]="$txtcyn"
simpleColor[debug]="$txtgrn"
simpleColor[info]="$txtrst"
simpleColor[vcom]="$txtrst"

declare -A msgCounter
msgCounter[error]="e"
msgCounter[critical]="c"
msgCounter[warning]="w"
msgCounter[debug]="d"
msgCounter[info]="i"
msgCounter[vcom]="i"

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
  # echo "========================"
  # echo "log_stdout : ${1} : ${2}"
  if [[ "${1}" == LogBuff:* ]]; then
    # IN_out="${IN_out#LogBuff:}"
    buffered=true
  else
    buffered=false
  fi

  if [ -n "${2}" ]; then
    IN_out="${2//\\/\\\\}"
    # echo "----"
  else
    while read -r IN_out # This reads a string from stdin and stores it in a variable called IN_out
    do
      # echo $IN_out
      #if In_out starts with "LogHelp:" remove it
      if [[ "$IN_out" == LogHelp:* ]]; then
        IN_out="${IN_out#LogHelp:}"
      fi
      # if IN_out starts with "LogBuff:" remove it
      
      if [[ $next_is_err == 0 ]]; then
        line="${IN_out//\\/\\\\}"
      else
        line="ERROR:${IN_out//\\/\\\\}"
        next_is_err=$(($next_is_err-1))
      fi
      dataLine=$line
      if $buffered; then
        stderr_ack="b"
      else
        if [ "${1}" == "stdout" ]; then
          stderr_ack=" "
        elif [ "${1}" == "stderr" ]; then
          # dataLine=$line
          stderr_ack="*"
          # echo $line
        else
          stderr_ack="E"
          # Msg Error "Error in logger"
        fi
      fi
      # echo "b:$buffered - $dataline"
        case "$line" in
          *'DEBUG:'* | *'Debug['* | *'debug:'*)
            # msgTypeOverload msgType "debug" "$dataLine"
            msgType="debug"
          ;;
          *'ERROR:'* | *'Error:'* | *':Error'* | *'error:'* | *'Error '* | *'FATAL ERROR'* | *'Fatal'*)
            # if [[ "$line" == *'Fatal'* ]]; then
            #   next_is_err=1
            # fi
            msgType="error"
            if [[ "$line" =~ "error: unable to create directory (errc=1) (Operation not permitted)" ]]; then
              msgType="critical"
            fi
            if [[ "$line" =~ [Ee]os ]]; then
              msgType="critical"
            fi
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
          *'vcom'*)
            # msgTypeOverload msgType "vcom" "$dataLine"
            msgType="vcom"
            ;;
          *)
            # msgType=$(msgTypeOverload "info" "$dataLine")
            msgType="info"
            ;;
        esac
      # elif [ "${1}" == "stderr" ]; then
      #   stderr_line=$dataLine
      #   msgType="error"
      #   echo $line
      # else
      #   Msg Error "Error in logger"
      # fi
      #######################################
      # Overwriting
      #######################################
      case "$msgType" in
        "error")
          for key in "${!errorOverload[@]}"; do
            if [[ "$line" == *"$key"* ]]; then
              Msg Debug "Message level Override: Key < '$key' > exists in the string < $line > with value '${errorOverload[$key]}'"
              msgType="${errorOverload[$key]}"
            fi
          done
        ;;
        "critical")
          for key in "${!criticalOverload[@]}"; do
            if [[ "$line" == *"$key"* ]]; then
              Msg Debug "Message level Override: Key < '$key' > exists in the string < $line > with value '${criticalOverload[$key]}'"
              msgType="${criticalOverload[$key]}"
            fi
          done
        ;;
        "warning")
          for key in "${!warningOverload[@]}"; do
            if [[ "$line+" == *"$key"* ]]; then
              Msg Debug "Message level Override: Key < '$key' > exists in the string < $line > with value '${warningOverload[$key]}'"
              msgType="${warningOverload[$key]}"
            fi
          done
        ;;
        "info")
          for key in "${!infoOverload[@]}"; do
            if [[ "$line" == *"$key"* ]]; then
              Msg Debug "Message level Override: Key < '$key' > exists in the string < $line > with value '${infoOverload[$key]}'"
              msgType="${infoOverload[$key]}"
            fi
          done
        ;;
        "vcom")
          for key in "${!infoOverload[@]}"; do
            if [[ "$line" == *"$key"* ]]; then
              Msg Debug "Message level Override: Key < '$key' > exists in the string < $line > with value '${infoOverload[$key]}'"
              msgType="${infoOverload[$key]}"
            fi
          done
        ;;
        "debug")
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
      if [[ $VERBOSE_LEVEL -gt ${msgDbgLvl[$msgType]} ]]; then
        if [[ $EN_SHOW_PID -gt 0 ]]; then
          printf "PID:%06d : " $BASHPID
        fi
        if [[ $ENABLE_LINE_NUMBER -gt 0 ]]; then
          printf "%05d : " $(msg_counter r g)
        fi
        if [[ $ENABLE_MSG_TYPE_CNT -gt 0 ]]; then
          printf "%d : " $(msg_counter w ${msgCounter[$msgType]})
        else
          msg_counter w ${msgCounter[$msgType]} >> /dev/null
        fi
        if [[ $HOG_COLOR_EN -gt 1 ]]; then
          case "${clrschselected}" in
            "dark")
              echo -e "${stderr_ack}${darkColorScheme[$msgType]} ${dataLine#${msgRemove[$msgType]}} "
            ;;
            "clear")
              echo -e "${stderr_ack}${clearColorScheme[$msgType]} ${dataLine#${msgRemove[$msgType]}} "
            ;;
          esac
        elif [[ $HOG_COLOR_EN -gt 0 ]]; then
          echo -e "${stderr_ack}${simpleColor[$msgType]} $dataLine $txtwht"
        else
          echo -e "${stderr_ack}$dataLine"
        fi
      else
        msg_counter w ${msgCounter[$msgType]} >> /dev/null
      fi
      if [[ $HOG_LOG_EN -gt 0 ]]; then
        if [[ -n $LOG_WAR_ERR_FILE ]] && [[ 3 -gt ${msgDbgLvl[$msgType]} ]]; then
          echo "${stderr_ack}${msgHeadBW[$msgType]} ${dataLine#${msgRemove[$msgType]}} "  >> $LOG_WAR_ERR_FILE
        fi
        if [[ -n $LOG_INFO_FILE ]]; then
          echo "${stderr_ack}${msgHeadBW[$msgType]} ${dataLine#${msgRemove[$msgType]}} "  >> $LOG_INFO_FILE;
        fi
      else
        # store in a temporary file
        if [[ -n $LOG_WAR_ERR_FILE ]] && [[ 3 -gt ${msgDbgLvl[$msgType]} ]]; then
          echo "${stderr_ack}${msgHeadBW[$msgType]} ${dataLine#${msgRemove[$msgType]}} "  >> $TEMP_LOG_WAR_ERR_FILE
        fi
        if [[ -n $LOG_INFO_FILE ]]; then
          echo "${stderr_ack}${msgHeadBW[$msgType]} ${dataLine#${msgRemove[$msgType]}} "  >> $TEMP_LOG_INFO_FILE;
        fi
      fi
      if [[ $ENABLE_FWE -eq 1 ]];then
        if [[ $fwe_fail_trig -eq 0 ]]; then
          if [[ "$msgType" == "error" ]]; then
            fwe_failing=$fwe_delay
            fwe_fail_trig=1
            error_fail=1
            error_pid=$BASHPID
            Msg Warning "Process $error_pid will be killed in $fwe_failing"
          fi
        else
          if [[ $failing_en -eq 0 ]];then
            if [[ $fwe_failing -gt 0 ]];then
              fwe_failing=$(($fwe_failing - 1))
            else
              wait "$launch_tcl_pid" 2>/dev/null
              echo "Process $hog_pid has been terminated."
              failing_en=-1
              Hog_exit_fwe
            fi
          fi
        fi
      fi
    done
  fi
}

## @function Hog_exit()
  #
  # @brief Prints a resum of the messages types
function Hog_exit () {
  if [[  "$HOG_COLOR_EN" -gt 0 ]]; then
    echo -e "$txtrst"
  fi
  echo "  ================ RESUME ================ "
  echo "   # of Total messages: $(msg_counter r g)"
  echo "   # of Info messages: $(msg_counter r i)"
  echo "   # of debug messages : $(msg_counter r d)"
  echo "   # of warning messages : $(msg_counter r w)"
  echo "   # of critical warning messages : $(msg_counter r c)"
  echo "   # of Errors messages : $(msg_counter r e)"
  echo "  ======================================== "
  if [[ $(msg_counter r e) -gt 0 ]]; then
    echo -e "$txtred *** Hog finished with errors *** $txtrst"
    exit 1
  elif [[ $(msg_counter r c) -gt 0 ]]; then
    echo -e "$txtylw *** Hog finished with Critical Warnings *** $txtrst"
    exit 0
  else
    echo -e "$txtgrn *** Hog finished without errors *** $txtrst"
    exit 0
  fi

}

## @function Hog_exit()
  #
  # @brief Prints a resum of the messages types
function Hog_exit_fwe () {
  echo "  ================ RESUME ================ "
  echo "   # of Total messages: $(msg_counter r g)"
  echo "   # of Info messages: $(msg_counter r i)"
  echo "   # of debug messages : $(msg_counter r d)"
  echo "   # of warning messages : $(msg_counter r w)"
  echo "   # of critical warning messages : $(msg_counter r c)"
  echo "   # of Errors messages : $(msg_counter r e)"
  echo "  ======================================== "
  if [[ $(msg_counter r e) -gt 0 ]]; then
    echo -e "$txtred *** Hog finished with errors *** $txtwht"
    kill -SIGINT "-$hog_pid"
    exit 1
  else
    echo -e "$txtgrn *** Hog finished  without errors *** $txtwht"
    kill -SIGINT "-$hog_pid"
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
  Msg Debug "Running: $*"
  if [[ "$HOG_LOG_EN" -gt 0 ]] || [[  "$HOG_COLOR_EN" -gt 0 ]]; then
    Log_capture "$@"
    Hog_exit
  else
    "$@"
    exit $?
  fi
  # if [[ "$HOG_COLOR_EN" -gt 0 ]]; then
  #   Hog_exit
  # else
  #   Msg Info "Logger args : $*"
  #   exit $?
  # fi
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
  if  $BUFFERING; then
    {
      if [[ $VERBOSE_LEVEL -gt ${msgDbgLvl[$msgType]} ]]; then
        if [[ $EN_SHOW_PID -gt 0 ]]; then
          printf "PID:%06d : " $BASHPID
        fi
        if [[ $ENABLE_LINE_NUMBER -gt 0 ]]; then
          printf "%05d : " $(msg_counter r g)
        fi
        if [[ $ENABLE_MSG_TYPE_CNT -gt 0 ]]; then
          printf "%d : " $(msg_counter w ${msgCounter[$msgType]})
        else
          msg_counter w ${msgCounter[$msgType]} >> /dev/null
        fi

        # if [[ $HOG_COLOR_EN -gt 1 ]]; then
        #   case "${clrschselected}" in
        #     "dark")
        #       echo -e " ${darkColorScheme[$msgType]} HOG:$1[${FUNCNAME[1]}] $text"
        #     ;;
        #     "clear")
        #       echo -e " ${clearColorScheme[$msgType]} HOG:$1[${FUNCNAME[1]}] $text "
        #     ;;
        #   esac
        # elif [[ $HOG_COLOR_EN -gt 0 ]]; then
        #   echo -e "${simpleColor[$msgType]} HOG:$1[${FUNCNAME[1]}] $text $txtwht"
        # else
          echo "HOG:$1[${FUNCNAME[1]}] $text"
        # fi
      else
        msg_counter w ${msgCounter[$msgType]} >> /dev/null
      fi
    } >> "$BUFFER_FILE"
  else
    if [[ $VERBOSE_LEVEL -gt ${msgDbgLvl[$msgType]} ]]; then
      if [[ $EN_SHOW_PID -gt 0 ]]; then
        printf "PID:%06d : " $BASHPID
      fi
      if [[ $ENABLE_LINE_NUMBER -gt 0 ]]; then
        printf "%05d : " $(msg_counter r g)
      fi
      if [[ $ENABLE_MSG_TYPE_CNT -gt 0 ]]; then
        printf "%d : " $(msg_counter w ${msgCounter[$msgType]})
      else
        msg_counter w ${msgCounter[$msgType]} >> /dev/null
      fi

      if [[ $HOG_COLOR_EN -gt 1 ]]; then
        case "${clrschselected}" in
          "dark")
            echo -e " ${darkColorScheme[$msgType]} HOG:$1[${FUNCNAME[1]}] $text"
          ;;
          "clear")
            echo -e " ${clearColorScheme[$msgType]} HOG:$1[${FUNCNAME[1]}] $text "
          ;;
        esac
      elif [[ $HOG_COLOR_EN -gt 0 ]]; then
        echo -e "${simpleColor[$msgType]} HOG:$1[${FUNCNAME[1]}] $text $txtwht"
      else
        echo "HOG:$1[${FUNCNAME[1]}] $text"
      fi
    else
      msg_counter w ${msgCounter[$msgType]} >> /dev/null
    fi
  fi

  if [[ $HOG_LOG_EN -gt 0 ]]; then
    if [[ -n $LOG_WAR_ERR_FILE ]] && [[ 3 -gt ${msgDbgLvl[$msgType]} ]]; then
      echo "${msgHeadBW[$msgType]} HOG [${FUNCNAME[1]}] : $text " >> $LOG_WAR_ERR_FILE;
      # echo "${msgHeadBW[$msgType]} ${dataLine#${msgRemove[$msgType]}} "  >> $LOG_WAR_ERR_FILE
    fi
    if [[ -n $LOG_INFO_FILE ]]; then
      echo "${msgHeadBW[$msgType]} HOG [${FUNCNAME[1]}] : $text " >> $LOG_INFO_FILE;
      # echo "${msgHeadBW[$msgType]} ${dataLine#${msgRemove[$msgType]}} "  >> $LOG_INFO_FILE;
    fi
  else
    # store in a temporary file
    if [[ -n $LOG_WAR_ERR_FILE ]] && [[ 3 -gt ${msgDbgLvl[$msgType]} ]]; then
      echo "${msgHeadBW[$msgType]} HOG [${FUNCNAME[1]}] : $text " >> $TEMP_LOG_WAR_ERR_FILE;
    fi
    if [[ -n $LOG_INFO_FILE ]]; then
      echo "${msgHeadBW[$msgType]} HOG [${FUNCNAME[1]}] : $text " >> $TEMP_LOG_INFO_FILE;
    fi
  fi
  if [[ $ENABLE_FWE -eq 1 ]];then
        # Msg Debug "$fwe_fail_trig "
        if [[ $fwe_fail_trig -eq 0 ]]; then
          if [[ "$msgType" == "error" ]]; then
            # if (( $fail_when_error > 0 )); then
              fwe_failing=$fwe_delay
              fwe_fail_trig=1
              error_fail=1
              error_pid=$BASHPID
              Msg Warning "Process $error_pid will be killed in $fwe_failing"
            # fi
          fi
        else
          if [[ $failing_en -eq 0 ]];then
            if [[ $fwe_failing -gt 0 ]];then
              fwe_failing=$(($fwe_failing - 1))
              # Msg Debug "Process $BASHPID will be killed in $fwe_failing"
              # Msg Debug "Process $hog_pid will be killed in $fwe_failing"
            else
              # Msg Error "exitaaaando"
              wait "$launch_tcl_pid" 2>/dev/null
              echo "Process $hog_pid has been terminated."
              failing_en=-1
              Hog_exit_fwe
            fi
          fi
        fi
      fi
  return 0
}



# @function trim
  #
  # @param[in] string
  #
  # @return  string
trim() {
  local var=$1
  # echo $var
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  echo -n "$var"
}

# @function Msg
  #
  # @param[in] file path to configuration in (simple)toml format
  # @param[in] dictionary name where to store the data
  #
  # @return  '1' if missing arguments else '0'
process_HogEnv_config() {
  # echo "Processing HogEnv config from $1 into $2"
  local file_path=$1
  local dict_name=$2
  declare -n toml_dict=$dict_name
  local arraylvl=0
  local index=0
  while IFS= read -r rline; do
    if [[ "$rline" =~ ^[:space:]*#.*$ ]]; then continue; fi
    if [[ "$rline" =~ ^[:space:]*$ ]]; then continue; fi
    chari=0
    cnt1=0
    for ((i=0; i<${#rline}; i++)); do
      char="${rline:i:1}"
      chari=$((i+1))
      if [[ $char == '"' ]]; then ((cnt1++)); fi
      if [[ $((cnt1 % 2)) == 0 ]]; then
        if [[ $char == "#" ]]; then
          chari=$i
          break
        fi
      fi
    done
    line=${rline:0:$chari}
    if [[ $line =~ ^\[.*\] ]]; then
      section_name=$(echo "$line" | sed 's/[[:space:]]*$//' | sed 's/\[\(.*\)\]/\1/' | sed 's/ /_/g' )
      continue
    elif [[ $line =~ ^[a-zA-Z0-9_[:space:]]*= ]]; then
      key=$(echo "${line// /}" | sed 's/=.*//')
      line=$(echo "$line" | sed 's/.*=//')
    fi
    line=$(trim "$line")
    while [[ -n $line ]]; do
      line=$(trim "$line")
      if [[ ${line:0:1} == "[" ]]; then
        line=${line:1}
        ((arraylvl++))
        index=0
        continue
      fi
      if [[ ${line:0:1} == "]" ]]; then
        line=${line:1}
        ((arraylvl--))
        continue
      fi
      open_array=-1
      closing_array=-1
      cnt_dc=0
      coma_cnt=0
      first_coma=-1
      for ((i=0; i<${#line}; i++)); do
        char="${line:i:1}"
        chari=$((i+1))
        if [[ $char == '"' ]]; then ((cnt_dc++)); fi
        if [[ $((cnt_dc % 2)) == 0 ]]; then #discarding things inside strings
          if [[ $char == "[" ]]; then
            Msg Error "error!!!!!!!!!!!!"
            exit
          fi
          if [[ $char == "]" ]]; then
            closing_array=$i
          fi
          if [[ $char == "," ]]; then
            if [[ $coma_cnt == 0 ]]; then first_coma=$i; fi
            ((coma_cnt++))
            last_coma=$i
          fi
        fi
      done
      proc_line=""
      if [[ $coma_cnt -gt 0 ]]; then
        proc_line=${line:0:first_coma}
        line=${line:((first_coma + 1))}
      elif [[ $closing_array -gt -1 ]]; then
        proc_line=${line:0:closing_array}
        line=${line:closing_array}
      else
        proc_line=$line
        line=""
      fi
      if [[ ${#proc_line} -gt 0 ]]; then
        Msg Debug "saving to dict ::: ${section_name[$key]} = <${proc_line}>"
        if [[ $arraylvl == 0 ]]; then
          toml_dict["$section_name.$key"]=$(trim "${proc_line//\"/}")
        else
          toml_dict["$section_name.${key}.$index"]=$(trim "${proc_line//\"/}")
          ((index++))
        fi
      fi
    done
  done < $1
}

## @function print_hog_logo()
  #
  # @brief prints the logo
  #
function print_hog_logo () {
  cd $ROOT_PROJECT_FOLDER/Hog
  HOG_VERSION=$(git describe --always)
  cd $ROOT_PROJECT_FOLDER
  if [[ -v "HOG_COLOR" && "${HOG_COLOR}" =~ ^[0-9]+$ && "${HOG_COLOR}" -gt 0 ]]; then
    if [[ "${HOG_COLOR}" =~ ^[0-9]+$ && "${HOG_COLOR}" -gt 1 ]]; then
      logo_file=$ROOT_PROJECT_FOLDER/Hog/images/hog_logo_full_color.txt
    else
      logo_file=$ROOT_PROJECT_FOLDER/Hog/images/hog_logo_color.txt
    fi
  else
    logo_file=$ROOT_PROJECT_FOLDER/Hog/images/hog_logo.txt
  fi
  if [ -f $logo_file ]; then
    while IFS= read -r line; do
      if [[ "$line" == *"Version:"* ]]; then
        version_str="Version: $HOG_VERSION"
        version_len=${#HOG_VERSION}
        # Replace "Version:" and the following spaces with "Version: $HOG_VERSION"
        line=$(echo "$line" | sed -E "s/(Version:)[ ]{0,$((version_len + 1))}/\1 $HOG_VERSION/")
        # Pad or trim to match original line length
        echo -e "$line"
      else
        echo -e "$line"
      fi
    done < "$logo_file"
    export HOG_LOGO_PRINTED=1
  else
    Msg Warning "Logo file $logo_file doesn't exist"
  fi
}



## @function loadUserConf
function loadUserConf() {
  Msg Info "Loading user configuration"
  current_user=$(whoami)
  hog_user_cfg=$(eval echo "~$USER")"/HogEnv.conf"
  if test -f $hog_user_cfg; then
    Msg Info "Hog project configuration file $hog_user_cfg exists."
    process_HogEnv_config $hog_user_cfg "Hog_Usr_dict"
    hog_user_cfg_exists=1
    for key in "${!Hog_Usr_dict[@]}"; do
      Msg Debug "Hog_Usr_dict[ $key ] = <${Hog_Usr_dict[$key]}>"
    done
  else
    Msg Debug "Hog project configuration file $hog_user_cfg doesn't exists."
  fi

}

function printDict() {
  local -n dict=$1
  for key in "${!dict[@]}"; do
    echo "$key = ${dict[$key]}"
  done
}

function getConfigValue() {
  local -n dict=$1
  local section=$2
  local key=$3
  if [[ -v dict["$section.$key"] ]]; then
    echo "${dict["$section.$key"]}"
  else
    echo 0
  fi
}

## @function Logger_Init()
#
# @brief creates output files and pipelines stdout and stderr to
#
# @param[in] execution line to process
function Logger_Init() {
  hog_sh_pid=$BASHPID
  VERBOSE_LEVEL=4
  if [[ "$*" =~ "-verbose" ]]; then
    VERBOSE_LEVEL=5
    HOG_DEBUG_MODE=1
  fi
  force_verbose=$VERBOSE_LEVEL
  hog_pid=$BASHPID

  ROOT_PROJECT_FOLDER=$(pwd)
  LOG_INFO_FILE=$ROOT_PROJECT_FOLDER"/hog_info.log"
  LOG_WAR_ERR_FILE=$ROOT_PROJECT_FOLDER"/hog_warning_errors.log"
  TEMP_LOG_INFO_FILE="$tempfolder/hog_log_info"
  TEMP_LOG_WAR_ERR_FILE="$tempfolder/hog_log_war_err"
  touch $TEMP_LOG_INFO_FILE
  touch $TEMP_LOG_WAR_ERR_FILE

  msg_counter init

  ############################################
  #    USER CONFIGURATIONS
  ############################################

  # loadUserConf

  if [[ -v HOG_COLOR ]]; then
    if [[ $HOG_COLOR =~ ^[0-9]$ ]]; then
      HOG_COLOR_EN=$HOG_COLOR
    else
      HOG_COLOR_EN=0
    fi
  fi
  if [[ -v HOG_LOGGER && $HOG_LOGGER == ENABLED ]]; then
    HOG_LOG_EN=1
  else
    HOG_LOG_EN=0
  fi

  if [[ $hog_user_cfg_exists -eq 0 ]]; then
    Msg Warning "Hog project configuration file $hog_user_cfg doesn't exists."
  else
    Msg Debug " SETTING COLORS"
    if [[ -v Hog_Usr_dict["terminal.colored"] ]]; then
      Msg Debug "terminal.colored exists"
      if [[ ${Hog_Usr_dict["terminal.colored"]} =~ ^[0-9]$ ]]; then
        Msg Debug "The variable <terminal.colored> is a one-digit number"
        HOG_COLOR_EN=${Hog_Usr_dict["terminal.colored"]}
        HOG_COLOR=$HOG_COLOR_EN
      else
        Msg Warning "The variable <terminal.colored> is not a one-digit number, Defaulting to 0"
      fi
    fi

    Msg Debug "SETTING Message type counter"
    if [[ -v Hog_Usr_dict["verbose.msgtypeCounter"] ]]; then
      if [[ ${Hog_Usr_dict["verbose.msgtypeCounter"]} =~ ^[01]$ ]]; then
        ENABLE_MSG_TYPE_CNT=${Hog_Usr_dict["verbose.msgtypeCounter"]}
        Msg Debug "The variable <verbose.msgtypeCounter> is ${Hog_Usr_dict['verbose.msgtypeCounter']}"
      else
        Msg Warning "The variable verbose.msgtypeCounter is not 1 or 0, Default to 0"
      fi
    fi

    Msg Debug "SETTING Message number"
    if [[ -v Hog_Usr_dict["verbose.lineCounter"] ]]; then
      if [[ ${Hog_Usr_dict["verbose.lineCounter"]} =~ ^[01]$ ]]; then
        ENABLE_LINE_NUMBER=${Hog_Usr_dict["verbose.lineCounter"]}
        Msg Debug "The variable <verbose.lineCounter> is ${Hog_Usr_dict['verbose.lineCounter']}"
      else
        Msg Warning "The variable verbose.lineCounter is not 1 or 0, Default to 0"
      fi
    fi

    Msg Debug "SETTING pidshow"
    if [[ -v Hog_Usr_dict["verbose.pidshow"] ]]; then
      if [[ ${Hog_Usr_dict["verbose.pidshow"]} =~ ^[01]$ ]]; then
        EN_SHOW_PID=${Hog_Usr_dict["verbose.pidshow"]}
        Msg Debug "The variable <verbose.pidshow> is ${Hog_Usr_dict['verbose.pidshow']}"
      else
        Msg Warning "The variable verbose.pidshow is not 1 or 0, Default to 0"
      fi
    fi

    # Msg Info "Loading Hog configuration..."
    # if test -f $hog_user_cfg; then
    #   Msg Info "Hog project configuration file $hog_user_cfg exists."
    #   process_HogEnv_config $hog_user_cfg "Hog_Usr_dict"
    #   for key in "${!Hog_Usr_dict[@]}"; do
    #     Msg Info "Hog_Usr_dict[ $key ] = <${Hog_Usr_dict[$key]}>"
    #   done
    # else
    #   Msg Debug "Hog project configuration file $hog_user_cfg doesn't exists."
    # fi

    # if test -f $hog_user_cfg; then
    #   Msg Info "Hog project configuration file $hog_user_cfg exists."
    #   for key in "${!Hog_Usr_dict[@]}"; do
    #     Msg Info "Hog_Usr_dict[ $key ] = <${Hog_Usr_dict[$key]}>"
    #   done
    # else
    #   Msg Debug "Hog project configuration file $hog_user_cfg doesn't exists."
    # fi

    # SETTING LOGGER_LEVEL
    if [[ -v Hog_Usr_dict["verbose.log_level"] ]]; then
      if [[ ${Hog_Usr_dict["verbose.log_level"]} =~ ^[0-9]$ ]]; then
        Msg Debug "The variable <verbose.log_level> is ${Hog_Usr_dict['verbose.log_level']}"
        LOGGER_LEVEL=${Hog_Usr_dict["verbose.log_level"]}
      else
        Msg Warning "The variable verbose.log_level is not a one-digit number, Defaulting to 0"
      fi
    fi
    if [[ "$*" =~ "-verbose" ]]; then
      if (( $LOGGER_LEVEL < $force_verbose )); then
        LOGGER_LEVEL=$force_verbose
      fi
    fi
    # SETTING VERBOSE_LEVEL
    if [[ -v Hog_Usr_dict["verbose.level"] ]]; then
      if [[ ${Hog_Usr_dict["verbose.level"]} =~ ^[0-9]$ ]]; then
        Msg Debug "The variable <verbose.level> is ${Hog_Usr_dict['verbose.level']}"
        VERBOSE_LEVEL=${Hog_Usr_dict["verbose.level"]}
      else
        Msg Warning "The variable verbose.level is not a one-digit number, Defaulting to 0"
      fi
    fi
    if [[ "$*" =~ "-verbose" ]]; then
      if (( $VERBOSE_LEVEL < $force_verbose )); then
        VERBOSE_LEVEL=$force_verbose
      fi
    fi
    # SETTING LOGGER
    if [[ -v Hog_Usr_dict["terminal.logger"] ]]; then
      if [[ ${Hog_Usr_dict["terminal.logger"]} =~ ^[01]$ ]]; then
        Msg Debug "The variable <terminal.logger> is ${Hog_Usr_dict['terminal.logger']}"
        HOG_LOG_EN=${Hog_Usr_dict["terminal.logger"]}
      else
        Msg Warning "The variable terminal.logger is not 1 or 0, Default to 0"
      fi
    fi
    if [[ -v Hog_Usr_dict["terminal.colorscheme"] ]]; then
      clrschselected=${Hog_Usr_dict["terminal.colorscheme"]}
    else
      clrschselected="dark"
    fi
    if [[ " ${vldColorSchemes[*]} " =~ " $clrschselected " ]]; then
      Msg Info "Color Scheme set to $clrschselected"
    else
      Msg Warning "Invalid color scheme $clrschselected ; Color scheme set to dark"
      clrschselected="dark"
    fi
  fi

  ############ FROM HERE WILL USE LOGGER COLORS IF ENABLED
  print_hog_logo

  BUFFERING=false
  # log_stdout "$BUFFER_FILE"
  while IFS= read -r line; do
    log_stdout "LogBuff:$line"
  done < "$BUFFER_FILE"
  # echo "$BUFFER_FILE"
  rm -f "$BUFFER_FILE"

  Msg Debug "HOG_LOG_EN -- $HOG_LOG_EN"
  Msg Debug "HOG_COLOR_EN -- $HOG_COLOR_EN"
  Msg Debug "ENABLE_LINE_NUMBER -- $ENABLE_LINE_NUMBER"
  Msg Debug "ENABLE_MSG_TYPE_CNT -- $ENABLE_MSG_TYPE_CNT"
  Msg Debug "EN_SHOW_PID -- $EN_SHOW_PID"
  Msg Debug "LOGGER_LEVEL -- $LOGGER_LEVEL"
  Msg Debug "VERBOSE_LEVEL -- $VERBOSE_LEVEL"
  Msg Debug "color terminal = $clrschselected"



  ############################################
  #    PROJECT CONFIGURATIONS
  ############################################

  hog_proj_cfg=$(pwd)"/HogEnv.conf"
  if test -f $hog_proj_cfg; then
    Msg Info "Hog project configuration file $hog_proj_cfg exists."
    process_HogEnv_config $hog_proj_cfg "Hog_Prj_dict"
    for key in "${!Hog_Prj_dict[@]}"; do
      Msg Debug "Hog_Prj_dict[ $key ] = <${Hog_Prj_dict[$key]}>"
    done
  else
    Msg Debug "Hog project configuration file $hog_proj_cfg doesn't exists."
  fi
  # debug

  # error fail
  # hog_prj_fwe="${current_user}_fail_when_error_enabled"
  # hog_user_dfwe="${current_user}_fail_when_error_delay"
  if [[ -v Hog_Prj_dict["fail_when_error.enabled"] ]]; then
    if [[ ${Hog_Prj_dict["fail_when_error.enabled"]} =~ ^[01]$ ]]; then
      ENABLE_FWE=$((${Hog_Prj_dict["fail_when_error.enabled"]}))
      if [[ $ENABLE_FWE -eq 1 ]]; then
        Msg Warning "Fail when error enabled"
        if [[ -v Hog_Prj_dict["fail_when_error.delay"] ]]; then
          if [[ ${Hog_Prj_dict["fail_when_error.delay"]} =~ ^[0-9]+$ ]]; then
            fwe_delay=$((${Hog_Prj_dict["fail_when_error.delay"]}))
            Msg Warning "The fail delay is set to $fwe_delay"
          else
            fwe_delay=10
            Msg Warning "The variable fail_when_error.delay is not only nunmbers delay set to 10"
          fi
        fi
      fi
    else
      Msg Warning "The variable terminal.logger is not 1 or 0, Default to 0"
      fwe_delay=0
    fi
  else
    fwe_delay=0
  fi
  Msg Debug "fail_when_error delay = $fwe_delay"
  # hog_user_fwe="${current_user}_fail_when_error_enabled"
  # hog_user_dfwe="${current_user}_fail_when_error_delay"
  # if [[ -v Hog_Prj_dict["$hog_user_fwe"] ]]; then
  #   if [[ -v Hog_Prj_dict["$hog_user_dfwe"] ]]; then
  #     fail_when_error=$((1 + ${Hog_Prj_dict["$hog_user_dfwe"]}))
  #   else
  #     fail_when_error=1
  #   fi
  # else
  #   fail_when_error=0
  # fi
  # Msg Debug "fail_when_error = $fail_when_error"
# exit
  hog_user_eo="${current_user}_overloads"
  use_user_ol=0
  use_glob_ol=1
  for key in "${!Hog_Prj_dict[@]}"; do
    if [[ $key == *"overloads"* ]]; then
      if [[ $key == *"include_global"* ]]; then
        use_glob_ol=${Hog_Prj_dict["overloads"]}
      fi
      if [[ $key =~ \.[a-z]2[a-z]\. ]]; then
          case "${key}" in
            *"2e"*) destination="error" ;;
            *"2c"*) destination="critical" ;;
            *"2w"*) destination="warning" ;;
            *"2i"*) destination="info" ;;
            *"2d"*) destination="debug" ;;
          esac
          case "${key}" in
            *"e2"*) errorOverload["${Hog_Prj_dict[$key]}"]=$destination ;;
            *"c2"*) criticalOverload["${Hog_Prj_dict[$key]}"]=$destination ;;
            *"w2"*) warningOverload["${Hog_Prj_dict[$key]}"]=$destination ;;
            *"i2"*) infoOverload["${Hog_Prj_dict[$key]}"]=$destination ;;
            *"d2"*) debugOverload["${Hog_Prj_dict[$key]}"]=$destination ;;
          esac
        fi
    fi
  done

  if [[ -v errorOverload[@] || -v criticalOverload[@] || -v warningOverload[@] || -v infoOverload[@] || -v debugOverload[@] ]]; then
    Msg Info " ========================================= "
    Msg Info "        Message Overloads"
    Msg Info " ========================================= "
    if [[ -v errorOverload[@] ]]; then
      Msg Info "errorOverload"
      for key in "${!errorOverload[@]}"; do
        Msg Info " 2 ${errorOverload[$key]} ::: [$key] "
      done
    fi
    if [[ -v criticalOverload[@] ]]; then
      Msg Info "criticalOverload"
      for key in "${!criticalOverload[@]}"; do
        Msg Info " 2 ${criticalOverload[$key]} ::: [$key]"
      done
    fi
    if [[ -v warningOverload[@] ]]; then
      Msg Info "warningOverload"
      for key in "${!warningOverload[@]}"; do
        Msg Info " 2 ${warningOverload[$key]} ::: [$key]"
      done
    fi
    if [[ -v infoOverload[@] ]]; then
      Msg Info "infoOverload"
      for key in "${!infoOverload[@]}"; do
        Msg Info " 2 ${infoOverload[$key]} ::: [$key]"
      done
    fi
    if [[ -v debugOverload[@] ]]; then
      Msg Info "debugOverload"
      for key in "${!debugOverload[@]}"; do
        Msg Info " 2 ${debugOverload[$key]} ::: [$key]"
      done
    fi
  else
    Msg Debug " There are not Overload instructions"
  fi
  # exit
  custom_timestamp=$(date +"%Y-%m-%d_%H:%M:%S")

  if [ "$HOG_LOG_EN" -eq 1 ]; then
    {
      echo "-----------------------------------------------"
      echo "  HOG INFO LOG "
      echo "  CMD : ${1} "
      echo "  Timestamp: $custom_timestamp"
      echo "-----------------------------------------------"
    } > $LOG_INFO_FILE
    while IFS= read -r -t 0.5 line; do
      # if [[ -n $line ]]; then
        echo "$line" >> $LOG_INFO_FILE
      # fi
    done < $TEMP_LOG_INFO_FILE
    rm -f $TEMP_LOG_INFO_FILE
    {
      echo "-----------------------------------------------"
      echo "  HOG WARNINGS AND ERRORS"
      echo "  CMD : ${1} "
      echo "  Timestamp: $custom_timestamp"
      echo "-----------------------------------------------"
    } > $LOG_WAR_ERR_FILE
    # timeout 0.5s cat $TEMP_LOG_WAR_ERR_FILE >> $LOG_WAR_ERR_FILE
    while IFS= read -r -t 0.5 line; do
      # if [[ -n $line ]]; then
        echo "$line" >> $LOG_WAR_ERR_FILE
      # fi
    done < $TEMP_LOG_WAR_ERR_FILE
    rm -f $TEMP_LOG_WAR_ERR_FILE

    Msg Debug "LogColorVivado : $*"
    log_stdout "stdout" "LogColorVivado : $*"
    log_stdout "stderr" "LogColorVivado : $*"
  fi

  Msg Info "Hog configuration setup done!!!"
}



