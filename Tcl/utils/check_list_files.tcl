#!/usr/bin/env tclsh
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

# @file
# Check if the content of list files matches the project. It can also be used to update the list files.

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

set hog_path [file normalize "[file dirname [info script]]/.."]
set repo_path [file normalize "$hog_path/../.."]
source $hog_path/hog.tcl

if {[IsISE]} {
  set tcl_path         [file normalize "[file dirname [info script]]"]
  source $tcl_path/cmdline.tcl
}
set parameters {
  {project.arg "" "Project name. If not set gets current project"}
  {outDir.arg "" "Name of output dir containing log files."}
  {log.arg "1" "Logs errors/warnings to outFile."}
  {recreate  "If set, it will create List Files from the project configuration"}
  {recreate_conf  "If set, it will create the project hog.conf file."}
  {force  "Force the overwriting of List Files. To be used together with \"-recreate\""}
  {pedantic  "Script fails in case of mismatch"}
  {ext_path.arg "" "Sets the absolute path for the external libraries."}
}



set usage "Checks if the list and conf files matches the project ones. It can also be used to update the list and conf files. \nUSAGE: $::argv0 \[Options\]"


if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}]} {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
}

set ext_path $options(ext_path)

set ListErrorCnt 0
set ListSimErrorCnt 0
set ConfErrorCnt 0
set SrcListErrorCnt 0
set SimConfErrorCnt 0
set ConListErrorCnt 0
set TotErrorCnt 0
set SIM_PROPS  [list "dofile" \
  "wavefile" \
  "topsim" \
  "runtime" \
]

if {![string equal $options(project) ""]} {
  set project $options(project)
  set group_name [file dirname $project]
  set project_name [file tail $project]
  Msg Info "Opening project $project_name..."

  if {[IsVivado]} {
    file mkdir "$repo_path/Projects/$project/$project_name.gen/sources_1"
    open_project "$repo_path/Projects/$project/$project_name.xpr"
    set proj_file [get_property DIRECTORY [current_project]]
    set proj_dir [file normalize $proj_file]
    set group_name [GetGroupName  $proj_dir $repo_path]
  }
} else {
  set project_name [get_projects [current_project]]
  set proj_file [get_property DIRECTORY [current_project]]
  set proj_dir [file normalize $proj_file]
  set group_name [GetGroupName  $proj_dir $repo_path]
}


if {$options(outDir)!= ""} {
  set outFile $options(outDir)/diff_list_and_conf.txt
  set outSimFile $options(outDir)/diff_sim_list_and_conf.txt
  if {[file exists $outFile]} {
    file delete $outFile
  }

  if {[file exists $outSimFile]} {
    file delete $outSimFile
  }

  if {!$options(log)} {
    set outFile ""
    set outSimFile ""
  }

} else {
  set outFile ""
  set outSimFile ""
}


if {[file exists $repo_path/Top/$group_name/$project_name] && [file isdirectory $repo_path/Top/$group_name/$project_name] && $options(force) == 0} {
  set DirName Top_new/$group_name/$project_name
} else {
  set DirName Top/$group_name/$project_name
}

if { $options(recreate_conf) == 0 || $options(recreate) == 1 } {
  Msg Info "Checking $project_name list files..."

  Msg Info "Retrieved Vivado project files..."
  # Get project libraries and properties from list files
  lassign [GetHogFiles -ext_path "$ext_path" -list_files ".src,.ext" "$repo_path/Top/$group_name/$project_name/list/" $repo_path] listLibraries listProperties listSrcSets
  # Get project constraints and properties from list files
  lassign [GetHogFiles -ext_path "$ext_path" -list_files ".con" "$repo_path/Top/$group_name/$project_name/list/" $repo_path] listConstraints listConProperties listConSets
  # Get project simulation libraries and properties from list files
  lassign [GetHogFiles -ext_path "$ext_path" -list_files ".sim" "$repo_path/Top/$group_name/$project_name/list/" $repo_path] listSimLibraries listSimProperties listSimSets
  # Get files generated at creation time
  set extraFiles [ReadExtraFileList "$repo_path/Projects/$group_name/$project_name/.hog/extra.files"]
  set extraFiles_copy $extraFiles
  # Get project libraries and properties from Vivado
  lassign [GetProjectFiles] prjLibraries prjProperties prjSimLibraries prjConstraints prjSrcSets prjSimSets prjConSets

  # Removing duplicates from listlibraries listProperties listSimLibraries listSimProperties
  set listLibraries [RemoveDuplicates $listLibraries]
  set listProperties [RemoveDuplicates $listProperties]
  set listSimLibraries [RemoveDuplicates $listSimLibraries]
  set listSimProperties [RemoveDuplicates $listSimProperties]
  set listConstraints [RemoveDuplicates $listConstraints]
  set prjSimLibraries [RemoveDuplicates $prjSimLibraries]
  set prjLibraries [RemoveDuplicates $prjLibraries]
  set prjConstraints [RemoveDuplicates $prjConstraints]

  #################################################################
  ##### START COMPARISON OF FILES IN PROJECT AND LIST FILES ######
  #################################################################
  lassign [CompareLibDicts $prjLibraries $listLibraries $prjSrcSets $listSrcSets $prjProperties $listProperties "CriticalWarning" $outFile $extraFiles] SrcListErrorCnt extraFiles
  lassign [CompareLibDicts $prjSimLibraries $listSimLibraries $prjSimSets $listSimSets $prjProperties $listSimProperties "Warning" $outSimFile $extraFiles] SimListErrorCnt extraFiles
  lassign [CompareLibDicts $prjConstraints $listConstraints $prjConSets $listConSets $prjProperties $listConProperties  "CriticalWarning" $outFile $extraFiles] ConListErrorCnt extraFiles

  # Check if any files remained in extraFiles
  foreach {k v} $extraFiles {
    MsgAndLog "$k was found in .hog/extra.files but not in project." "CriticalWarning" $outFile 
    incr SrcListErrorCnt
  }

  if {$SrcListErrorCnt == 0} {
    Msg Info "Design List Files matches project. Nothing to do."
  }

  if {$SimListErrorCnt == 0} {
    Msg Info "Simulation List Files matches project. Nothing to do."
  }

  if {$ConListErrorCnt == 0} {
    Msg Info "Constraint List Files matches project. Nothing to do."
  }


  # Recreating src list files
  if {$options(recreate) == 1 && ($SrcListErrorCnt > 0 || $SimListErrorCnt > 0 || $ConListErrorCnt > 0) } {
    set listpath "$repo_path/$DirName/list/"
    Msg Info "Updating list files in $listpath"
    # Create the list path, if it does not exist yet
    file mkdir $listpath
    if {$SrcListErrorCnt > 0} {
      # Delete existing .src list files
      if {$options(force) == 1} {
        foreach F [glob -nocomplain "$listpath/*.src" "$listpath/*.ext"] {
          file delete $F
        }
      }
      WriteListFiles $prjLibraries $prjProperties $listpath $repo_path $ext_path
    }
    if {$SimListErrorCnt > 0} {
      # Delete existing .sim list files
      if {$options(force) == 1} {
        foreach F [glob -nocomplain "$listpath/*.sim"] {
          file delete $F
        }
      }
      WriteSimListFiles $prjSimLibraries $prjProperties $prjSimSets $listpath $repo_path
    }
    if {$ConListErrorCnt > 0} {
      # Delete existing .con list files
      if {$options(force) == 1} {
        foreach F [glob -nocomplain "$listpath/*.con"] {
          file delete $F
        }
      }
      WriteListFiles $prjConstraints $prjProperties $listpath $repo_path
    }
  } 
}


set conf_file "$repo_path/Top/$group_name/$project_name/hog.conf"
# checking project settings
if { $options(recreate) == 0 || $options(recreate_conf) == 1 } {
  #creating 4 dicts:
  #   - hogConfDict:     hog.conf properties (if exists)
  #   - defaultConfDict: default properties
  #   - projConfDict:    current project properties
  #   - newConfDict:     "new" hog.conf

  # Get project libraries and properties from Vivado
  lassign [GetProjectFiles] prjLibraries prjProperties
  ##nagelfar ignore
  set prjSrcDict  [DictGet $prjLibraries SRC]


  set hogConfDict [dict create]
  set defaultConfDict [dict create]
  set projConfDict [dict create]
  set newConfDict  [dict create]

  #filling hogConfDict
  if {[file exists $conf_file]} {
    set hogConfDict [ReadConf $conf_file]

    #convert hog.conf dict keys to uppercase
    foreach key [list main synth_1 impl_1 generics] {
      set runDict [DictGet $hogConfDict $key]
      foreach runDictKey [dict keys $runDict ] {
        #do not convert paths
        if {[string first $repo_path [DictGet $runDict $runDictKey]]!= -1} {
          continue
        }
        dict set runDict [string toupper $runDictKey] [DictGet $runDict $runDictKey]
        dict unset runDict [string tolower $runDictKey]
      }
      dict set hogConfDict $key $runDict
    }
  } elseif {$options(recreate_conf)==0} {
    Msg Warning "$repo_path/Top/$group_name/$project_name/hog.conf not found. Skipping properties check"
  }


  # filling newConfDict with existing hog.conf properties apart from main synth_1 impl_1 and generics
  foreach key [dict keys $hogConfDict] {
    if {$key != "main" && $key != "synth_1" && $key != "impl_1" && $key != "generics"} {
      dict set newConfDict $key [DictGet $hogConfDict $key]
    }
  }

  # list of properties that must not be checked/written
  set PROP_BAN_LIST  [ list DEFAULT_LIB \
    AUTO_RQS.DIRECTORY \
    AUTO_INCREMENTAL_CHECKPOINT.DIRECTORY \
    AUTO_INCREMENTAL_CHECKPOINT \
    COMPXLIB.MODELSIM_COMPILED_LIBRARY_DIR \
    COMPXLIB.QUESTA_COMPILED_LIBRARY_DIR \
    COMPXLIB.RIVIERA_COMPILED_LIBRARY_DIR \
    COMPXLIB.ACTIVEHDL_COMPILED_LIBRARY_DIR \
    COMPXLIB.IES_COMPILED_LIBRARY_DIR \
    COMPXLIB.VCS_COMPILED_LIBRARY_DIR \
    ENABLE_RESOURCE_ESTIMATION \
    INCREMENTAL_CHECKPOINT \
    IP_CACHE_PERMISSIONS \
    IP.USER_FILES_DIR \
    NEEDS_REFRESH \
    PART \
    REPORT_STRATEGY \
    SIM.IP.AUTO_EXPORT_SCRIPTS \
    SIM.IPSTATIC.SOURCE_DIR \
    STEPS.WRITE_DEVICE_IMAGE.ARGS.READBACK_FILE \
    STEPS.WRITE_DEVICE_IMAGE.ARGS.VERBOSE \
    STEPS.WRITE_BITSTREAM.ARGS.READBACK_FILE \
    STEPS.WRITE_BITSTREAM.ARGS.VERBOSE \
    STEPS.SYNTH_DESIGN.TCL.PRE \
    STEPS.SYNTH_DESIGN.TCL.POST \
    STEPS.WRITE_BITSTREAM.TCL.PRE \
    STEPS.WRITE_BITSTREAM.TCL.POST \
    STEPS.WRITE_DEVICE_IMAGE.TCL.PRE \
    STEPS.WRITE_DEVICE_IMAGE.TCL.POST \
    STEPS.INIT_DESIGN.TCL.POST \
    STEPS.ROUTE_DESIGN.TCL.POST \
    XPM_LIBRARIES \
  ]

  set HOG_GENERICS [ list GLOBAL_DATE \
    GLOBAL_TIME \
    FLAVOUR \
  ]

  #filling defaultConfDict and projConfDict
  foreach proj_run [list [current_project] [get_runs synth_1] [get_runs impl_1] [current_fileset]] {
    #creating dictionary for each $run
    set projRunDict [dict create]
    set defaultRunDict [dict create]
    #selecting only READ/WRITE properties
    set run_props [list]
    foreach propReport [split "[report_property  -return_string -all $proj_run]" "\n"] {
      if {[string equal "[lindex $propReport 2]" "false"]} {
        lappend run_props [lindex $propReport 0]
      }
    }
    # Append BOARD_PART_REPO_PATHS since it is not in given by report_property...
    if {$proj_run == [current_project]} {
      lappend run_props "BOARD_PART_REPO_PATHS"
    }
    
    foreach prop $run_props {
      #ignoring properties in $PROP_BAN_LIST
      if {$prop in $PROP_BAN_LIST} {
        set tmp  0
        #Msg Info "Skipping property $prop"
      } elseif { "$proj_run" == "[current_fileset]" } {
        # For current fileset extract only generics
        if {$prop == "GENERIC"} {
          foreach generic [get_property $prop [current_fileset]] {
            set generic_prop_value [split $generic {=}]
            if {[llength $generic_prop_value] == 2} {
              if {[string toupper [lindex $generic_prop_value 0]] in $HOG_GENERICS } {
                continue
              }
              dict set projRunDict [string toupper [lindex $generic_prop_value 0]] [lindex $generic_prop_value 1]
              dict set defaultRunDict [string toupper $prop] ""
            }
          } 
        }
      } else {
        #Project values
        # setting only relative paths
        if {[string first  $repo_path [get_property $prop $proj_run]] != -1} {
          dict set projRunDict [string toupper $prop] [Relative $repo_path [get_property $prop $proj_run]]
        } elseif {[string first  $ext_path [get_property $prop $proj_run]] != -1} {
          dict set projRunDict [string toupper $prop]  [Relative $ext_path [get_property $prop $proj_run]]
        } else {
          dict set projRunDict [string toupper $prop] [get_property $prop $proj_run]
        }

        # default values
        dict set defaultRunDict [string toupper $prop]  [list_property_value -default $prop $proj_run]
      }
    }
    if {"$proj_run" == "[current_project]"} {
      dict set projRunDict "PART" [get_property PART $proj_run]
      dict set projConfDict main  $projRunDict
      dict set defaultConfDict main $defaultRunDict
    } elseif {"$proj_run" == "[current_fileset]"} {
      dict set projConfDict generics  $projRunDict
      dict set defaultConfDict generics $defaultRunDict
    } else {
      dict set projConfDict $proj_run  $projRunDict
      dict set defaultConfDict $proj_run $defaultRunDict
    }
  }

  #adding default properties set by default by Hog or after project creation
  set defMainDict [dict create TARGET_LANGUAGE VHDL SIMULATOR_LANGUAGE MIXED]
  dict set defMainDict IP_OUTPUT_REPO "[Relative $repo_path $proj_dir]/${project_name}.cache/ip"
  dict set defaultConfDict main [dict merge [DictGet $defaultConfDict main] $defMainDict]

  #comparing projConfDict, defaultConfDict and hogConfDict
  set hasStrategy 0

  foreach proj_run [list main synth_1 impl_1 generics] {
    set projRunDict [DictGet $projConfDict $proj_run]
    set hogConfRunDict [DictGet $hogConfDict $proj_run]
    set defaultRunDict [DictGet $defaultConfDict $proj_run]
    set newRunDict [dict create]

    set strategy_str "STRATEGY strategy Strategy"
    foreach s $strategy_str {
      if {[dict exists $hogConfRunDict $s]} {
        set hasStrategy 1
      }
    }

    if {$hasStrategy == 1 && $options(recreate_conf) == 0} {
      Msg Warning "A strategy for run $proj_run has been defined inside hog.conf. This prevents Hog to compare the project properties. Please regenerate your hog.conf file using the dedicated Hog button."
    }

    foreach settings [dict keys $projRunDict] {
      set currset [DictGet  $projRunDict $settings]
      set hogset [DictGet  $hogConfRunDict $settings]
      set defset [DictGet  $defaultRunDict $settings]

      # Remove quotes from vivado properties
      regsub -all {\"} $currset "" currset

      if {[string toupper $currset] != [string toupper $hogset] && ([string toupper $currset] != [string toupper $defset] || $hogset != "")} {
        if {[string first "DEFAULT" [string toupper $currset]] != -1 && $hogset == ""} {
          continue
        }
        if {[string tolower $hogset] == "true" && $currset == 1} {
          continue
        }
        if {[string tolower $hogset] == "false" && $currset == 0} {
          continue
        }
        if {[regexp {\_VER$} [string toupper $settings]] || [regexp {\_SHA$} [string toupper $settings]] } {
          continue
        }

        if {[string toupper $settings] != "STRATEGY"} {
          dict set newRunDict $settings $currset
          if {$options(recreate_conf) == 1} {
            incr ConfErrorCnt
            Msg Info "$proj_run setting $settings has been changed from \"$hogset\" in hog.conf to \"$currset\" in project."
          } elseif {[file exists $repo_path/Top/$group_name/$project_name/hog.conf] && $hasStrategy == 0} {
            MsgAndLog "Project $proj_run setting $settings value \"$currset\" does not match hog.conf \"$hogset\"." "CriticalWarning" $outFile
            incr ConfErrorCnt
          }
        }
      } elseif {[string toupper $currset] == [string toupper $hogset] && [string toupper $hogset] != "" && [string toupper $settings] != "STRATEGY"} {
        dict set newRunDict $settings $currset
      }
    }
    dict set newConfDict $proj_run $newRunDict

    #if anything remains into hogConfDict it means that something is wrong
    foreach settings [dict keys $hogConfRunDict] {
      if {[dict exists $projRunDict [string toupper $settings]]==0} {
        if {$settings in $PROP_BAN_LIST} {
          Msg Warning "In hog.conf section $proj_run the following property is defined: \"$settings\". This property is ignored and will not be rewritten when automatically recreating hog.conf (i.e. pressing Hog button)."
          continue
        }
        incr ConfErrorCnt
        if {$options(recreate_conf) == 0} {
          MsgAndLog "hog.conf property $settings is not a valid Vivado property." "CriticalWarning" $outFile
        } else {
          Msg Info "found property $settings in old hog.conf. This is not a valid Vivado property and will be deleted."
        }
      }
    }
  }

  #check if the version in the she-bang is the same as the IDE version, otherwise incr ConfErrorCnt
  set actual_version [GetIDEVersion]
  if {[file exists $conf_file]} {
    lassign [GetIDEFromConf $conf_file] ide conf_version
    if {$actual_version != $conf_version} {
      MsgAndLog "The version specified in the first line of hog.conf is wrong or no version was specified. If you want to run this project with $ide $actual_version, the first line of hog.conf should be: \#$ide $actual_version" "CriticalWarning" $outFile
      incr ConfErrorCnt
    }
  }


  if {$ConfErrorCnt == 0 && [file exists $conf_file ] == 1} {
    Msg Info "$conf_file matches project. Nothing to do"
  }

  # recreating hog.conf
  if { $options(recreate_conf) == 1 && ($ConfErrorCnt > 0 || [file exists $conf_file] == 0 || $hasStrategy == 1)} {
    Msg Info "Updating configuration file $repo_path/$DirName/hog.conf."
    # writing configuration file
    set confFile $repo_path/$DirName/hog.conf
    set version [GetIDEVersion]
    WriteConf $confFile $newConfDict "vivado $version"
    
  }
 }

set sim_conf "$repo_path/Top/$group_name/$project_name/sim.conf"
# Checking simulation settings
if { $options(recreate) == 0 || $options(recreate_conf) == 1 } {
  #creating 4 dicts:
  #   - simConfDict:     sim.conf properties (if exists)
  #   - defaultConfDict: default properties
  #   - projConfDict:    current project properties
  #   - newConfDict:     "new" sim.conf
  set simConfDict [dict create]
  set defaultConfDict [dict create]
  set projConfDict [dict create]
  set newSimConfDict  [dict create]

  #filling hogConfDict
  if {[file exists $sim_conf]} {
    set simConfDict [ReadConf $sim_conf]
    # convert sim.conf dict keys to uppercase
    set simsets [dict keys $simConfDict]

    foreach simset $simsets {
      set simDict [DictGet $simConfDict $simset]
      foreach simDictKey [dict keys $simDict ] {
        #do not convert paths
        if {[string first $repo_path [DictGet $simDict $simDictKey]]!= -1} {
          continue
        }
        dict set simDict [string toupper $simDictKey] [DictGet $simDict $simDictKey]
        dict unset simDict [string tolower $simDictKey]
      }
      dict set simConfDict $simset $simDict
    }
  } elseif {$options(recreate_conf)==0} {
    Msg Warning "$repo_path/Top/$group_name/$project_name/sim.conf not found. Skipping properties check"
  }

  #filling defaultConfDict and projConfDict
  foreach proj_simset [get_filesets] {
    if {[get_property FILESET_TYPE $proj_simset] != "SimulationSrcs" } {
      continue
    }
    #creating dictionary for each simset
    set projSimDict [dict create]
    set defaultSimDict [dict create]
    #selecting only READ/WRITE properties
    set sim_props [list]
    foreach propReport [split "[report_property  -return_string -all [get_filesets $proj_simset]]" "\n"] {

      if {[string equal "[lindex $propReport 2]" "false"]} {
        lappend sim_props [lindex $propReport 0]
      }
    }

    foreach prop $sim_props {
      if {$prop == "HBS.CONFIGURE_DESIGN_FOR_HIER_ACCESS"} {
        continue
      }

      #Project values
      # setting only relative paths
      if {[string first  $repo_path [get_property $prop $proj_simset]] != -1} {
        dict set projSimDict [string toupper $prop] [Relative $repo_path [get_property $prop $proj_simset]]
      } elseif {[string first  $ext_path [get_property $prop $proj_simset]] != -1} {
        dict set projSimDict [string toupper $prop]  [Relative $ext_path [get_property $prop $proj_simset]]
      } else {
        dict set projSimDict [string toupper $prop] [get_property $prop $proj_simset]
      }

      # default values
      dict set defaultSimDict [string toupper $prop]  [list_property_value -default $prop $proj_simset]
      dict set projConfDict $proj_simset  $projSimDict
      dict set defaultConfDict $proj_simset $defaultSimDict
    }
  }

  foreach simset [get_filesets -quiet] {
    if {[get_property FILESET_TYPE $simset] != "SimulationSrcs" } {            
      continue
    }
    set hogConfSimDict [DictGet $simConfDict $simset]
    set hogAllSimDict [DictGet $simConfDict sim]
    set hogGenericsSimDict [DictGet $simConfDict generics]
    set newSimDict [dict create]
    set newGenericsDict [dict create]
    set projSimDict [DictGet $projConfDict $simset]
    set defaultRunDict [DictGet $defaultConfDict $simset]

    foreach setting [dict keys $projSimDict] {
      set currset [DictGet $projSimDict $setting]
      set hogset [DictGet $hogConfSimDict $setting]
      set allhogset [DictGet $hogAllSimDict $setting]
      set defset [DictGet $defaultRunDict $setting]

      if {[string toupper $setting] == "GENERIC"} {
        # Check the generics section of the sim.conf
        foreach gen_set $currset {
          set generic_and_value [split $gen_set =]
          set generic [string toupper [lindex $generic_and_value 0]]
          set gen_value [lindex $generic_and_value 1]
          set generichogset [DictGet $hogGenericsSimDict $generic ]

          # Remove quotes from vivado properties
          regsub -all {\"} $gen_value "" gen_value
          dict set newGenericsDict $generic $gen_value
          if { $gen_value != $generichogset} {
            if {$options(recreate_conf) == 1} {
              incr SimConfErrorCnt
              Msg Info "$simset generics setting $generic has been changed from \"$generichogset\" in sim.conf to \"$gen_value\" in project."
            } elseif {[file exists $sim_conf]} {
              MsgAndLog "Simset $simset setting $generic value \"$gen_value\" does not match sim.conf \"$generichogset\"." "Warning" $outSimFile
              incr SimConfErrorCnt
            }
          }
        }
        continue
      }

      if {[string toupper $currset] != [string toupper $hogset] && [string toupper $currset] != [string toupper $defset] && [string toupper $currset] != [string toupper $allhogset]} {
        if {[string first "DEFAULT" [string toupper $currset]] != -1 && $hogset == "" && $allhogset == ""} {
          continue
        }
        if {[string tolower $hogset] == "true" && $currset == 1} {
          continue
        }
        if {[string tolower $hogset] == "false" && $currset == 0} {
          continue
        }
        if {[string tolower $allhogset] == "true" && $currset == 1} {
          continue
        }
        if {[string tolower $allhogset] == "false" && $currset == 0} {
          continue
        }
        if {[regexp {^[^\.]*\.[^\.]*$} $setting]} {
          continue
        }

        dict set newSimDict $setting $currset
        if {$options(recreate_conf) == 1} {
          incr SimConfErrorCnt
          Msg Info "$simset setting $setting has been changed from \"$hogset\" (\"$allhogset\") in sim.conf to \"$currset\" in project."
        } elseif {[file exists $sim_conf]} {
          MsgAndLog "Simset $simset setting $setting value \"$currset\" does not match sim.conf \"$hogset\" (\"$allhogset\")." "Warning" $outSimFile
          incr SimConfErrorCnt
        }
      } elseif {[string toupper $currset] == [string toupper $hogset] && [string toupper $hogset] != ""} {
        dict set newSimDict $setting $currset
      } elseif {[string toupper $currset] == [string toupper $allhogset] && [string toupper $allhogset] != ""} {
        dict set newSimDict $setting $currset
      }
      # Check if this is the active simulation set
      if {$simset == [current_fileset -simset]} {
        dict set newSimDict "ACTIVE" "1" 
      }
    }
    dict set newSimConfDict $simset $newSimDict
    dict set newSimConfDict generics $newGenericsDict

    #if anything remains into hogConfDict it means that something is wrong
    foreach setting [dict keys $hogConfSimDict] {
      set hogset [DictGet $hogConfSimDict $setting]
      if {$setting == "ACTIVE"} {
        if {$hogset == "1" && $simset != [current_fileset -simset]} {
          incr SimConfErrorCnt
          if {$options(recreate_conf) == 0} {
            MsgAndLog "Simulation set $simset is set as active, but the actual active one in the project is [current_fileset -simset]" "Warning" $outSimFile
          } else {
            Msg Info "Simulation set $simset was set as active in old sim.conf. I will set [current_fileset -simset] as active in the file instead."
          }
        }
        continue
      }

      # ignore settings for other simulators
      set other_sim_prop 0 
      foreach simulator [GetSimulators] {
        if {[string toupper $simulator] != [string toupper [get_property target_simulator [current_project]]]} {
          if {[string first [string toupper $simulator] [string toupper $setting]] == 0} {
            set other_sim_prop 1
            break
          }
        }
      }

      if {$other_sim_prop == 1} {
        continue
      }

      if {[dict exists $projSimDict [string toupper $setting]]==0 && [dict exists $projSimDict $setting]==0} {
        incr SimConfErrorCnt
        if {$options(recreate_conf) == 0} {
          MsgAndLog "sim.conf property $setting is not a valid Vivado property." "Warning" $outSimFile
        } else {
          Msg Info "Found property $setting in old sim.conf. This is not a valid Vivado property and will be deleted."
        }
      }
    }
  }

  if {$SimConfErrorCnt == 0 && [file exists $sim_conf ] == 1} {
    Msg Info "$sim_conf matches project. Nothing to do"
  }

  #recreating hog.conf
  if {$options(recreate_conf) == 1 && $SimConfErrorCnt > 0 } {
    Msg Info "Updating configuration file $sim_conf"
    file mkdir  $repo_path/$DirName/list
    #writing configuration file
    set confFile $repo_path/$DirName/sim.conf
    set version [GetIDEVersion]
    WriteConf $confFile $newSimConfDict
  }
}



#closing project if a new one was opened
if {![string equal $options(project) ""]} {
  if {[IsVivado]} {
    close_project
  }
}


set TotErrorCnt [expr {$ConfErrorCnt + $SrcListErrorCnt + $ConListErrorCnt}]

if {$options(recreate_conf) == 0 && $options(recreate) == 0} {
  if {$options(pedantic) == 1 && $TotErrorCnt > 0} {
    Msg Error "Number of errors: $TotErrorCnt. (Design List files = [expr $SrcListErrorCnt + $ConListErrorCnt], hog.conf = $ConfErrorCnt)."
  } elseif {$TotErrorCnt > 0} {
    Msg CriticalWarning "Number of errors: $TotErrorCnt (Design List files = [expr $SrcListErrorCnt + $ConListErrorCnt], hog.conf = $ConfErrorCnt)."
  } else {
    Msg Info "Design List files and hog.conf match project. All ok!"
  }

  if { $SimListErrorCnt > 0 } {
    Msg Warning "Number of mismatch in simulation list files = $SimListErrorCnt"
  } else {
    Msg Info "Simulation list files match project. All ok!"
  }

  if { $SimConfErrorCnt > 0 } {
    Msg Warning "Number of mismatch in simulation conf files = $SimConfErrorCnt"
  } else {
    Msg Info "Simulation config files match project. All ok!"
  }
}



Msg Info "All done."

return $TotErrorCnt
