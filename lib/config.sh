#
# functions for sourcing in config files from a selection of locations
#

sk-config-read(){
  local profile='' config_found='' vars=unused fail_on_missing_config=0
  sk_help "Usage: $FUNCNAME. -c <config_filename>

    Look for a config file based on an order:-

      ENV variables
      Config file(s) first one found. based on:-
      1: ./
      2: home dir including .<config_filename>
      3: /etc/
      4: /etc/config_file_no_extension_or_dot/

    and source that config file for any BASH variables

    Options:
        -c | --config_file ) config file name (e.g .artifact.conf)
        -p | --profile ) TODO add ini file support
        -V | --vars ) comma separated list of variables to check for
        -f | --fail_on_missing_config ) fail if the config file is missing
" "$@" && return

  while :
  do
    case ${1-default} in
        -c | --config_file ) local config_file=$2 ; shift 2;;
        -p | --profile ) local profile=$2 ; shift 2;;
        -V | --vars ) local vars=$2 ; shift 2;;
        -f | --fail_on_missing_config ) local fail_on_missing_config=1 ; shift ;;
        --verbose )        VERBOSE=$((VERBOSE+1)); shift ;;
        *)  break ;;
    esac
  done

  undotted_file="${config_file#.}"
  config_base="${undotted_file%.*}"
  config_list="./$config_file ~/.$config_file ~/$config_file /etc/$config_file /etc/$config_base/$config_file"

  if config_found=$(_sk-config-selector $config_list);then
    source $config_found 2> /dev/null
  elif [[ "$fail_on_missing_config" -eq 1 ]];then
    echo_log "FATAL missing config from $config_list"
    return 1
  fi

  if [[ "$vars" != 'unused' ]];then
    var_list=$(sk-trans-comma-to-space $vars)
    # record our current setting
    backup_set_state=$-
    # allow unset variables
    set +u
    for var in $var_list;do
      argument=$(eval "echo \$$var")
      if [[ -z "$argument" ]] ;then
        echo "You must provide envvar or in a config file $var"
        set -$backup_set_state
        return 1
      fi
    done

    set -$backup_set_state 2>/dev/null
  fi

}

_sk-config-selector(){
  sk_help "Usage: $FUNCNAME. [list of files] Return the filename of the first file that exists on the local fs a secondary function must source this config

  e.g

  if config_file=\$(_sk-config-selector pd.conf ~/.pd.conf /etc/pd.conf);then
    source \$config_file
  fi

  ideally use the sk-config-read function

  " "$@" && return
  for file in $@;do
    # expand any tidle pathpath
    eval file=$file
    # check for readable file
    if [[ -r "$file" ]];then
      echo $file
      return 0
    fi
  done
  echo_log "INFO: missing config in $@ failing to envvars"
  return 1
}

sk-config-show-paths(){
  local profile='' config_found=''
  sk_help "Usage: $FUNCNAME. -c <config_filename>

    Show config preference order:-

      ENV variables
      Config file(s) first one found. based on:-
      1: current dir
      2: home dir
      3: /etc/
      4: /etc/config_file_no_extension_or_dot/

    Options:
        -c | --config_file ) config file name (e.g .artifact.conf)
        -p | --profile ) TODO add ini file support
        -V | --vars ) TODO add support for checking for variable existance
" "$@" && return

  while :
  do
    case ${1-default} in
        -c | --config_file ) local config_file=$2 ; shift 2;;
        -p | --profile ) local profile=$2 ; shift 2;;
        -V | --vars ) local vars=$2 ; shift 2;;
        --verbose )        VERBOSE=$((VERBOSE+1)); shift ;;
        --nogit )          nogit=1; shift ;;
        *)  break ;;
    esac
  done

  undotted_file="${config_file#.}"
  config_base="${undotted_file%.*}"

  config_list="./$config_file ~/$config_file ~/.$config_file /etc/$config_file /etc/$config_base/$config_file"
  echo $config_list

}



