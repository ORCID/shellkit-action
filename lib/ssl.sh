sk-ssl-pem-to-raw(){
  sk_help_noarg "Usage: $FUNCNAME <pem cert file>. Strip raw cert from a pem file and output it" "$@" && return
  local certfile=${1:-wibble.pem}
  awk '!/-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----/{printf "%s", $0}' "$certfile"
}

sk-ssl-sig() {
  sk_help_noarg "Usage: $FUNCNAME x509cert. Generate fingerprint" "$@" && return
  echo_log_run_logoutput openssl x509 -in ${1}* -fingerprint -noout
}

sk-ssl-ca-list(){
  sk_help "Usage: $FUNCNAME </etc/ssl/certs/ca-certificates.crt> List all the subject names of the system wide ca store" "$@" && return
  awk -v cmd='openssl x509 -noout -subject' '
    /BEGIN/{close(cmd)};{print | cmd}' < /etc/ssl/certs/ca-certificates.crt
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

