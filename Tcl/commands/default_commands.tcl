
set ::hog_commands {
  LIST {
    aliases {L LI}
    description "List the projects in the repository. To show hidden projects use the -all option"
    options {
        {all     "List all projects, including test projects."}
    }
    script {
        Msg Status "\n** The projects in this repository are:"
        ListProjects $repo_path 1
        Msg Status "\n"
        exit 0
    }
    requires_proj true
  }
}
