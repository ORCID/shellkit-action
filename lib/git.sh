export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWCOLORHINTS=1
export GIT_PS1_SHOWUNTRACKEDFILES=1

alias gr='git restore'
alias gb='git branch'
alias gp='git push'
alias gs='git status -s'
alias ga='git add '
alias gaa='git add -A'

alias gbs='sk-git-branch-create-switch'

alias gd='git diff'
alias gco='git checkout '
alias gk='gitk --all&'
alias gx='gitx --all'
alias grm='git rebase master'
alias gmm='git merge master'
alias gnb='sk-git-create-local-remote-branch '
alias gbn='sk-git-create-local-remote-branch '
alias gbc='sk-git-create-local-remote-branch '
alias nb='sk-git-create-local-remote-branch '
alias cb='sk-git-create-local-remote-branch '
alias sw='git switch '

alias gcm='sk-git-checkout-default'
alias gbm='sk-git-checkout-default'

alias gcd='sk-git-checkout-dev'
alias gbd='sk-git-checkout-dev'

alias gbl=sk-git-branch-last
alias gbll=sk-git-branch-last-last
alias gcll=sk-git-branch-last-last

alias gcl=sk-git-branch-last



alias got='git '
alias get='git '
alias gl='git pull'
alias gu='git pull'

alias sk-git-delete-local-branch="git branch -D "
alias sk-git-delete-remote-branch="git push origin --delete "
alias sk-git-create-local-branch="git checkout -b "
alias gci="sk-git-commit-id"
alias gc="sk-git-commit"
alias gcn="sk-git-commit-no-verify"


# FIXME: what use case?
alias gau="git ls-files -o --exclude-standard | xargs -i git add '{}'"

alias gt=sk-git-tag

alias pci=sk-git-pre-commit-install

alias grl=sk-git-rebase-last

alias gbpt=sk-git-branch-pr-merge-test

sk-git-branch-delete-local-remote(){
  local branch=${1:-wibble}
  git checkout main
  git push --delete origin $branch
  git branch -D $branch
}

sk-git-branch-pr-merge-test(){
  gcd
  branch_id="gha-dummy-$(( ( RANDOM % 100 )  + 1 ))"
  branch_name="fix/$branch_id"
  sk-git-branch-create-switch $branch_name
  touch trigger_github_action
  echo "$branch_id" >> trigger_github_action
  git add trigger_github_action
  git commit -m "$branch_id"
  git push
  pr
  gh pr merge -m
  gcd
}

sk-git-log-latest-merge(){
  git log --merges -n 1
}

sk-git-branch-create-switch(){
  local branch=${1:-feat/blar}
  git pull
  git branch $branch
  git switch $branch
}

sk-git-restore(){
  git restore
}

sk-git-restore-deleted(){
  for files in `git -c color.status=false status -s | grep 'D ' | awk '{print $2}'`;do
    git restore
  done
}

alias sk-git-branch-list-ui=sk-git-switch-recent

sk-git-switch-recent(){

  TMP_FILE=/tmp/selected-git-branch

  eval `resize`
  sk-pack-install -b dialog -p dialog
  dialog --title "Recent Git Branches" --menu "Choose a branch" $LINES $COLUMNS $(( $LINES - 8 )) $(git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short) %(committerdate:short)') 2> $TMP_FILE

  if [[ "$?" -eq 0 ]];then
    git checkout $(< $TMP_FILE)
  fi

  rm -f $TMP_FILE

  clear
}

alias gsr=sk-git-switch-recent

sk-git-rebase-last(){
  git rebase -i HEAD~1
}

sk-git-branch-to-type(){
  current_branch=$(sk-git-current-branch-tag)
  if grep -q '/' <<< $(echo $current_branch);then
    echo $current_branch | awk -F '/' '{print $1}'
  else
    echo "empty"
  fi
}

sk-git-status-to-type(){
  local git_status=$(git -c color.status=false status -s)
  if grep -q 'D ' <<< $(echo $git_status);then
    echo "refactor"
  elif grep -q '??' <<< $(echo $git_status);then
    echo "feat"
  fi
}

sk-git-diff-to-type(){
  git_diff=$(git diff --stat)

}


lcl(){
  echo "lazycommit into the last commit"
  lc -t rebase $@
}

lcb(){
  echo "lazycommit with bug type"
  lc -t empty $@
}

lce(){
  echo "lazycommit with empty type. This will not show up in changelogs"
  lc -t empty $@
}

lcc(){
  echo "lazycommit with chore type"
  lc -t chore $@
}

lcr(){
  echo "lazycommit with refactor type"
  lc -t refactor $@
}

_git-commit-type(){
  local commit_type=$(sk-git-branch-to-type)

}

#
# commit_type defaults
# - branch name <type>/asdfasdfsadf
# - if commit is adding [feat]
# - if commit is deleting [refactor]

lc(){

  current_branch=$(sk-git-current-branch-tag)

  local commit_type=$(sk-git-branch-to-type)

  local lc_dir="/tmp/$(basename `pwd`)/$current_branch"

  sk-dir-make $lc_dir

  if sk-file-older-than $lc_dir/pull.state 1;then
    # attempt to pull any changes that were made elsewhere
    git pull origin "$current_branch" > $lc_dir/pull.state
  fi

  while :
  do
    case ${1-default} in
        -t | --type )          commit_type=$2 ; shift 2;;
        -a | --add )           add=1 ; shift ;;
        -v | --verbose )       VERBOSE=$((VERBOSE+1)); shift ;;
        *)  break ;;
    esac
  done

  local git_status_output=$(git -c color.status=false status --short)
  echo "$git_status_output"


  echo "commit_type=$commit_type"
  echo "-------------------------"

  if echo "$status_store" | grep -q "Untracked files";then
    commit_type="feat"
  fi

#   if sk-prompt-confirm "Do you want to add these modified files?";then
#     git add .
#   fi

  modified=''
  if modified=$(grep -q ' M ' <<< $(echo $git_status_output));then
    if [[ "$modified" != '' ]];then
      if sk-prompt-confirm "Do you want to add these modified files: $modified";then
        git add .
      fi
    fi
  fi

}

lf(){
  git add .
  sk-git-commit-feature $@
  git push
}

fe(){
  git commit -m "feat: $@"
  git push
}

sk-git-commit-feature(){
  git commit -m "feat: $@"
}

sk-git-commit-bugfix(){
  git commit -m "bugfix: $@"
  git push
}

sk-git-commit-bugfix(){
  git commit -m "bugfix: $@"
  git push
}

sk-git-reset-x(){
  git reset --hard HEAD~${1:-1}
}

sk-git-switch-last(){
  git switch @{-1}
}

sk-git-switch-last-last(){
  git switch @{-2}
}

sk-git-pre-commit-install(){
  pre-commit install --allow-missing-config
}

sk-git-branch-empty(){
  local new_branch=${1:-new_branch}
  git switch --orphan $new_branch
  git commit --allow-empty -m "Initial commit on orphan branch"
  git push -u origin $new_branch
}

sk-git-branch-last(){
  git switch -
}

sk-git-branch-last-last(){
  last_last_branch=$(git for-each-ref --count=30 --sort=-committerdate refs/heads/ --format='%(refname:short)' | grep -v main | head -n3 | tail -n1)
  git switch $last_last_branch
}

_sk-git-url-to-repo(){
  local git_url=${1:-git@github.com:ORCID/wibble.git}
  echo "$git_url" | perl -ne '/\/(.*?)\.git/ && print $1;'
}

_sk-git-url-to-namespace(){
  local git_url=${1:-git@github.com:ORCID/wibble.git}
  echo "$git_url" | perl -ne '/:(.*?)\// && print $1;'
}

sk-git-track(){
  git branch --set-upstream-to=origin/$(git branch --show-current)
}

sk-gitflow-branch(){
  local branch=${1:-feature/wibble}
  if sk-git-checkout-dev;then
    sk-git-create-local-remote-branch "$branch"
  else
    echo "FATAL: failed to change to base branch gf_base_branch"
    return 1
  fi
}

sk-git-tag-latest(){
  git describe --tags --abbrev=0
}

sk-git-tag-latest-remote(){
  local remote_repo=${1:-https://github.com/asdf-vm/asdf}
  git ls-remote --tags $remote_repo | \
  grep -o 'refs/tags/[^^{}]*$' | \
  sed 's#refs/tags/##' | \
  sort -V | \
  tail -n 1
}

### SAFER LAZY GIT
lazygit-bash() {
  git add .
  if git commit -a -m "$1"; then
    read -r -p "Are you sure you want to push these changes? [y/N]} " response
    case "$response" in
      [yY][eE][sS]|[yY])
        git push
        ;;
      *)
        git reset HEAD~1 --soft
        echo "Reverted changes."
        ;;
    esac
  fi
}


sk-git-checkout-default(){
  git fetch --all
  git checkout $(sk-git-default-branch)
  git pull
}

sk-git-checkout-dev(){
  sk-gitflow-conf
  git fetch --all
  git checkout $gf_base_branch
  git pull
}

sk-git-private-key-session(){
  sk_help "Usage: $FUNCNAME <private_key>. Change the GIT_SSH_COMMAND for a bash session to use a private key different to your default. NOTE key must be added to the ssh keychain too" "$@" && return
  local private_key=$1
  export GIT_SSH_COMMAND="ssh -i $private_key -o IdentitiesOnly=yes -F /dev/null"
}

sk-git-private-key(){
  sk_help "Usage: $FUNCNAME <private_key>. Change a repo to use a different private key (account) in github. NOTE key must be added to the ssh keychain too" "$@" && return
  local private_key=$1
  git config core.sshCommand "ssh -i $private_key -F /dev/null"
}

_sk-git-keygen(){
  local repo='' git_dir=''
  while :
  do
    case ${1-default} in
        -r | --repo ) local repo=$2 ; shift 2;;
        -g | --git_dir ) local git_dir=$2 ; shift 2;;
        *)  break ;;
    esac
  done

  if [[ ! -z "$git_dir" ]] && [[ -f "$git_dir/.git/config" ]];then
    repo=$(perl -ne '/url = (.*)$/ && print $1' $git_dir/.git/config)
  fi

  git_host=$(echo "$repo" | perl -ne '/@(.*):/ && print $1')
  ssh-keygen -F $git_host >/dev/null || ssh-keyscan $git_host >>~/.ssh/known_hosts
}


sk-sk-git-ubuntu-update(){
  sudo add-apt-repository ppa:sk-git-core/ppa
  sudo apt-get update
  sudo apt-get -y install git
}

sk-git-remove-file(){
  git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch $1" \
  --prune-empty --tag-name-filter cat -- --all
}

sk-git-add-modified(){
  # N.B git add -u
  for file in `git status | grep modified | awk '{print $3}'`;do git add $file ;done
}

sk-git-remove-modified(){
  git checkout .
}

sk-git-remove-untracked(){
  git clean -fd
}

sk-git-copy-current-branch(){
  git fetch --all
  old_branch=$(git rev-parse --abbrev-ref HEAD)
  git checkout $1 $old_branch
}

sk-git-create-remote-branch(){
  git checkout -b $1
  git push origin $1
}

sk-git-create-local-remote-branch(){
  sk-git-create-remote-branch $1
  git checkout $1
}

sk-git-commit-no-verify(){
  [ -z "$@" ] && echo "Provide a commit description" && return
  git commit --no-verify -m "$@"
}

sk-git-commit(){
  [ -z "$@" ] && echo "Provide a commit description" && return
  git commit -m "$@"
}

sk-git-commit-id(){
  [ -z "$@" ] && echo "Provide a commit description" && return
  id_from_branch=$(echo "$(git rev-parse --abbrev-ref HEAD)" | sed 's/^.*\///')
  git commit -m "${id_from_branch}: $@"
}

sk-git-add-modified-and-deleted(){
  git add -u
}

sk-git-unstage-file(){
  [ -z "$@" ] && echo "Provide a staged file ready for commit" && return
  git reset -- $@
}

sk-git-undelete-file(){
  [ -z "$@" ] && echo "Provide a staged file ready for commit" && return
  git reset -- $@
  git checkout $@
}

sk-git-merge-main-to-branch(){
  git fetch origin
  git merge origin/main
}

sk-git-merge-branch-to-main(){
  id_from_branch="$(git rev-parse --abbrev-ref HEAD)"
  git checkout main
  git fetch origin
  git merge origin/${id_from_branch}
  echo "edit any unstaged files manually to resolve conflict"
  echo "or git checkout --theirs <file> to accept from master branch"
  echo "or git checkout --ours <file> to accept from our branch"
  echo "then git commit -m '${id_from_branch}: merging to master"
  echo "then run: git push origin master"
}

sk-git-commit-force(){
  mkfile .dummy
  echo "$@" >> .dummy
  git add .dummy
  git commit -m "Forced commit: $@"
  git push
}

sk-git-merge-branch-to-main-auto(){
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  git checkout main
  git pull origin main
  git merge $current_branch
  git push origin main
  git checkout $current_branch
}

sk-git-branch-config-source(){
  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  local git_top_level=$(git rev-parse --show-toplevel)

  local git_branch_config="${git_top_level}/.git/${current_branch}"
  if [[ ! -f "$git_branch_config" ]];then
    mkfile "$git_branch_config"
  fi
  source $git_branch_config
}

sk-git-branch-config-add(){
  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  local git_top_level=$(git rev-parse --show-toplevel)

  local git_branch_config="${git_top_level}/.git/${current_branch}"

  if [[ ! -f "$git_branch_config" ]];then
    mkfile "$git_branch_config"
  fi

  echo "$@" >> $git_branch_config
}

sk-git-add-remote-repo-to-current(){
  sk_help "Usage: $FUNCNAME <repo to add> <directory_in_local_repo_to_create>(default is the reponame) Merge another repo into the current checked out repo. e.g https://github.com/example/example dir/to/save. NOTE git push is required after combining." "$@" && return
  local repo="$1"
  local reponame=${2:-$(echo $repo | perl -ne '/:(.*)\.git/ && print $1;')}
  local dir="$(echo "$reponame" | sed 's/\/$//')"

  path="$(pwd)"

  # tmp area to work on repo
  tmp="$(mktemp -d)"

  # ensure remote name has no illegal chars in it
  remote="$(echo "$tmp" | sed 's/\///g'| sed 's/\./_/g')"
  git clone "$repo" "$tmp"

  # put complex filter into file
  # this filter updated the path of files to have a prepended directory
  # ready for the files new location in the merged repo
echo '
#!/usr/bin/env bash
git ls-files -s | \
    sed "s,\t,&'"$dir"'/," | \
    GIT_INDEX_FILE="$GIT_INDEX_FILE.new" git update-index --index-info

mv "$GIT_INDEX_FILE.new" "$GIT_INDEX_FILE" || true' > ~/sk-git-add-filter
  chmod +x ~/sk-git-add-filter


  cd $tmp
  echo git filter-branch -f --index-filter '~/sk-git-add-filter' HEAD
  git filter-branch -f --index-filter '~/sk-git-add-filter' HEAD

  cd "$path"
  git remote add -f "$remote" "file://$tmp/.git"
  git pull $remote master --allow-unrelated-histories --no-edit
  git merge --allow-unrelated-histories -m "Merge repo $repo into master" --no-edit
  git remote remove "$remote"
  rm -rf "$tmp"
}

_git_bfg_bootstrap(){
  if [[ ! -x /usr/local/bin/bfg ]];then
    sudo mkdir /usr/local/bin
    sudo curl -o /usr/local/bin/bfg.jar https://repo1.maven.org/maven2/com/madgag/bfg/1.13.0/bfg-1.13.0.jar
    sudo bash -c "echo 'java -jar /usr/local/bin/bfg.jar "\$\@"' > /usr/local/bin/bfg"
    sudo chmod 755 /usr/local/bin/bfg
  fi
}

sk-git-backup-remote-repo(){
  sk_help_noarg "Usage: $FUNCNAME <reponame.git> <local_dir>." "$@" && return
  git clone --mirror $1 $2
}

sk-git-permanently-remove-file-based-on-size(){
  sk_help_noarg "Usage: $FUNCNAME <reponame.git> <size>(100M). Remove a file using BFG tool from a git repo to allow importing to github. Checkout repo with git clone --mirror <reponame>. You will get a chance to review the final push." "$@" && return
  _git_bfg_bootstrap
  current_dir=`pwd`
  local reponame=${1:-wibble.git}
  local filesize=${2:-100M}
  echo bfg --strip-blobs-bigger-than $filesize $reponame
  bfg --no-blob-protection -b $filesize $reponame

  echo "NO CHANGE HAS BEEN PUSHED YET"
  echo "Review the logs"
  echo "then run"
  echo "cd $reponame; git reflog expire --expire=now --all && git gc --prune=now --aggressive ; git push ; cd .."
}

sk-git-permanently-remove-file-based-on-size-noprompt(){
  sk_help_noarg "Usage: $FUNCNAME <reponame.git> <size>(100M). Remove a file using BFG tool from a git repo to allow importing to github. Checkout repo with git clone --mirror <reponame>.WARNING !!!! this will push to the repo with no prompt." "$@" && return
  _git_bfg_bootstrap
  current_dir=`pwd`
  local reponame=${1:-wibble.git}
  local filesize=${2:-100M}
  echo bfg --strip-blobs-bigger-than $filesize $reponame
  bfg --no-blob-protection -b $filesize $reponame
  cd $reponame; git reflog expire --expire=now --all && git gc --prune=now --aggressive ; git push ; cd ..
}


sk-git-find-file(){
  git log --all --name-only --full-history  | grep -b5 $1
}

sk-git-clone-fetch(){
  current_dir=`pwd`
  local repo=${1:-wibble}
  local reponame=${2:-$(echo $repo | perl -ne '/\/(.*)\.git/ && print $1;')}
  _sk-git-keygen -r $repo
  verbose_log "$repo --> $reponame"
  if [[ -d "$reponame" ]];then
    cd $reponame
    git fetch --all
  else
    git clone $repo $reponame --quiet
  fi
  cd $current_dir
}

sk-git-changed(){
  current_dir=`pwd`
  git_dir=${1:-.}
  cd $git_dir
  status=`git status --porcelain`
  cd $current_dir
  if [[ -z "$status" ]];then
    # no changes
    return 1
  else
    return 0
  fi
}

sk-git-show-latest-branch(){
  current_dir=`pwd`
  git_dir=${1:-.}
  match_pattern=${2:-.\*}
  cd $git_dir
  branch=`git branch -r | sed -e 's!origin/!!g' | grep -v master | tr -d ' ' | grep -P "$match_pattern" | sort -n |tail -n1`
  cd $current_dir
  echo "$branch"
}

# test a git repo for a branches existance
sk-git-test-for-branch(){
  current_dir=`pwd`
  git_dir=${1:-.}
  branch=$2
  return_code=1
  cd $git_dir
  git branch -r | sed -e 's/.*master.*//' | tr -d '\n' | sed -e 's!origin/!!g' | grep -q " $branch"
  return_code=$?
  cd $current_dir
  return $return_code
}

sk-git-checkout-latest-numeric-branch(){
  current_dir=`pwd`
  git_dir=${1:-.}
  match_pattern=${2:-.\*}
  cd $git_dir
  git fetch --all
  branch=`git branch -r | sed -e 's!origin/!!g' | grep -v master | tr -d ' ' | grep -P "$match_pattern" | sort -n |tail -n1`
  
  git checkout $branch --quiet
  cd $current_dir
}


sk-git-commit-changes-git_dir(){
  current_dir=`pwd`
  git_dir=${1:-.}
  message=${2:-commit}
  cd $git_dir
  git add *
  git commit -m "$message"
  git push
  cd $current_dir
}

sk-git-repo-name(){
  echo "$@" | perl -ne '/\/(.*)\.git/ && print $1'
}

sk-git-clone(){
  USER=$(whoami) ; local git_dir=unset tag=unset  patch=0 source_branch=default

  sk_help "Usage: $FUNCNAME <options>

    Description: clone a repo if it doesn't already exist
    Options:
        -r | --repo  git repo
        -g | --git_dir ) git_dir location or /var/tmp/repo_name.user
        -t | --tag ) tag to checkout, if it exists
        -p | --patch ) assume the repo already has a branch checked out and add any files nasty
        -sb | --source_branch ) source branch to use when a tag doesn't exist
" "$@" && return

  while :
  do
    case ${1-default} in
        -r | --repo ) local repo=$2 ; shift 2;;
        -g | --git_dir ) local git_dir=$2 ; shift 2;;
        -t | --tag ) local tag=$2 ; shift 2;;
        -sb | --source_branch ) local source_branch=$2 ; shift 2;;
        -p | --patch ) local patch=1 ; shift ;;
        -v | --verbose )        VERBOSE=$((VERBOSE+1)); shift ;;
        *)  break ;;
    esac
  done



  if [[ $git_dir = 'unset' ]];then
    repo_name=$(sk-git-repo-name $repo)
    git_dir="/var/tmp/$repo_name.$USER"
  fi

  _sk-git-keygen -r $repo -g $git_dir

  if [[ ! -d ${git_dir}/.git ]];then
    echo "cloning repo $repo"
    git clone "$repo" "$git_dir"
    # 1>/dev/null 2>&1
  fi

}

sk-git-pull(){
  USER=$(whoami) ; local git_dir=unset tag=unset  patch=0 source_branch=default

  sk_help "Usage: $FUNCNAME <options>

    Description: clone a repo if it doesn't already exist
    Options:
        -r | --repo  git repo
        -g | --git_dir ) git_dir location or /var/tmp/repo_name.user
        -t | --tag ) tag to checkout, if it exists
        -p | --patch ) assume the repo already has a branch checked out and add any files nasty
        -sb | --source_branch ) source branch to use when a tag doesn't exist
" "$@" && return

  while :
  do
    case ${1-default} in
        -r | --repo ) local repo=$2 ; shift 2;;
        -g | --git_dir ) local git_dir=$2 ; shift 2;;
        -t | --tag ) local tag=$2 ; shift 2;;
        -sb | --source_branch ) local source_branch=$2 ; shift 2;;
        -p | --patch ) local patch=1 ; shift ;;
        -v | --verbose )        VERBOSE=$((VERBOSE+1)); shift ;;
        *)  break ;;
    esac
  done


  if [[ $git_dir = 'unset' ]];then
    repo_name=$(sk-git-repo-name $repo)
    git_dir="/var/tmp/$repo_name.$USER"
  fi

  if [[ ! -d "${git_dir}/.git" ]];then
    echo "cloning repo $repo"
    git clone "$repo" "$git_dir"
    # 1>/dev/null 2>&1
  fi

  _sk-git-keygen -r $repo -g $git_dir

  git -C $git_dir pull --no-edit || true

}

sk-git-clone-checkout-patch(){
  USER=$(whoami) ; local git_dir=unset tag=unset  patch=0 source_branch=default

  sk_help "Usage: $FUNCNAME <options>

    Description: this is horrible function that does lots of things and probably should be split up.
    Options:
        -r | --repo  git repo
        -g | --git_dir ) git_dir location or /var/tmp/repo_name.user
        -t | --tag ) tag to checkout, if it exists
        -p | --patch ) assume the repo already has a branch checked out and add any files nasty
        -sb | --source_branch ) source branch to use when a tag doesn't exist
" "$@" && return

  while :
  do
    case ${1-default} in
        -r | --repo ) local repo=$2 ; shift 2;;
        -g | --git_dir ) local git_dir=$2 ; shift 2;;
        -t | --tag ) local tag=$2 ; shift 2;;
        -sb | --source_branch ) local source_branch=$2 ; shift 2;;
        -p | --patch ) local patch=1 ; shift ;;
        -v | --verbose )        VERBOSE=$((VERBOSE+1)); shift ;;
        *)  break ;;
    esac
  done


  if [[ $git_dir = 'unset' ]];then
    repo_name=$(sk-git-repo-name $repo)
    git_dir="/var/tmp/$repo_name.$USER"
  fi

  _sk-git-keygen -r $repo -g $git_dir

  if [[ ! -d "${git_dir}/.git" ]];then
    echo "cloning repo $repo"
    git clone "$repo" "$git_dir"
    # 1>/dev/null 2>&1
  fi

  if [[ "$source_branch" == 'default' ]];then
    source_branch=$(sk-git-default-branch -g $git_dir)
  fi

  if [[ "$patch" -eq 1 ]];then
    verbose "Creating a patch release on $git_dir"
    git -C $git_dir add --all
    return
  fi

  if sk-git-branch-tag-exists -g $git_dir -t $tag;then
    git -C $git_dir reset --hard
    git -C $git_dir fetch --all
    git -C $git_dir checkout $tag
    git -C $git_dir pull --no-edit || true
  else
    # FIXME: what is the correct way to checkout a branch or tag?
    git -C $git_dir reset --hard
    git -C $git_dir fetch --all
    git -C $git_dir checkout $source_branch
    git -C $git_dir pull --no-edit || true
  fi

}

sk-git-current-branch-tag(){
  git symbolic-ref -q --short HEAD || git describe --tags --exact-match
}

sk-git-set-git-dir(){
  local git_repo=${1:-wibble}
  export GIT_DIR=$(sk-readlink-f $git_repo)
}

sk-git-default-branch(){
  local git_dir=. tag=default
  sk_help "Usage: $FUNCNAME <options>
    Options:
        -r | --repo  git repo
        -g | --git_dir ) git_dir location or /var/tmp/repo_name.user
        -t | --tag ) tag or branch to use or default (main or master)
" "$@" && return

  while :
  do
    case ${1-default} in
        -r | --repo ) local repo=$2 ; shift 2;;
        -g | --git_dir ) local git_dir=$2 ; shift 2;;
        -v | --verbose )        VERBOSE=$((VERBOSE+1)); shift ;;
        *)  break ;;
    esac
  done

  if sk-git-branch-tag-exists -g $git_dir -t main >/dev/null;then
    echo 'main'
  else
    echo 'master'
  fi
}

sk-git-dev-branch(){
  local git_dir=. tag=default
  sk_help "Usage: $FUNCNAME <options>
    Options:
        -r | --repo  git repo
        -g | --git_dir ) git_dir location or /var/tmp/repo_name.user
        -t | --tag ) tag or branch to use or default (main or master)
" "$@" && return

  while :
  do
    case ${1-default} in
        -r | --repo ) local repo=$2 ; shift 2;;
        -g | --git_dir ) local git_dir=$2 ; shift 2;;
        -v | --verbose )        VERBOSE=$((VERBOSE+1)); shift ;;
        *)  break ;;
    esac
  done

  local git_branches=$(git -C $git_dir for-each-ref --format='%(refname:short)' refs/heads/)

   case $git_branches in
    *main*) echo 'main' ;;
    *development*) echo 'development' ;;
    *develop*) echo 'develop';;
    *master*) echo 'master' ;;
   esac
}


sk-git-branch-tag-exists(){
  local git_dir=. tag=default
  sk_help "Usage: $FUNCNAME <options>
    Options:
        -r | --repo  git repo
        -g | --git_dir ) git_dir location or /var/tmp/repo_name.user
        -t | --tag ) tag or branch to use or default (main or master)
" "$@" && return

  while :
  do
    case ${1-default} in
        -g | --git_dir )        local git_dir=$2 ; shift 2;;
        -v | --verbose )        VERBOSE=$((VERBOSE+1)); shift ;;
        -t | --tag )            local tag=$2 ; shift 2;;
        *)  break ;;
    esac
  done
  local remote_branch=''
  # default is we hope they already exist
  if git -C "$git_dir" rev-parse $tag >/dev/null 2>&1;then
    return 0
  elif remote_branch=$(git -C "$git_dir" ls-remote --heads origin $tag 2>/dev/null );then
    if [[ ! -z "$remote_branch" ]];then
      return 0
    fi
  fi

  # attempt to download latest
  sk-git-fetch-branch-tag -g $git_dir

  if git -C "$git_dir" rev-parse $tag >/dev/null 2>&1;then
    return 0
  elif remote_branch=$(git -C "$git_dir" ls-remote --heads origin $tag 2>/dev/null );then
    if [[ ! -z "$remote_branch" ]];then
      return 0
    else
      return 1
    fi
  fi


}

sk-git-fetch-branch-tag(){
  local git_dir=. tag=default
  sk_help "Usage: $FUNCNAME <options>
    Options:
        -r | --repo  git repo
        -g | --git_dir ) git_dir location or /var/tmp/repo_name.user
        -t | --tag ) tag or branch to use or default (main or master)
" "$@" && return

  while :
  do
    case ${1-default} in
        -g | --git_dir )        local git_dir=$2 ; shift 2;;
        -v | --verbose )        VERBOSE=$((VERBOSE+1)); shift ;;
        *)  break ;;
    esac
  done

  _sk-git-keygen -g $git_dir
  git -C $git_dir fetch --all --tags -f
}

sk-git-tag-delete(){
  local tag=${1:-wibble}
  git push --delete origin $tag
  git tag -d $tag
}

sk-git-tag(){
  local git_dir=. tag=default
  sk_help "Usage: $FUNCNAME <options>
    Options:
        -r | --repo  git repo
        -g | --git_dir ) git_dir location or /var/tmp/repo_name.user
        -t | --tag ) tag or branch to use or default (main or master)
" "$@" && return

  while :
  do
    case ${1-default} in
        -r | --repo )           local repo=$2 ; shift 2;;
        -g | --git_dir )        local git_dir=$2 ; shift 2;;
        -t | --tag )            local tag=$2 ; shift 2;;
        -v | --verbose )        VERBOSE=$((VERBOSE+1)); shift ;;
        *)  break ;;
    esac
  done

  if [[ $tag == 'default' ]];then
    tag=$(sk-git-current-branch-tag -g $git_dir)
    echo $tag
    return
  fi

  if sk-git-branch-tag-exists -g $git_dir -t $tag;then
    verbose "$tag exists"
    echo $tag
    return
  else
    git -C $git_dir tag $tag
    git -C $git_dir push origin $tag
    echo $tag
    return
  fi
}

sk-git-fetch-or-tag(){
  local git_dir=. tag=default
  sk_help "Usage: $FUNCNAME <options>
    Options:
        -r | --repo  git repo
        -g | --git_dir ) git_dir location or /var/tmp/repo_name.user
        -t | --tag ) tag or branch to use or default (main or master)
" "$@" && return

  while :
  do
    case ${1-default} in
        -r | --repo )           local repo=$2 ; shift 2;;
        -g | --git_dir )        local git_dir=$2 ; shift 2;;
        -t | --tag )            local tag=$2 ; shift 2;;
        -v | --verbose )        VERBOSE=$((VERBOSE+1)); shift ;;
        *)  break ;;
    esac
  done

  if [[ $tag == 'default' ]];then
    tag=$(sk-git-current-branch-tag -g $git_dir)
    echo $tag
    return
  fi

  if sk-git-branch-tag-exists -g $git_dir -t $tag;then
    git -C $git_dir fetch --all
    git -C $git_dir checkout $tag >/dev/null 2>&1
    echo $tag
    return
  else
    git -C $git_dir tag $tag >/dev/null 2>&1
    echo $tag
    return
  fi
}
