sk-ssl-cert-gen(){
  sk_help_noarg "Usage: $FUNCNAME <subject> <days> <format>. Gen self signed certificate" "$@" && return
  local subject=${1:-"/CN=`hostname`"} days=${2:-3650} key_format=${3:-"rsa:3072"}
  openssl req -x509 -nodes -newkey "${key_format}" -keyout "/tmp/cert.key" -out "/tmp/cert.pem" -days $days -subj "${subject}"
}

sk-ssl-pem-to-raw(){
  sk_help_noarg "Usage: $FUNCNAME <pem cert file>. Strip raw cert from a pem file and output it" "$@" && return
  local certfile=${1:-wibble.pem}
  awk '!/-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----/{printf "%s", $0}' "$certfile"
}

sk-ssl-sig() {
  sk_help_noarg "Usage: $FUNCNAME x509cert. Generate fingerprint" "$@" && return
  echo_log_run_logoutput openssl x509 -in ${1}* -fingerprint -noout
}

sk-ssl-ca-list-java(){
  sk_help "Usage: $FUNCNAME <optional service for java_home> <optional_cacert_file> List all the subject names of the system wide ca store" "$@" && return
  local service=${1:-wibble}
  local cacerts_file=${2:-unset}

  sk-java-home -s "$service"
  if [[ "$cacerts_file" != 'unset' ]];then
    CACERTS_FILE=$cacerts_file
  else
    CACERTS_FILE="$JAVA_HOME/lib/security/cacerts"
  fi
  echo "keytool -list -v -keystore "$CACERTS_FILE" -storepass changeit"
  keytool -list -v -keystore "$CACERTS_FILE" -storepass changeit
}

sk-ssl-ca-list(){
  sk_help "Usage: $FUNCNAME </etc/ssl/certs/ca-certificates.crt> List all the subject names of the system wide ca store" "$@" && return
  if [[ "$PLATFORM" = Darwin ]];then
    default_cacerts_file=/etc/ssl/cert.pem
  else
    default_cacerts_file=/etc/ssl/certs/ca-certificates.crt
  fi

  local cacerts_file="${1:-$default_cacerts_file}"
  awk -v cmd='openssl x509 -noout -subject' '
    /BEGIN/{close(cmd)};{print | cmd}' < $cacerts_file
}

sk-ssl-text() {
  sk_help_noarg "Usage: $FUNCNAME x509cert (parse x509 certificate and output text format)" "$@" && return
  echo_log_run_logoutput openssl x509 -in ${1}* -text
}

sk-ssl-cipher() {
  sk_help_noarg "Usage: $FUNCNAME <server> <port>. Find what ciphers a remote server uses" "$@" && return
  local server=${1:-google.com}
  local port=${2:-443}
  for v in ssl2 ssl3 tls1 tls1_1 tls1_2; do
   for c in $(openssl ciphers 'ALL:eNULL' | tr ':' ' '); do
   openssl s_client -connect $server:$port \
   -cipher $c -$v < /dev/null > /dev/null 2>&1 && echo -e "$v:\t$c"
   done
  done
}

