sk-tmp-userdir(){
  local age='' create=1 id=${FUNCNAME[1]:-sk-tmp} base=/var/tmp remove=0
  sk_help "Usage: $FUNCNAME create a tmp dir ($base/$id.$USER)
      -r | --remove) remove tmp dir
      -a | --age) cleanup before create if older than X days
      -i | --id)  unique id to pass in default is the calling function name
      -b | --base) base dir to use ($base) which lasts between reboots
" "$@" && return 1

  while :
  do
    case ${1-default} in
      -r | --remove) remove=1 ; shift ;;
      -a | --age) age=$2 ; shift 2 ;;
      -i | --id) id=$2 ; shift 2 ;;
      -b | --base) age=base ; shift 2 ;;
      --) shift ; break ;;
      -*) echo "WARN: Unknown option (ignored): $1" >&2 ; shift ;;
      *)  break ;;
    esac
  done

  dir="${base}/${id}.${USER}"

  if [[ -d "$dir" ]];then
    # basic protection against different user creating the tmpdir
    if [[ ! "$(sk-file-stat-user "$dir")" == "$USER" ]];then
      sk-logger-args-stdout "CRITICAL: $dir not owned by $USER"
      return 1
    fi
    # cleanup dir if it's older than a certain age
    if [[ ! -z "$age" ]];then
      find $dir -mtime +$age | xargs rm -rf || true
    fi
  fi

  if [[ ! -d "$dir" ]] && [[ "$create" -eq 1 ]];then
    mkdir -p $dir
  fi

  if [[ -d "$dir" ]] && [[ "$remove" -eq 1 ]];then
    rmdir $dir
  fi

  echo $dir

}

sk-tmp-test(){
  sk-tmp
}
