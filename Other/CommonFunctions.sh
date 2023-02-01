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

## @file CreateProject.sh
#  @brief Create the specified Vivado or Quartus project

## @var FILE_TYPE
#  @brief Global variable used to distinguish tcl project from hog.conf
#
export FILE_TYPE=""

## @var COMMAND
#  @brief Global variable used to contain the command to be used
#
export COMMAND=""

## @var COMMAND_OPT
#  @brief Global variable used to contain the options associated to the command to be used
#
export COMMAND_OPT=""

## @var POST_COMMAND_OPT
#  @brief Global variable used to contain the post command options to be used (e.g. -tclargs)
#
export POST_COMMAND_OPT=""

## @var HDL_COMPILER
#  @brief Global variable containing the full path to the HDL compiler to be used
#
export HDL_COMPILER=""

## @var HOG_PROJECT_FOLDER
#  @brief Global variable containing the full path of the root project folder
#
export HOG_PROJECT_FOLDER=""

## @var HOG_GIT_VERSION
#  @brief Global variable containing the full path of the root project folder
#
export HOG_GIT_VERSION=""

## @var LOGGER
#  @brief Global variable used to contain the logger
if [[ -z $HOG_LOGGER ]]; then 
  export HOG_LOGGER=""; 
fi

## @var LOGGER
#  @brief Global variable used to contain the logger
if [[ -z $HOG_COLORED ]]; then 
  export HOG_COLORED=""; 
fi

## @var DEBUG_VERBOSE
#  @brief Global variable 
#
export DEBUG_VERBOSE=""

#Define temp files in shared memory
temp_i_cnt_file="/dev/shm/hog_i_cnt"
temp_d_cnt_file="/dev/shm/hog_d_cnt"
temp_w_cnt_file="/dev/shm/hog_w_cnt"
temp_c_cnt_file="/dev/shm/hog_c_cnt"
temp_e_cnt_file="/dev/shm/hog_e_cnt"

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
txtblk='\e[0;30m' # Black - Regular
txtred='\e[0;31m' # Red
txtgrn='\e[0;32m' # Green
txtylw='\e[0;93m' # Yellow
txtorg='\e[0;33m' # Yellow
txtblu='\e[0;34m' # Blue
txtpur='\e[0;35m' # Purple
txtcyn='\e[0;36m' # Cyan
txtwht='\e[0;37m' # White

## @function log_stdout()
# 
# @brief parsers the output of the executed program ( Vivado, Questa,...) 
# 
# @param[in] execution line to process
shopt -s extglob
function log_stdout(){
  if [ -n "${2}" ]; then
    IN_out="${2}"
  else
    while read -r IN_out # This reads a string from stdin and stores it in a variable called IN_out
    do
      line=${IN_out}
      if [ "${1}" == "stdout" ]; then
        case "$line" in
          *'ERROR:'* | *'Error:'* | *':Error'* | *'error:'* | *'Error '* | *'FATAL ERROR'*)
            error_line=$line
            if [[ $DEBUG_VERBOSE -gt 5 ]]; then
              printf "%d : %d :" $BASHPID "$(msg_counter ew)"  
            else
              msg_counter ew >> /dev/null
            fi;
            if [[ $DEBUG_VERBOSE -gt 0 ]]; then
              if [[ -n "$HOG_COLORED" ]]; then
                echo -e "$txtred ERROR $txtwht: ${error_line#*@(ERROR:|Error:)} "; 
              else
                echo -e "$error_line"
              fi
            fi
            if [[ -n $HOG_LOGGER ]]; then
              if [[ -n $LOG_WAR_ERR_FILE ]]; then 
                echo " ERROR : ${error_line#*@(ERROR:|Error:)} " >> $LOG_WAR_ERR_FILE
              fi
              if [[ -n $LOG_INFO_FILE ]]; then 
                echo " ERROR : ${error_line#*@(ERROR:|Error:)} " >> $LOG_INFO_FILE; 
              fi
            fi
          ;;
          *'CRITICAL:'* | *'CRITICAL WARNING:'* )
            critical_line=$line
            if [[ $DEBUG_VERBOSE -gt 5 ]]; then
              printf "%d : %d :" $BASHPID "$(msg_counter cw)"
            else
              msg_counter cw >> /dev/null 
            fi;
            if [[ $DEBUG_VERBOSE -gt 1 ]]; then
              if [[ -n "$HOG_COLORED" ]]; then
                echo -e "${txtylw}CRITICAL $txtwht: $critical_line" 
              else
                echo -e "$critical_line"
              fi
            fi
            if [[ -n $HOG_LOGGER ]]; then
              if [[ -n $LOG_WAR_ERR_FILE ]]; then 
                echo "CRITICAL : ${critical_line#*@(WARNING: |Warning: |warning: )}" >> $LOG_WAR_ERR_FILE
              fi
              if [[ -n $LOG_INFO_FILE ]]; then 
                echo "CRITICAL : ${critical_line#*@(WARNING: |Warning: |warning: )}" >> $LOG_INFO_FILE; 
              fi
            fi
          ;;
          *'WARNING:'* | *'Warning:'* | *'warning:'*)
            warning_line=$line
            if [[ $DEBUG_VERBOSE -gt 5 ]]; then
              printf "%d : %d :" $BASHPID "$(msg_counter ww)"
            else
              msg_counter ww >> /dev/null
            fi;
            if [[ $DEBUG_VERBOSE -gt 2 ]]; then
              if [[ -n "$HOG_COLORED" ]]; then
                echo -e "$txtylw WARNING $txtwht: ${warning_line#*@(WARNING: |Warning: |warning: )} "; 
              else
                echo -e "$warning_line"
              fi
            fi
            if [[ -n $HOG_LOGGER ]]; then
              if [[ -n $LOG_WAR_ERR_FILE ]]; then 
                echo " WARNING : ${warning_line#*@(WARNING: |Warning: |warning: )}" >> $LOG_WAR_ERR_FILE
              fi
              if [[ -n $LOG_INFO_FILE ]]; then 
                echo " WARNING : ${warning_line#*@(WARNING: |Warning: |warning: )}" >> $LOG_INFO_FILE; 
              fi
            fi
          ;;
          *'INFO:'*)
            info_line=$line
            if [[ $DEBUG_VERBOSE -gt 5 ]]; then
              printf "%d : %d :" $BASHPID "$(msg_counter iw)"
            else
              msg_counter iw >> /dev/null
            fi;
            if [[ $DEBUG_VERBOSE -gt 3 ]]; then
              if [[ -n "$HOG_COLORED" ]]; then
                echo -e "$txtblu    INFO $txtwht: ${info_line#INFO: }"; 
              else
                echo -e "${info_line}"
              fi
            fi
            if [[ -n $HOG_LOGGER ]]; then
              if [[ -n $LOG_INFO_FILE ]]; then 
                echo "    INFO : ${info_line#INFO: }" >> $LOG_INFO_FILE; 
              fi
            fi
          ;;
          *'DEBUG:'*)
            debug_line=$line
            if [[ $DEBUG_VERBOSE -gt 5 ]]; then
              printf "%d : %d :" $BASHPID "$(msg_counter dw)" 
            else
              msg_counter dw >> /dev/null
            fi;
            if [[ $DEBUG_VERBOSE -gt 4 ]]; then
              if [[ -n "$HOG_COLORED" ]]; then
                echo -e "$txtgrn   DEBUG $txtwht: ${debug_line#DEBUG: }" 
              else
                echo -e "$debug_line"
              fi
            fi
            if [[ -n $HOG_LOGGER ]]; then
              if [[ -n $LOG_INFO_FILE ]]; then 
                echo "   DEBUG : ${debug_line#DEBUG: }" >> $LOG_INFO_FILE; 
              fi
            fi
            ;;
          *'vcom'*)
            vcom_line=$line
            if [[ $DEBUG_VERBOSE -gt 5 ]]; then
              printf "%d : %d :" $BASHPID "$(msg_counter iw)"
            else
              msg_counter iw >> /dev/null
            fi;
            if [[ $DEBUG_VERBOSE -gt 3 ]]; then
              if [[ -n "$HOG_COLORED" ]]; then
                echo -e "$txtblu    VCOM $txtwht: ${vcom_line#INFO: }"; 
              else
                echo -e "$vcom_line"
              fi
            fi
            if [[ -n $HOG_LOGGER ]]; then
              if [[ -n $LOG_INFO_FILE ]]; then 
                echo "    VCOM : ${vcom_line#INFO: }" >> $LOG_INFO_FILE; 
              fi
            fi
            ;;
          # *'Errors'* | *'Warnings'* | *'errors'* | *'warnings'*)
          #   if [[ $DEBUG_VERBOSE -gt 5 ]]; then
          #     printf "%d : %d :" $BASHPID "$(msg_counter iw)"
          #   else
          #     msg_counter iw >> /dev/null
          #   fi;
          #   if [[ -n "$HOG_COLORED" ]]; then
          #     if [ $echo_info == 1 ]; then 
          #       echo -e "$txtblu    INFO $txtwht: ${line#INFO: }"; 
          #     fi
          #     if [[ -n $HOG_LOGGER ]]; then
          #       if [[ -n $LOG_INFO_FILE ]]; then 
          #         echo "    INFO : ${line#INFO: }" >> $LOG_INFO_FILE; 
          #       fi
          #     fi
          #   fi
          #   # msg_counter iw
          # ;;
          *)
            info_line=$line
            if [[ $DEBUG_VERBOSE -gt 5 ]]; then
              printf "%d : %d :" $BASHPID "$(msg_counter iw)"
            else
              msg_counter iw >> /dev/null
            fi;
            if [[ $DEBUG_VERBOSE -gt 3 ]]; then
              if [[ -n "$HOG_COLORED" ]]; then
                echo -e "$txtblu    INFO $txtwht: ${info_line#INFO: }"; 
              else
                echo -e "$info_line"
              fi
            fi
            if [[ -n $HOG_LOGGER ]]; then
              if [[ -n $LOG_INFO_FILE ]]; then 
                echo "   *INFO : ${info_line#INFO: }" >> $LOG_INFO_FILE; 
              fi
            fi
            ;;
        esac
      elif [ "${1}" == "stderr" ]; then
        stderr_line=$line
        if [[ $DEBUG_VERBOSE -gt 5 ]]; then
          printf "%d : %d :" $BASHPID "$(msg_counter ew)"  
        else
          msg_counter ew >> /dev/null
        fi;
        if [[ $DEBUG_VERBOSE -gt 0 ]]; then
          if [[ -n "$HOG_COLORED" ]]; then
            echo -e "$txtred*ERROR $txtwht: ${stderr_line#*@(ERROR:|Error:)} "; 
          else
            echo -e "$stderr_line"
          fi
        fi
        if [[ -n $HOG_LOGGER ]]; then
          if [[ -n $LOG_WAR_ERR_FILE ]]; then 
            echo "*ERROR : ${stderr_line#*@(ERROR:|Error:)} " >> $LOG_WAR_ERR_FILE
          fi
          if [[ -n $LOG_INFO_FILE ]]; then 
            echo "*ERROR : ${stderr_line#*@(ERROR:|Error:)} " >> $LOG_INFO_FILE; 
          fi
        fi
      else
       Msg Error "Error in logger" 
      fi  
    done    
  fi
}

## @function Logger_Init()
# 
# @brief creates output files and pipelines stdout and stderr to 
# 
# @param[in] execution line to process
function Logger_Init() {
  {
    print_log_hog $HOG_GIT_VERSION
    echo "-----------------------------------------------"
    echo " HOG INFO LOG "
    echo " CMD : ${1} "
    echo "-----------------------------------------------"
  } > $LOG_INFO_FILE
  {
    print_log_hog $HOG_GIT_VERSION
    echo "-----------------------------------------------"
    echo " HOG WARNINGS AND ERRORS"
    echo " CMD : ${1} "
    echo "-----------------------------------------------"
  } > $LOG_WAR_ERR_FILE

  Msg Debug "LogColorVivado : $*"
  log_stdout "stdout" "LogColorVivado : $*"
  log_stdout "stderr" "LogColorVivado : $*"
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

## @function Logger()
# 
# @brief creates output files and pipelines stdout and stderr to 
# 
# @param[in] execution line to process
function Logger(){
  Msg Debug "$*"
  $* > >(log_stdout "stdout") 2> >(log_stdout "stderr" >&2)
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
    if [[ $DEBUG_VERBOSE -gt 5 ]]; then
      printf "%d : %d :" $BASHPID "$(msg_counter ew)"  
    else
      msg_counter ew >> /dev/null
    fi;
    if [[ $DEBUG_VERBOSE -gt 0 ]]; then
      print_msg=1
      if [[ -n "$HOG_COLORED" ]]; then
        echo -e "$txtred   ERROR $txtwht: HOG [${FUNCNAME[1]}] : $text "; 
      else
        Colour=$txtred
      fi
    fi
    if [[ -n $HOG_LOGGER ]]; then
      if [[ -n $LOG_INFO_FILE ]]; then 
        echo "   ERROR : HOG [${FUNCNAME[1]}] : $text " >> $LOG_INFO_FILE; 
        echo "   ERROR : HOG [${FUNCNAME[1]}] : $text " >> $LOG_WAR_ERR_FILE; 
      fi
    fi
    ;;
  "CriticalWarning")
    if [[ $DEBUG_VERBOSE -gt 5 ]]; then
      printf "%d : %d :" $BASHPID "$(msg_counter cw)"
    else
      msg_counter cw >> /dev/null 
    fi;
    if [[ $DEBUG_VERBOSE -gt 1 ]]; then
      print_msg=1
      if [[ -n "$HOG_COLORED" ]]; then
        echo -e "${txtblu}CRITICAL $txtwht: HOG [${FUNCNAME[1]}] : $text "; 
      else
        Colour=$txtorg
      fi
    fi
    if [[ -n $HOG_LOGGER ]]; then
      if [[ -n $LOG_INFO_FILE ]]; then 
        echo "CRITICAL : HOG [${FUNCNAME[1]}] : $text " >> $LOG_INFO_FILE; 
        echo "CRITICAL : HOG [${FUNCNAME[1]}] : $text " >> $LOG_WAR_ERR_FILE; 
      fi
    fi
    ;;
  "Warning")
    if [[ $DEBUG_VERBOSE -gt 5 ]]; then
      printf "%d : %d :" $BASHPID "$(msg_counter ww)"
    else
      msg_counter ww >> /dev/null
    fi;
    if [[ $DEBUG_VERBOSE -gt 2 ]]; then
      print_msg=1
      if [[ -n "$HOG_COLORED" ]]; then
        echo -e "$txtylw WARNING $txtwht: HOG [${FUNCNAME[1]}] : $text "; 
      else
        Colour=$txtcyn
      fi
    fi
    if [[ -n $HOG_LOGGER ]]; then
      if [[ -n $LOG_INFO_FILE ]]; then 
        echo "WARNING : HOG [${FUNCNAME[1]}] : $text" >> $LOG_INFO_FILE; 
        echo "WARNING : HOG [${FUNCNAME[1]}] : $text" >> $LOG_WAR_ERR_FILE; 
      fi
    fi
    ;;
  "Info")
    if [[ $DEBUG_VERBOSE -gt 5 ]]; then
      printf "%d : %d :" $BASHPID "$(msg_counter iw)"
    else
      msg_counter iw >> /dev/null
    fi;
    if [[ $DEBUG_VERBOSE -gt 3 ]]; then
      print_msg=1
      if [[ -n "$HOG_COLORED" ]]; then
        echo -e "$txtblu    INFO $txtwht: HOG [${FUNCNAME[1]}] : $text "; 
      else
        Colour=$txtwht
      fi
    fi
    if [[ -n $HOG_LOGGER ]]; then
      if [[ -n $LOG_INFO_FILE ]]; then 
        echo "    INFO : HOG [${FUNCNAME[1]}] : $text" >> $LOG_INFO_FILE; 
      fi
    fi
    ;;
  "Debug")
    if [[ $DEBUG_VERBOSE -gt 5 ]]; then
      printf "%d : %d :" $BASHPID "$(msg_counter dw)" 
    else
      msg_counter dw >> /dev/null
    fi;
    if [[ $DEBUG_VERBOSE -gt 4 ]]; then
      print_msg=1
      if [[ -n "$HOG_COLORED" ]]; then
          echo -e "${txtgrn}   DEBUG${txtwht} : HOG [${FUNCNAME[1]}] : $text "; 
      else
        Colour=$txtgrn
      fi
    fi
    if [[ -n $HOG_LOGGER ]]; then
      if [[ -n $LOG_INFO_FILE ]]; then 
        echo "   DEBUG : HOG [${FUNCNAME[1]}] : $text " >> $LOG_INFO_FILE; 
      fi
    fi
    ;;
  *)
    Msg Error "messageLevel: $1 not supported! Use Info, Warning, CriticalWarning, Error"
    ;;
  esac

  if [[ $print_msg == 1 ]]; then
    if [[ -z $HOG_COLORED ]] ; then
      if [[ "$1" != "Debug" ]]; then
        echo -e "${Colour}HOG:$1[${FUNCNAME[1]}] $text $txtwht"
      else
        if [[ $DEBUG_VERBOSE -gt 0 ]]; then
          echo -e "${Colour}HOG:$1[${FUNCNAME[1]}] $text $txtwht"
        fi
      fi
    fi
  fi
  
  return 0
}



## @fn select_command_from_line
#
# @brief Selects which command has to be used based on the first line of the tcl
#
# This function:
# - checks if the line CONTAINS:
#   * vivado
#     + vivadoHLS
#   * quartus
#     + quartusHLS
#   * intelHLS
#   * planahead
#   * libero
#
# @param[in]    $1 the first line of the tcl file or a suitable string
# @param[out]   COMMAND  global variable: the selected command
# @param[out]   COMMAND_OPT global variable: the selected command options
# @param[out]   POST_COMMAND_OPT global variable: the post command options
#
# @returns  0 if success, 1 if failure
#
function select_command_from_line() {
  if [ -z ${1+x} ]; then
    Msg Error " missing input! Got: $1!"
    return 1
  fi

  local TCL_FIRST_LINE=$1

  if [[ $TCL_FIRST_LINE =~ 'vivado' ]]; then
    if [[ $TCL_FIRST_LINE =~ 'vivadoHLS' ]]; then
      Msg Info " Recognised VivadoHLS project"
      COMMAND="vivado_hls"
      COMMAND_OPT="-f"
    else
      Msg Info " Recognised Vivado project"
      COMMAND="vivado"
      COMMAND_OPT="-nojournal -nolog -mode batch -notrace -source "
      POST_COMMAND_OPT="-tclargs "
    fi
  elif [[ $TCL_FIRST_LINE =~ 'quartus' ]]; then
    if [[ $TCL_FIRST_LINE =~ 'quartusHLS' ]]; then
      Msg Error " Intel HLS compiler is not supported!"
      return 1
    else
      Msg Info " Recognised QuartusPrime project"
      COMMAND="quartus_sh"
      COMMAND_OPT="-t "
    fi
  elif [[ $TCL_FIRST_LINE =~ 'intelHLS' ]]; then
    Msg Error "Intel HLS compiler is not supported!"
    return 1
  elif [[ $TCL_FIRST_LINE =~ 'planahead' ]]; then
    Msg Info " Recognised planAhead project"
    COMMAND="planAhead"
    COMMAND_OPT="-nojournal -nolog -mode batch -notrace -source "
    POST_COMMAND_OPT="-tclargs"
  elif [[ $TCL_FIRST_LINE =~ 'libero' ]]; then
    Msg Info " Recognised Libero SoC project"
    COMMAND="libero"
    COMMAND_OPT="SCRIPT:"
    POST_COMMAND_OPT="SCRIPT_ARGS:"
  else
    Msg Warning " You should write #vivado, #quartus or #planahead as first line in your hog.conf file or project Tcl file, assuming Vivado... "
    Msg Info " Recognised Vivado project"
    COMMAND="vivado"
    COMMAND_OPT="-mode batch -notrace -source"
    POST_COMMAND_OPT="-tclargs"
  fi

  return 0
}

## @fn select_command
#
# @brief Selects which command has to be used based on the first line of the tcl/conf file
#
# This function:
# - checks that the tcl file exists
# - gets the first line using head -1
# - calls select_command_from_line()
#
# @param[in]    $1 full path to the tcl/conf file
# @param[out]   COMMAND  global variable: the selected command
# @param[out]   COMMAND_OPT global variable: the selected command options
#
# @returns  0 for ok, 1 for error
#
function select_command() {
  proj=$(basename "$1")
  conf="$1"/"hog.conf"
  tcl="$1"/"$proj.tcl"

  if [ -f "$conf" ]; then
    file="$conf"
    FILE_TYPE=CONF
  elif [ -f "$tcl" ]; then
    file="$tcl"
    FILE_TYPE=TCL
  else
    Msg Error "No suitable file found in $1!"
    return 1
  fi

  
  if ! select_command_from_line "$(head -1 "$file")"; then
    Msg Error "Failed to select COMMAND, COMMAND_OPT and POST_COMMAND_OPT"
    return 1
  fi

  return 0
}

## @fn select_compiler_executable
#
# @brief selects the path to the executable to be used for invoking the HDL compiler
#
# This function:
# - checks at least 1 argument is passed
# - uses command -v to select the executable
#   * if no executable is found and the command is vivado it uses XILINX_VIVADO
#   *
# - stores the result in a global variable called HDL_COMPILER
#
# @param[in]    $1 The command to be invoked
# @param[out]   HDL_COMPILER global variable: the full path to the HDL compiler executable
#
# @returns  0 if success, 1 if failure
#
function select_compiler_executable() {
  if [ "a$1" == "a" ]; then
    Msg Error "select_compiler_executable(): Variable COMMAND is not set!"
    return 1
  fi

  if [ "$(command -v "$1")" ]; then
    HDL_COMPILER=$(command -v "$1")
  else
    if [ "$1" == "vivado" ]; then
      if [ -z ${XILINX_VIVADO+x} ]; then
        Msg Error "No vivado executable found and no variable XILINX_VIVADO set\n"
        cd "${OLD_DIR}" || exit
        return 1
      elif [ -d "$XILINX_VIVADO" ]; then
        Msg Info "XILINX_VIVADO is set to '$ XILINX_VIVADO'"
        HDL_COMPILER="$XILINX_VIVADO/bin/$1"
      else
        Msg Error "Failed locate '$1' executable from XILINX_VIVADO: $XILINX_VIVADO"
        return 1
      fi
    elif [ "$1" == "quartus_sh" ]; then
      if [ -z ${QUARTUS_ROOTDIR+x} ]; then
        Msg Error "No quartus_sh executable found and no variable QUARTUS_ROOTDIR set\n"
        cd "${OLD_DIR}" || exit 
        return 1
      else
        Msg Info "QUARTUS_ROOTDIR is set to '$QUARTUS_ROOTDIR'"
        #Decide if you are to use bin or bin 64
        #Note things like $PROCESSOR_ARCHITECTURE==x86 won't work in Windows because this will return the version of the git bash
        if [ -d "$QUARTUS_ROOTDIR/bin64" ]; then
          HDL_COMPILER="$QUARTUS_ROOTDIR/bin64/$1"
        elif [ -d "$QUARTUS_ROOTDIR/bin" ]; then
          HDL_COMPILER="$QUARTUS_ROOTDIR/bin/$1"
        else
          Msg Error "Failed locate '$1' executable from QUARTUS_ROOTDIR: $QUARTUS_ROOTDIR"
          return 1
        fi
      fi
    elif [ "$1" == "libero" ]; then
      Msg Error "No libero executable found."
      cd "${OLD_DIR}" || exit
      return 1
    else
      Msg Error "cannot find the executable for $1."
      echo "Probable causes are:"
      echo "- $1 was not setup"
      echo "- command not available on the machine"
      return 1
    fi
  fi

  return 0
}

## @fn select_executable_from_project
#
# @brief Selects which compiler executable has to be used based on the first line of the conf or tcl file
#
# @param[in]    $1 full path to the project dir
# @param[out]   COMMAND  global variable: the selected command
# @param[out]   COMMAND_OPT global variable: the selected command options
# @param[out]   POST_COMMAND_OPT global variable: the post command options
# @param[out]   HDL_COMPILER global variable: the full path to the HDL compiler executable
#
# @returns  0 if success, 1 if failure
#
function select_executable_from_project_dir() {
  if [ -z ${1+x} ]; then
    Msg Error "missing input! Got: $1!"
    return 1
  fi
  
  if ! select_command "$1"; then
    Msg Error "Failed to select project type: exiting!"
    return 1
  fi

  #select full path to executable and place it in HDL_COMPILER global variable
  
  if ! select_compiler_executable $COMMAND; then
    Msg Error "Failed to get HDL compiler executable for $COMMAND"
    return 1
  fi

  return 0
}

# @fn print_hog
#
# @param[in] $1 path to Hog dir
# @brief prints the hog logo
function print_hog() {
  if [ -z ${1+x} ]; then
    Msg Error "missing input! Got: $1!"
    return 1
  fi
  cd "$1" || exit
  ver=$(git describe --always)
  HOG_GIT_VERSION=$(git describe --always)
  echo
  cat ./images/hog_logo.txt
  echo " Version: ${ver}"
  echo
  cd "${OLDPWD}" || exit >> /dev/null
  HogVer "$1"

  return 0
}

# @fn print_hog
#
# @param[in] $1 path to Hog dir
# @brief prints the hog logo
function print_log_hog() {
  if [ -z ${1+x} ]; then
    Msg Error "Missing input! Got: $1!"
    return 1
  fi
  cat ${ROOT_PROJECT_FOLDER}"/Hog/images/hog_logo.txt"
  echo " Version: ${HOG_GIT_VERSION}"
  echo
  return 0
}

# @fn new_print_hog
#
# @param[in] $1 path to Hog dir
# @brief prints the hog logo
function new_print_hog() {
  if [ -z ${1+x} ]; then
    Msg Error "missing input! Got: $1!"
    return 1
  fi
  cd "$1"
  HOG_GIT_VERSION=$(git describe --always)
  while IFS= read -r line; do
    echo -e "$line"
  done < ./images/hog_logo_color.txt
  echo
  echo " Version: ${HOG_GIT_VERSION}"
  echo
  echo "***************************************************"
  cd "${OLDPWD}" || exit >> /dev/null
  return 0
}

## @fn search available projects inside input folder
#
# @brief Search all hog projects inside a folder
#
# @param[in]    $1 full path to the dir containing the projects
# @returns  0 if success, 1 if failure
#
function search_projects() {
  if [ -z ${1+x} ]; then
    Msg Error "missing input! Got: $1!"
    return 1
  fi

  if [[ -d "$1" ]]; then
    for dir in "$1"/*; do
      if [ -f "$dir/hog.conf" ]; then
        subname=${dir#*Top/}
        Msg Info $subname
      else
        search_projects "$dir"
      fi
    done
  fi
  return 0
}

#
# @brief Check if the running Hog version is older than the latest stable
#
# @param[in]    $1 full path to the dir containing the HDL repo
# @returns  0 if success, 1 if failure
#
function HogVer() {
  Msg Info "Checking the latest available Hog version..."
  if ! check_command timeout
  then
    return 1
  fi

  if [ -z ${1+x} ]; then
    Msg Error "Missing input! You should give the path to your Hog submodule. Got: $1!"
    return 1
  fi

  if [[ -d "$1" ]]; then
    cd "$1" || exit
    current_version=$(git describe --always)
    current_sha=$(git log "$current_version" -1 --format=format:%H)
    timeout 5s git fetch
    master_version=$(git describe origin/master)
    master_sha=$(git log "$master_version" -1 --format=format:%H)    
    merge_base=$(git merge-base "$current_sha" "$master_sha")

    # The next line checks if master_sha is an ancestor of current_sha 
    if [ "$merge_base" != "$master_sha" ]; then
      Msg Info
      Msg Info "Version $master_version has been released (https://gitlab.cern.ch/hog/Hog/-/releases/$master_version)"
      Msg Info "You should consider updating Hog submodule with the following instructions:"
      echo
      Msg Info "cd Hog && git checkout master && git pull"
      echo 
      Msg Info "Remember also to update the ref: in your .gitlab-ci.yml to $master_version"
      echo 
    else
      Msg Info "Latest official version is $master_version, nothing to do."
    fi

  fi
  cd ${OLDPWD} || exit >> /dev/null
}


#
# @brief Check if a command is available on the running machine
#
# @param[in]    $1 Command name
# @returns  0 if success, 1 if failure
#
function check_command() {
  if ! command -v "$1" &> /dev/null
  then
    Msg Warning "Command $1 could not be found"
    return 1
  fi
  return 0
}


## @fn print_projects
#
# @brief Prints a message with projects names
#
# The print_projects takes the directory to search and since search projects will change directory, it requires the directory to which return.
# This function uses echo to print to screen
#
# @param[in]    $1 search directory
# @param[in]    $2 return directory
#
function print_projects() {
    echo
    echo "Possible projects are:"
    echo ""
    search_projects "$1"
    echo
    cd "$2" || exit 

}
