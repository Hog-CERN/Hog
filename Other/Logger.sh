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
#   Guillermo
##############################################################
##############################################################

## @var HOG_PROJECT_FOLDER
#  @brief Global variable containing the full path of the root project folder
#
# export HOG_PROJECT_FOLDER=""

## @var HOG_GIT_VERSION
#  @brief Global variable containing the full path of the root project folder
#
# export HOG_GIT_VERSION=""

## @var LOGGER
#  @brief Global variable used to contain the logger
# if [[ -z $HOG_LOGGER ]]; then 
#   export HOG_LOGGER=""; 
# fi

## @var LOGGER
#  @brief Global variable used to contain the logger
# if [[ -z $HOG_COLORED ]]; then 
#   export HOG_COLORED=""; 
# fi

## @var DEBUG_VERBOSE
#  @brief Global variable 
#
export DEBUG_VERBOSE=""

#Define temp files in shared memory
# dirToCreate=/dev/shm/hog/
# if [ ! -w "$(dirname "$dirToCreate")" ]; then
#     echo "Insufficient permissions to create $dirToCreate" >&2
# else
#     mkdir "$dirToCreate" || {
#         echo "Error creating $dirToCreate (due to something other than permissions)" >&2
#     }
# fi


# if [ -w "/dev/shm" ]; then
#   echo "1"
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
# else
#   echo " N "
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
next_is_err=0
shopt -s extglob
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
        case "$line" in
          *'ERROR:'* | *'Error:'* | *':Error'* | *'error:'* | *'Error '* | *'FATAL ERROR'* | *'Fatal'*)
            if [[ "$line" == *'Fatal'* ]]; then
              next_is_err=1
            fi
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
    # print_log_hog $HOG_GIT_VERSION
    echo "-----------------------------------------------"
    echo " HOG INFO LOG "
    echo " CMD : ${1} "
    echo "-----------------------------------------------"
  } > $LOG_INFO_FILE
  {
    # print_log_hog $HOG_GIT_VERSION
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
  $* > >(log_stdout "stdout") 2> >(log_stdout "stderr" >&2) &
  tcl_pid=$!
  Msg Debug "pid = $tcl_pid"
  while kill -0 $tcl_pid 2>/dev/null; do
    sleep 1
  done
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

# ##############################################################
# ##############################################################
# #   TILL HERE ALL THE ELEMENTS FOR THE LOGGER
# #   Guillermo
# ##############################################################
# ##############################################################








































































