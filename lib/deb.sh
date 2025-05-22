_sk-deb-changelog-tests(){
  current_dir=`pwd`
  local test_base_dir=/tmp/_sk-deb-changelog-tests.${USER}
  rm -Rf $test_base_dir || true

  sk-print-break '########################################' 2

  mkdir -p ${test_base_dir}/case1/debian

echo "nginx (1.18.0-3ubuntu1+focal2) focal; urgency=medium

  * Resync with Debian and Ubuntu merge from Debian

 -- Thomas Ward <teward@ubuntu.com>  Mon, 06 Jul 2020 11:00:31 -0400
"> ${test_base_dir}/case1/debian/changelog


  cd ${test_base_dir}/case1/
  echo `pwd`
  echo "sk-deb-changelog"
  sk-deb-changelog

  echo "ORIGINAL: nginx (1.18.0-3ubuntu1+focal2) focal; urgency=medium"
  head -n1 ${test_base_dir}/case1/debian/changelog

  sk-print-break '########################################' 2

  mkdir -p ${test_base_dir}/case2/debian

echo "nginx (4.3-14ubuntu1.3) focal; urgency=medium

  * Resync with Debian and Ubuntu merge from Debian

 -- Thomas Ward <teward@ubuntu.com>  Mon, 06 Jul 2020 11:00:31 -0400
"> ${test_base_dir}/case2/debian/changelog

  cd ${test_base_dir}/case2/
  echo `pwd`
  echo "sk-deb-changelog"
  sk-deb-changelog

  echo "ORIGINAL: nginx (4.3-14ubuntu1.3) focal; urgency=medium"
  head -n1 ${test_base_dir}/case2/debian/changelog

  sk-print-break '########################################' 2

  mkdir -p ${test_base_dir}/case3/debian

echo "nginx (4.3-14ubuntu1.3) focal; urgency=medium

  * Resync with Debian and Ubuntu merge from Debian

 -- Thomas Ward <teward@ubuntu.com>  Mon, 06 Jul 2020 11:00:31 -0400
"> ${test_base_dir}/case3/debian/changelog

  cd ${test_base_dir}/case3/

  echo `pwd`
  echo "sk-deb-changelog --version 2.4.0-2"
  sk-deb-changelog --version 2.4.0-2

  echo "ORIGINAL: nginx (4.3-14ubuntu1.3) focal; urgency=medium"
  head -n1 ${test_base_dir}/case3/debian/changelog

  cd $current_dir
  echo ""
}

sk-deb-changelog(){
  local version='unset'

  sk_help "Usage: $FUNCNAME  Bump the version in a debian changelog

    Use cases:
      case 1: backport from newer distro with alpha codename in its version
      Version: 1.18.0-3ubuntu1+focal2

      case 2: backport from a distro with no codename add a tilde identifier
      Version: 4.3-14ubuntu1.3

      case 3: add a specific version ignoring the current version
      Version 2.4.0-2

    -v  --version) explicitly set the version
  " "$@" && return
  while : ; do
    case ${1-default} in
      -v  | --version) version=$2; shift 2;;
      --) shift ; break ;;
      -*) echo "WARN: Unknown option (ignored): $1" >&2 ; shift ;;
      *)  break ;;
    esac
  done

  # NOTE: dch with no prompt not supported on older distros
  dpkg-parsechangelog > /tmp/$$.current-changelog
  eval `perl -n -e'/^(\w+): (\S+)$/ && print "$1=$2\n"' /tmp/$$.current-changelog`

  # Source: pglogical
  # Version: 2.4.0-1.pgdg20.04+1ubuntu1
  # Distribution: xenial
  # Urgency: medium
  # Maintainer: Wibble
  # Date: Wed, 17 Nov 2021 14:32:09 +0000
  # Changes:
  #  pglogical (2.4.0-1.pgdg20.04+1ubuntu1) xenial-backports; urgency=medium

  # backporting from a newer distro
  # case 1
  if [[ "$Distribution" != "$DISTRIB_CODENAME" ]];then
    if grep -q $Distribution <<< $(echo $Version);then
      export Distribution=$Distribution
      export DISTRIB_CODENAME=$DISTRIB_CODENAME
      # replace with our current distro
      Version=$(echo $Version | perl -p -e 's/$ENV{'Distribution'}/$ENV{'DISTRIB_CODENAME'}/')
    fi
  fi

  # case 3
  if [[ "$version" != 'unset' ]];then
    Version=$version
  else
    Version=$(sk-maths-inc-last $Version)
  fi

  # case 2
  # no distro tag in version add a tilde tag on
  if ! grep -q $DISTRIB_CODENAME <<< $(echo $Version);then
    Version="${Version}~$DISTRIB_CODENAME"
  fi



cat << EOF > /tmp/$$.backport-changelog
$Source (${Version}) $DISTRIB_CODENAME; urgency=low

  * $FUNCNAME $package backporting $1

 -- $USER <$USER@$(hostname -f)>  $(date -R)

EOF

  cat debian/changelog >> /tmp/$$.backport-changelog
  mv -f /tmp/$$.backport-changelog debian/changelog
  rm /tmp/$$.current-changelog

}

sk-deb-compat-for-distro(){
  sk_help "Usage: $FUNCNAME Update a Debian compat file to the maximum supported by a distro" "$@" && return
  case $DISTRIB_CODENAME in
    sarge) max_compat=4 ;;
    *) max_compat=7 ;;
  esac
  dpkg-checkbuilddeps && return
  [ -e debian/compat ] && [ ! -z "$max_compat" ] && echo $max_compat > debian/compat
  perl -pi -e "s/debhelper \(>= \d+\)/debhelper (>= $max_compat)/" debian/control
}

sk-deb-cleanup-repo(){
  sk_help "Usage: $FUNCNAME <package>. Cleanup packages uploaded " "$@" && return
  local package=$1
  local basedir="/opt/upload"
  local upload_dir="${basedir}/${package}/${DISTRIB_CODENAME}"
  echo_log_run_logoutput ssh $REPO_HOST "rm -Rf ${upload_dir}"
}

sk-deb-build-dep(){
  sk_help "Usage: $FUNCNAME <package> install a source package dependencies via a meta package for flexibility." "$@" && return 1
  [ -d debian ] || ( echo "Must run in a package dir" && return )
  sk-pack-install equivs-build -p equivs
  echo_log_run_logoutput mk-build-deps
  echo_log_run_logoutput sudo dpkg -i *build-deps*.deb
  echo_log_run_logoutput rm -f *build-deps*.deb
  echo_log_run_logoutput sudo apt-get -y -f install


  check_builddeps_result=$(dpkg-checkbuilddeps | perl -pe '/dpkg-checkbuilddeps: error: Unmet build dependencies://' | perl -pe 's/(\(.*\))//' )


#   for dependency in $check_builddeps_result;do
#     sudo apt-get install -y $dependency
#   done
# 

  sudo apt-get install -y $check_builddeps_result
}

sk-deb-backport-upload(){
  sk_help_noarg "Usage: $FUNCNAME

    Upload a package that has beenbackported already and lives in a local dir

    -p | --package) package to backport

 " "$@" && return 1

  local package=bash  backport_codename=bionic noupdate=0 current_dir=`pwd` upload=0 runner_file='unset' nocleanup=0 custom_source='' custom_source_contents='' ignore_errors=0

  while : ; do
    case ${1-default} in
      -p | --package) package=$2 ; shift 2 ;;
      --) shift ; break ;;
      -*) echo "WARN: Unknown option (ignored): $1" >&2 ; shift ;;
      *)  break ;;
    esac
  done

  local package_dir="/var/tmp/sk-deb-backport-package-${package}.${USER}"
  sk-nexus-uploaddir -f $package_dir
}

sk-deb-parse(){
  sk_help_noarg "Usage: $FUNCNAME <deb file>. Parse the deb files info and initialize variable from it like Version " "$@" && return 1
  local deb_file=${1:-default}
  sk-pack-install dpkg
  dpkg-deb -f $deb_file > /tmp/$(basename $deb_file).parsed
  eval `perl -n -e'/^(\w+): (\S+)$/ && print "$1=$2\n"' /tmp/$(basename $deb_file).parsed`
  rm /tmp/$(basename $deb_file).parsed
}

sk-deb-distribution(){
  sk_help_noarg "Usage: $FUNCNAME <deb file>. Extract the distribution from a deb files changelog" "$@" && return 1
  local deb_file=${1:-default} parsed_distro=''
  sk-pack-install dpkg
  if parsed_distro=$(dpkg --fsys-tarfile $deb_file  | sk-tar xOf - --wildcards ./usr/share/doc/*/changelog.Debian.gz | zcat | sk-head -n1 | awk '{print $3}' | tr -d ';') ;then
    # strip any variation like pgdg or security off
    echo $parsed_distro | sed 's/-.*//'
  else
    echo ${DISTRIB_CODENAME}
  fi
}

sk-deb-backport-package(){
  sk_help_noarg "Usage: $FUNCNAME

    Rebuild a package for the current distro. Optionally dont update sources list

    -p | --package) package to backport
    -d | --distro) distro to backport from
    -n | --noupdate) dont tinker with apt source list
    -u | --upload) upload the package to nexus
    -r | --runner_file) custom
    -i | --ignore_errors) build with -d

 " "$@" && return 1

  local version='unset' package=bash  backport_codename=bionic noupdate=0 current_dir=`pwd` upload=0 runner_file='unset' custom_source='' custom_source_contents='' ignore_errors=0

  while : ; do
    case ${1-default} in
      -p | --package) package=$2 ; shift 2 ;;
      -d | --distro) backport_codename=$2 ; shift 2 ;;
      -n | --noupdate) noupdate=1 ; shift  ;;
      -i | --ignore_errors) ignore_errors=1 ; shift  ;;
      -u | --upload) upload=1; shift ;;
      -r | --runner_file) runner_file=$2; shift 2;;
      -C | --custom_source) custom_source=$2; shift 2;;
      -CC | --custom_source_contents) custom_source_contents=$2; shift 2;;
      -v  | --version) version=$2; shift 2;;
      --) shift ; break ;;
      -*) echo "WARN: Unknown option (ignored): $1" >&2 ; shift ;;
      *)  break ;;
    esac
  done

  sk-pack-install dpkg-source -p dpkg-dev
  # unpacking sources
  sk-pack-install debuild -p devscripts
  # unused but allows for distro validation
  sk-pack-install null --file /usr/share/perl5/Debian/DistroInfo.pm  -p libdistro-info-perl

  local tmp_dir="/var/tmp/sk-deb-backport-build-${package}.${USER}" package_dir="/var/tmp/sk-deb-backport-package-${package}.${USER}"

  [[ -d "$tmp_dir" ]] && rm -Rf $tmp_dir

  mkdir $tmp_dir
  cd $tmp_dir

  # configure apt

  if [[ -z "$custom_source" ]];then
    sk-apt-add-distro-source $backport_codename /etc/apt/sources.list.d/$backport_codename
    [[ "$noupdate" -eq 0 ]] && sk-apt-update-repos /etc/apt/sources.list.d/$backport_codename
    # source package
    sk-apt-source-from-repo $package /etc/apt/sources.list.d/$backport_codename || return

  else
    sk-apt-add-custom-source $custom_source "$custom_source_contents"
    sk-apt-update-repos $custom_source
    sk-apt-source-from-repo $package $custom_source
  fi

  expanded_package_dir=$tmp_dir/$(ls -d */|head -n 1)
  cd $expanded_package_dir

  echo `pwd`
  sk-deb-build-dep

  # prepare package for backport build and upload
  echo `pwd`

  if [[ "$version" != 'unset' ]];then
    sk-deb-changelog --version $version
  else
    sk-deb-changelog
  fi
  echo `pwd`
  sk-deb-compat-for-distro

  # run some custom commands
  [[ $runner_file != 'unset' ]] && $runner_file

  echo_log "Building $package package..."

  if [[ "$ignore_errors" -eq 1 ]];then
    debuild -b -d | tee $tmp_dir/build.log
  else
    # -b allows for modifications to the package source files
    debuild -b | tee $tmp_dir/build.log
  fi
  build_exit_code=$?

  if [[ ! "$build_exit_code" -eq 0 ]] && [[ "$ignore_errors" -eq 0 ]];then
    echo "FATAL: build failed with $build_exit_code"
    return
  fi

  rm -Rf $package_dir
  mkdir $package_dir

  cd $tmp_dir
  mv *.deb $package_dir/

  cd $package_dir

  [[ $upload -eq 1 ]] && sk-deb-backport-upload -p ${package}

  echo "packages are in $package_dir"

  cd $current_dir
}
