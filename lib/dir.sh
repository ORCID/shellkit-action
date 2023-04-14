sk-dir-make(){
  local dir_name=$1
  if [[ ! -d "$dir_name" ]];then
    if ! mkdir -p $dir_name; then
      echo_log "Can't make dir: $dir_name"
      return 1
    fi
  fi
}
