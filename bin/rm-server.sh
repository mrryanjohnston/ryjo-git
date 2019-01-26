#!/bin/bash
echo "WARNING: This script straight-up removes AWS resources."
echo "Make sure you read this script to figure out what it does first!"
read -p "Continue? (y/N): " continue_if_y
continue_if_y=${continue_if_y:-"N"}
if [ "$continue_if_y" != "Y" ] && [ "$continue_if_y" != "y" ]
then
  echo "Canceling..."
  exit 0
fi

key_name=${KEY_NAME:-"ssh-ubuntu-user"}
security_group_name=${SECURITY_GROUP_NAME:-"ssh-server"}

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

if ! instance_id=$(aws ec2 describe-instances \
	--filters "Name=tag:role,Values=git,Name=instance-state-name,Values=running" |
	jq ".Reservations[].Instances | first(.[]) | .InstanceId" -r)
then
  echo "ERROR: Could not find security group with security group name $security_group_name."
  echo "You may not have the proper permissions for this opertaion."
  echo "Add it through the IAM management page in the AWS Console"
  echo "One option is to just add the AmazonEC2FullAccess permission,"
  echo "but this may be more permissive than you want."
  echo "Continuing on..."
fi

if ! aws ec2 terminate-instances --instance-ids "$instance_id"
then
  echo "ERROR: Could not delete security group with id $security_group_id."
  echo "You may not have the proper permissions for this opertaion."
  echo "Add it through the IAM management page in the AWS Console"
  echo "One option is to just add the AmazonEC2FullAccess permission,"
  echo "but this may be more permissive than you want."
  echo "Continuing on..."
fi

instance_still_shutting_down="$instance_id"
while [ "$instance_still_shutting_down" != "" ]
do
  sleep 5
  if ! instance_still_shutting_down=$(aws ec2 describe-instances \
	--filters "Name=instance-id,Values=$instance_id,Name=instance-state-name,Values=shutting-down" |
	jq ".Reservations[].Instances | first(.[]) | .InstanceId" -r)
  then
    echo "ERROR: Could not check if instance $instance_id was still running."
    echo "This can happen if the instance is still in the process of terminating."
    echo "You may also not have the proper permissions for this opertaion."
    echo "Add it through the IAM management page in the AWS Console"
    echo "One option is to just add the AmazonEC2FullAccess permission,"
    echo "but this may be more permissive than you want."
    exit 1
  fi
done

rm ~/.aws/"$key_name".pem

if ! security_group_id=$(aws ec2 describe-security-groups \
	--filters "Name=group-name,Values=$security_group_name" |
	jq ".SecurityGroups | first(.[]) | .GroupId" -r)
then
  echo "ERROR: Could not find security group with security group name $security_group_name."
  echo "You may not have the proper permissions for this opertaion."
  echo "Add it through the IAM management page in the AWS Console"
  echo "One option is to just add the AmazonEC2FullAccess permission,"
  echo "but this may be more permissive than you want."
  echo "Continuing on..."
fi

if ! aws ec2 delete-security-group --group-id "$security_group_id"
then
  echo "ERROR: Could not delete security group with id $security_group_id."
  echo "You may not have the proper permissions for this opertaion."
  echo "Add it through the IAM management page in the AWS Console"
  echo "One option is to just add the AmazonEC2FullAccess permission,"
  echo "but this may be more permissive than you want."
  echo "Continuing on..."
fi


if ! aws ec2 delete-key-pair --key-name "$key_name"
then
  echo "ERROR: Could not delete key pair with name $key_name."
  echo "This can happen if the instance is still in the process of terminating."
  echo "You may also not have the proper permissions for this opertaion."
  echo "Add it through the IAM management page in the AWS Console"
  echo "One option is to just add the AmazonEC2FullAccess permission,"
  echo "but this may be more permissive than you want."
fi

sed -i 's/^Host/\n&/' ~/.ssh/config
sed -i '/^Host gitservadmin$/,/^$/d;/^$/d' ~/.ssh/config
