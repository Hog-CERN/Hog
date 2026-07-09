dict set Manifest commands {
  PING {
    aliases     {p}
    description "Stub tool command — prints a hello from Vivado tool scope (tclsh-side)."
    ide         vivado
    script {
      puts "pong"
    }
  }
}