echo_log_run(){
  sk-logger-args "$@"
  echo_log $@
}

echo_log(){
  echo "$@"
  echo ""
  sk-logger-args "$@"
}

echo_log_keyevent(){
  echo "$@"
  echo ""

  keyevent "${FUNCNAME[@]} $@"
}

echo_run() {
  sk-trans-requote "$@"
  "$@"
}

echo_log_run_logoutput(){

  sk-trans-requote "$@"
  sk-logger-args $(sk-trans-requote "$@")

  "$@" >/tmp/echo_out.$$

  if [[ -s "/tmp/echo_out.$$" ]];then
    cat /tmp/echo_out.$$ | sk-logger-stdin-stdout
  fi
  rm /tmp/echo_out.$$

}

