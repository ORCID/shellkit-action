
sk-pack-distro-from-file(){
  sk_help_noarg "Usage: $FUNCNAME <package>. Extract a backported distro from a package filename .e.g. nginx-module-lengthhiding_1.18.0-3ubuntu1+focal2_amd64.deb " "$@" && return 1
  echo $1 | perl -ne '/[\~|\+](.*)_/ && print $1'  | tr -d '[:digit:]'
}


sk-pack-install() {
  local binary=${1:-true}
  if command -v $binary &>/dev/null;then
    return
  fi
  shift
  sk_help "
    Usage: $FUNCNAME <binary_to_check_for>

    Description:
      Wrapper around upt rust universal package installer to install packages from various sources until a specific binary exists on a users path
        -p| --package) package to install if it's name is different from the binary
        -a| --ppa ) ppa mode
        -o| --repoform ) gem, run (curl with bash), download (curl --output <binary> <repo>) , npm
        -r| --repo ) repository to use for ppa say
        -v| --version ) set a version to install
        -d| --dir ) test for a directory if a package does not have a binary
        -f| --file ) test for a file if a package does not have a binary

    Example: sk-pack-install hatop --repo ppa:vshn/hatop --ppa


    Options:
    "  "$@" && return 1

  local ppa=0 package_type='' repo='' repoform='' package=$binary version='' dir='unset' file='unset' post_install='' npm='unset' sudo_cmd=''

  while :
  do
    case ${1-default} in
        -p | --package)   package=$2; shift 2 ;;
        -pi | --post_install)   post_install=$2; shift 2 ;;
        -a | --ppa )   ppa=1; shift ;;
        -o | --repoform ) repoform=$2; shift 2 ;;
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

  if [[ ! -z $post_install ]];then
    $post_install || true
  fi

  if [[ "$PLATFORM" == 'Darwin' ]];then
    # have a failback to check for package installations on macos
    [[ -d /usr/local/Cellar/$package ]] && return
  fi

  if [[ "$dir" != 'unset' ]];then
    if [[ -d "$dir" ]];then
      return
    fi
  fi

  if [[ "$file" != 'unset' ]];then
    if [[ -f "$file" ]];then
      return
    fi
  fi



  log "Bootstraping ${package} as ${binary} was not found"
  local version_cmd=''
  [[ "$version" ]] && version_cmd="-v $version"

  if [[ "$PLATFORM" != 'Darwin' ]];then
    sudo_cmd='sudo'
  fi

  if [[ "$ppa" -eq 1 ]] && [[ "$PLATFORM" = 'Linux' ]];then
    [ ! "$(which add-apt-repository)" ] && sudo apt-get --quiet -y install python-software-properties
    sudo add-apt-repository -y $repo && sudo apt-get --quiet --quiet update
  fi

  case $repoform in
    download)
      curl --output $binary $repo
    ;;
    gem)
      $sudo_cmd gem install $package $version_cmd
    ;;
    npm)
      # FIXME: allow ver to be configurable
      sk-asdf-install npm -p nodejs -v 18.7.0
      npm install --prefix ~ $package@$version
    ;;

    run)
      curl -s $repo | sudo bash
    ;;
    *)
      sk-asdf-install upt -p upt -v 0.3.0 --silent --plugin_git_url https://github.com/ORCID/asdf-upt.git
      if [[ "$PLATFORM" = 'Darwin' ]];then
        upt install -y $package
      else
        sudo -E $(which upt) install -y $package 2>/dev/null 1>&2
      fi
    ;;
  esac

}

sk-pack-fpm(){

  usage(){
    echo "Helper around fpm to add some defaults and parse a parameter --dir and work our settings based on the name.

        Args:-
        -s ) type (dir)
        -t ) output (deb)
        -v ) version (1)
        -n ) name (basename of --dir)
        -a ) arch (uname -m)
        --dir) full path to a file or directory to make into a package
    "
  }
  local type=dir; local dir=/tmp/wibble; local arch=`uname -m`; local version=1

  if [[ -f /etc/debian_version ]];then
    local output="deb"; local codename=`lsb_release -c | awk '{print $2}'`; local separator='~'
  fi

  if [[ -f /etc/redhat-release ]];then
    local output="rpm"; local codename=`lsb_release -r | awk '{print $2}'`; local separator='.'
  fi

  if [[ -f /usr/sbin/up2date-nox ]];then
    local output="rpm"; local codename=`lsb_release -r | awk '{print $2}'`; local separator='.'
  fi

  while :
  do
    case ${1-default} in
        -s ) type=$2; shift 2 ;;
        -t ) output=$2; shift 2 ;;
        -v ) version=$2; shift 2 ;;
        -n ) name=$2; shift 2 ;;
        -a ) arch=$2; shift 2 ;;
        --dir ) dir=$2; shift 2 ;;
        --help ) usage; return;  shift ;;
        --) shift ; break ;;
        -*) echo "WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done

  [ -z $name ] && local name=`basename $dir`

# FIXME: add features here..

cat << EOF > /tmp/after-install.sh
pwd
EOF

  # add some more search paths to find fpm on
  export PATH=$PATH:/var/lib/gems/1.8/bin/:/usr/local/bin

  sk-pack-install fpm -f gem -v 1.6.2

  fpm -s $type -t $output -m blar -n $name -v $version -a $arch --description 'sk-pack-fpm' --deb-no-default-config-files --exclude */build/tmp --after-install /tmp/after-install.sh "$dir"

}


sk-pack-cpan2deb(){
  #Create perl CPAN deb package

  PRODUCT=$1
  TAG=$2
  export DEB_BUILD_OPTIONS=nocheck

  if [[ "$TAG" == "trunk" ]];then
      echo "export code"
      svn export ${SVNROOT}/main/${PRODUCT}/${TAG} ${PRODUCT}_1
      echo "build without running tests (tests run by jenkins)"
      dh-make-perl --build ${PRODUCT}_1
      dh-make-perl refresh ${PRODUCT}_1
      dh-make-perl --build ${PRODUCT}_1
  else
      echo "export code"
      svn export ${SVNROOT}/main/${PRODUCT}/tags/${TAG} $TAG
      echo "build without running tests (tests run by jenkins)"
      dh-make-perl --build $TAG
      dh-make-perl refresh $TAG
      dh-make-perl --build $TAG
  fi
}

sk-pack-cpan2rpm(){
  #Create perl CPAN rpm package

  PRODUCT=$1
  TAG=$2
  VERSION=$3
  echo "setup rpm environment"
  cpan2rpm --mk-rpm-dirs=~/rpm

  echo "setup build environment"
  cd
  mkdir packages
  cd packages

  if [[ "$TAG" == "trunk" ]];then
      echo "export code"
      svn export ${SVNROOT}/main/${PRODUCT}/${TAG} $TAG
      tar zcf ${TAG}.tar.gz ${TAG}
      cpan2rpm --author blar --version ${VERSION} --no-sign --make-no-test ${TAG}.tar.gz
  else
      echo "export code"
      svn export ${SVNROOT}/main/${PRODUCT}/tags/${TAG} $TAG
      tar zcf ${TAG}.tar.gz ${TAG}
      cpan2rpm --author blar --version ${VERSION} --no-sign --make-no-test ${TAG}.tar.gz
  fi

}

sk-pack-distid-from-package(){
  echo $1 | grep -qEe '.deb$' && distid=debian || distid=redhat
}

sk-pack-arch-from-package(){
  if echo $1 | grep -qEe '86.rpm$';then
    arch=i386
  else
    arch=$(echo $1 | perl -ne '/.(\w+)\.rpm$/ && print $1')
  fi
}

sk-pack-add-package-to-repo(){
  local packagefile=$1
  sk-pack-distid-from-package $packagefile
  sk-pack-arch-from-package $packagefile
  if [[ $distid = 'debian' ]];then
    repo_dir=${repo_base}/${environment}/${distid}
    echo "reprepro -b $repo_dir includedeb $distcodename $packagefile"
    sudo su $repo_user -c "reprepro -b $repo_dir includedeb $distcodename $packagefile"
  else
    repo_dir=${repo_base}/${environment}/${distid}/${distcodename}/os/$arch
    echo "cp $packagefile $repo_dir ; createrepo $repo_dir"
    sudo su $repo_user -c "cp $packagefile $repo_dir ; createrepo $repo_dir"
  fi
}

sk-pack-import-packages(){
  sk_help_noarg "Usage: $FUNCNAME <package>. Add a package in /opt/import/<package>/<distro>/<debfile> to local repository" "$@" && return 1
  local packagename=$1
  upload_base=/opt/upload
  repo_base=/opt/slotr/repo
  repo_user=hudson
  environment_list='dev test prod'
  for packagefile in $(find ${upload_base}/$packagename/ -type f);do
    distcodename=$(dirname $packagefile | perl -ne '/(\w+)$/ && print $1')
    for environment in $environment_list;do
      sk-pack-add-package-to-repo $packagefile $distcodename
    done
  done
}



