
Commands::RegisterCommand LIST {
  aliases {L LI}
  description "List the projects in the repository. To show hidden projects use the -all option"
  options {
    {all     "List all projects, including test projects."}
  }
  script {
    Msg Status "\n** The projects in this repository are:"
    if {[Launcher::Get options all]} {
      ListProjects [Repo::Get repo_path] 1
    } else {
      ListProjects [Repo::Get repo_path] 2 1
    }
    Msg Status "\n"
    exit 0
  }
}

Commands::RegisterCommand CHECKPROJENV {
  aliases {CPE}
  description "Check that the environment variables needed for Hog-CI to run the chosen project are set and point to valid paths."
  requires_proj true
  options {
    {verbose "If set, launch the script in verbose mode"}
  }
  script {
    if {[Launcher::GetOr options verbose 0]} {
      setDebugMode 1
    }
    # IDE executable (vivado, quartus_sh, libero, ...) from the project's hog.conf
    set _ide [lindex [GetIDECommand [CurrentProject::Get conf_path]] 0]
    CheckEnv [CurrentProject::Get project_name] $_ide
  }
}

Commands::RegisterCommand CHECKPROJVER {
  aliases {CPV}
  description "Check the project version just before creating the HDL project in Create_Project stage. \
  The CI job will SKIP the project pipeline, if it the project has not been modified with respect to the target branch."
  requires_proj true
  options {
    {verbose "If set, launch the script in verbose mode"}
    {ext_path.arg   "" "Sets the absolute path for the external libraries."}
    {simcheck         "If set, checks also the version of the simulation files."}
    {ci_run           "If set, CheckProjVer will run only on the projects that are active in the CI's pipeline.\n\
  It requires the glab or the gh package installed."}
  }
  script {
    if {[Launcher::GetOr options verbose 0]} {
      setDebugMode 1
    }
    set _ide [lindex [GetIDECommand [CurrentProject::Get conf_path]] 0]
    set ci_run [Launcher::GetOr options ci_run 0]
    set repo_path [Repo::Get repo_path]
    cd $repo_path
    set ci_config ""
    if {$ci_run == 1} {
      # Compile YAML to get list of projects
      if {[info exists env(GITLAB_CI)] && $env(GITLAB_CI) eq "true" && [auto_execok glab] != ""} {
        # running in GitLab CI
        Msg Info "Running in the GitLab CI/CD. I will check only the active projects in the current pipeline..."
        # Tell glab the host and project explicitly: on SaaS runners the git remote
        # points to the CI gateway, which glab does not recognise as a GitLab host.
        if {[info exists env(CI_SERVER_HOST)]} {
          set env(GITLAB_HOST) $env(CI_SERVER_HOST)
        }
        if {[info exists env(CI_PROJECT_PATH)]} {
          lassign [ExecuteRet glab ci get -p $env(CI_PIPELINE_ID)] ret ci_config
        } else {
          lassign [ExecuteRet glab ci get] ret ci_config
        }
        if {$ret != 0} {
          Msg Warning "Failed to get CI config from GitLab, checking all projects instead."
          set ci_run 0
        }

        # Check if we are using the dynamic CI and set ci_run to 0 in case, so we check the version of all projects
        if {[info exists env(CI_CONFIG_PATH)]} {
          set ci_config_path $env(CI_CONFIG_PATH)
        } else {
          set ci_config_path $repo_path/.gitlab-ci.yml
        }

        if {[file exists $ci_config_path]} {
          set fh [open $ci_config_path r]
          set content [read $fh]
          close $fh
          if {[string first "hog-dynamic.yml" $content] != -1} {
            set ci_run 0
          }
        } else {
          Msg Warning "CI config file $ci_config_path not found, checking all projects instead."
          set ci_run 0
        }
      } elseif {[info exists env(GITHUB_ACTIONS)] && $env(GITHUB_ACTIONS) eq "true"} {
        # running in GitHub Actions
        set workflow_dir "$repo_path/.github/workflows"
        set ci_run 0
        foreach workflow_file [glob -nocomplain -directory $workflow_dir -- *.yml *.yaml] {
          set fh [open $workflow_file r]
          set content [read $fh]
          close $fh
          if {[string first "Hog-pull.yml" $content] != -1} {
            set ci_config $content
            set ci_run 1
            break
          }
        }
      } else {
        set ci_run 0
      }
    }

    set proj_to_check {}
    set project_name [CurrentProject::Get project_name]

    if {$project_name eq ""} {
      set projects [ListProjects $repo_path 1 0 1]
      foreach p $projects {
        if {$ci_run == 0 || ($ci_run == 1 && [string first $p $ci_config] != -1)} {
          if {[CheckProjVer $repo_path $p [Launcher::GetOr options simcheck 0] [Launcher::GetOr options ext_path ""]] == 0} {
            lappend proj_to_check $p
          }
        }
      }
    } else {
      if {[CheckProjVer $repo_path $project_name [Launcher::GetOr options simcheck 0] [Launcher::GetOr options ext_path ""]] == 0} {
        lappend proj_to_check $project_name
      }
    }

    set n [llength $proj_to_check]
    if {$n > 0} {
      Msg Info "The following projects were modified: \n[join $proj_to_check \n]"
    }

    Msg Info "$n projects were modified since last official version."
    exit 0
  }
}
