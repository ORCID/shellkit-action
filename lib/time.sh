#
# Time
#

sk-time-sec2h() {
  sk_help_noarg "Usage: $FUNCNAME SECONDS" "$@" && return
  perl -e '
  my $time = shift @ARGV;

  my $days = int($time / 86400);
  $time -= ($days * 86400);

  my $hours = int($time / 3600);
  $time -= ($hours * 3600);

  my $minutes = int($time / 60);
  my $seconds = $time % 60;

  printf("\%d day(s) %02d:%02d:%02d\n",$days,$hours,$minutes,$seconds);
' $1
}


sk-time-epoch2date() {
  # perl -e 'print scalar(localtime(1268727836))."\n"'
  date -d @${1}
}

sk-time-epoch-to-human(){
  local epoch_time=${1:-1234567891}
  local epoch_divider=${2:-1}
  date -d@$(bc <<<$epoch_time/$epoch_divider)
}

sk-time-epoch-micro-to-human(){
  local epoch_time=$1
  sk-time-epoch-to-human $epoch_time 1000000
}

sk-time-human-to-epoch-micro(){
  sk_help_noarg "Usage: $FUNCNAME Provide date in following format 2009/05/25 18:34:30" "$@" && return 1
  local epoch_seconds=$(date --date="$1" "+%s")
  echo $(bc <<< $epoch_seconds*1000000)
}

sk-time-epoch-milli-to-human(){
  local epoch_time=$1
  sk-time-epoch-to-human $epoch_time 1000
}

sk-time-human_to_epoch_milli(){
  sk_help_noarg "Usage: $FUNCNAME Provide date in following format 2009/05/25 18:34:30" "$@" && return 1
  local epoch_seconds=$(date --date="$1" "+%s")
  echo $(bc <<< $epoch_seconds*1000)
}

sk-time-spent(){
  secs=$SECONDS
  hrs=$(( secs/3600 )); mins=$(( (secs-hrs*3600)/60 )); secs=$(( secs-hrs*3600-mins*60 ))

  printf 'Time spent: %02d:%02d:%02d\n' $hrs $mins $secs
}

