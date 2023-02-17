GITHUB_SECRET_FILE_DEFAULT="~/.github"

alias ghl="gh workflow list"
alias ghpr="gh pr create"

alias al=sk-github-actionlint
alias ghal=sk-github-actionlint

sk-github-actionlint(){
  local file=${1:default}
  sk-asdf-install actionlint -p actionlint -v 1.6.15 --plugin_git_url git@github.com:crazy-matt/asdf-actionlint.git
  files=$(git  -c color.status=always status -sb --ignore-submodules=dirty | grep .github | awk '{print $2}')
  for file in $files; do
    actionlint $file
  done
}

# configure git on a github runner
sk-github-runner-setup(){
  if printenv GITHUB_REF_NAME;then
    git config --global user.email "actions@github.com"
    git config --global user.name "github actions"
    repository_url="https://github.com/$GITHUB_REPOSITORY"
  fi
}

sk-gitflow-conf(){
  if [[ -f ".gitflow" ]];then
    source .gitflow
  else
    gf_base_branch=$(sk-git-dev-branch)
  fi
}

alias gfi=sk-github-flow-init

sk-github-flow-init(){
  sk-asdf-install gh -p github-cli -v 2.13.0
  sk-gitflow-conf
  _sk-github-config $(sk-github-org)

  if ! sk-git-branch-tag-exists -t $gf_base_branch;then
    git checkout main
    git pull
    sk-git-create-local-remote-branch $gf_base_branch
  fi

}

_sk-github-pr-number-branch(){
  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  _sk-github-config $(sk-github-org)
  sk-asdf-install jq -p jq -v 1.6
  gh pr list --json "number,title" | jq -r '.[]| select(.title == "'"$current_branch"'").number'
}

_sk-github-pr-url-branch(){
  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  _sk-github-config $(sk-github-org)
  sk-asdf-install jq -p jq -v 1.6
  gh pr list --json "url,title" | jq -r '.[]| select(.title == "'"$current_branch"'").url'
}

alias prp=sk-gitgub-pr-poke
alias poke=sk-gitgub-pr-poke

sk-gitgub-pr-poke(){
  sk-asdf-install gh -p github-cli -v 2.13.0
  pr_url=$(_sk-github-pr-url-branch)
  if [[ "$pr_url" == '' ]];then
    sk-github-pr-create
    pr_url=$(_sk-github-pr-url-branch)
  fi

  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  sk-trello-config-source

  echo "Can someone merge my pr please for $current_branch? $pr_url" | slacktee --no-output --channel $github_poke_slack_channel --username $(whoami)
}

sk-github-pr-merge(){
  sk-asdf-install gh -p github-cli -v 2.13.0
  pr_url=$(_sk-github-pr-url-branch)
  gh pr merge $pr_url --merge
}

alias review=sk-github-pr-review

sk-github-pr-review(){
  sk-asdf-install gh -p github-cli -v 2.13.0
  pr_url=$(_sk-github-pr-url-branch)

  if [[ "$pr_url" == '' ]];then
    sk-github-pr-create
    pr_url=$(_sk-github-pr-url-branch)
  fi

  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  sk-trello-config-source

  echo "Can someone review my pr please $current_branch? $pr_url" | slacktee --no-output --channel $github_poke_slack_channel --username $(whoami)
}

sk-github-repo-parent(){
  local github_url=$(git remote get-url origin)
  local namespace=$(_sk-git-url-to-namespace $github_url)
  local repo=$(_sk-git-url-to-repo $github_url)
  sk-asdf-install jq -p jq -v 1.6
  gh api -H "Accept: application/vnd.github+json" /repos/${namespace}/${repo} | jq -r .parent.git_url
}


sk-github-is-fork(){
  local github_url=$(git remote get-url origin)
  local namespace=$(_sk-git-url-to-namespace $github_url)
  local repo=$(_sk-git-url-to-repo $github_url)
  if grep -q 'fork' <<< $(gh repo list $namespace | grep $repo);then
    return 0
  else
    return 1
  fi
}

alias pr=sk-github-pr-create
sk-github-pr-create(){
  sk-asdf-install gh -p github-cli -v 2.13.0
  sk-gitflow-conf

  trello_id='unset'
  local github_reviewer_arg=''
  local current_branch=$(git rev-parse --abbrev-ref HEAD)

  local github_base_arg="--base $gf_base_branch"
  local github_title=$current_branch
  local github_body=.
  gitub_pr_default_reviewers='unset'

  sk_help "
    Usage: $FUNCNAME

    Description: Create a github pr either manually or by looking for a .git/branch_name file to source. Optionally link to trello cards.
      If no commits have been made on the branch yet make a .dummy file so the pr can be created

    Options:
        -t | --title)  title of the pr
        -b | --body)   body of the pr

    "  "$@" && return 1

  if [[ "$trello_id" != 'unset' ]];then
    sk-trello-id-parser
    github_body="$trello_details"
    github_title="$current_branch"

    if [[ "$gitub_pr_default_reviewers" != 'unset' ]];then
      github_reviewer_arg="--reviewer $gitub_pr_default_reviewers"
    fi
  fi

  if sk-github-is-fork ;then
    github_base_arg=''
    github_parent_url=$(sk-github-repo-parent)
    github_parent_namespace=$(_sk-git-url-to-namespace $github_parent_url)
    github_parent_repo=$(_sk-git-url-to-repo $github_parent_url)
    git config --local --unset "remote.origin.gh-resolved"
    echo "Select yes if you want a fork based on the parent repo $github_parent_url ?"
    if sk-prompt-confirm;then
      git config --local --add "remote.origin.gh-resolved" "${github_parent_namespace}/${github_parent_repo}"
      # we don't know the reviewers in parent repos
      github_reviewer_arg=""
    fi
  fi

  while :
  do
    case ${1-default} in
        -t | --title)  local github_title=$2; shift 2 ;;
        -b | --body)   local github_body=$2; shift 2 ;;
        -e | --reviewer)   local github_reviewer_arg="--reviewer $2"; shift 2 ;;
        -n | --no_reviewer)local github_reviewer_arg=""; shift ;;
        -nb | --no_base)   local github_base_arg=""; shift ;;
        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done

  _sk-github-config $(sk-github-org)
  sk-git-branch-config-source

  body_file="/tmp/sk-github-pr-create.$$"

  if [[ "$current_branch" != "$github_title" ]];then
    echo "creating new branch for our pr as $current_branch != $github_title"
    if ! sk-prompt-confirm;then
      return
    fi

    git checkout $gf_base_branch
    sk-git-create-local-remote-branch $github_title
  fi

  echo "$github_body" > $body_file

  pr_err_file=/tmp/pr_err_file.$USER
  mkfile $pr_err_file
  echo gh pr create $github_base_arg $github_reviewer_arg --title "$github_title" --body-file "$body_file"
  if ! pr_details=$(gh pr create $github_base_arg $github_reviewer_arg --title "$github_title" --body-file "$body_file" 2> $pr_err_file) ;then

    if grep -q between <<< "$(cat $pr_err_file)";then
      echo "WARN: forcing commit to allow pr creation"
      if ! sk-prompt-confirm;then
        return
      fi
      sk-git-commit-force "$github_title"
      pr_details=$(gh pr create $github_base_arg $gf_base_branch $github_reviewer_arg --title "$github_title" --body-file "$body_file" 2> $pr_err_file)
    else
      echo "unknown error" ; echo "pr creation failed with $(cat $pr_err_file)"; return
    fi
  fi
  echo "$pr_details"

  # map pr details to our branch ( we might not use a 1:1 mapping of names...)
  pr_url=$( echo $pr_details | grep \/pull)
  pr_number=$(echo $pr_url | perl -ne '/(\d+$)/ && print $1;')

  sk-git-branch-config-add pr_url=$pr_url
  sk-git-branch-config-add pr_number=$pr_number

  sk-github-pr-trello-comment
  sk-trello-github-pr-comment

  rm $body_file
}

sk-github-org(){
  echo $(git config --get remote.origin.url | perl -ne '/\:(.*?)\// && print $1')
}

sk-github-pr-trello-comment(){
  if [[ "$trello_id" != 'unset' ]];then
    sk-git-branch-config-source
    sk-trello-id-parser
    _sk-github-config $(sk-github-org)
    echo "Reference trello card in github PR"
    echo gh pr comment "$gh_number" --body "$trello_url"
    gh pr comment "$gh_number" --body "$trello_url"
  fi
}

_sk-git-test(){
  GITHUB_ORG=ORCID
}

sk-git-creds(){
  secret_format='
  GITHUB_USERNAME=

  GITHUB_TOKEN=
  GITLAB_TOKEN=
  GITLAB_HOST=
'
  sk_help "Usage: $FUNCNAME. Source bash variables from the target of the env variable GITHUB_SECRET_FILE. Format of secrets file:-
  $secret_format
  " "$@" && return
  [[ -z "$GITHUB_SECRET_FILE" ]] && GITHUB_SECRET_FILE="$GITHUB_SECRET_FILE_DEFAULT"
  eval GITHUB_SECRET_FILE=$GITHUB_SECRET_FILE

  if [[ -r "$GITHUB_SECRET_FILE" ]];then
    source $GITHUB_SECRET_FILE
  fi
  if [[ -z "$GITHUB_TOKEN" ]];then
    echo "FATAL: unable to source GITHUB_TOKEN from environment variables or GITHUB_SECRET_FILE file ($GITHUB_SECRET_FILE)
    Format of secrets file:-
      $secret_format
"
    return 1
  fi
}

alias ghw=sk-github-run-workflow-with-logs

sk-github-run-workflow-with-logs(){
  local workflow=${1:-default}
  _sk-github-config $(sk-github-org)
  gh workflow run $workflow
  latest_job_id=$(gh run list | head -1 | awk -F'\t' '{print $7}')
  gh run view $latest_job_id --log
}

sk-github-workflow-latest(){
  _sk-github-config
  latest_job_id=$(gh run list | head -1 | awk -F'\t' '{print $7}')
  gh run view $latest_job_id --log
}


_sk-github_curl(){
  curl -s -H "Accept: application/vnd.github.v3+json" -u "$GITHUB_USERNAME:$GITHUB_TOKEN"  "$@"
}

sk-github(){
  sk_help "Usage: $FUNCNAME. show schema" "$@" && return
  sk-git-creds
  _sk-github_curl https://api.github.com
}

sk-github-org-list-watchers(){
  local reponame=$1
  local output=''
  sk-git-creds
  output=`_sk-github_curl https://api.github.com/repos/$GITHUB_ORG/$reponame/subscribers`
  echo $output | jq -r '. [] | .login'
}

sk-github-org-unwatch(){
  local reponame=${1:-wibble}
  local output=''
  sk-git-creds
  output=`_sk-github_curl -X DELETE https://api.github.com/repos/$GITHUB_ORG/$reponame/subscription`
  echo $output | jq -r '.'
}

_sk-github-config(){
  github_org=${1:-default}
  if [[ "$github_org" = 'default' ]];then
    sk-config-read -c github.conf -v GITHUB_TOKEN
  else
    sk-config-read --fail_on_missing_config -c github.$github_org.conf -v GITHUB_TOKEN
  fi
  export GITHUB_TOKEN=$GITHUB_TOKEN
}

sk-github-runner-ips(){
  sk-asdf-install gh -p github-cli -v 2.13.0
  sk-asdf-install jq -p jq -v 1.6

  gh api -H "Accept: application/vnd.github+json" /meta | jq -r .actions | grep -E '[0-9]\/' | sed 's/["|,| ]//g' | sk-ip-merge
}

sk-github-runner-ips-nginx-allow(){
  sk-github-runner-ips | sk-ip-to-nginx-allow
}

sk-github-visibility(){
  local github_url=${1:-$(git config --get remote.origin.url)}

  local namespace=$(_sk-git-url-to-namespace $github_url)
  local repo=$(_sk-git-url-to-repo $github_url)
  _sk-github-config $namespace

  if $(gh repo list $namespace | grep $repo | grep -q 'public');then
    echo 'public'
  else
    # safe default
    echo 'private'
  fi

}

sk-github-migrate-repo(){
  local source=${1:-git@github.com:ORCID/wibble.git}
  local target=${2:-git@github.com:ORCID-dev/wibble.git}

  sk_help "
    Usage: $FUNCNAME

    Description:

      Migrate one repo to another creating the target repo if needed
        - list the source repo to get is private public settings

    Options:

    "  "$@" && return 1

  while :
  do
    case ${1-default} in
        -u | --url)           github_url=$2; shift 2 ;;
        -r | --target_url)    github_target_url=$2; shift 2 ;;
        -d | --description)   github_description=$2; shift 2 ;;
        -P | --public)        visibility='public'; shift 2 ;;

        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done

  ####### Do source things
  source_namespace=$(_sk-git-url-to-namespace $github_url)
  source_repo=$(_sk-git-url-to-repo $github_url)

  visibility=$(sk-github-visibility $github_url)

  target_namespace=$(_sk-git-url-to-namespace $github_target_url)
  target_repo=$(_sk-git-url-to-repo $github_target_url)

  echo "source_namespace: $source_namespace"
  echo "source_repo: $source_repo"

  echo "target_namespace: $target_namespace"
  echo "target_repo: $target_repo"

  echo sk-github-create-repo --url $github_target_url --$visibility
  sk-github-create-repo --url $github_target_url --$visibility

  current_dir=`pwd`
  temp_dir=`mktemp -d`

  cd $temp_dir
  git clone --bare $github_url
  cd *.git
  git push --mirror $github_target_url
  cd $current_dir
}

sk-github-create-repo(){
  local github_url='git@github.com:ORCID/blar.git'
  local github_description='empty description'
  local github_visibility_arg='--private'



  sk_help "
    Usage: $FUNCNAME

    Description:

    Options:

    "  "$@" && return 1

  while :
  do
    case ${1-default} in
        -u | --url)           github_url=$2; shift 2 ;;
        -d | --description)   github_description=$2; shift 2 ;;
        -P | --public)        visibility_arg='--public'; shift ;;
        -R | --private)        visibility_arg='--private'; shift ;;

        --) shift ; break ;;
        -*) echo "$FUNCNAME WARN: Unknown option (ignored): $1" >&2 ; shift ;;
        *)  break ;;
    esac
  done

  namespace=$(_sk-git-url-to-namespace $github_url)
  repo=$(_sk-git-url-to-repo $github_url)

  _sk-github-config $namespace

  gh repo create $namespace/$repo $visibility_arg

}
