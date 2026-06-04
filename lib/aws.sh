_sk_aws_region(){
  if _sk_aws_host;then
    curl -s http://169.254.169.254/latest/dynamic/instance-identity/document|jq -r .region
  else
    echo 'us-east-2'
  fi
}

_sk_aws_host(){
  if grep -q 'i-' <<< $(cat /sys/devices/virtual/dmi/id/board_asset_tag 2>/dev/null);then
    return 0
  else
    return 1
  fi
}

sk-aws-sso(){
  if [ -z "$1" ]; then
    echo "Please provide a profile name. Usage: sso profile_name"
  else
    aws sso login --profile "$1" && export AWS_PROFILE="$1"
  fi
}

sk-aws-rds-failover(){
  sk_help "$FUNCNAME: <db instance> <region> <profile>" "$@" && return
  region=${2:-'eu-west-1'}
  profile=${3:-blar}
  sk-pack-install -b aws -p awscli
  aws --region $region --profile $profile rds reboot-db-instance --db-instance-identifier $1  --force-failover
}

sk-aws-rds-latest-restore-time(){
  sk_help "Usage: $FUNCNAME <instance_id>. Show the latest restore time available for an instance"
  echo "$1"
  aws rds describe-db-instances --db-instance-identifier "$1" --query "DBInstances[*].[DBInstanceIdentifier,LatestRestorableTime]"
}

sk-aws-ec2-ipranges(){
  sk_help "Usage: $FUNCNAME. Outputs ec2 public ip ranges line by line"
  sk-asdf-install jq -p jq -v 1.6
  curl -s https://ip-ranges.amazonaws.com/ip-ranges.json 2>/dev/null |jq --raw-output '.prefixes[] |
  select(
    .service   == "EC2" and
    .region    == "us-east-1"
    or .region == "us-west-1"
    or .region == "ap-southeast-1"
    or .region == "eu-central-1"
    or .region == "eu-west-1"
  ) |
  .ip_prefix'
}

sk-aws-ec2-ipranges-3rdparty-fw(){
  sk_help "Usage: $FUNCNAME [ source ip ] , [ port ] , [service] . Output EC2 public ip ranges in a src,dest,port,name format for 3rd parties." "$@"
  local source_ip=${1:-1.1.1.1}
  local port=${2:-2234}
  local service=${2:-sftp}

  echo "source_ip,destination_ip,port,service"
  ec2_ips=$(sk-aws-ec2-ipranges)
  for destination_ip in $ec2_ips;do
    echo "$source_ip , $destination_ip , $port , $service"
  done
}

sk-aws-ec2-ipranges-nginx(){
  sk_help "Usage: $FUNCNAME  Output EC2 public ip ranges in a nginx format and allow" "$@"

  ec2_ips=$(sk-aws-ec2-ipranges)
  for destination_ip in $ec2_ips;do
    echo "allow $destination_ip;"
  done
}

sk-aws-ip-ranges() {
  curl -ks 'https://ip-ranges.amazonaws.com/ip-ranges.json' | perl -ne 'm,ip_prefix.*?([\d\./]+), and !$h{$1}++ and print "$1\n"'
}

######################################

sk-aws-sso-profile(){
  local profile="${1:-orcid-qa}"
  aws sso login --profile $profile
  aws sts get-caller-identity --profile $profile
}


sk-aws-mfa-device-serial-number() {
  sk_help_noarg "Usage: $FUNCNAME <mfa device serial number>. Sets your MFA device for cli use - see 'Assigned MFA device' in the Security Credentials section of your AWS account." "$@" && return
  export AWS_MFA_DEVICE_SERIAL_NUMBER=$1
}

sk-aws-mfa-session() {
  sk_help_noarg "Usage: $FUNCNAME <authorization code from MFA device or app>. Sets up an aws client session using MFA." "$@" && return
  [[ -z $AWS_MFA_DEVICE_SERIAL_NUMBER ]] && echo "AWS_MFA_DEVICE_SERIAL_NUMBER must be set, see sk-aws-mfa-device-serial-number" && return
  sk-asdf-install jq -p jq -v 1.6
  sk-aws-mfa-clear-session
  local sts_output=$(aws sts get-session-token --serial-number $AWS_MFA_DEVICE_SERIAL_NUMBER --output=json --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" --token-code $1)
  local key_id=$(jq -r '.[0]' <<< $sts_output)
  local access_key=$(jq -r '.[1]' <<< $sts_output)
  local session_token=$(jq -r '.[2]' <<< $sts_output)
  export AWS_ACCESS_KEY_ID=$key_id AWS_SECRET_ACCESS_KEY=$access_key AWS_SESSION_TOKEN=$session_token
}

sk-aws-mfa-clear-session() {
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
}

sk-aws-secret-source(){
  sk_help_noarg "Usage: $FUNCNAME <secret_id>. Source key=value secrets into your bash script" "$@" && return
  sk-asdf-install jq -p jq -v 1.6
  sk-pack-install -b aws -p awscli

  local aws_secret_id=${1:-default}
  local secret_tmp_file=~/${aws_secret_id}.env
  touch $secret_tmp_file
  chmod 600 $secret_tmp_file
  aws secretsmanager get-secret-value --secret-id ${aws_secret_id} --query SecretString --output text | jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' > $secret_tmp_file
  source $secret_tmp_file
  rm $secret_tmp_file
}

sk-aws-list-instances(){
  sk_help "Usage: $FUNCNAME. List all instances in current region" "$@" && return
  sk-asdf-install jq -p jq -v 1.6
  sk-pack-install -b aws -p awscli
  aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | (.Tags[] | select(.Key=="Name").Value) + "\t" + .InstanceId' | sort
}

sk-leapp(){
  current_dir=$(pwd)
  case $current_dir in
    *prod*) profile="orcid-prod" ;;
    *int*) profile="orcid-int" ;;
    *stage*) profile="orcid-stage" ;;
    *shared*) profile="orcid-shared" ;;
    *sbox*) profile="orcid-sbox" ;;
    *qa*) profile="orcid-qa" ;;
    *) echo "undetected env in current dir"; return ;;
  esac
  echo profile "$profile"
  sk-aws-sso-leapp $profile
}

sk-aws-sso-leapp(){
  local profile="${1:-orcid-int}"

  # Check if SSO session is still valid by trying to export credentials
  local creds=$(aws configure export-credentials --profile "$profile" --format process 2>/dev/null)

  # If credentials export failed, we need to login
  if [ $? -ne 0 ] || [ -z "$creds" ]; then
    echo "SSO session expired or invalid, logging in..."
    aws sso login --sso-session orcid 2>&1 | grep -v "Attempting to automatically open\|If the browser does not open\|https://\|Then enter the code\|Successfully logged into"

    # Try exporting credentials again after login
    creds=$(aws configure export-credentials --profile "$profile" --format process 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$creds" ]; then
      echo "✗ Failed to export credentials after login"
      return 1
    fi
  fi

  # Parse the credentials (process format is JSON)
  local access_key=$(echo "$creds" | jq -r '.AccessKeyId')
  local secret_key=$(echo "$creds" | jq -r '.SecretAccessKey')
  local session_token=$(echo "$creds" | jq -r '.SessionToken')
  local expiration=$(echo "$creds" | jq -r '.Expiration')

  # Write to ~/.aws/credentials as [default] profile (Leapp-style)
  local creds_file=~/.aws/credentials

  # Create ~/.aws directory if it doesn't exist
  mkdir -p ~/.aws

  # Backup existing credentials
  if [ -f "$creds_file" ]; then
    cp "$creds_file" "${creds_file}.bak"
  fi

  # Remove existing [default] section if it exists
  if grep -q "\[default\]" "$creds_file" 2>/dev/null; then
    # Remove the [default] section and everything until the next section or EOF
    awk 'BEGIN {skip=0} /^\[default\]/ {skip=1; next} /^\[.*\]/ {skip=0} !skip' "$creds_file" > "${creds_file}.tmp"
    mv "${creds_file}.tmp" "$creds_file"
  fi

  # Prepend new default credentials at the top of the file
  {
    echo "[default]"
    echo "aws_access_key_id = ${access_key}"
    echo "aws_secret_access_key = ${secret_key}"
    echo "aws_session_token = ${session_token}"
    echo "# Profile: ${profile}"
    echo "# Expires: ${expiration}"
    echo ""
    cat "$creds_file" 2>/dev/null
  } > "${creds_file}.new"

  mv "${creds_file}.new" "$creds_file"
  chmod 600 "$creds_file"

  # Clear any profile override
  unset AWS_PROFILE

  echo "✓ Switched to AWS profile: $profile"
  echo "✓ Credentials written to ~/.aws/credentials as [default]"
  echo "✓ Credentials expire: $expiration"
}

# Simpler environment-only version
sk-aws-sso-env(){
  local profile="${1:-orcid-int}"

  aws sso login --profile "$profile" 2>&1 | grep -v "Attempting to automatically open\|If the browser does not open\|https://\|Then enter the code\|Successfully logged into" || return 1

  eval $(aws configure export-credentials --profile "$profile" --format env 2>/dev/null)

  # Clear AWS_PROFILE so it uses the exported credentials
  unset AWS_PROFILE

  if [ -n "$AWS_ACCESS_KEY_ID" ]; then
    local expiration=$(aws configure export-credentials --profile "$profile" --format process 2>/dev/null | jq -r '.Expiration')
    echo "✓ Logged into AWS SSO"
    echo "✓ Credentials exported to environment"
    echo "✓ Source profile: $profile"
    echo "✓ Valid until: $expiration"
  else
    echo "✗ Failed to export credentials"
    return 1
  fi
}
