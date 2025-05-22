# set these in a config file
# NEXUS_URL="http://nexus.wibble.com"
# NEXUS_USER=blar
# NEXUS_PASS="password"

sk-nexus-creds(){
  sk-config-read -c .nexus.conf --vars NEXUS_URL,NEXUS_USER,NEXUS_PASS
  NEXUS_VERSION_BASE="${NEXUS_URL}/service/local/repositories"
  #NEXUS_CONTENT_BASE="${NEXUS_URL}/service/local/artifact/maven/content"
  NEXUS_CONTENT_BASE="${NEXUS_URL}/service/rest/v1/components"
  NEXUS_SEARCH_ASSETS_BASE="${NEXUS_URL}/service/rest/v1/search/assets?"
}

_sk-nexus-tmpdirs(){
  [[ -z "$USER" ]] && USER=$(whoami)
  NEXUS_DOWNLOAD_DIR="/var/tmp/nexus.$USER/download"
  NEXUS_UPLOAD_DIR="/var/tmp/nexus.$USER/upload"

  [[ -d "$NEXUS_UPLOAD_DIR" ]] || mkdir -p $NEXUS_UPLOAD_DIR
  [[ -d "$NEXUS_DOWNLOAD_DIR" ]] || mkdir -p $NEXUS_DOWNLOAD_DIR
}

# https://community.sonatype.com/t/nxrm-3-16-rest-search-and-filtering-enhancements/1586
sk-nexus-get-latest-version(){

usage(){
    I_USAGE="Usage: $FUNCNAME
        description: Search nexus ordered by version and return the first value

        options:
          -a <artifact>
          -g <groupid>
          -r <repository>(private-release)
          -t <type>(war)
          -V <version>(latest)
     "
    echo "$I_USAGE"
  }
  local artifact=blar; local groupid=com.wibble.blar; local repository=private-release; local type=war; local version=latest
  sk-nexus-creds
  sk-asdf-install jq -p jq -v 1.6

  while :
  do
    case ${1-default} in
        -a | --artifact )  artifact=$2; shift 2 ;;
        -g | --groupid )  groupid=$2; shift 2 ;;
        -r | --repository )  repository=$2; shift 2 ;;
        -t | --type )  type=$2; shift 2 ;;
        -V | --version )  version=$2; shift 2 ;;
        -v | --verbose )   VERBOSE=$((VERBOSE+1)); shift ;;
        -h | --help ) usage; return ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done

  groupid_url=$(sk-trans-dot-to-forward-slash "$groupid")

  sk-nexus-creds; _sk-nexus-tmpdirs

  search_url="${NEXUS_URL}/service/rest/v1/search/assets?repository=${repository}&group=${groupid}&name=${artifact}&maven.extension=${type}&sort=version&prerelease=false"

#  echo "curl -u $NEXUS_USER:$NEXUS_PASS -s \"$search_url\" | jq -r '.items[0].downloadUrl'"

  version=$(curl -u $NEXUS_USER:$NEXUS_PASS -s "$search_url" | jq -r '.items[0].downloadUrl' | perl -ne '/-([\d|\.]+)\.\w{3}$/ && print $1;' )

  echo "$version"


}

sk-nexus-md5(){

usage(){
    I_USAGE="Usage: $FUNCNAME
        description: Get md5 of artifact in Nexus. Returns md5 using the .md5s that nexus generates when files are uploaded. Used to validate if we need to re-download a file.

        options:
          -a <artifact>
          -g <groupid>
          -r <repository>(private-release)
          -t <type>(war)
          -V <version>(latest)
     "
    echo "$I_USAGE"
  }
  local artifact=blar; local groupid=com.wibble.blar; local repository=private-release; local type=war; local version=latest

  while :
  do
    case ${1-default} in
        -a | --artifact )  artifact=$2; shift 2 ;;
        -g | --groupid )  groupid=$2; shift 2 ;;
        -r | --repository )  repository=$2; shift 2 ;;
        -t | --type )  type=$2; shift 2 ;;
        -V | --version )  version=$2; shift 2 ;;
        -v | --verbose )   VERBOSE=$((VERBOSE+1)); shift ;;
        -h | --help ) usage; return ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done

  groupid_url=$(sk-trans-dot-to-forward-slash "$groupid")
  sk-asdf-install jq -p jq -v 1.6

  sk-nexus-creds; _sk-nexus-tmpdirs

  [ "$version" = 'latest' ] && version=$(sk-nexus-get-latest-version -a $artifact -g $groupid -r $repository)

  version="$(sk-url-encode $version)"
  search_url="${NEXUS_URL}/service/rest/v1/search/assets?repository=${repository}&group=${groupid}&name=${artifact}&version=${version}&maven.extension=${type}"

  nexus_md5=$(curl -u $NEXUS_USER:$NEXUS_PASS -s "$search_url" | jq -r '.items[].checksum.md5' )
  echo "$nexus_md5"
}

sk-nexus-md5-match(){

  local artifact=blar; local groupid=com.wibble.blar; local repository=private-release; local type=war; local version=latest ; local file='unset'

  usage(){
    I_USAGE="Usage: $FUNCNAME
        description: Compare local md5 of a file in $NEXUS_URL_DIR to a nexus md5. Return 1 exit code if the match fails

        options:
          -a <artifact>
          -g <groupid>
          -r <repository>(private-release)
          -t <type>(war)
          -V <version>(latest)
          -f --file provide a file to match ( ${NEXUS_DOWNLOAD_DIR}/$artifact-${version}.${type} )
     "
    echo "$I_USAGE"
  }

  while :
  do
    case ${1-default} in
        -a | --artifact )  artifact=$2; shift 2 ;;
        -g | --groupid )  groupid=$2; shift 2 ;;
        -r | --repository )  repository=$2; shift 2 ;;
        -t | --type )  type=$2; shift 2 ;;
        -V | --version )  version=$2; shift 2 ;;
        -v | --verbose )   VERBOSE=$((VERBOSE+1)); shift ;;
        -f | --file ) file=$2 ;shift 2 ;;
        -h | --help ) usage; return ;;

        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done
  sk-pack-install md5sum -p coreutils
  sk-asdf-install jq -p jq -v 1.6

  sk-nexus-creds; _sk-nexus-tmpdirs
  groupid_url=$(sk-trans-dot-to-forward-slash "$groupid")
  [[ "$version" = 'latest' ]] && version=$(sk-nexus-get-latest-version -a $artifact -g $groupid -r $repository)
  nexus_md5=$(sk-nexus-md5 -a $artifact -g $groupid -r $repository -t $type -V $version)

  if [[ "$file" = 'unset' ]];then
    local_file="${NEXUS_DOWNLOAD_DIR}/$artifact-${version}.${type}"
  else
    local local_file="$file"
  fi

  if [[ -f "$local_file" ]];then
    local_md5=$(md5sum $local_file | awk '{ print $1}')
    if [[ "$nexus_md5" = "$local_md5" ]];then
      return 0
    fi
  fi
  return 1
}

sk-nexus-getfile(){

  usage(){
    I_USAGE="Usage: $FUNCNAME
        description: Download file from nexus if not already downloaded. Return the path of the file

        options:
          -a <artifact>
          -g <groupid>
          -r <repository>(private-release)
          -t <type>(war)
          -V <version>(latest)
     "
    echo "$I_USAGE"
  }
  local artifact=blar; local groupid=com.wibble.blar; local repository=private-release; local type=war; local version=latest

  while :
  do
    case ${1-default} in
        -a | --artifact )    artifact=$2; shift 2 ;;
        -g | --groupid )     groupid=$2; shift 2 ;;
        -r | --repository )  repository=$2; shift 2 ;;
        -t | --type )        type=$2; shift 2 ;;
        -V | --version )     version=$2; shift 2 ;;
        -v | --verbose )     VERBOSE=$((VERBOSE+1)); shift ;;
        -h | --help ) usage; return ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done
  sk-nexus-creds; _sk-nexus-tmpdirs
  sk-asdf-install jq -p jq -v 1.6

  version="$(sk-url-encode $version)"
  groupid_url=$(sk-trans-dot-to-forward-slash "$groupid")
  [ "$version" = 'latest' ] && version=$(sk-nexus-get-latest-version -a $artifact -g $groupid -r $repository)

  search_url="${NEXUS_URL}/service/rest/v1/search/assets?repository=${repository}&group=${groupid}&name=${artifact}&version=${version}&maven.extension=${type}"

  download_url=$(curl -u $NEXUS_USER:$NEXUS_PASS -s "$search_url" | jq -r '.items[].downloadUrl')

  download_file="${NEXUS_DOWNLOAD_DIR}/$artifact-${version}.${type}"

  if ! $(sk-curl-is-up "$download_url" "-u $NEXUS_USER:$NEXUS_PASS");then
    echo_log "FATAL: download_url $download_url failed using $search_url"
    return 1
  fi

  if ! $(sk-nexus-md5-match -a $artifact -g $groupid -r $repository -t $type -V $version) && [[ ! -f "$download_file" ]];then
    log "INFO: md5 of $download_file doesn't match the file in nexus or it doesn't exist so downloading"
    curl -u $NEXUS_USER:$NEXUS_PASS -s "$download_url" -o $download_file
  fi

  echo "$download_file"
}

sk-nexus-uploadfile(){

  usage(){
    I_USAGE="Usage: $FUNCNAME
        description: Upload a file to nexus from /var/tmp/nexus/. File must be named in the format <artifact>-<version string>.<type>. NOTE: _ are not accepted as a divider

        bugs: failed uploads due to artifact being there are not caught..

        options:
          -a <artifact>
          -g <groupid>
          -r <repository>(maven repository like private-release or apt repository) detected automatically if the package contains ~distro
              (private_apt_<distro_codename>)
          -t <type>(war)
          -V <version>(latest)
          -f --upload_file <full path to file to upload>

        requirements:
          Config file
          . ~/.nexus.conf or . /etc/nexus.conf
             NEXUS_URL=http://nexus.wibble.com
             NEXUS_USER:$NEXUS_PASS=blar:password



     "
    echo "$I_USAGE"
  }
  local mime_type='war' artifact=blar; local groupid=com.wibble.blar; local repository=private-release; local type; local version=latest ; local upload_file='' local distro='' type='unset'

  while :
  do
    case ${1-default} in
        -a | --artifact )    artifact=$2; shift 2 ;;
        -g | --groupid )     groupid=$2; shift 2 ;;
        -r | --repository )  repository=$2; shift 2 ;;
        -t | --type )        type=$2; shift 2 ;;
        -V | --version )     version=$2; shift 2 ;;
        -v | --verbose )     VERBOSE=$((VERBOSE+1)); shift ;;
        -f | --upload_file ) upload_file=$2 ;shift 2 ;;
        -d | --distro )      distro_codename=$2 ;shift 2 ;;
        -h | --help ) usage; return ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done
  if ! sk-nexus-creds;then
    echo_log "FATAL: missing nexus config file"
    return
  fi
  sk-asdf-install jq -p jq -v 1.6

  _sk-nexus-tmpdirs

  groupid_url=$(sk-trans-dot-to-forward-slash "$groupid")
  upload_url="${NEXUS_CONTENT_BASE}"
  if [[ -z "$upload_file" ]];then
    upload_file="${NEXUS_UPLOAD_DIR}/${artifact}-${version}.${type}"
  else
    filename=$(basename -- "$upload_file")

    [[ -z "$artifact" ]] && artifact=$(echo $filename | perl -ne '/([\w|-]+)-\d+/ && print $1')
    [[ -z "$version" ]] &&  version=$(echo $filename | perl -ne '/([\w|-]+)-([\d|\.|\-|\w]+)\.\w{3}/ && print $2' )
  fi

  sk-asdf-install jq -p jq -v 1.6
  sk-pack-install md5sum -p coreutils

  local md5_upload_file=$(md5sum $upload_file | awk '{print $1}' )

  if [[ "$type" = unset ]];then
    type=$(sk-file-ext "$filename")
  fi

  local apt_distro=''

  if [[ "$type" == 'deb' ]];then
    sk-deb-parse $upload_file
    echo "$Version"

    if [[ "$repository" == 'private-release' ]];then
      apt_distro=$(sk-deb-distribution $upload_file)
      if [[ "$Architecture" == 'all' ]];then
        repository="private_apt_all"
      else
        repository="private_apt_${apt_distro}"
      fi

    fi

    echo_log curl --fail -u $NEXUS_USER:xxxx -X POST -H "Content-Type: multipart/form-data" --data-binary "@$upload_file" "$NEXUS_URL/repository/$repository/"
    curl --fail -u $NEXUS_USER:$NEXUS_PASS -X POST -H "Content-Type: multipart/form-data" --data-binary "@$upload_file" "$NEXUS_URL/repository/$repository/"

    return
  fi

  mime_type=$(sk-file-mime-type $upload_file)
  md5_nexus=$(sk-nexus-md5 -r $repository -a $artifact -g $groupid -t $type -V $version)

  if sk-nexus-md5-match -a $artifact -g $groupid -r $repository -t $type -V $version -f $upload_file;then
    echo_log "already in nexus"
    return
  fi

  if grep raw <<< $(echo "$repository") ;then
     echo_log curl --fail -u $NEXUS_USER:xxx -v -F  raw.asset1=@$upload_file -F raw.directory=/ -F raw.asset1.filename=$artifact-$version.$type "$upload_url?repository=$repository"
    curl --fail -u $NEXUS_USER:$NEXUS_PASS \
      -F raw.asset1=@$upload_file \
      -F raw.directory=/ \
      -F "raw.asset1.filename=$artifact-$version.$type" \
      "$upload_url?repository=$repository"
  else
    echo_log curl --fail -u $NEXUS_USER:xxx -v -F maven2.groupId=$groupid -F maven2.artifactId=$artifact -F maven2.version=$version -F maven2.asset1.extension=$type -F "maven2.asset1=@$upload_file;type='${mime_type}'" "$upload_url?repository=$repository"
    curl --fail -u $NEXUS_USER:$NEXUS_PASS -F maven2.groupId=$groupid \
      -F "maven2.artifactId=$artifact" \
      -F "maven2.version=$version" \
      -F "maven2.asset1.extension=$type" \
      -F "maven2.asset1=@$upload_file;type='${mime_type}'" \
      "$upload_url?repository=$repository"
  fi

  echo "$upload_file"
}

sk-nexus-uploaddir(){
  usage(){
    I_USAGE="Usage: $FUNCNAME
        description: Upload a directory of files to nexus. Maven files must be named in the format <artifact>-<version string>.<type>. NOTE: _ are not accepted as a divider

        options:
          -a <artifact>
          -g <groupid>
          -r <repository>
          -t <type>
          -V <version>(latest)
          -f <directory> directory of files to try and upload to nexus

        requirements:
          Config file
          . ~/.nexus.conf or . /etc/nexus.conf
             NEXUS_URL=http://nexus.wibble.com
             NEXUS_USER=blar
             NEXUS_PASS=password


     "
    echo "$I_USAGE"
  }

  local version_arg='' ; local upload_file=''

  while :
  do
    case ${1-default} in
        -a | --artifact )    artifact_arg=$2; shift 2 ;;
        -g | --groupid )     groupid_arg="-g $2" ; shift 2 ;;
        -r | --repository )  repository_arg="-r $2"; shift 2 ;;
        -t | --type )        type=$2; shift 2 ;;
        -V | --version )     version_arg="-V $2"; shift 2 ;;
        -v | --verbose )     VERBOSE=$((VERBOSE+1)); shift ;;
        -f | --upload_dir )  uploaddir=$2 ;shift 2 ;;
        -h | --help ) usage; return ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done
  sk-nexus-creds || return
  _sk-nexus-tmpdirs

  for file in `ls -1 $uploaddir/*` ;do
    verbose_run sk-nexus-uploadfile $repository_arg $groupid_arg -f $file $version_arg
  done

}

sk-nexus-list-components(){
  usage(){
    I_USAGE="Usage: $FUNCNAME
        description: nexus list compoments

        options:
          -a <artifact>
          -g <groupid>
          -r <repository>
          -t <type>
          -V <version>(latest)
          -f <directory> directory of files to try and upload to nexus
          -p | --path_id_output  return the compoment path id only

        requirements:
          Config file
          . ~/.nexus.conf or . /etc/nexus.conf
             NEXUS_URL=http://nexus.wibble.com
             NEXUS_USER=blar
             NEXUS_PASS=password
     "
    echo "$I_USAGE"
  }

  local artifact='' groupid='' repository='' type='' version='' extension_arg='' docker_registry="$DOCKER_REG_PRIVATE"
  local raw_output=0 path_id_output=0 docker_output=0

  while :
  do
    case ${1-default} in
        -a | --artifact )    artifact=$2; shift 2 ;;
        -g | --groupid )     groupid="$2" ; shift 2 ;;
        -r | --repository )  repository=$2; shift 2 ;;
        -t | --type )        extension_arg="&maven.extension=$2"; shift 2 ;;
        -V | --version )     version="$2"; shift 2 ;;
        -v | --verbose )     VERBOSE=$((VERBOSE+1)); shift ;;
        -f | --upload_dir )  uploaddir=$2 ;shift 2 ;;
        -w | --raw_output )  raw_output=1 ;shift ;;
        -p | --path_id_output ) path_id_output=1 ;shift ;;
        -d | --docker_output ) docker_output=1 ;shift ;;
        -dr | --docker_registry ) docker_registry=1 ;shift ;;

        -h | --help ) usage; return ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done
  sk-asdf-install jq -p jq -v 1.6

  sk-nexus-creds || return
  _sk-nexus-tmpdirs

  component_url="${NEXUS_URL}/service/rest/v1/components?repository=${repository}"

  echo "" > /tmp/sk-nexus-component.$USER

  component_results=$(curl -u $NEXUS_USER:$NEXUS_PASS -s "$component_url")
  echo "$component_results" >> /tmp/sk-nexus-component.$USER


  continuation_token=$(echo "$component_results" | jq -r .continuationToken 2>/dev/null)
  items=$(echo $component_results | jq -r '.items | length' 2>/dev/null | head -n 1 )

  while [[ "$items" -gt 0 ]] && [[ "$continuation_token" != 'null' ]] ;do
    component_results=$(curl -u $NEXUS_USER:$NEXUS_PASS -s "$component_url&continuationToken=$continuation_token")

    # check to see if we've run out of items
    items=$(echo "$component_results" | jq -r '.items | length' 2>/dev/null | head -n 1 )
    if [[ "$items" -gt 0 ]];then
      echo "$component_results" >> /tmp/sk-nexus-component.$USER
      # update token
      continuation_token=$(echo "$component_results" | jq -r .continuationToken 2>/dev/null)
    fi
  done

  if [[ "$path_id_output" -eq 1 ]];then
    cat /tmp/sk-nexus-component.$USER | jq -r '.items[]| .path + " " + .id + " " + .lastModified ' 2>/dev/null | sort
    return
  fi

  if [[ "$raw_output" -eq 1 ]];then
    cat /tmp/sk-nexus-component.$USER | jq -r '.items[]' 2>/dev/null
    return
  fi

  if [[ "$docker_output" -eq 1 ]];then

    export docker_registry=$docker_registry
    cat /tmp/sk-nexus-component.$USER | jq -r '.items[]| env.docker_registry + "/" + .name + ":" + .version ' 2>/dev/null | sort -V
    return
  fi

   cat /tmp/sk-nexus-component.$USER | jq -r '.items[]| .group + "," + .name + ","  + .version '
   return
}

sk-nexus-search-components(){
  usage(){
    I_USAGE="Usage: $FUNCNAME
        description: search nexus for components based on various optional filters and sorting on version

        options:
          -a <artifact>
          -g <groupid>
          -r <repository>
          -t <type>
          -V <version>(latest)
          -f <directory> directory of files to try and upload to nexus
          -p | --path_id_output  return the compoment path id only
        -w | --raw_output )  raw_output=1 ;shift ;;

        requirements:
          Config file
          . ~/.nexus.conf or . /etc/nexus.conf
             NEXUS_URL=http://nexus.wibble.com
             NEXUS_USER=blar
             NEXUS_PASS=password


     "
    echo "$I_USAGE"
  }

  local artifact='unset' groupid='unset' repository='unset' type='' version='unset' extension_arg=''
  local repository_arg='' groupid_arg='' name_arg=''

  local raw_output=0 path_id_output=0

  while :
  do
    case ${1-default} in
        -a | --artifact )    artifact=$2; shift 2 ;;
        -g | --groupid )     groupid="$2" ; shift 2 ;;
        -r | --repository )  repository=$2; shift 2 ;;
        -t | --type )        extension_arg="&maven.extension=$2"; shift 2 ;;
        -V | --version )     version="$2"; shift 2 ;;
        -v | --verbose )     VERBOSE=$((VERBOSE+1)); shift ;;
        -f | --upload_dir )  uploaddir=$2 ;shift 2 ;;
        -w | --raw_output )  raw_output=1 ;shift ;;
        -p | --path_id_output ) path_id_output=1 ;shift ;;

        -h | --help ) usage; return ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done
  sk-nexus-creds || return
  _sk-nexus-tmpdirs

  [[ "$version" != 'unset' ]] && version="$(sk-url-encode $version)"

  groupid_url=$(sk-trans-dot-to-forward-slash "$groupid")
  [ "$version" = 'latest' ] && version=$(sk-nexus-get-latest-version -a $artifact -g $groupid -r $repository)

  [[ "$repository" != 'unset' ]] && repository_arg="&repository=${repository}"
  [[ "$groupid" != 'unset' ]] && groupid_arg="&group=${repository}"
  [[ "$artifact" != 'unset' ]] && name_arg="&name=${artifact}"
  [[ "$version" != 'unset' ]] && version_arg="&version=${version}"

  search_url="${NEXUS_URL}/service/rest/v1/search?sort=version${repository_arg}${groupid_arg}${name_arg}${version_arg}${extension_arg}"

  search_tmp_file=/tmp/sk-nexus-search-components.$USER
  echo "" > $search_tmp_file

  search_results=$(curl -u $NEXUS_USER:$NEXUS_PASS -s "$search_url")
  echo "$search_results" >> $search_tmp_file
  continuation_token=$(echo "$search_results" | jq -r .continuationToken 2>/dev/null)
  items=$(echo "$search_results" | jq -r '.items | length' 2>/dev/null | head -n 1 )

  while [[ "$items" -gt 0 ]] && [[ "$continuation_token" != 'null' ]] ;do
    search_results=$(curl -u $NEXUS_USER:$NEXUS_PASS -s "$search_url&continuationToken=$continuation_token")

    # check to see if we've run out of items
    items=$(echo "$search_results" | jq -r '.items | length' 2>/dev/null | head -n 1 )
    if [[ "$items" -gt 0 ]];then
      echo "$search_results" >> $search_tmp_file
      # update token
      continuation_token=$(echo "$search_results" | jq -r .continuationToken 2>/dev/null)
    fi
  done

  if [[ "$raw_output" -eq 1 ]];then
    cat $search_tmp_file | jq -r . 2>/dev/null
    return
  fi

  # path_id_output is the default
  cat $search_tmp_file | jq -r '.items[]| .name + " " + .version + " " + .assets[0].lastModified + "         " + .id' 2>/dev/null | sort
  return

}


sk-nexus-mass-clean-components(){
  usage(){
    I_USAGE="Usage: $FUNCNAME
        description: Use the nexus search facility to delete components with 2 controls to stop components being
    deleted that might be in use:-

      1. Images must be created more than $days_keep days
      2. $versions_keep latest versions will be left out of the cleanup

        method:

          1: search for all the assets (or filtered by repo)
          2: normalize the paths of each asset to remove repo specific things
          3: cut the paths down to a unique name ( this will be each component or project we work with)
          4: Split the and sort the assets under their unique path names cutting off the first X versions
          5: test each asset to see whether it's more than X days old to see if it should be deleted

        example:-

          $FUNCNAME -r docker-hosted -z

          Assets are split into these normalized paths:-

            /xxx
            /sdfsdfds
            /sfsdfsdf
            /orcid/sdfsdf

        options:
          -a <artifact>
          -g <groupid>
          -r <repository>
          -t <type>
          -V <version>(latest)
          -f <directory> directory of files to try and upload to nexus
          -y | --days_keep) containers must have a creation date older than this number of days
          -z | --dry_run) list only matches
          -k | --versions_keep) How many versions to always keep

        requirements:
          Config file
          . ~/.nexus.conf or . /etc/nexus.conf
             NEXUS_URL=http://nexus.wibble.com
             NEXUS_USER=blar
             NEXUS_PASS=password


     "
    echo "$I_USAGE"
  }

  local artifact_arg='' groupid_arg='' repository_arg='' type_arg='' version_arg='' extension_arg=''

  local days_keep=365 versions_keep=50 dry_run=0

  local       component_path='' component_id=''  component_modified_date_time='' component_modified_sec=''
  VERBOSE=0
  while :
  do
    case ${1-default} in
        -a | --artifact )    artifact_arg="-a $2"; shift 2 ;;
        -g | --groupid )     groupid_arg="-g $2" ; shift 2 ;;
        -r | --repository )  repository_arg="-r $2"; shift 2 ;;
        -t | --type )        extension_arg="-t $2"; shift 2 ;;
        -V | --version )     version_arg="-V $2"; shift 2 ;;
        -v | --verbose )     VERBOSE=$((VERBOSE+1)); shift ;;
        -f | --upload_dir )  uploaddir=$2 ;shift 2 ;;
        -w | --raw_output )  raw_output=1 ;shift ;;
        -p | --path_id_output ) path_id_output=1 ;shift ;;
        -m | --group_by_major_version ) group_by_major_version=1 ;shift ;;
        -y | --days_keep) days_keep=$2 ; shift 2 ;;
        -k | --versions_keep) versions_keep=$2 ; shift 2 ;;
        -z | --dry_run) dry_run=1 ; shift ;;

        -h | --help ) usage; return ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done
  sk-nexus-creds || return
  _sk-nexus-tmpdirs

  sk-nexus-search-components --path_id_output $version_arg $artifact_arg $groupid_arg $extension_arg $repository_arg > /tmp/sk-nexus-search.path_id.$USER

  paths=$(cat /tmp/sk-nexus-search.path_id.$USER | sort | awk '{print $1}' | uniq )

  cutoff="$(sk-date -d -${days_keep}days '+%s')"

  verbose_log "PATHS:"
  verbose_log "$paths"

  echo "" > /tmp/sk-nexus-search.path_id.path.$USER
  while IFS=$'\n' read -r path; do
    verbose_log " "
    verbose_log "##############################################"
    verbose_log " "


    verbose_log "PATH: $path"

    # break our list of all components in a repo into unique paths and cut off a certain number of versions we always want to exclude
    # use -V, --version-sort natural sort of (version) numbers within text
    grep "$path" /tmp/sk-nexus-search.path_id.$USER | sort -V | sk-head -n -$versions_keep > /tmp/sk-nexus-search.path_id.path.$USER

    if [[ `cat /tmp/sk-nexus-search.path_id.path.$USER | wc -l` -eq 0 ]];then
      continue
    fi

    verbose_log "COMPONENTS:"
    # Process a list of components under a single path
    while IFS=$'\n' read -r component_line; do

      # parse each component line
      component_path=$(echo $component_line | awk '{ print $1,"/",$2}')
      component_modified_date_time=$(echo $component_line | awk '{ print $3}')
      component_modified_sec="$(sk-date -d "$component_modified_date_time" '+%s')"
      component_id=$(echo $component_line | awk '{ print $4}')

      verbose_log "component: $component_path "
      verbose_log "component_id: $component_id"
      verbose_log "component_modified_date_time: $component_modified_date_time"
      verbose_log "component_modified_sec: $component_modified_sec"

      if [[ "$component_modified_sec" -lt "$cutoff" ]];then

        if [[ "$dry_run" -eq 1 ]];then
          echo_log "DRY_RUN: deleting because $component_modified_date_time > ${days_keep} days old"

          echo_log "curl -X 'DELETE' -u $NEXUS_USER:$NEXUS_PASS -s \"${NEXUS_URL}/service/rest/v1/components/$component_id\" -H 'accept: application/json'"
          if [[ "$VERBOSE" -gt 1 ]];then
            echo_log "component details:-"
            curl -u $NEXUS_USER:$NEXUS_PASS -s "${NEXUS_URL}/service/rest/v1/components/$component_id" -H 'accept: application/json'
          fi
          sleep 1
        else
          verbose_log "deleting because $component_modified_date_time > ${days_keep} days old"
          verbose_log "id: $component_id"
          verbose_log "curl -u $NEXUS_USER:$NEXUS_PASS ${NEXUS_URL}/service/rest/v1/components/$component_id -H 'accept: application/json'"
          curl -X 'DELETE' -u $NEXUS_USER:$NEXUS_PASS -s "${NEXUS_URL}/service/rest/v1/components/$component_id" -H 'accept: application/json'
          sleep 1
        fi
        verbose_log "-----------------------------------"
      fi

    done <<< $(cat /tmp/sk-nexus-search.path_id.path.$USER )
  done <<< $(echo "$paths")

}

###########################################################

sk-nexus-search-assets(){
  usage(){
    I_USAGE="Usage: $FUNCNAME
        description: search nexus for assets based on various optional filters and sorting on version

        options:
          -a <artifact>
          -g <groupid>
          -r <repository>
          -t <type>
          -V <version>(latest)
          -f <directory> directory of files to try and upload to nexus
          -p | --path_id_output  return the compoment path id only

        requirements:
          Config file
          . ~/.nexus.conf or . /etc/nexus.conf
             NEXUS_URL=http://nexus.wibble.com
             NEXUS_USER=blar
             NEXUS_PASS=password


     "
    echo "$I_USAGE"
  }

  local artifact='' groupid='' repository='' type='' version='' extension_arg=''

  local raw_output=0 path_id_output=0

  while :
  do
    case ${1-default} in
        -a | --artifact )    artifact=$2; shift 2 ;;
        -g | --groupid )     groupid="$2" ; shift 2 ;;
        -r | --repository )  repository=$2; shift 2 ;;
        -t | --type )        extension_arg="&maven.extension=$2"; shift 2 ;;
        -V | --version )     version="$2"; shift 2 ;;
        -v | --verbose )     VERBOSE=$((VERBOSE+1)); shift ;;
        -f | --upload_dir )  uploaddir=$2 ;shift 2 ;;
        -w | --raw_output )  raw_output=1 ;shift ;;
        -p | --path_id_output ) path_id_output=1 ;shift ;;

        -h | --help ) usage; return ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done
  sk-nexus-creds || return
  _sk-nexus-tmpdirs

  search_url="${NEXUS_URL}/service/rest/v1/search/assets?repository=${repository}&sort=version&group=${groupid}&name=${artifact}&version=${version}${extension_arg}"

  echo "" > /tmp/sk-nexus-search.$USER

  search_results=$(curl -u $NEXUS_USER:$NEXUS_PASS -s "$search_url")
  echo "$search_results" >> /tmp/sk-nexus-search.$USER
  continuation_token=$(echo "$search_results" | jq -r .continuationToken 2>/dev/null)
  items=$(echo "$search_results" | jq -r '.items | length' 2>/dev/null | head -n 1 )

  while [[ "$items" -gt 0 ]] && [[ "$continuation_token" != 'null' ]] ;do
    search_results=$(curl -u $NEXUS_USER:$NEXUS_PASS -s "$search_url&continuationToken=$continuation_token")

    # check to see if we've run out of items
    items=$(echo "$search_results" | jq -r '.items | length' 2>/dev/null | head -n 1 )
    if [[ "$items" -gt 0 ]];then
      echo "$search_results" >> /tmp/sk-nexus-search.$USER
      # update token
      continuation_token=$(echo "$search_results" | jq -r .continuationToken 2>/dev/null)
    fi
  done

  if [[ "$path_id_output" -eq 1 ]];then
    cat /tmp/sk-nexus-search.$USER | jq -r '.items[]| .path + " " + .id + " " + .lastModified ' 2>/dev/null | sort
    return
  fi

  if [[ "$raw_output" -eq 1 ]];then
    cat /tmp/sk-nexus-search.$USER | jq -r .  2>/dev/null
    return
  fi

}


sk-nexus-mass-clean-assets(){
  usage(){
    I_USAGE="Usage: $FUNCNAME
        description: Use the nexus search facility to delete components with 2 controls to stop components being
    deleted that might be in use:-

      1. Images must be created more than $days_keep days
      2. $versions_keep latest versions will be left out of the cleanup

        method:

          1: search for all the assets (or filtered by repo)
          2: normalize the paths of each asset to remove repo specific things
          3: cut the paths down to a unique name ( this will be each component or project we work with)
          4: Split the and sort the assets under their unique path names cutting off the first X versions
          5: test each asset to see whether it's more than X days old to see if it should be deleted

        example:-

          $FUNCNAME -r docker-hosted -z

          Assets are split into these normalized paths:-

            /xxx
            /xx
            /xxx

        options:
          -a <artifact>
          -g <groupid>
          -r <repository>
          -t <type>
          -V <version>(latest)
          -f <directory> directory of files to try and upload to nexus
          -y | --days_keep) containers must have a creation date older than this number of days
          -z | --dry_run) list only matches
          -k | --versions_keep) How many versions to always keep

        requirements:
          Config file
          . ~/.nexus.conf or . /etc/nexus.conf
             NEXUS_URL=http://nexus.wibble.com
             NEXUS_USER=blar
             NEXUS_PASS=password


     "
    echo "$I_USAGE"
  }

  local artifact_arg='' groupid_arg='' repository_arg='' type_arg='' version_arg='' extension_arg=''

  local days_keep=365 versions_keep=50 dry_run=0

  local       asset_path='' asset_id=''  asset_modified_date_time='' asset_modified_sec=''
  VERBOSE=0
  while :
  do
    case ${1-default} in
        -a | --artifact )    artifact_arg="-a $2"; shift 2 ;;
        -g | --groupid )     groupid_arg="-g $2" ; shift 2 ;;
        -r | --repository )  repository_arg="-r $2"; shift 2 ;;
        -t | --type )        extension_arg="-t $2"; shift 2 ;;
        -V | --version )     version_arg="-V $2"; shift 2 ;;
        -v | --verbose )     VERBOSE=$((VERBOSE+1)); shift ;;
        -f | --upload_dir )  uploaddir=$2 ;shift 2 ;;
        -w | --raw_output )  raw_output=1 ;shift ;;
        -p | --path_id_output ) path_id_output=1 ;shift ;;
        -m | --group_by_major_version ) group_by_major_version=1 ;shift ;;
        -y | --days_keep) days_keep=$2 ; shift 2 ;;
        -k | --versions_keep) versions_keep=$2 ; shift 2 ;;
        -z | --dry_run) dry_run=1 ; shift ;;

        -h | --help ) usage; return ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done
  sk-nexus-creds || return
  _sk-nexus-tmpdirs

  sk-nexus-search-assets --path_id_output $version_arg $artifact_arg $groupid_arg $extension_arg $repository_arg > /tmp/sk-nexus-search.path_id.$USER

  # normalize paths
  perl -p -e 's/(manifests\/|release-|v2)//g' /tmp/sk-nexus-search.path_id.$USER > /tmp/sk-nexus-search.path_id_cleaned.$USER

  # drop any specialized latest assets
  perl -pi -e 's/.*(current|latest).*//g' /tmp/sk-nexus-search.path_id_cleaned.$USER

  if [[ group_by_major_version -eq 1 ]];then
    # nasty hack to get a list of the unique asset paths so we can use this to keep X of any type of asset
    # major_version_paths
    paths=$(cat /tmp/sk-nexus-search.path_id_cleaned.$USER | sort | perl -ne '/(.*?\d{1}).* / && print "$1\n"' | sort | uniq)
  else
    paths=$(cat /tmp/sk-nexus-search.path_id_cleaned.$USER | sort | perl -ne '/(.*?)\/\d.* / && print "$1\n"' | sort | uniq)
  fi

  cutoff="$(sk-date -d -${days_keep}days '+%s')"

  echo "PATHS:"
  echo "$paths"

  echo "" > /tmp/sk-nexus-search.path_id_cleaned.path.$USER
  while IFS=$'\n' read -r path; do
    echo " "
    echo "##############################################"
    echo " "


    echo "PATH: $path"

    # break our list of all assets in a repo into unique paths and cut off a certain number of versions we always want to exclude
    grep "$path" /tmp/sk-nexus-search.path_id_cleaned.$USER | sk-head -n -$versions_keep > /tmp/sk-nexus-search.path_id_cleaned.path.$USER

    if [[ `cat /tmp/sk-nexus-search.path_id_cleaned.path.$USER | wc -l` -eq 0 ]];then
      continue
    fi

    echo "ASSETS:"
    # Process a list of assets under a single path
    while IFS=$'\n' read -r asset_line; do

      # parse each asset line
      asset_path=$(echo $asset_line | awk '{ print $1}')
      asset_id=$(echo $asset_line | awk '{ print $2}')
      asset_modified_date_time=$(echo $asset_line | awk '{ print $3}')
      asset_modified_sec="$(sk-date -d "$asset_modified_date_time" '+%s')"

      echo "asset: $asset_path "
      verbose "asset_id: $asset_id"
      echo "asset_modified_date_time: $asset_modified_date_time"
      echo "asset_modified_sec: $asset_modified_sec"

      if [[ "$asset_modified_sec" -lt "$cutoff" ]];then

        if [[ "$dry_run" -eq 1 ]];then
          echo "DRY_RUN: deleting because $asset_modified_date_time > ${days_keep} days old"

          echo "curl -X 'DELETE' -u $NEXUS_USER:$NEXUS_PASS -s \"${NEXUS_URL}/service/rest/v1/assets/$asset_id\" -H 'accept: application/json'"
          if [[ "$VERBOSE" -gt 1 ]];then
            echo "asset details:-"
            curl -u $NEXUS_USER:$NEXUS_PASS -s "${NEXUS_URL}/service/rest/v1/assets/$asset_id" -H 'accept: application/json'
          fi
          sleep 1
        else
          echo "deleting because $asset_modified_date_time > ${days_keep} days old"
          echo "id: $asset_id"
          verbose "curl -u $NEXUS_USER:$NEXUS_PASS ${NEXUS_URL}/service/rest/v1/assets/$asset_id -H 'accept: application/json'"
          curl -X 'DELETE' -u $NEXUS_USER:$NEXUS_PASS -s "${NEXUS_URL}/service/rest/v1/assets/$asset_id" -H 'accept: application/json'
          sleep 1
        fi
        echo "-----------------------------------"
      fi

    done <<< $(cat /tmp/sk-nexus-search.path_id_cleaned.path.$USER )
  done <<< $(echo "$paths")

}





