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
            # if [[ "$line" == *'Fatal'* ]]; then
            #   next_is_err=1
            # fi
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

# @function trim
  #
  # @param[in] string
  #
  # @return  string
trim() {
  local var=$1
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
process_toml_file() {
  local file_path=$1
  local dict_name=$2
  declare -n toml_dict=$dict_name
  local arraylvl=0
  local index=0
  while IFS= read -r rline; do
    # echo " ######################### ::: <${rline}>"
    # echo "$rline"
    if [[ "$rline" =~ ^[:space:]*#.*$ ]]; then continue; fi
    if [[ "$rline" =~ ^[:space:]*$ ]]; then continue; fi
    # echo " ######################### ::: <${rline}>"
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
    # echo "new line ::: <$line>"
    if [[ ! $line = *[!\ ]* ]]; then echo "he pasado por aqui";continue; fi # no me acuerdo que hace est0?
    # echo "new line ::: <$line>"
    if [[ $line =~ ^\[.*\] ]]; then
      # echo "1 - $line"
      section_name=$(echo "$line" | sed 's/[[:space:]]*$//' | sed 's/\[\(.*\)\]/\1/' | sed 's/ /_/g' )
      # echo "section_name ::: $section_name"
      continue
    elif [[ $line =~ ^[a-zA-Z0-9_[:space:]]*= ]]; then
      # echo "12a - $line"
      key=$(echo "${line// /}" | sed 's/=.*//')
      # echo "key ::: $key"
      line=$(echo "$line" | sed 's/.*=//')
    fi
    line=$(trim "$line")
    # echo "line post key :::: <$line>"
    
    while [[ -n $line ]]; do
      # echo "oL = <${line}>"
      line=$(trim "$line")
      # echo "nL = <${line}>"
      # echo "AL = $arraylvl"

      if [[ ${line:0:1} == "[" ]]; then
        line=${line:1}
        ((arraylvl++))
        # echo "OPENING ARRAY"
        index=0
        continue
      fi
      if [[ ${line:0:1} == "]" ]]; then
        line=${line:1}
        ((arraylvl--))
        # echo "CLOSING ARRAY"
        continue
      fi

      open_array=-1
      closing_array=-1
      cnt_dc=0
      coma_cnt=0
      first_coma=-1
      for ((i=0; i<${#line}; i++)); do
        char="${line:i:1}"
        # echo "char --- $char"
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

      # echo "coma cnt ::: $coma_cnt"
      # echo "first_coma ::: $first_coma"
      # echo "last_coma ::: $last_coma"
      # echo "closing_array ::: $closing_array"
      proc_line=""
      if [[ $coma_cnt > 0 ]]; then
        proc_line=${line:0:first_coma}
        line=${line:((first_coma + 1))}
      elif [[ $closing_array > -1 ]]; then
        proc_line=${line:0:closing_array}
        line=${line:closing_array}
      else
        proc_line=$line
        line=""
      fi
      # echo "proc line ::: <$proc_line>"
      # echo "next line ::: <$line>"
      if [[ ${#proc_line} > 0 ]]; then
        Msg Debug "saving in dict ::: $proc_line"
        if [[ $arraylvl == 0 ]]; then
          toml_dict["$section_name.$key"]=$(trim ${proc_line//\"/}) #${proc_line//\"/} #(trim "$line")
          # echo " ==========  toml_dict[ ${section_name}.${key} ] = <${toml_dict[$section_name.${key}]}>"
        else
          toml_dict["$section_name.${key}.$index"]=$(trim ${proc_line//\"/})
          # echo "toml_dict[ ${section_name}.${key}.${index} ] = <${toml_dict[$section_name.${key}.$index]}>"
          ((index++))
        fi
      fi
    done
  done < $1 
  # echo " =============== DONE ============== "
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

  ############################################
  #    USER CONFIGURATIONS
  ############################################

  # declare -A CONF
  # CONF[test]="on"

  # declare -A yaml_dict
  current_user=$(whoami)
  hog_user_cfg=$(eval echo "~$USER")"/HogEnv.conf"
  if test -f $hog_user_cfg; then
    Msg Info "Hog project configuration file $hog_user_cfg exists."
    process_toml_file $hog_user_cfg "Hog_Usr_dict"
    for key in "${!Hog_Usr_dict[@]}"; do
      Msg Info "Hog_Usr_dict[ $key ] = <${Hog_Usr_dict[$key]}>"
    done
  else
    Msg Debug "Hog project configuration file $hog_user_cfg doesn't exists."
  fi



  # hog_proj_cfg=$(pwd)"/HogEnv.conf"
  # if test -f $hog_proj_cfg; then
  #   Msg Info "Hog project configuration file $hog_proj_cfg exists."
  #   process_toml_file $hog_proj_cfg "Hog_Prj_dict"
  #   for key in "${!Hog_Prj_dict[@]}"; do
  #     echo "Hog_Prj_dict[ $key ] = <${Hog_Prj_dict[$key]}>"
  #   done
  # else
  #   Msg Debug "Hog project configuration file $hog_proj_cfg doesn't exists."
  # fi
  # if test -f $hog_user_cfg; then
  #   Msg Info "Hog user configuration file $hog_user_cfg exists."
  # else
  #   Msg Debug "Hog user configuration file $hog_user_cfg doesn't exists."
  # fi
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


  # exit

  # SETTING COLORS
  HOG_COLOR_EN=0
  # hog_user_tc="${current_user}_terminal_colored"
  # echo "$hog_user_tc"
  if [[ -v Hog_Usr_dict["terminal.colored"] ]]; then
    if [[ ${Hog_Usr_dict["terminal.colored"]} =~ ^[0-9]$ ]]; then
      Msg Debug "The variable <terminal.colored> is a one-digit number"
      HOG_COLOR_EN=${Hog_Usr_dict["terminal.colored"]}
    else
      Msg Warning "The variable <terminal.colored> is not a one-digit number, Defaulting to 0"
    fi
  else
    # if [[ -v CONF[global_terminal_colored] ]]; then
    #   if [[ ${CONF["global_terminal_colored"]} =~ ^[0-9]$ ]]; then
    #     Msg Debug "The variable global_terminal_colored is a one-digit number"
    #     HOG_COLOR_EN=${CONF["global_terminal_colored"]}
    #   else 
    #     Msg Warning "The variable global_terminal_colored is not a one-digit number, Defaulting to 0"
    #   fi
    # else
      if [[ -v HOG_COLORED ]]; then
        if [[ $HOG_COLORED =~ ^[0-9]$ ]]; then
          HOG_COLOR_EN=$HOG_COLORED
        else
          HOG_COLOR_EN=1
        fi 
      fi
    # fi
  fi
  Msg Debug "HOG_COLOR_EN -- $HOG_COLOR_EN"

  # SETTING DEBUG_VERBOSE
  # hog_user_td="${current_user}_terminal_debug"
  # HOG_LOG_EN=0
  # echo "$hog_user_tc"
  if [[ -v Hog_Usr_dict["terminal.debug"] ]]; then
    if [[ ${Hog_Usr_dict["terminal.debug"]} =~ ^[0-9]$ ]]; then
      Msg Debug "The variable <terminal.debug> is ${Hog_Usr_dict['terminal.debug']}"
      DEBUG_VERBOSE=${Hog_Usr_dict["terminal.debug"]}
    else
      Msg Warning "The variable $hog_user_td is not a one-digit number, Defaulting to 0"
    fi
  # else
  #   if [[ -v CONF[global_terminal_debug] ]]; then
  #     if [[ ${CONF["global_terminal_debug"]} =~ ^[0-9]$ ]]; then
  #       Msg Debug "The variable global_terminal_debug is a one-digit number"
  #       DEBUG_VERBOSE=${CONF["global_terminal_debug"]}
  #     else 
  #       Msg Warning "The variable global_terminal_debug is not a one-digit number, Defaulting to 0, Defaulting to 0"
  #     fi
    # else
    # fi
  fi
  if [[ "$@" =~ "-verbose" ]]; then
    if (( $DEBUG_VERBOSE < int2 )); then
      DEBUG_VERBOSE=5
    fi
  fi
  Msg Debug "DEBUG_VERBOSE -- $DEBUG_VERBOSE"

  # SETTING LOGGER
  # hog_user_tl="${current_user}_terminal_logger"
  HOG_LOG_EN=0
  # echo "$hog_user_tc"
  if [[ -v Hog_Usr_dict["terminal.logger"] ]]; then
    if [[ ${Hog_Usr_dict["terminal.logger"]} =~ ^[01]$ ]]; then
      Msg Debug "The variable <terminal.logger> is ${Hog_Usr_dict['terminal.logger']}"
      HOG_LOG_EN=${Hog_Usr_dict["terminal.logger"]}
    else
      Msg Warning "The variable terminal.logger is not 1 or 0, Default to 0"
    fi
  else
    # if [[ -v CONF[global_terminal_logger] ]]; then
    #   if [[ ${CONF["global_terminal_logger"]} =~ ^[01]$ ]]; then
    #     Msg Debug "The variable global_terminal_logger is a one-digit number"
    #     HOG_LOG_EN=${CONF["global_terminal_logger"]}
    #   else 
    #     Msg Warning "The variable global_terminal_logger is not a one-digit number, Defaulting to 0"
    #   fi
    # else
      if [[ -v HOG_LOGGER && $HOG_LOGGER == ENABLED ]]; then
        HOG_LOG_EN=1
      fi
    # fi
  fi
  Msg Debug "HOG_LOG_EN -- $HOG_LOG_EN"

  # hog_user_cs="${current_user}_terminal_colorscheme"
  # echo $hog_user_cs
  if [[ -v Hog_Usr_dict["terminal.colorscheme"] ]]; then
    clrschselected=${Hog_Usr_dict["terminal.colorscheme"]}
  # elif  [[ -v CONF[global_terminal_colorscheme] ]]; then
  #   clrschselected="${CONF['global_terminal_colorscheme']}"
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

  # exit

  ############################################
  #    PROJECT CONFIGURATIONS
  ############################################
  

  hog_proj_cfg=$(pwd)"/HogEnv.conf"
  if test -f $hog_proj_cfg; then
    Msg Info "Hog project configuration file $hog_proj_cfg exists."
    process_toml_file $hog_proj_cfg "Hog_Prj_dict"
    for key in "${!Hog_Prj_dict[@]}"; do
      Msg Info "Hog_Prj_dict[ $key ] = <${Hog_Prj_dict[$key]}>"
    done
  else
    Msg Debug "Hog project configuration file $hog_proj_cfg doesn't exists."
  fi

  # exit

  # error fail
  hog_user_fwe="${current_user}_fail_when_error_enabled"
  hog_user_dfwe="${current_user}_fail_when_error_delay"
  if [[ -v Hog_Prj_dict["$hog_user_fwe"] ]]; then
    if [[ -v Hog_Prj_dict["$hog_user_dfwe"] ]]; then
      fail_when_error=$((1 + ${Hog_Prj_dict["$hog_user_dfwe"]}))
    else
      fail_when_error=1
    fi
  # elif  [[ -v Hog_Prj_dict[global_fail_when_error_enabled] ]]; then
  #   if [[ -v Hog_Prj_dict["global_fail_when_error_delay"] ]]; then
  #     fail_when_error=$((1 + ${Hog_Prj_dict["global_fail_when_error_delay"]}))
  #   else
  #     fail_when_error=1
  #   fi
  else
    fail_when_error=0
  fi
  Msg Debug "fail_when_error = $fail_when_error"
  
  hog_user_eo="${current_user}_overloads"
  use_user_ol=0
  use_glob_ol=1
  for key in "${!Hog_Prj_dict[@]}"; do
    if [[ $key == *"overloads"* ]]; then
      # echo "key $key"
      if [[ $key == *"include_global"* ]]; then
        use_glob_ol=${Hog_Prj_dict["overloads"]}
      fi
      if [[ $key =~ \.[a-z]2[a-z]\. ]]; then
          # echo "aaaaa"
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
            *"e2"*) infoOverload["${Hog_Prj_dict[$key]}"]=$destination ;;
            *"e2"*) debugOverload["${Hog_Prj_dict[$key]}"]=$destination ;;
          esac
        fi
    fi
  done

  # echo "use_glob_ol : $use_glob_ol"

  # if (( $use_glob_ol == 1 )); then
  #   for key in "${!Hog_Prj_dict[@]}"; do
  #     if [[ $key == *"global_overloads"* ]]; then
  #       # echo "key--- $key"
  #       if [[ $key =~ _[a-z]2[a-z]_ ]]; then
  #         # echo "aaaaa"
  #         case "${key}" in
  #           *"2e"*) destination="error" ;;
  #           *"2c"*) destination="critical" ;;
  #           *"2w"*) destination="warning" ;;
  #           *"2i"*) destination="info" ;;
  #           *"2d"*) destination="debug" ;;
  #         esac
  #         case "${key}" in
  #           *"e2"*) errorOverload["${Hog_Prj_dict[$key]}"]=$destination ;;
  #           *"c2"*) criticalOverload["${Hog_Prj_dict[$key]}"]=$destination ;;
  #           *"w2"*) warningOverload["${Hog_Prj_dict[$key]}"]=$destination ;;
  #           *"e2"*) infoOverload["${Hog_Prj_dict[$key]}"]=$destination ;;
  #           *"e2"*) debugOverload["${Hog_Prj_dict[$key]}"]=$destination ;;
  #         esac
  #       fi
  #     fi
  #   done
  # fi
  Msg Debug " ========================================= "
  Msg Debug "        Message Overloads"
  Msg Debug " ========================================= "
  for key in "${!errorOverload[@]}"; do
    Msg Warning "::: errorOverload[$key] --- ${errorOverload[$key]}"
  done
  for key in "${!criticalOverload[@]}"; do
    Msg Warning "::: criticalOverload[$key] --- ${criticalOverload[$key]}"
  done
  for key in "${!warningOverload[@]}"; do
    Msg Warning "::: warningOverload[$key] --- ${warningOverload[$key]}"
  done
  for key in "${!infoOverload[@]}"; do
    Msg Warning "::: infoOverload[$key] --- ${infoOverload[$key]}"
  done
  for key in "${!debugOverload[@]}"; do
    Msg Warning "::: debugOverload[$key] --- ${debugOverload[$key]}"
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



