#-------------------------------------------------------------------------------
#
# General systems functions
#
#-------------------------------------------------------------------------------

sk-ntp-fix(){
  sudo service chrony stop
  sudo service chrony start
  sleep 2
  sudo chronyc -a makestep
  sk-nagios-check-nrpe check_ntp_time
  sleep 10
  sk-nagios-check-nrpe check_ntp_time
}

sk-rg(){
  sk-pack-install rg -p ripgrep
  rg $@
}

sk-sys-cores(){
  if [[ "$PLATFORM" == 'Darwin' ]];then
    sysctl -n hw.ncpu
  else
    grep -c ^processor /proc/cpuinfo
  fi
}

sk-datediff-setup(){
  if [[ "$PLATFORM" == 'Darwin' ]];then
    sk-pack-install datediff -p dateutils
  else
    sk-pack-install dateutils.ddiff -p dateutils
  fi
}

sk-sed(){
  if [[ "$PLATFORM" == 'Darwin' ]];then
    sk-pack-install gsed -p gnu-sed
    gsed $@
  else
    sed $@
  fi
}

# bring macos into compat with linux
sk-date(){
  if [[ "$PLATFORM" == 'Darwin' ]];then
    sk-pack-install gdate -p coreutils
    gdate $@
  else
    date $@
  fi
}

sk-find(){
  if [[ "$PLATFORM" == 'Darwin' ]];then
    sk-pack-install gfind -p findutils
    gfind "$@"
  else
    find "$@"
  fi
}

sk-head(){
  if [[ "$PLATFORM" == 'Darwin' ]];then
    sk-pack-install ghead -p coreutils
    ghead $@
  else
    head $@
  fi
}

sk-gawk(){
 if [[ "$PLATFORM" == 'Darwin' ]];then
    sk-pack-install gawk -p gawk
    gawk $@
  else
    awk $@
  fi
}

sk-tar(){
  if [[ "$PLATFORM" == 'Darwin' ]];then
    sk-pack-install gtar -p coreutils
    gtar $@
  else
    tar $@
  fi
}

sk-sys-watch() {

  watch_fct() {
    # watch with temporary bashrc to load a bash function
    declare tmp="/tmp/$FUNCNAME.$$" opt="-t" cmd="" fct="" i="" other_fct=""
    while [ $# -gt 0 ]; do
      case "$1" in
        -n) opt="$opt $1 $2"; shift ;;
        -d|-t) opt="$opt $1" ;;
        -fct) shift; other_fct="$other_fct $1" ;;
        *)  cmd="${cmd}${1} " ;;
      esac
      shift
    done

    # extract first word from $cmd
    for i in $cmd{@}; do fct=$i; break; done
    fct="${fct}${other_fct}"
    #type $fct | tail -n +2 > "$tmp"
    type $fct | grep -vE '^\S+ is a function' > "$tmp"

    watch $opt "bash -c '. $tmp && ($cmd)'"
    rm -f "$tmp"
  }

  case ${1-default} in

    mail)
      tail -f /var/log/mail.log
    ;;

    syslog)
      tail -f /var/log/kern.log /var/log/syslog
    ;;

    bind|named)
      tail -vf /var/log/bind/*.log
    ;;

    mem) watch_fct -fct sk-maths-bytes-to-human sk-mem-info ;;

    ips) watch_fct sk-ip-infos ;;


    io)
      watch -d iostat -c -m -d -x `df -hT -x tmpfs -x nfs |perl -ane 'm:^/: and print $F[0]."\n"'`
    ;;

    *)
      echo "Usage: $FUNCNAME syslog|mem|ips|bind|io"
    ;;

  esac

}

sk-sys-dns-lookup(){
  sk_help "Usage: $FUNCNAME <dnsname>" "$@" && return
  echo_log_run_logoutput dig +trace @8.8.4.4 $@
}

sk-sys-zcat() {
  if [[ "$#" = "0" ]]; then
     cat "$@"| gzip -cdfq
     exit 0
  fi


  while [ $# -gt 0 ]; do
    continue=0
    test -f "$1" || continue=1
    test -s "$1" || continue=1
    [[ "$continue" = "0" ]] && bunzip2 -fc "$1" | gzip -cdfq -
    shift
  done
}

sk-sys-strace-top-pid(){
  sk_help "Usage: <filter>(default http). Run strace on the process using most cpu filtered on a term, output to ./strace.log" "$@" && return
  local filter=${1:-http}
  sudo strace -p$(top -b -n 1 | grep $filter | head -n 12 | tail -n1 | awk '{print $1}') -o strace.log
}

sk-sys-linkchecker(){
  sk_help_noarg "Usage: $FUNCNAME <url> -o csv. Run linkchecker on a site to test performance." "$@" && return
  sk-pack-install linkchecker
  echo_log_run_logoutput linkchecker $@
}

sk-sys-ipmi-ignore(){
  sk_help "Usage: $FUNCNAME. Tell IPMI check to ignore sensors returning status = Critical" "$@" && return
  ids=''
  for id in `sudo ipmimonitoring | awk -F'|' '$4 ~ /Critical/ {print $1}'`;do
    ids="$id;$ids"
  done
  echo "$ids" | sudo tee /etc/check_ipmi_sensor_ignore 1>/dev/null
}

sk-sys-leapyear(){
  sk_help "Usage: $FUNCNAME. Fix 100% cpu kernel leap year servers" "$@" && return
  echo_log_run_logoutput sudo date -s "$(LC_ALL=C date)"
}

sk-sys-console-no-monitor-power-off(){
  setterm -blank 0
}

sk-sys-swap-smem() {
  sk-pack-install smem
  echo_log_run_logoutput sudo smem  --totals --percent -k --sort=swap
}

sk-sys-bond-remove(){
  sk_help_noarg "$FUNCNAME: [bondx] . Remove a bonding interface which still exist after interfaces file has been changed." "$@" && return
  interface=$1
  sudo bash -c "echo \"-${interface}\" > /sys/class/net/bonding_masters"
}

sk-sys-int-remove(){
  sk_help_noarg "$FUNCNAME: [ethx:x] . Remove a interface not configured in /etc/network/interfaces." "$@" && return
  interface=$1
  sudo ip link delete $interface
}

sk-sys-purge-old-kernels() {
  sk-pack-install purge-old-kernels -p bikeshed
  sudo purge-old-kernels --keep 3 -qy
}

sk-sys-add-swap() {
  sk_help_noarg "Usage: $FUNCNAME size in MB of swap file. Creates a swap file of /var/swap.1" "$@" && return
  echo_log_run_logoutput sudo /bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=$1
  echo_log_run_logoutput sudo /sbin/mkswap /var/swap.1
  echo_log_run_logoutput sudo /sbin/swapon /var/swap.1
  echo_log_run_logoutput sudo bash -c 'echo "/var/swap.1 swap swap defaults 0 0" >> /etc/fstab'
}

sk-sys-uptime(){
  sk_help "Usage: <uptime_min_minutes> . Show uptime and warn if below a certain time" "$@" && return
  local uptime_min_minutes=${1:-10}
  uptime_minutes=$(awk '{print int($1/60)}' /proc/uptime)
  if [[ "$uptime_minutes" -lt "$uptime_min_minutes" ]]; then
    sk-logger-args-stdout "WARN: Uptime ${uptime_minutes}m < ${uptime_min_minutes}m"
    return 0
  else
    echo "Uptime: ${uptime_minutes}m"
    return 1
  fi
}

alias int=sk-sys-int

sk-sys-int(){
  sk_help "Usage: . Show primary interface name" "$@" && return

  case $PLATFORM in
    Darwin) route -n get 0.0.0.0 2>/dev/null | awk '/interface: / {print $2}' ;;
    *) ip route get 8.8.8.8 | sed -nr 's/.*dev ([^\ ]+).*/\1/p' ;;
  esac

}

sk-sys-int-isup(){
  # http://stackoverflow.com/questions/808560/how-to-detect-the-physical-connected-state-of-a-network-cable-connector
  local interface=${1:-$(sk-sys-int)}
  if grep -Eq 'up|unknown' /sys/class/net/$interface/operstate;then
    return 0
  else
    return 1
  fi
}

sk-sys-is-root(){
  if [[ $EUID -ne 0 ]]; then
    echo "non root user detected"
    return 1
  else
    return 0
  fi
}

sk-sys-is-root-no-output(){
  if [[ $EUID -ne 0 ]]; then
    log "non root user detected"
    return 1
  else
    return 0
  fi
}

sk-sys-is-user(){
  sk_help "Usage: [user to test] . Check if current user equals a user specified as an argument" "$@" && return
  local test_user=${1:-root}
  if [[ "$USER" = "$test_user" ]];then
    return 0
  else
    echo_log "$$USER != $test_user"
    return 1
  fi
}

sk-sys-cpu-usage-per-process(){
  local service='' instance=1 pid=''
  usage(){
      I_USAGE="$FUNCNAME


          -s | --service) search string to look for pid file in common locations and alternatively try init script
          -i | --instance) slotr specific instance to search for
      "
      echo "$I_USAGE"
  }

  while :
  do
    case ${1-default} in
        -h | --help | -\?) usage ; return ;;
        -s | --service) service=$2 ; shift 2 ;;
        -i | --instance) instance=$2 ; shift 2 ;;
        *)  break ;;
    esac
  done
  YMD=`date +%Y-%m-%d`
  [[ -z $USER ]] && USER=$(whoami)
  STAT_DIR="/var/tmp/${service}.stats.$USER"
  NB_PROC=$(grep -c ^processor /proc/cpuinfo)
  PROCESS_CPU_CHECK=99 # require the single process to be using xx% of total cpu
  CPU_THRESHOLD_MIN=30 # require 30m of high cpu before restarting

  # cleanup old date based stats
  [[ ! -d $STAT_DIR ]] && mkdir -p $STAT_DIR
  find $STAT_DIR -name "*.log" -type f -mtime +15 -exec rm -f {} \;


  local cpu_usage=0 threshold_state_file=$STAT_DIR/cpu.state threshold_log_file=$STAT_DIR/cpu.$YMD.log

  pid=$(sk-pid -s $service)

  if [[ -z "$pid" ]];then
    echo "pid not found for $service"
    return
  fi

  # get cpu usage as a % / 100 to compare it to a core based value. e.g 800% cpu becomes 8.
  cpu_usage=$(echo "scale=2; ($(top -p $pid -n1 -b -d1 | tail -1 | awk '{print $9}') / 100 )" | bc -l)
  # PROCESS_CPU_CHECK % converted to a core based value
  cpu_threshold=$(echo "scale=2; ($NB_PROC * ( $PROCESS_CPU_CHECK / 100 ))" | bc -l)
  sk-logger-args-stdout "STAT: $service pid:$pid CPU_USAGE: $cpu_usage, CPU_THRESHOLD: $cpu_threshold, CORES $NB_PROC, PERCENT_THRESHOLD: $PROCESS_CPU_CHECK%"

  echo "$cpu_usage" >> $threshold_log_file

  if [[ $(echo "($cpu_usage > $cpu_threshold )" | bc -l) -eq 1 ]];then
    if test "`find $threshold_state_file -mmin +$CPU_THRESHOLD_MIN`";then
      sk-logger-args-stdout-keyevent "$service WARN: CPU threshold:  $cpu_usage > $cpu_threshold and $threshold_state_file > $CPU_THRESHOLD_MIN min old"
      rm -f $threshold_state_file
      return 1
    fi
    # create an initial state file
    if [[ ! -f "$threshold_state_file" ]];then
      verbose_log "STAT: $service CPU threshold:  $cpu_usage > $cpu_threshold touching state file $threshold_state_file"
      echo "$cpu_usage" > $threshold_state_file
    fi

  else
    # if cpu usage drops with the $CPU_THRESHOLD_MIN min we delete the state file and start again
    rm -f $threshold_state_file
  fi
}


