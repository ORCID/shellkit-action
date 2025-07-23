log(){
  sk-logger-args "$@"
}

_sk_logger_common(){
  NAME=${NAME:-shellkit}
  RUN_ID=${RUN_ID:-default}
  log_name="${LOG_NAME:-"${NAME}.log"}"

  if [[ $EUID -ne 0 ]];then
    log_dir_default="${HOME}/log"
  else
    log_dir_default=/var/log/shellkit
  fi

  log_dir=${LOG_DIR:-$log_dir_default}

  export LOG_DIR=$log_dir

  if [[ ! -d "$log_dir" ]];then
    if ! sk-dir-make $log_dir;then
      log_dir=/tmp
      export LOG_DIR=$log_dir
    fi
    # dont use logrotate if we have a date based log_dir
    year=$(date +"%Y")
    if ! grep -q $year <<< $(echo $log_dir);then
      sk-logrotate --config_name shellkit.$USER --log_dir $log_dir --log_name '*.log'
    fi
  fi
}

# Special function just for stdout to not wait on input
# exec 2> >(errout)
sk-logger-stdout(){
  _sk_logger_common

  sed "s/^/$(date  "+%b %d %H:%M:%S") $(hostname -s) ${NAME} $RUN_ID: /" | tee -a ${log_dir}/${log_name}
}

# Special function to not wait on input and log either stdout or stderr
# exec 2> >(sk-logger)
# exec 1> >(sk-logger)
sk-logger-noout(){
  _sk_logger_common

  sed "s/^/$(date  "+%b %d %H:%M:%S") $(hostname -s) ${NAME} $RUN_ID: /" | tee -a ${log_dir}/${log_name}  1>/dev/null
}


# Special function just for stderr to not wait on input
sk-logger-stderr(){
  _sk_logger_common

  sed "s/^/$(date  "+%b %d %H:%M:%S") $(hostname -s) ${NAME} $RUN_ID: /" | tee -a ${log_dir}/${log_name} >&2
}

sk-logger-stderr-keyevent(){
  _sk_logger_common

  sed "s/^/$(date  "+%b %d %H:%M:%S") $(hostname -s) ${NAME} $RUN_ID: /" | tee -a ${log_dir}/${log_name} | slacktee --channel $KEYEVENT_CHANNEL --username $(whoami)
}

#
# stdin
#

sk-logger-stdin(){
  _sk_logger_common
  input="$(cat -)"

  echo "$(date  "+%b %d %H:%M:%S") $(hostname -s) ${NAME} $RUN_ID: $input" >> ${log_dir}/${log_name}
}

sk-logger-stdin-stdout(){
  _sk_logger_common
  input="$(cat -)"

  echo "$input"
  echo "$(date  "+%b %d %H:%M:%S") $(hostname -s) ${NAME} $RUN_ID: $input" >> ${log_dir}/${log_name}
}

sk-logger-stdin-keyevent(){
  _sk_logger_common
  input="$(cat -)"

  echo "$(date  "+%b %d %H:%M:%S") $(hostname -s) ${NAME} $RUN_ID: $input" >> ${log_dir}/${log_name}
  keyevent "$input"
}

sk-logger-stdin-stdout-keyevent(){
  _sk_logger_common
  input="$(cat -)"

  echo "$input"
  echo "$(date  "+%b %d %H:%M:%S") $(hostname -s) ${NAME} $RUN_ID: $input" >> ${log_dir}/${log_name}
  keyevent "$input"
}

#
# args
#

sk-logger-args(){
  _sk_logger_common
  echo "$(date  "+%b %d %H:%M:%S") $(hostname -s) ${NAME} $RUN_ID: $@" >> ${log_dir}/${log_name}
}

sk-logger-args-stdout(){
  _sk_logger_common
  echo "$@"
  echo "$(date  "+%b %d %H:%M:%S") $(hostname -s) ${NAME} $RUN_ID: $@" >> ${log_dir}/${log_name}
}

sk-logger-args-stderr(){
  _sk_logger_common
  >&2 echo "$@"
  echo "$(date  "+%b %d %H:%M:%S") $(hostname -s) ${NAME} $RUN_ID: $@" >> ${log_dir}/${log_name}
}

sk-logger-args-stdout-keyevent(){
  _sk_logger_common
  echo "$@"
  echo "$(date  "+%b %d %H:%M:%S") $(hostname -s) ${NAME} $RUN_ID: $@" >> ${log_dir}/${log_name}
  keyevent "$@"
}

sk-logger-args-stderr-keyevent(){
  _sk_logger_common
  >&2 echo "$@"
  echo "$(date  "+%b %d %H:%M:%S") $(hostname -s) ${NAME} $RUN_ID: $@" >> ${log_dir}/${log_name}
  keyevent "$@"
}

