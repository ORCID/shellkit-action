# https://unix.stackexchange.com/questions/276911/is-it-dangerous-to-always-have-extglob-on
shopt -s extglob 2>/dev/null

mkfile() {
    mkdir -p $( dirname "$1") && touch "$1"
}

sk-file-latest(){
  local file=$(sk-find . -type f -printf '%T@ %p\n' | sort -n | cut -d' ' -f 2- | tail -n 1)
  ls -la $file
}

sk-file-hex-compare(){
  sk_help_noarg "Usage: $FUNCNAME <file_A> <file_B>. hex compare 2 files" "$@" && return
  local file_a=${1:-blar} file_b=${2:-blar}
  vimdiff <(xxd $file_a) <(xxd $file_b)
}

sk-file-no-comments-no-blank(){
  sk_help_noarg "Usage: $FUNCNAME <file>. strip a filetest if file is compressed" "$@" && return
  local filename=${1:-/tmp}
  grep -v "^#\|^$" $filename
}

sk-file-older-than(){
  local file=${1:-/var/tmp/} days=${2:-1}
  sk_help "Usage: $FUNCNAME <file> <days>" "$@" && return 1

  if [[ -f "$file" ]];then
    foo=bar
  elif [[ -d "$file" ]];then
    foo=bar
  else
    log "file or dir does not exist"
    return 1
  fi

  if test "`find $file -mtime +$days`";then
    return 0
  else
    return 1
  fi
}

sk-file-older-than-mins-or-nonexistant(){
  local file=${1:-/var/tmp/} min=${2:-1}
  sk_help "Usage: $FUNCNAME <file> <mins>" "$@" && return 1

  [[ ! -f "$file" ]] && return 0
  if test "`find $file -mmin +$min`";then
    return 0
  else
    return 1
  fi
}

sk-file-is-compressed(){
  sk_help_noarg "Usage: $FUNCNAME <file>. test if file is compressed" "$@" && return
  local filename=${1:-/tmp}
  if grep -q compressed <<< $(file $filename) || grep -q '.gz' <<< $(echo $filename);then
    return 0
  else
    return 1
  fi
}

sk-file-mime-type(){
  sk_help_noarg "Usage: $FUNCNAME <file>. Print the mime type of a file" "$@" && return
  local filename=${1:-/tmp}

  type=$(sk-file-ext $filename)
  case $type in
    tar.gz) echo "application/tar+gzip" ;;
    war) echo "application/java-archive" ;;
    zip) echo "application/zip" ;;
    *) file --mime-type $filename | awk '{print $2}' ;;
  esac

}

sk-file-stat-user(){
  sk_help_noarg "Usage: $FUNCNAME <file>. Show the owner of a file or dir" "$@" && return
  local filename=${1:-/tmp}
  case $PLATFORM in
    Darwin) stat -f "%Su" $filename ;;
    Linux) stat -c "%U" $filename ;;
  esac
}

sk-file-ext(){
  sk_help_noarg "Usage: $FUNCNAME <file>. return the file extension" "$@" && return
  local filename=${1:-/tmp}
  case $filename in
    *tar.gz) echo tar.gz ; return ;;
    *tar.bz2) echo tar.bz2 ; return ;;
  esac
  echo "$filename" | awk -F . '{print $NF}'
}

sk-file-dd(){
  sk_help "Usage: $FUNCNAME <size>(default 10M) <filename>. Create a testfile to test disk speed." "$@" && return
  local size=${1:-10M} filename=${2:-testfile}
  echo_log_run_logoutput dd if=/dev/zero of=${filename} bs=${size} count=1
}

sk-file-tar-duplicates(){
  sk_help_noarg "Usage: $FUNCNAME <tar_file>. Print any duplication files in a tar.gz tar.bz2 tar file" "$@" && return
  local tarfile=${1:-/tmp}
  case $tarfile in
    *.gz) sk-pack-install -b pigz pigz; use_compress_prog="--use-compress-prog=pigz" ;;
    *.bz2) sk-pack-install -b pbzip2 pbzip2; use_compress_prog="--use-compress-prog=pbzip2" ;;
    *) use_compress_prog="";;
  esac
  echo_log_run_logoutput tar $use_compress_prog -tvf $tarfile | awk '{ print $6 }' | sort | uniq --repeated
}

sk-file-no-world-read(){
  find . -type f ! -perm -004
}

sk-file-insert-after-search() {
  sk_help_noarg "$FUNCNAME: <search_string> <search_file> <insert_file>. Insert contents of one file into another after a specific search string." "$@" && return
  local search_string=${1:-wibble}; local search_file=${2:-/tmp}; local insert_file=${3:-/tmp/1}; local insert_string=$(cat $insert_file);
  perl -pi -e "s!$search_string!$search_string\n$insert_string\n\n!g" $search_file
}

sk-file-decompress() {
  sk_help_noarg "<file>. Detect type and extract archive in the current directory" $1 && return
  local file=$1; local compress_prog='false'
  echo $file | grep -q tar && local use_tar='true'

  case $file in
    *gz) sk-pack-install -b pigz pigz; compress_prog=pigz ;;
    *bz2) sk-pack-install -b pbzip2 pbzip2 ; compress_prog=pbzip2 ;;
  esac

  if [[ "$use_tar" ]];then
    if [[ $compress_prog = 'false' ]];then
      echo_log_run_logoutput tar -xf "$file"
    else
      echo_log_run_logoutput tar -xf "$file" --use-compress-prog=$compress_prog
    fi
  fi

}

sk-file-compress() {
  sk_help_noarg "<archive_file>. Compress the current directory into a specified archive." $1 && return
  local file=$1; local compress_prog='false'
  echo $file | grep -q tar && local use_tar='true'

  case $file in
    *gz) sk-pack-install -b pigz; compress_prog=pigz ;;
    *bz2) sk-pack-install -b pbzip2 ; compress_prog=pbzip2 ;;
  esac

  if [[ "$use_tar" ]];then

    if [[ "$compress_prog" = 'false' ]];then
      tar -xf "$file" .
    else
      tar cf - . | pigz > "$file"
    fi
  fi

}


sk-file-between-dates(){

  usage(){
    I_USAGE="

      Description:

        Find files between dates using the filename (not date) and output them into a target file for later processing

        e.g sk-file-between-dates -p /var/lib/slotr/slot/blar/1/logs/ -f 20181120

        Files are matched on a set of wildcard definitions in this format path/*term*format* e.g. $path/*$term*$(date +$format  -d $from_date)*
      Options:
        -h | --help)
        -f | --from     : date to start from in format (%Y%m%d)
        -t | --to       : latest date to use. default ($to_date)
        -i | --inc)     : incrementer for each pass. default ($inc)
        -m | --format)  : format of the filenames date. default ($format)
        -r | --result)  : result file.  default ($result)
        -e | --term)    : term to match on. default ($term)
    "
    echo "$I_USAGE"
  }
  local inc='1 day' format='%Y-%m-%d' result=/tmp/$FUNCNAME.$$ term=access
  local to_date=$(date +%Y%m%d)
  while : ;do
    case ${1-default} in
      -h | --help) usage ; return ;;
      -f | --from) local from_date=$2 ; shift 2;;
      -i | --inc) local inc=$2 ; shift 2;;
      -m | --format) local format=$2 ; shift 2;;
      -t | --to) local to_date=$2 ; shift 2;;
      -p | --path) local path=$2 ; shift 2;;
      -r | --result) local result=$2 ; shift 2;;
      -e | --term) local term=$2 ; shift 2;;
      *) break ;;
    esac
  done

  rm -f $result

  while [[ "$from_date" -le "$to_date" ]]; do
    match=$(date +$format  -d $from_date)
    filename=$(ls $path/*$term*${match}*) && echo $filename >> $result
    from_date=$(date +%Y%m%d -d "$from_date $inc")
  done
  echo $result
}

sk-file-ls-tree() {
  for d in $@; do
    d=$(sk-readlink-f "$d")
    (
    while [ "$d" != "/" ]; do
      echo $d
      d=$(dirname "$d");
    done
    ) | xargs ls -lhd
  done
}

sk-file-rm-except() {
  sk_help_noarg "$FUNCNAME: '<file to exclude>'. rm all files in the current directory except one that you specify (which can use wildcards but must be quoted)" "$@" && return
  rm -v !("$1")
}

alias extract=sk-file-extract

sk-file-extract () {
  sk_help_noarg "$FUNCNAME: <file_to_extract> <target>(.) . Extract any compressed file type" "$@" && return
  local extract_file=$1 target_dir=${2:-.}

  sk-asdf-install arc -p arc -v 3.5.0 --plugin_git_url https://github.com/ORCID/asdf-arc.git

  if [[ -f $extract_file ]] ; then
    case ${extract_file-default} in
      *.tar.gz)  arc unarchive $extract_file $target_dir ;;

      *.tar)     arc unarchive $extract_file $target_dir ;;
      *.tgz)     arc unarchive $extract_file $target_dir ;;
      *.tar.bz2) arc unarchive $extract_file $target_dir ;;
      *.zip)     arc unarchive $extract_file $target_dir ;;
      *.tbz2)    tarc unarchiv $extract_file $target_dir ;;

      *.gz)      arc decompress $extract_file $target_dir ;;
      *.bz2)     arc decompress $extract_file $target_dir ;;
      *.rar)     arc decompress $extract_file $target_dir ;;
      *.Z)       arc decompress $extract_file $target_dir;;
      *)         arc decompress $extract_file $target_dir;;
    esac
  else
    echo "no file called $extract_file"
  fi
}

sk-file-compress() {
  sk_help_noarg "Usage: (file or directory) if .bz2 will decompress" $1 && return
  local file=$1
  sk-pack-install -b pbzip2
  [ ${file: -4} == ".bz2" ] && ( echo_log_run_logoutput pbzip2 -d $file ;return )
  echo_log_run_logoutput tar -cf "$file".tar.bz2 --use-compress-prog=pbzip2 "$file"
}

sk-file-upcase() {
  sk_help "Pass in a match of filenames you want upcasing which will be postpended with *" "$@" && return 1
  rename 's/^(.*)$/uc($1)/e' $@
}

sk-file-downcase() {
  sk_help "Pass in a match of filenames you want downcasing which will be postpended with *" "$@" && return 1
  rename 's/^(.*)$/lc($1)/e' $@
}

sk-file-sum-mb(){
  sk_help "<match of files in current dir>. Show the size of files in mb" "$@" && return 1
  ls -FaGl --block-size=M "${@}" | awk '{ total += $4 }; END { print total }'
}

sk-file-perms-user-read(){
  sk_help_noarg "Usage: $FUNCNAME <file>. Check if file is readable only by the current user" "$@" && return
  local file=${1:-/tmp}
  local mode

  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS uses BSD stat
    mode=$(stat -f "%p" "$file")
  else
    # Linux uses GNU stat
    mode=$(stat -c "%a" "$file")
  fi

  if [[ "$mode" == "100400" || "$mode" == "400" ]]; then
    foo='bar'
  else
    echo "File $file has permissions that are too open and not 400"
    return 1
  fi
}

sk-file-exists(){
  sk_help "Usage: -f <file_to_check>. Check if a file exists and return true if it does
      optional:
        -d : delete check file
        -t : touch check file

    " "$@" && return
  local file="${1:-/tmp/}" touch=0 delete=0

  while : ; do
    case ${1-default} in
       -f | --file     ) file=$2 ; shift 2 ;;
       -d | --delete     ) delete=1 ; shift ;;
       -r | --remove     ) delete=1 ; shift ;;
       -s | --set     ) touch=1 ; shift ;;
       -t | --touch     ) touch=1 ; shift ;;
        *)  break ;;
      esac
  done


  if [[ -f "$file" ]];then

    if [[ "$delete" -eq 1 ]];then
      rm $file
      return 1
    fi
    verbose_log "WARN: $file exists"
    return 0

  else
    if [[ $touch -eq 1 ]];then
      touch $file ; chmod 777 $file
    fi

    return 1
  fi

}

