#!/usr/bin/env tclsh
#   Copyright 2018-2022 The University of Birmingham
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
# Format a .tcl file

proc reformat {tclcode {pad 2}} {

  set lines [split $tclcode \n]
  set out ""
  set nquot 0   ;# count of quotes
  set ncont 0   ;# count of continued strings
  set line [lindex $lines 0]
  set indent [expr {([string length $line]-[string length [string trimleft $line \ \t]])/$pad}]
  set padst [string repeat " " $pad]
  foreach orig $lines {
    incr lineindex
    if {$lineindex>1} {append out \n}
    set newline [string trimleft $orig]
    if {$newline==""} continue
    set is_quoted $nquot
    set is_continued $ncont
    if {[string index $orig end] eq "\\"} {
      incr ncont
    } else {
      set ncont 0
    }
    if { [string index $newline 0]=="#" } {
      set line $orig   ;# don't touch comments
    } else {
      set npad [expr {$indent * $pad}]
      set line [string repeat $padst $indent]$newline
      set i [set ns [set nl [set nr [set body 0]]]]
      for {set n [string length $newline]} {$i<$n} {incr i} {
        set ch [string index $newline $i]
        if {$ch=="\\"} {
          set ns [expr {[incr ns] % 2}]
        } elseif {!$ns} {
          if {$ch=="\""} {
            set nquot [expr {[incr nquot] % 2}]
          } elseif {!$nquot} {
            switch $ch {
              "\{" {
                if {[string range $newline $i $i+2]=="\{\"\}"} {
                  incr i 2  ;# quote in braces - correct (though tricky)
                } else {
                  incr nl
                  set body -1
                }
              }
              "\}" {
                incr nr
                set body 0
              }
            }
          }
        } else {
          set ns 0
        }
      }
      set nbbraces [expr {$nl - $nr}]
      incr totalbraces $nbbraces
      if {$totalbraces<0} {
        error "Line $lineindex: unbalanced braces!"
      }
      incr indent $nbbraces
      if {$nbbraces==0} { set nbbraces $body }
      if {$is_quoted || $is_continued} {
        set line $orig     ;# don't touch quoted and continued strings
      } else {
        set np [expr {- $nbbraces * $pad}]
        if {$np>$npad} {   ;# for safety too
          set np $npad
        }
        set line [string range $line $np end]
      }
    }
    append out $line
  }
  return $out
}

proc eol {} {
  switch -- $::tcl_platform(platform) {
    windows {return \r\n}
    unix {return \n}
    macintosh {return \r}
    default {error "no such platform: $::tc_platform(platform)"}
  }
}

proc count {string char} {
  set count 0
  while {[set idx [string first $char $string]]>=0} {
    set backslashes 0
    set nidx $idx
    while {[string equal [string index $string [incr nidx -1]] \\]} {
      incr backslashes
    }
    if {$backslashes % 2 == 0} {
      incr count
    }
    set string [string range $string [incr idx] end]
  }
  return $count
}

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

set parameters {
  {tab_width.arg 2 "Width of the indentation tabs. Default: "}
}

set usage "- USAGE: $::argv0 \[OPTIONS\] <tcl_file> \n. Options:"
set old_path [pwd]
set path [file normalize "[file dirname [info script]]/.."]
source $path/hog.tcl

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] ||  [llength $argv] < 1 } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} else {
  set indent $options(tab_width)
  set f [open $argv r]
  set data [read $f]
  close $f
  set permissions [file attributes $argv -permissions]

  set filename "$argv.tmp"
  set f [open $filename  w]

  puts -nonewline $f [reformat [string map [list [eol] \n] $data] $indent]
  close $f
  file copy -force $filename  $argv
  file delete -force $filename
  file attributes $argv -permissions $permissions
}
