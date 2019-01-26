#!/bin/bash
key_name=${KEY_NAME:-"ssh-ubuntu-user"}
security_group_name=${SECURITY_GROUP_NAME:-"ssh-server"}
if [ "$MY_IP" == "" ]
then
  MY_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
fi

if [ ! "$(command -v aws)" ]
then
  echo "ERROR: You'll need to install aws-cli first."
  exit 1;
fi
if ! aws sts get-caller-identity > /dev/null 2>&1 
then
  echo "ERROR: It looks like aws is not configured."
  echo "Do these things first:"
  echo "  1. Open the IAM console"
  echo "  2. Choose Users from navigation pane"
  echo "  3. Choose your IAM username"
  echo "  4. Choose Security Credentials tab, then Create access key"
  echo "  5. Click Show and enter the info shown there in the following prompts"
  echo "  6. Run 'aws configure' at the command line"
  exit 1
fi
mkdir -p ~/.aws
aws ec2 create-key-pair \
  --key-name "$key_name" \
  --query 'KeyMaterial' \
  --output text \
  > ~/.aws/"$key_name".pem
chmod 400 ~/.aws/"$key_name".pem

if ! security_group_id=$(aws ec2 create-security-group \
  --group-name "$security_group_name" \
  --description "SSH Server" |
  jq ".GroupId" -r)
then
  echo "ERROR: Could not create security group."
  echo "You may not have the proper permissions for this opertaion."
  echo "Add it through the IAM management page in the AWS Console"
  echo "One option is to just add the AmazonEC2FullAccess permission,"
  echo "but this may be more permissive than you want."
  exit 1
fi

if ! aws ec2 authorize-security-group-ingress \
  --group-id "$security_group_id" \
  --cidr "$MY_IP"/24 \
  --port 22 \
  --protocol tcp
then
  echo "ERROR: Could not add ingress to security group."
  echo "You may not have the proper permissions for this opertaion."
  echo "Add it through the IAM management page in the AWS Console"
  echo "One option is to just add the AmazonEC2FullAccess permission,"
  echo "but this may be more permissive than you want."
  exit 1
fi

if ! image_id=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters 'Name=name,
    Values=ubuntu/images/hvm-ssd/ubuntu-cosmic-18.10-amd64-server*' |
  jq '.Images | sort_by(.CreationDate) | last(.[]) | .ImageId' -r)
then
  echo "ERROR: Could not search for base ami images."
  echo "You may not have the proper permissions for this opertaion."
  echo "Add it through the IAM management page in the AWS Console"
  echo "One option is to just add the AmazonEC2FullAccess permission,"
  echo "but this may be more permissive than you want."
  exit 1
fi

if ! instance_id=$(aws ec2 run-instances \
  --image-id "$image_id" \
  --count 1 \
  --instance-type t2.micro \
  --key-name "$key_name" \
  --security-group-ids "$security_group_id" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=role,Value=git}]' |
  jq '.Instances | first(.[]).InstanceId' -r)
then
  echo "ERROR: Could not start an instance from ami $image_id."
  echo "You may not have the proper permissions for this opertaion."
  echo "Add it through the IAM management page in the AWS Console"
  echo "One option is to just add the AmazonEC2FullAccess permission,"
  echo "but this may be more permissive than you want."
  exit 1
fi

while [ "$instance_ip_address" == "" ]
do
  sleep 5
  if ! instance_ip_address=$(aws ec2 describe-instances \
	--filters "Name=instance-id,Values=$instance_id,Name=instance-state-name,Values=running" |
	jq ".Reservations[].Instances | first(.[]) | .PublicIpAddress" -r)
  then
    echo "ERROR: Could not find the public ip of instance with id $instance_id."
    echo "You may not have the proper permissions for this opertaion."
    echo "Add it through the IAM management page in the AWS Console"
    echo "One option is to just add the AmazonEC2FullAccess permission,"
    echo "but this may be more permissive than you want."
    exit 1
  fi
done

mkdir -p ~/.ssh
cat << CONFIG >> ~/.ssh/config
Host gitservadmin
    Hostname $instance_ip_address
    IdentityFile ~/.aws/$key_name.pem
    IdentitiesOnly yes
CONFIG
