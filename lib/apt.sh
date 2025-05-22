sk-apt-rmadison(){
  sk_help "$FUNCNAME: package. Search multiple distro versions for a package" "$@" && return
  sk-pack-install rmadison -p devscripts
  rmadison $@
}

sk-apt-versions(){
  local package=${1:-docker}
  apt-cache madison $package
}

sk-dpkg-sort-size() {
  dpkg-query -W --showformat='${Installed-Size;10}\t${Package}\n' | sort -k1,1nr
}

sk-apt-key-add() {
  sk_help "$FUNCNAME: <key>(pgdg default). Add a missing apt key" "$@" && return
  key=${1:-7FCC7D46ACCC4CF8}
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $key
}


sk-apt-distupgrade-prep(){
  sk_help "$FUNCNAME: Prep for a distupgrade by upgrading current release to latest packages. Pass in -f to force upgrade with no prompts." "$@" && return
  local force=$1
  echo "Prepping OS for upgrade"
  [ "$force" ] || confirm "This will potentially break the distribution, have you taken backups?" || return 1
  sudo apt-get update
  sudo  DEBIAN_FRONTEND=noninteractive apt-get -y -q -o 'DPkg::Options::=--force-confold' upgrade
  sudo apt-get clean all
}

sk-apt-distupgrade-post(){
  sk_help "$FUNCNAME: Cleanup after a dist-upgrade. Pass in -f to force upgrade with no prompts." "$@" && return
  local force=$1
  echo "Checking edge cases after upgrade"
  [ "$force" ] || confirm "This will potentially break the distribution, have you taken backups?" || return 1
  sudo apt-get -y -q autoremove
  if ! grep -q open-vm-dkms <<< $(dpkg -l) ;then
    sudo apt-get -y install open-vm-dkms
  fi

  echo "Running kernel: `uname -va`"
  echo "Installed kernels: `dpkg -l | grep linux`"
  echo "Next bootup kernel: `cat /boot/grub/menu.lst | grep default`"
  echo "`cat /boot/grub/menu.lst | grep title | grep Ubuntu`"
  echo "Ensure you are booting up with the latest kernel if not selected"
  echo "Testing logrotate"
  sudo logrotate /etc/logrotate.conf
  [ "$force" ] || confirm "Perform reboot?" || return 1
  sudo shutdown -r now
}


# https://www.queryxchange.com/q/3_658047/ubuntu-8-04-lts-upgrade-to-10-04-python-problem-39-with-39-will-become-a-reserved-keyword-in-python-2-6/
# http://askubuntu.com/questions/719465/why-does-do-release-upgrade-skip-a-version
sk-apt-distupgrade-manual(){
  sk_help_noarg "$FUNCNAME: <LTS RELEASE TO UPGRADE TO> <-f (force)>. Upgrade a system using dist-upgrade NOT do-release-upgrade due to it's limitations of selecting the lts version to upgrade to." "$@" && return
  local upgrade_distro=$1
  local force=$2
  sk-apt-distupgrade-prep $force
  current_distro=$(lsb_release -c | awk '{print $2}')
  sudo perl -pi -e "s/${current_distro}/${upgrade_distro}/g" /etc/apt/sources.list /etc/apt/sources.list.d/*.list
  sudo apt-get update
  sudo env DEBIAN_FRONTEND=noninteractive apt-get -y -q -o 'DPkg::Options::=--force-confold' dist-upgrade &
  while [ $(lsof /var/lib/dpkg/lock >> /dev/null;) ];do sleep 2;done
  sk-apt-distupgrade-post $force
}





sk-apt-support-eol(){
  sk_help "Usage: $FUNCNAME. Migrate an EOL Ubuntu server to the old-releases apt repo. This should be a last resort as we should be upgrading them. Use when OS and code dependencies exist that block an upgrade." "$@" && return
  sudo perl -pi -e 's/us-east-1\.ec2\.archive\.ubuntu\.com/old-releases\.ubuntu\.com/g' /etc/apt/sources.list
  sudo perl -pi -e 's/gb\.archive\.ubuntu\.com/old-releases\.ubuntu\.com/g' /etc/apt/sources.list
  sudo perl -pi -e 's/security\.ubuntu\.com/old-releases\.ubuntu\.com/g' /etc/apt/sources.list
  sudo perl -pi -e 's/deb-src.*$//g' /etc/apt/sources.list
  sudo apt-get clean all
  sudo apt-get update
}

sk-apt-purge-sources(){
  sk_help "$FUNCNAME . Clean out any src lines from /etc/apt/sources.list" "$@" && return
  sudo perl -pi -e 's/deb-src.*//g' /etc/apt/sources.list
}

sk-apt-add-custom-source(){
  sk_help_noarg "$FUNCNAME <filename_of_source> (/etc/apt/sources.list.d/wibble.conf) <line to add> Add /etc/apt/sources.list.d/<listname>.list" "$@" && return
  local source_filename=$1
  shift
  if [[ ! -f "$source_filename" ]];then
    sudo bash -c "echo $@ > $source_filename"
  fi
}

sk-apt-add-distro-source(){
  sk_help_noarg "$FUNCNAME <distro> <listname>.  Add /etc/apt/sources.list.d/<listname>.list" "$@" && return
  local distribution=$1
  local listfile=${2:-/etc/apt/sources.list.d/$distribution}

  # sources.list format: deb uri distribution [component1] [component2] [...]
  [ ! -d /etc/apt/sources.list.d ] && sudo mkdir /etc/apt/sources.list.d

  # start with a new file
  sudo rm -f $listfile

  lsbdistid=$(lsb_release -i | awk '{print $3}')
  case $lsbdistid in
    Ubuntu) local components="main restricted universe multiverse";;
    Debian) local components="main contrib non-free";;
    *) local components="main restricted universe multiverse";;
  esac

  local distribution_list="$distribution ${distribution}-updates ${distribution}-backports"
  echo $distribution_list
  case $distribution in
    lucid)      local uri_list="http://old-releases.ubuntu.com/ubuntu/";;
    *)          local uri_list="http://gb.archive.ubuntu.com/ubuntu/ http://security.ubuntu.com/ubuntu";;
  esac

  for uri in $uri_list;do
    grep -q security <<< $(echo "$uri") && distribution_list="${distribution}-security"
    for distribution_name in $distribution_list;do
      sudo bash -c "echo 'deb-src $uri $distribution_name $components' >> $listfile"
    done
  done

}
sk-apt-update-repos(){
  sk_help_noarg "$FUNCNAME <listnames> Update multiple listnames (/etc/apt/sources.list.d/wibble). Avoiding lengthy update of /etc/apt/sources.list " "$@" && return
  for source in "$@"; do
    sudo apt-get update -o Dir::Etc::sourcelist="${source}" \
      -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
  done
}

sk-apt-source-from-repo(){
  sk_help_noarg "$FUNCNAME <package> <listname>. Source package from listname <listname>(/etc/apt/sources.list.d/wibble) . Avoiding lengthy update of /etc/apt/sources.list " "$@" && return
  apt-get source $1 -o Dir::Etc::sourcelist="$2" \
      -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
}



