sk-env-postpend-path() {
  sk_help_noarg "Usage: PATH=\$($FUNCNAME \$PATH /path /path2). Add paths to an environment variable like \$PATH. Only add if the paths exist and don't already exist " "$@" && return
  # first arg is the variable we're going to manipulate
  local env_var=$1; shift
  # loop over all the remaining arguments
  for env_path in $@; do

    # does the path exist?
    [ -e "$env_path" ] || continue

    # is the path already in the env_var?
    case "${env_var}" in
      *:$env_path|*:$env_path:*|$env_path:*|$env_path) continue;;
    esac

    # if not then postpend
    [ -z "$env_var" ] || env_var=":${env_var}"
    env_var="${env_path}${env_var}"
  done

  # return the final result to be assigned to the variable
  echo "$env_var"
}

