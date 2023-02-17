################################################################################
#
# /etc/shellkit/shellkit.sh
#
################################################################################
# This file standardizes shellkits environment if it's run as a cronjob or a non bash shell

# dash compatible tests
case "$SHELL" in
  */bash)
    shopt -s extglob
    # rm !(*.html|*.txt) # remove everything except html and txt files

    if [ "${BASH_VERSINFO:-0}" -lt 4 ];then
      echo "WARN: bash > 4 required for shellkit; on a mac install with brew install bash"
      return 0
    fi

  ;;
  */zsh)
    BASH_SOURCE=${(%):-%x}
  ;;
  *)
    # handle scripts called by cronjobs where SHELL=/bin/sh but the running script uses bash
    RUNNING_SHELL=$(ps h -p $$ -o args='' | cut -f1 -d' ')
    if ! echo "$RUNNING_SHELL" | grep -E '(bash|zsh)' >/dev/null ;then
      echo "WARN: unsupported shell"
      return 1
    fi
  ;;
esac

#
# Editor
#

export EDITOR=vim
export VISUAL=$EDITOR
export SUDO_EDITOR=$EDITOR
export LESS=-iMR


#
# Standardize between zsh and bash
#

# http://zsh.sourceforge.net/Doc/Release/Parameters.html
# https://tldp.org/LDP/abs/html/internalvariables.html
OSTYPE=${OSTYPE:-$(uname|tr "[:upper:]" "[:lower:]")}
ID_LIKE=unknown
DISTRIB_ID=default
case $OSTYPE in
  linux-gnu*)
    PLATFORM=Linux
    [[ -f "/etc/lsb-release" ]] && source /etc/lsb-release
    [[ -f "/etc/os-release" ]] && source /etc/os-release
  ;;
  darwin*)
    PLATFORM=Darwin
    DISTRIB_RELEASE="$(sw_vers -productVersion)"
    DISTRIB_CODENAME="$(sed -nE '/SOFTWARE LICENSE AGREEMENT FOR/s/([A-Za-z]+ ){5}|\\$//gp' /System/Library/CoreServices/Setup\ Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf | perl -ne '/macOS (.*)/ && print $1')"
    DISTRIB_ID="$DISTRIB_CODENAME"
  ;;
  cygwin*)
    PLATFORM=Windows
    DISTRIB_RELEASE=1
    DISTRIB_CODENAME=unknown
  ;;
  msys*)
    PLATFORM=Windows
    DISTRIB_RELEASE=1
    DISTRIB_CODENAME=unknown
  ;;
  win32*)
    PLATFORM=Windows
    DISTRIB_RELEASE=1
    DISTRIB_CODENAME=unknown
  ;;
  freebsd*)
    PLATFORM=Bsd
    DISTRIB_RELEASE=1
    DISTRIB_CODENAME=unknown
  ;;
  *)
    PLATFORM=Linux
    [[ -f "/etc/lsb-release" ]] && source /etc/lsb-release
    [[ -f "/etc/os-release" ]] && source /etc/os-release
  ;;
esac
export DISTRIB_RELEASE=$DISTRIB_RELEASE
export DISTRIB_ID=$DISTRIB_ID
export DISTRIB_CODENAME=$DISTRIB_CODENAME
export PLATFORM=$PLATFORM
export ARCH=$(uname -m)

# not available on zsh
HOSTNAME=${HOSTNAME:-$(hostname)}
export HOSTNAME=$HOSTNAME

# not available in cron
USER=${USER:-$(whoami)}
export USER=$USER

HOME=${HOME:-$(ls -d ~/)}
export HOME=$HOME

#
# Source shellkit libraries
#

export SHELLKIT_DEV_MODE=${SHELLKIT_DEV_MODE-0}

# Use the full path of this sourced file to work out the base shellkit directory and lib dir
# so we can then source the individual libs


# ${BASH_SOURCE[0]} (or, more simply, $BASH_SOURCE[1] ) contains the (potentially relative) path of the containing script in all invocation scenarios, notably also when the script is sourced, which is not true for $0.
SHELLKIT_DIR=$(echo "${BASH_SOURCE[0]}" | sed 's/profile.d\/shellkit.sh//')
# edge case when sourced in project
if [[ "$SHELLKIT_DIR" = '' ]];then
  SHELLKIT_DIR='./'
  source ${SHELLKIT_DIR}/conf/conf.sh
fi
SHELLKIT_LIB_DIR="${SHELLKIT_DIR}lib"

# always try to source a global set of conf
[[ -f /etc/shellkit/conf.sh ]] && . /etc/shellkit/conf.sh

# some projects use a local checkout of shellkit that we don't want overriding unless dev mode is active
if [[ "$SHELLKIT_DIR" =~ "shellkit_local" ]] && [[ "$SHELLKIT_DEV_MODE" -eq 0 ]];then
  echo "INFO: using $SHELLKIT_DIR"
else
  # if we have code in our home directory prefer this
  for shellkit_override_dir in ~/work/shellkit ~/shellkit;do
    if [[ -d $shellkit_override_dir ]];then
      echo "INFO: using $shellkit_override_dir"
      SHELLKIT_DIR="${shellkit_override_dir}"
      SHELLKIT_LIB_DIR="${shellkit_override_dir}/lib"
      . ${SHELLKIT_DIR}/conf/conf.sh
      break
    fi
  done
fi

export VERBOSE=0
for i in "$SHELLKIT_LIB_DIR"/*.sh; do
  [[ -r "$i" ]] && source "$i"
done
unset i

#
# PATH
#

# add shellkit to our path and adjust our path to add some key paths
# also bring path setup inline if we're running cron

if [[ ! -d $HOME/node_modules/.bin ]];then
  mkdir -p $HOME/node_modules/.bin
fi

PATH=`sk-env-path-postpend "$PATH" \
  $(sk-file-readlink $SHELLKIT_DIR/bin) \
  $HOME/node_modules/.bin \
  /sbin \
  /usr/sbin \
  /usr/bin \
  /opt/local/bin \
  /opt/local/sbin \
  /usr/local/bin \
  /usr/local/sbin \
  /usr/local/lib/nagios/plugins \
  $HOME/bin \
  $HOME/sbin \
`
export PATH

# this adds ~/.asdf/shims to the path to allow us to use asdf binaries
source ${SHELLKIT_DIR}/asdf/asdf.sh

