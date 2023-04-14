sk-aws-rds-failover(){
  sk_help "$FUNCNAME: <db instance> <region> <profile>" "$@" && return
  region=${2:-'eu-west-1'}
  profile=${3:-blar}
  sk-pack-install aws -p awscli
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
  sk-pack-install aws -p awscli

  local aws_secret_id=${1:-default}
  local secret_tmp_file=~/${aws_secret_id}.env
  touch $secret_tmp_file
  chmod 600 $secret_tmp_file
  aws secretsmanager get-secret-value --secret-id ${aws_secret_id} --query SecretString --output text | jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' > $secret_tmp_file
  source $secret_tmp_file
  rm $secret_tmp_file
}
