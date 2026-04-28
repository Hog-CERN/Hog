
#namespace eval Hog {
#}


# Returns the tdict of project -> conf for all Projects in the repository
#
# @param[in] repo_path  The main path of the git repository
proc GetProjectsConf {{repo_path .} } {
  set top_path [file normalize $repo_path/Top]
  set confs [findFiles [file normalize $top_path] hog.conf]
  set confs [lsort $confs]
  set g ""

  set ret [dict create]

  foreach c $confs {
    set p [Relative $top_path [file dirname $c]]
    dict set ret $p $c
  }
  return $ret
}