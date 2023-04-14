# activate with:
# set -o errexit -o errtrace -o nounset -o functrace -o pipefail
# shopt -s inherit_errexit || true

# trap 'sk-catch --exit_code $? --line $LINENO --linecallfunc "$BASH_COMMAND" --funcstack $(printf "::%s" ${FUNCNAME[@]}) -o stdout --keyevent' ERR

# NOTE: ERR used not exit keeps the $LINENO var so we have to exit. EXIT also fails on if statements that fail
# NOTE: unbound var errors only send their error to stderr. To capture that you will need to handle stderr like this
# exec 2> >(sk-logger-stderr-keyevent)
# or
# exec 2> >(sk-logger-stderr)

sk-catch(){
  sk_help "Usage: $FUNCNAME


    Description:
      catch errors in bash via trap and various bash standard variables. Output to various things

    Options:
        -e | --exit_code )
        -l | --line )
        -lc | --linecallfunc )
        -c | --command )
        -f | --funcstack )
        -o | --output )  stdout or stderr
        -k | --keyevent ) also send
        -g | --opsgenie )


" "$@" && return

  local exit_code=0 line=0 linecallfunc='' command='' expanded_command='' output=stdout opsgenie=0 keyevent=0 pagerduty=0

  # Cludge to keep the NAME of a passed in script when using cronwrappers
  NAME=${NAME:-''}

  # don't error a second time on unset variables
  set +u
  # don't error a second time on failing commands
  set +e

  while :
  do
    case ${1-default} in
        -e | --exit_code ) exit_code=$2 ; shift 2;;
        -l | --line ) line=$2 ; shift 2;;
        -lc | --linecallfunc ) linecallfunc=$2 ; shift 2;;
        -c | --command ) command=$2 ; shift 2;;
        -f | --funcstack ) funcstack=$2 ; shift 2;;
        -o | --output ) output=$2 ; shift 2;;
        -k | --keyevent ) keyevent=1 ; shift ;;
        -g | --opsgenie ) opsgenie=1 ; shift ;;
        -p | --pagerduty ) pagerduty=1 ; shift ;;
        *)  break ;;
    esac
  done
  local expanded_command=$(eval echo "$command")

  if [[ "$funcstack" != "::" ]]; then
    error_stack="$error_stack   ... Error at ${funcstack} "
  fi

  error_stack="ERROR: $NAME line $line - command: '$command' expanded: '$expanded_command' errored with status: $exit_code linecallfunc $linecallfunc"

  # always log errors
  log "$error_stack"

  if [[ "$output" = 'stdout' ]];then
    echo "$error_stack"
  fi

  if [[ "$output" = 'stderr' ]];then
    2>& echo "$error_stack"
  fi

  if [[ "$keyevent" -eq 1 ]];then
    keyevent "$error_stack"
  fi

  if [[ "$opsgenie" -eq 1 ]];then
    sk-opsgenie-p4-alert --message "$error_stack"
  fi

  if [[ "$pagerduty" -eq 1 ]];then
    sk-pagerduty-event --summary "$error_stack" --group prod_minor
  fi

  exit $exit_code
}

# deactivate with
# set +eE

