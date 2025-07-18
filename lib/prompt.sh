# confirm "Would you really like to do a X?" && run_x || exit
# use return rather than exit if bash function
# NOTE: this will not work in a loop that is using read, use for loops instead with an altered IFS.
sk-prompt-confirm() {
  read -r -p "${1:-Are you sure? [Y/n]} " response
  case $response in
    [yY][eE][sS]|[yY])
      true
    ;;
    [n])
      false
    ;;
    *)
      true
    ;;
  esac
}

sk-prompt-confirm-timeout() {
  read -r -t 5 -p "${1:-Are you sure? [Y/n]} " response || return 1
  case $response in
    [yY][eE][sS]|[yY])
      true
    ;;
    [n])
      false
    ;;
    *)
      true
    ;;
  esac
}



