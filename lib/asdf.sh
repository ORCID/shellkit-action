sk-asdf-search(){
  asdf plugin list all
}

# function for virtualenvs specifically for asdf installed pythons
sk-asdf-python-venv-create(){
  local requirements=requirements.txt venv_name=wibble venv_path=./ current_pwd=$PWD
  sk_help_noarg "
    Usage: $FUNCNAME -n wibble

    Description: setup a python virtualenv using a asdf python

    Options:

        -p | --path)  ($venv_path)
        -n | --name)  ($venv_name)

    "  "$@" && return 1

  while :
  do
    case ${1-default} in
        -r | --requirements)  requirements_file=$2; shift 2 ;;
        -p | --path)  venv_path=$2; shift 2 ;;
        -n | --name)  venv_name=$2; shift 2 ;;
        --verbose )   VERBOSE=$((VERBOSE+1)); shift ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done

  if ! _sk-asdf-python-test;then
    echo "FATAL: python is not from asdf: $(which python)"
  fi

  cd $venv_path
  python -m venv $venv_name
  cd $current_pwd
}

sk-asdf-python-venv-activate(){

  local requirements=requirements.txt venv_name=wibble venv_path=./

  sk_help_noarg "
    Usage: $FUNCNAME -n wibble

    Description: activate a python virtualenv using a asdf python

    Options:

        -p | --path)  ($venv_path)
        -n | --name)  ($venv_name)

    "  "$@" && return 1

  while :
  do
    case ${1-default} in
        -r | --requirements)  requirements_file=$2; shift 2 ;;
        -p | --path)  venv_path=$2; shift 2 ;;
        -n | --name)  venv_name=$2; shift 2 ;;
        --verbose )   VERBOSE=$((VERBOSE+1)); shift ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done

  if ! _sk-asdf-python-test;then
    echo "FATAL: python is not from asdf: $(which python)"
  fi


  source $venv_path/$venv_name/bin/activate

}

_sk-asdf-python-test(){
  # readlink is need if were in a venv to link to the source python
  if python_current=$(grep -q asdf <<< sk-file-readlink $(which python) ) ;then
    return 0
  else
    return 1
  fi
}

sk-asdf-python-venv-install(){

  local requirements_file=requirements.txt venv_name=wibble venv_path=./ pip_requirements_file=pip-requirements.txt build_requirements_file=build-requirements-$DISTRIB_ID.txt

  sk_help_noarg "
    Usage: $FUNCNAME -n wibble

    Description: install pips into a python virtualenv using a asdf python. Optionally setup the pip wheel setuptools versions first and install packages needed for the build

    Options:
        -p | --path)  ($venv_path)
        -n | --name)  ($venv_name)
        -r | --requirements)  ($requirements_file)
        -P | --pip_requirements)  ($pip_requirements_file)
        -b | --build_requirements)  ($build_requirements_file)
    "  "$@" && return 1

  while :
  do
    case ${1-default} in
        -r | --requirements)  requirements_file=$2; shift 2 ;;
        -p | --path)  venv_path=$2; shift 2 ;;
        -n | --name)  venv_name=$2; shift 2 ;;
        -P | --pip_requirements)  pip_requirements_file=$2; shift 2 ;;
        -b | --build_requirements)  build_requirements_file=$2; shift 2 ;;
        --verbose )   VERBOSE=$((VERBOSE+1)); shift ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done

  if ! _sk-asdf-python-test;then
    echo "FATAL: python is not from asdf: $(which python)"
  fi


  if [[ -f "$build_requirements_file" ]];then
    echo_log "install packages via $build_requirements_file"
    while read -r line;do
      local package=$(echo $line | awk '{print $1}')
      local file_to_check=$(echo $line | awk '{print $2}')

      sk-pack-install $package -p $package -f $file_to_check

    # skip comments and blank lines
    done < <(cat $build_requirements_file | grep -v '#' | grep -ve '^$' )
    echo "---------------------------------------"
  fi

  if [[ -f "$pip_requirements_file" ]];then
    echo_log "install pip requirements via $pip_requirements_file"
    cat $pip_requirements_file | grep -v '#' | xargs pip install --upgrade
    echo "---------------------------------------"
  fi

  # hack to install requirements in an order, if we need that?
  cat $requirements_file | grep -v '#' | xargs pip install --ignore-installed

}

sk-asdf-install-tool-versions(){

  if [[ -r .tool-versions ]];then

    while read -r line;do
      plugin='unset'
      program=$(echo $line | awk '{print $1}')
      version=$(echo $line | awk '{print $2}')
      plugin=$(echo $line | awk '{print $3}')
      echo $program
      echo $version
      echo $plugin

      if [[ $plugin = 'unset' ]];then
        echo "sk-asdf-install $program -p $program -v $version"
        sk-asdf-install "$program" -p "$program" -v "$version"
      else
        echo "sk-asdf-install $program -p $program -v $version -ug $plugin"
        sk-asdf-install "$program" -p "$program" -v "$version" -ug "$plugin"
      fi
      # skip comments and blank lines
    done < <(cat .tool-versions | grep -v '#' | grep -ve '^$' )

  else
    echo "Missing .tool-versions file"
    return 1
  fi

}

sk-asdf-uninstall-tool-versions(){

  if [[ -r .tool-versions ]];then

    while read -r line;do
      program=$(echo $line | awk -F "=" '{print $1}')
      version=$(echo $line | awk -F "=" '{print $2}')
      echo $program
      echo $version

      echo "asdf uninstall $program $version"
      asdf uninstall "$program" "$version"

      # skip comments and blank lines
    done < <(cat .tool-versions | grep -v '#' | grep -ve '^$' )

  else
    echo "Missing .tool-versions file"
    return 1
  fi

}

sk-asdf-install(){
  local binary=${1:-true}
  shift

  sk_help_noarg "
    Usage: $FUNCNAME <binary_to_check_for>

    Description:
      wrapper around asdf to auto install plugins too
        -p| --package) package to install if it's name is different from the binary
        -r| --repo ) repository to use for ppa say
        -v| --version ) set a version to install
        -d| --dir ) test for a directory if a package does not have a binary
        -f| --file ) test for a file if a package does not have a binary
        -u | --plugin)  if plugin and package are different
        -ug | --plugin_git_url)  https url to github asdf plugin
        -s | --silent ) enable silent mode so nothing is output during the install

    Example:


    Options:
    "  "$@" && return 1

  local ppa=0 package_type='' repo='' repoform='' package=$binary version=latest dir='unset' file='unset' post_install='' plugin_git_url='' plugin='' silent=0

  while :
  do
    case ${1-default} in
        -p | --package)  package=$2; plugin=$package; shift 2 ;;
        -u | --plugin)   plugin=$2; shift 2 ;;
        -ug | --plugin_git_url)   plugin_git_url=$2; shift 2 ;;
        -r | --repo )  repo=$2; shift 2 ;;
        -v | --version )  version=$2; shift 2 ;;
        -d | --dir )  dir=$2; shift 2 ;;
        -f | --file )  file=$2; shift 2 ;;
        -s | --silent )  silent=1; shift  ;;
        --verbose )   VERBOSE=$((VERBOSE+1)); shift ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done

  # Nasty hack to install plugins as well
  if ! grep -q $package <<< $(asdf plugin list 2>/dev/null);then
    if [[ "$silent" -eq 1 ]]; then
      if sk-sys-is-root-no-output;then
        # FIXME: find out why we need sudo
        # this will hide the sudo prompt
        asdf plugin add ${plugin} ${plugin_git_url} >/dev/null 2>&1
      else
        # this will still show the sudo prompt and the repository initialization
        asdf plugin add ${plugin} ${plugin_git_url} >/dev/null
      fi
    else
      asdf plugin add ${plugin} ${plugin_git_url}
    fi
  fi

  # hack needed to build python
  if [[ "$ID_LIKE" = 'debian' ]] && [[ "$package" = 'python' ]] && [[ ! -f ~/.asdf-python.DONE ]] ;then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gcc make libssl-dev liblzma-dev zlib1g-dev libreadline-dev libreadline8 sqlite3 libsqlite3-dev libbz2-dev python-tk python3-tk tk-dev libffi-dev && touch ~/.asdf-python.DONE
  fi

  if [[ "$PLATFORM" == 'Darwin' ]] && [[ "$package" = 'python' ]] && [[ ! -f ~/.asdf-python.DONE ]] ;then
    sk-mac-cmdline-tools-install
  fi

  if [[ "$version" = 'latest' ]];then
    version=$(asdf latest $package)
  fi

  # install a package if it does not exist ( and handle the error) , or if it is the wrong version
  if ! grep -q $version <<< $(asdf current $package 2>/dev/null || true);then

    if [[ "$silent" -eq 1 ]]; then
      asdf install $package $version >/dev/null 2>&1
      # set the version that will be globally used by the user running asdf in ~/.tool-versions
      asdf global $package $version

    else
      asdf install $package $version
      # set the version that will be globally used by the user running asdf in ~/.tool-versions
      asdf global $package $version
    fi

  fi

}

sk-asdf-remove(){
  local binary=${1:-true}
  shift

  sk_help_noarg "
    Usage: $FUNCNAME <binary_to_check_for>

    Description:
      wrapper around asdf to auto install plugins too
        -p| --package) package to install if it's name is different from the binary
        -r| --repo ) repository to use for ppa say
        -v| --version ) set a version to install
        -d| --dir ) test for a directory if a package does not have a binary
        -f| --file ) test for a file if a package does not have a binary
        -u | --plugin)   plugin=$2; shift 2 ;;
        -ug | --plugin_git_url)   plugin_git_url=$2; shift 2 ;;

    Example:


    Options:
    "  "$@" && return 1

  local ppa=0 package_type='' repo='' repoform='' package=$binary version=latest dir='unset' file='unset' post_install='' plugin_git_url='' plugin=''

  while :
  do
    case ${1-default} in
        -p | --package)  package=$2; plugin=$package; shift 2 ;;
        -u | --plugin)   plugin=$2; shift 2 ;;
        -ug | --plugin_git_url)   plugin_git_url=$2; shift 2 ;;
        -r | --repo )  repo=$2; shift 2 ;;
        -v | --version )  version=$2; shift 2 ;;
        -d | --dir )  dir=$2; shift 2 ;;
        -f | --file )  file=$2; shift 2 ;;
        --verbose )   VERBOSE=$((VERBOSE+1)); shift ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done


  if [[ "$version" = 'latest' ]];then
    version=$(asdf latest $package)
  fi

  if ! grep -q $version <<< $(asdf current $package);then
    asdf uninstall $package $version
  fi

  # Nasty hack to remove plugins as well
  if grep -q $package <<< $(asdf plugin list);then
    asdf plugin remove $plugin
  fi

}


