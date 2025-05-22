sk-template-bash() {
  sk_help_noarg "$FUNCNAME: filename. Render a template file containing bash variables. NOTE: escape any quotes." "$@" && return
  eval "echo \"$(cat $1)\""
}

