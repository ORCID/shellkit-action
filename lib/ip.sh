sk-ip-to-nginx-allow(){
  sk_help "$FUNCNAME: take stdin list of ips line by line and convert to a nginx allow format" "$@" && return
  cat - | perl -pe 's/^/allow /g' | perl -pe 's/$/;/'
}

sk-ip-azure-public-ips(){
  curl https://saasedl.paloaltonetworks.com/feeds/azure/public/any/ipv4
}

sk-ip-azure-public-ips-nginx-allow(){
  curl https://saasedl.paloaltonetworks.com/feeds/azure/public/any/ipv4 | sk-ip-to-nginx-allow
}

sk-ip-asn-to-ip(){
  sk_help "$FUNCNAME: <ASN number> <comment> . Show all the ip prefixes announced by a webhost." "$@" && return
  local asn=${1:-AS14061} comment=${2:-''}
  whois -h whois.radb.net -- "-i origin $asn" | grep --color=never -Eo "([0-9.]+){4}/[0-9]+" > /tmp/asns.$$
  if [[ "$comment" != '' ]];then
    while IFS='' read line;do
      echo "$line # $comment"
    done < /tmp/asns.$$
  else
    cat /tmp/asns.$$
  fi

}

sk-ip-to-asn(){
  sk_help "$FUNCNAME: <ip>. Lookup ASN number from an ip. DO NOT ABUSE" "$@" && return
  local ip=${1:-45.58.112.15}
  whois -h whois.cymru.com " -v $ip" | tail -1 | awk '{print $1}'
}

sk-ip-to-asn-bulk(){
  sk_help "$FUNCNAME: <file_with_list_of_ips> <output_file>. Lookup as number for a list of ips." "$@" && return
  local ip_list_file=$1 tmp_file="/tmp/$FUNCNAME.$$" output_file=${2:-asn_bulk.out}
  sk-pack-install nc.traditional -p netcat-traditional
  echo "begin" > $tmp_file
  echo "verbose" >> $tmp_file
  cat $ip_list_file >> $tmp_file
  echo "end" >> $tmp_file
  nc.traditional whois.cymru.com 43 < $tmp_file | sort -n > output_file
}

sk-ip() {
  local _ip _myip _line _nl=$'\n'
  while IFS=$': \t' read -a _line ;do
    [ -z "${_line%inet}" ] &&
    _ip=${_line[${#_line[1]}>4?1:2]} &&
    [ "${_ip#127.0.0.1}" ] && _myip=$_ip
  done< <(LANG=C /sbin/ifconfig)
  printf ${1+-v} $1 "%s${_nl:0:$[${#1}>0?0:1]}" $_myip
}

sk-ip-sort(){
  cat - | sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4
}

# FIXME: migrate to go!

sk-ip-range-to-cidr(){
  local start_ip=$1 end_ip=$2
  sk-pack-install netaddr -p python-netaddr
  local py_script="
import sys
from netaddr import *
cidrs = iprange_to_cidrs(sys.argv[1], sys.argv[2])
print cidrs[0]
"
  python -c "$py_script" $start_ip $end_ip
}

sk-ip-in-cidr-file(){
  sk_help "Usage: $FUNCNAME. <ip> <file_with_cidr_ranges>. Show is ip is in any of the cidr ranges" "$@" && return
  local ip=${1:-127.0.0.1}
  local file=${2:-/var/tmp/azure}

  sk-asdf-install cidrchk -p cidrchk -v 0.5 --plugin_git_url https://github.com/ORCID/asdf-cidrchk.git

  for cidr in `cat $file`;do
    if sk-ip-in-cidr $ip $cidr >/dev/null 2>&1;then
      echo $cidr
    fi
  done

}

sk-ip-in-cidr(){
  sk_help "Usage: $FUNCNAME. <ip> <cidr>. Show is ip is in cidr range" "$@" && return
  local ip=$1 cidr=$2
  sk-asdf-install cidrchk -p cidrchk -v 0.5 --plugin_git_url https://github.com/ORCID/asdf-cidrchk.git
  cidrchk contains $cidr $ip
}

sk-ip-mask-to-cidr(){
  sk-asdf-install cidr-merger -p cidr-merger -v 1.1.3 --plugin_git_url https://github.com/ORCID/asdf-cidr-merger.git
  cat - | cidr-merger --cidr -s
}

sk-ip-merge(){
  sk_help "Merge ipv4 ip address' on newlines from stdin into the smallest set of ranges. output on newlines to stdout" && return
  sk-asdf-install cidr-merger -p cidr-merger -v 1.1.3 --plugin_git_url https://github.com/ORCID/asdf-cidr-merger.git --silent
  cat - | cidr-merger
}


sk-ip-info() {
  echo 'Top ip connections activity:'
 netstat -ntu | awk '$5 ~ /^[0-9]/ {print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr -k 1 | xargs printf '%4d: %s\n' | head -50
}


sk-ip-public() {
  sk_help "Usage: $FUNCNAME. Returns the public ip of the current machine" "$@" && return
  dig @resolver4.opendns.com myip.opendns.com +short -4
}


sk-ip-ips() {
  sk_help "$FUNCNAME: Return interfaces ips" "$@" && return
  ifconfig | perl -ne '/^\s*inet (?:addr:)?([\d\.]+)/ and $1 ne "127.0.0.1" and print "$1\n"'
}

sk-ip-check-port() {
  sk_help_noarg "Usage: $FUNCNAME <PORT>. Check port is open on each ips" "$@"

  declare port; port=$1; shift
  declare i

  for i in 127.0.0.1 `sk-ip-ips`; do

    printf '%s ' $i
    if nc -w2 -z $i $port; then
      echo OK
    else
      echo ERR
    fi

  done

}

sk-ip-to-hex() {
  printf '%.2x:%.2x:%.2x:%.2x\n' `echo $@ | sed -e 's/\./ /g'`
}

sk-ip-to-vmware-hex(){
  sk_help_noarg "$FUNCNAME: ip_address. Generate a Vmware compatible MAC address based on the last 2 or 3 octets of an ip_address (00:50:56:<00:00:00> - 00:50:56:<3f:ff:ff>)" "$@" && return
  ip_address=$1; octet_identifier=$(echo $ip_address | cut -d. -f2)

  # assign fixed 1st mac if "x.>60.x.x" as Vm
  if [[ "$octet_identifier" > 60 ]];then
    mac_tail=$(sk-ip-to-hex $ip_address | cut -c 7- )
    mac_tail="3f:$mac_tail"
  else
    mac_tail=$(sk-ip-to-hex $1 | cut -c 4-)
  fi
  echo "00:50:56:${mac_tail}"
}

