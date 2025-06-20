sk-dir-make-read-write(){
  local dir_name=$1
  if [[ ! -d "$dir_name" ]];then
    mkdir -p $dir_name 2>/dev/null || sudo mkdir -p $dir_name
    chmod 777 $dir_name 2>/dev/null || sudo chmod 777 $dir_name
  fi
}

sk-dir-make(){
  local dir_name=$1
  if [[ ! -d "$dir_name" ]];then
    if ! mkdir -p $dir_name; then
      echo_log "Can't make dir: $dir_name"
      return 1
    fi
  fi
}

sk-dir-perm-list(){
    sk_help "Usage: $FUNCNAME <targetdir>(/.) function to output the permissions and ownership of directories. useful to compare the config of 2 different servers" "$@" && return
  target_dir=${1:-/.}
  current_dir=`pwd`
  cd $target_dir
  # echo cd $target_dir
  # echo `pwd`

  if [[ "$PLATFORM" == 'Darwin' ]];then
    gfind . \( -path ./proc \
      -o -path ./sys \
      -o -path ./snap \
      -o -path ./etc/.git \
      -o -path ./var/tmp \
      -o -path ./var/cache \
      -o -path ./usr/src \
      -o -path ./usr/lib/modules \
      -o -path ./home \
      -o -path ./tmp \
      -o -path ./usr/share/doc \
       \) -prune -o -name '*' -type d -exec gstat --format='%n %A %U %G' {} \; | sort
  else
    find . \( -path ./proc \
      -o -path ./sys \
      -o -path ./snap \
      -o -path ./etc/.git \
      -o -path ./var/tmp \
      -o -path ./var/cache \
      -o -path ./usr/src \
      -o -path ./usr/lib/modules \
      -o -path ./home \
      -o -path ./tmp \
      -o -path ./usr/share/doc \
       \) -prune -o -name '*' -type d -exec stat --format='%n %A %U %G' {} \; | sort
  fi
  cd $current_dir
}

