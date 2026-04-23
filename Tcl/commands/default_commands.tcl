
set ::hog_commands {
  LIST {
    aliases {L LI}
    description "List the projects in the repository. To show hidden projects use the -all option"
    options {
        {all     "List all projects, including test projects."}
    }
    script {
        Msg Status "\n** The projects in this repository are:"
        if {[Context::Get launcher options all]} {
            ListProjects [Context::Get launcher settings repo_path] 1
        } else {
            ListProjects [Context::Get launcher settings repo_path] 0 1
        }
        Msg Status "\n"
        puts "[tobj tojson [Context::GetObj settings] -pretty]"
        exit 0
    }
  }
}
