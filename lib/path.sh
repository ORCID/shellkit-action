sk-path-add-distro-arch(){
  sk_help "<path>. Adjust the path environment var prepending paths so they are used in preference" "$@" && return
  dir=${1:-./}
  arch=`uname -m | tr '[:upper:]' '[:lower:]'`
  [ "$arch" = "amd64" ] && arch=x86_64
  distro=`uname -s | tr '[:upper:]' '[:lower:]'`
  sk-path-prepend "$1/${distro}-${arch}"
}

sk-path-prepend() {
  sk_help "<path>. Adjust the path environment var prepending paths so they are used in preference" "$@" && return
  local path=$1 escaped_path=$(sk-trans-escape $1)
  if ! grep -Eq "(^|:)$escaped_path($|:)" <<< $(echo "$PATH") ; then
    PATH="$path:$PATH"
  fi
}

sk-path-postpend() {
  sk_help "<path>. Adjust the path environment var postpending paths so they are used when others aren't availiable" "$@" && return
  local path=$1 escaped_path=$(sk-trans-escape $1)
  if ! grep -Eq "(^|:)$escaped_path($|:)" <<< $(echo "$PATH") ; then
    PATH="$PATH:$escaped_path"
  fi
}

sk-env-path-postpend() {
  sk_help "USAGE: PATH=\$(sk-env-path-postpend \"\$PATH\" /wibble1 /wibble2 ) .Postpend paths that exist and aren't already set onto an environment variable that is a : separated list. NOTE: this function returns the result and you must set and export the environment variable from it." "$@" && return
  # Add paths to a variables
  # Usage PATH=`sk-paths-add "$PATH" "/blbabla"`
  local env_value; env_value=${1:-unset}; shift
  for p in $@; do
    # skip paths that don't exist
    [ -e "$p" ] || continue
    case "${env_value}" in
      *:$p|*:$p:*|$p:*|$p) continue;;
    esac
    # postpend our values unless we're initializing and new variable
    if [[ "$env_value" ]];then
      env_value=":${env_value}"
    fi
    env_value="${p}${env_value}"
  done
  echo "$env_value"
}

