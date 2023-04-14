sk-arg-check() {
  # NOTE: args are a non dollar version of the variable that an arg will set
  for argument in $@;do

    # record our current setting
    backup_set_state=$-
    # allow unset variables
    set +u
    argument=$(eval "echo \$$1")
    set -$backup_set_state 2>/dev/null

    if [[ -z "$argument" ]] ;then
      echo "You must specify --$1"
      return 1
    fi
  done
}

