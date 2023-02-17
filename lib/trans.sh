sk-trans-upcase-first-letter(){
  local word=${1:-bar}
  echo $(tr '[:lower:]' '[:upper:]' <<< ${word:0:1})${word:1}
}

sk-trans-comma-to-space(){
  echo "$@" |  tr "," " "
}

sk-trans-dot-to-forward-slash(){
  echo "$1" | sed 's/\./\//g'
}

sk-trans-strip-colour(){
  cat - | perl -ple 's/\e\[\d+(;\d+)*m//g'
}

sk-trans-space-to-dash(){
  echo "$@" |tr ' ' '-'
}

sk-trans-dash-to-underscore(){
  echo $1|tr '-' '_'
}

sk-trans-underscore-to-dash(){
  echo $1|tr '_' '-'
}

sk-trans-upcase(){
  echo $@ | tr [:lower:] [:upper:]
}

sk-trans-escape(){
  echo "$1" | sed 's/[^-A-Za-z0-9_]/\\&/g'
}

# requote space separated arguments that have quotes stripped by echo
sk-trans-requote() {
    local res=""
    for x in "${@}" ; do
        # detect space separated args
        grep -q "[[:space:]]" <<< "$x" && res="${res} '${x}'" || res="${res} ${x}"
    done
    # remove first space and print:
    sed -e 's/^ //' <<< "${res}"
}

sk-trans-trim() {
  local var="$@"
  var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
  var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
  echo "$var"
}

sk-trans-to-long-dep-label() {
  sk_help_noarg "Pass in a short deployment label and have it converted into long form" "$@" && return
  case ${1-default} in
    prod) r=$(echo $1 | perl -p -e 's/prod/production/') ;;
    preprod) r=$(echo $1 | perl -p -e 's/preprod/pre-production/') ;;
    test) r=$(echo $1 | perl -p -e 's/test/testing/') ;;
    dev) r=$(echo $1 | perl -p -e 's/dev/development/') ;;
    qa) r=$(echo $1 | perl -p -e 's/qa/dataqa/') ;;
    stage) r=$(echo $1 | perl -p -e 's/stage/staging/') ;;
  esac
  echo $r
}

sk-trans-to-short-label() {
  sk_help_noarg "Pass in a long deployment label and have it converted into short form" "$@" && return
  case ${1-default} in
    production) r=$(echo $1 | perl -p -e 's/production/prod/') ;;
    pre-production) r=$(echo $1 | perl -p -e 's/pre-production/preprod/') ;;
    testing) r=$(echo $1 | perl -p -e 's/testing/test/') ;;
    development) r=$(echo $1 | perl -p -e 's/development/dev/') ;;
    dataqa) r=$(echo $1 | perl -p -e 's/dataqa/qa/') ;;
    staging) r=$(echo $1 | perl -p -e 's/staging/stage/') ;;
  esac
  echo $r
}
