sk-help-functions() {
  typeset -f | perl -ne '/^([a-z][\w_-]+) \(\)\s*\{*$/ and print "$1\n"'
}

sk-help-search (){
  sk_help_noarg "$FUNCNAME: <search string>. Search over bash functions" "$@" && return
  local search=${1:-*}
  local profile_dirs="$(readlink_bash ~/shellkit/lib 2>/dev/null) /opt/shellkit/lib"
  local dir=''
  for dir in $profile_dirs;do
    if test -d $dir ;then
      grep --after-context 3 "$search" $dir/*
    fi
  done
}

sk_help() {
  #
  # Print help message and return true if args contains -?-h(elp)?
  #
  local msg="$1"; shift

  case "$@" in
    *-h |*-help*|*--help*)
      case $OSTYPE in
        darwin*) printf "$msg\n" ;;
        *) echo -e "$msg" ;;
      esac
      return 0
    ;;
    *) return 1 ;;
  esac

}

sk_help_noarg() {
  #
  # Print help message and return true if args contains -?-h(elp)? or is empty
  #
  local msg="$1"; shift

  local args=""; args="$@" # zsh compatible
  [ -z "$args" ] && args="--help"

  sk_help "$msg" "$args"
}
