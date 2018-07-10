#!/usr/bin/env bash

# This script will create an AMI with an encrypted boot volume from the latest Amazon Linux AMI (amzn-ami-hvm-x86_64-gp2)

# See:
# https://aws.amazon.com/blogs/aws/new-encrypted-ebs-boot-volumes/
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/CopyingAMIs.html
# https://aws.amazon.com/blogs/compute/query-for-the-latest-amazon-linux-ami-ids-using-aws-systems-manager-parameter-store/

# Requires the AWS CLI and jq


# Set Variables
AMITYPE="amzn-ami-hvm-x86_64-gp2"


# Debug Mode
DEBUGMODE="0"


# Functions


# Check Command
function check_command(){
	for command in "$@"
	do
	    type -P $command &>/dev/null || fail "Unable to find $command, please install it and run this script again."
	done
}

# Completed
function completed(){
	echo
	HorizontalRule
	tput setaf 2; echo "Completed!" && tput sgr0
	HorizontalRule
	echo
}

# Fail
function fail(){
	tput setaf 1; echo "Error: $*" && tput sgr0
	exit 1
}

# Horizontal Rule
function HorizontalRule(){
	echo "============================================================"
}

# Pause
function pause(){
	read -n 1 -s -p "Press any key to continue..."
	echo
}

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/credentials; then
	if ! grep -q aws_access_key_id ~/.aws/config; then
		fail "AWS config not found or CLI not installed. Please run \"aws configure\"."
	fi
fi

# Check for AWS CLI profile argument passed into the script
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-multiple-profiles
if [ $# -eq 0 ]; then
	scriptname=`basename "$0"`
	echo "Usage: ./$scriptname profile"
	echo "Where profile is the AWS CLI profile name"
	echo "Using default profile"
	echo
	profile=default
else
	profile=$1
fi

# Generate a client token
function ClientToken(){
	ClientToken=$(echo $(echo $RANDOM; date +%s; date +%s; date +%s; date +%s; echo $RANDOM) | tr -d ' ')
	if [ ! $? -eq 0 ]; then
		fail "$ClientToken"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "ClientToken: $ClientToken"
	fi
}

# Determine region
function GetRegion(){
	Region=$(aws configure get region --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$Region"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Region: $Region"
	fi
}

# Get the latest Amazon Linux AMI ID
function GetAMI(){
	AMI=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/"$AMITYPE" --region $Region --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$AMI"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "AMI: $AMI"
	fi
	NAME=$(echo $AMI | jq '.Parameters | .[] | .Name' | cut -d \/ -f5 | cut -d \" -f1)
	if [ ! $? -eq 0 ]; then
		fail "$NAME"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "NAME: $NAME"
	fi
	AMIID=$(echo $AMI | jq '.Parameters | .[] | .Value' | cut -d \" -f2)
	if [ ! $? -eq 0 ]; then
		fail "$AMIID"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "AMIID: $AMIID"
	fi
	DESCR=$(aws ec2 describe-images --image-ids "$AMIID" --region $Region --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$DESCR"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "DESCR: $DESCR"
	fi
	DESCR=$(echo "$DESCR" | jq '.Images | .[] | .Description' | cut -d \" -f2)
	# DESCR="$NAME-$AMIID"
	if [ ! $? -eq 0 ]; then
		fail "$DESCR"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "DESCR: $DESCR"
	fi
}

# Build encrypted AMI
function EncryptAMI(){
	Encrypt=$(aws ec2 copy-image --encrypted --client-token "$ClientToken" --description "Encrypted $DESCR ($AMIID)" --name "Encrypted $DESCR ($AMIID)" --source-image-id "$AMIID" --source-region $Region --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$Encrypt"
	fi
	EncryptedAMI=$(echo "$Encrypt" | jq '.ImageId' | cut -d \" -f2)
	if [ ! $? -eq 0 ]; then
		fail "$EncryptedAMI"
	fi
	HorizontalRule
	echo "Creating $AMITYPE AMI with encrypted boot volume:"
	HorizontalRule
	echo
	tput setaf 2; echo "New AMI ID: $EncryptedAMI" && tput sgr0
}

function TagAMI(){
	Tag=$(aws ec2 create-tags --resources "$EncryptedAMI" --tags "Key=Name,Value=Encrypted $DESCR ($AMIID)" --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$Tag"
	fi
	echo
	echo "Created Name tag for AMI: Encrypted $DESCR ($AMIID)"
}

# Run the script and call functions

# Check for required applications
check_command aws jq

ClientToken
GetRegion
GetAMI
EncryptAMI
TagAMI

completed
