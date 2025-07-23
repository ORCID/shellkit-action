sk-logrotate(){
  local config_name=shellkit.$USER log_name='*.log' log_dir=/var/log
  sk_help_noarg "
    Usage: $FUNCNAME

    Description:
      Setup logrotate and install a config file to rotate $log_dir/${log_name}

        -d | --log_dir)   directory with your logs
        -l | --log_name)  name of your logs to match e.g '*.log'
        -n | --config_name)  name of your config file ($config_name)

    Options:
    "  "$@" && return 1

  while :
  do
    case ${1-default} in
        -d | --log_dir)   log_dir=$2; shift 2 ;;
        -n | --config_name)  config_name=$2; shift 2 ;;
        -l | --log_name)  log_file=$2; shift 2 ;;

        *)  break ;;
    esac
  done

  sk-pack-install -b logrotate --post_install 'brew services start logrotate'

  if [[ "$PLATFORM" = 'Darwin' ]];then

    if [[ -d /opt/homebrew/etc/logrotate.d ]];then
      logrotate_config_file=/opt/homebrew/etc/logrotate.d/${config_name}
      export LOGROTATE_CONFIG_FILE=$logrotate_config_file
      logrotate_sudo=0
    elif [[ -d /usr/local/etc/logrotate.d ]];then
      logrotate_config_file=/usr/local/etc/logrotate.d/${config_name}
      export LOGROTATE_CONFIG_FILE=$logrotate_config_file
      logrotate_sudo=0
    fi

  else
    logrotate_config_file=/etc/logrotate.d/${config_name}
    export LOGROTATE_CONFIG_FILE=$logrotate_config_file
    logrotate_sudo=1
  fi

  if [[ ! -f /var/tmp/logrotate.template.daily ]];then
    echo "
    $log_dir/*.log {
    daily
    size +${log_size:-1M}
    rotate 7
    missingok
    copytruncate
    }
    " > /var/tmp/logrotate.template.daily.$USER
fi
  if [[ ! -f "${logrotate_config_file}" ]];then
    sk-template-bash /var/tmp/logrotate.template.daily.$USER > /tmp/logrotate.$USER
    if [[ "$logrotate_sudo" -eq 1 ]];then
      sudo cp /tmp/logrotate.$USER $logrotate_config_file
    else
      cp /tmp/logrotate.$USER $logrotate_config_file
    fi
  fi

}
