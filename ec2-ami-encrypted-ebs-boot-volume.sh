#!/usr/bin/env bash

# This script will create an AMI with an encrypted boot volume from the latest Amazon Linux AMI (amzn-ami-hvm-x86_64-gp2)

# See:
# https://aws.amazon.com/blogs/aws/new-encrypted-ebs-boot-volumes/
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/CopyingAMIs.html
# https://aws.amazon.com/blogs/compute/query-for-the-latest-amazon-linux-ami-ids-using-aws-systems-manager-parameter-store/

# Requires the AWS CLI and jq


# Set Variables
AMITYPE="amzn-ami-hvm-x86_64-gp2"
Region="default"


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

# Error
function error(){
	tput setaf 1; echo "Error: $*" && tput sgr0
	return 1
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
	if [ "$Region" == "default" ]; then
		Region=$(aws configure get region --profile $profile 2>&1)
		if [ ! $? -eq 0 ]; then
			fail "$Region"
		fi
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
	Encrypt=$(aws ec2 copy-image --encrypted --client-token "$ClientToken" --description "Encrypted $DESCR ($AMIID)" --name "Encrypted $DESCR ($AMIID)" --source-image-id "$AMIID" --source-region $Region --region $Region --profile $profile 2>&1)
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
	tput setaf 2; echo "New AMI ID: $EncryptedAMI"; echo "Encrypted $DESCR ($AMIID)"; tput sgr0
}

# Tag the AMI
function TagAMI(){
	# Short pause to allow resources some time to be created before attempting to tag
	echo
	for i in {1..10}; do
		printf "."
		sleep 1
	done
	echo
	echo
	echo "Creating Name Tag for AMI ID: $EncryptedAMI"
	Tag=$(aws ec2 create-tags --resources "$EncryptedAMI" --tags "Key=Name,Value=Encrypted $DESCR ($AMIID)" --region $Region --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$Tag"
	fi
}

# Tag the Snapshot
function QuicklyTagSnapshot(){
	CallerID=$(aws sts get-caller-identity --profile $profile 2>&1)
	# if [ ! $? -eq 0 ]; then
	# 	error "$CallerID"
	# fi
	AccountID=$(echo "$CallerID" | jq '.Account' | cut -d \" -f2)
	# if [ ! $? -eq 0 ]; then
	# 	error "$AccountID"
	# fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "AccountID: $AccountID"
	fi
	Snapshots=$(aws ec2 describe-snapshots --owner-ids $AccountID --filters Name=status,Values=pending --region $Region --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		error "$Snapshots"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "$Snapshots" | jq .
	fi
	NumSnapshots=$(echo "$Snapshots" | jq '.Snapshots | length')
	if [ ! $? -eq 0 ]; then
		error "$NumSnapshots"
	fi
	if [ "$NumSnapshots" -eq 1 ]; then
		SnapshotID=$(echo "$Snapshots" | jq '.Snapshots | .[] | .SnapshotId' | cut -d \" -f2)
		if [ ! $? -eq 0 ]; then
			error "$SnapshotID"
		fi
		if [[ $DEBUGMODE = "1" ]]; then
			echo "SnapshotID: $SnapshotID"
		fi
		if [ -z "$SnapshotID" ]; then
			return 1
			# fail "Unable to get Snapshot ID or Tag Snapshot."
		fi
		echo
		echo "Creating Name Tag for Snapshot ID: $SnapshotID"
		SnapshotTag=$(aws ec2 create-tags --resources "$SnapshotID" --tags "Key=Name,Value=Encrypted $DESCR ($AMIID)" --region $Region --profile $profile 2>&1)
		if [ ! $? -eq 0 ]; then
			error "$SnapshotTag"
		fi
		echo
	else
		return 1
	fi
}

# Tag the Snapshot (fallback)
function SlowlyTagSnapshot(){
	echo
	echo
	echo "Creating Name Tag for Snapshot..."
	echo "Waiting for AMI State to become available, may take around 5 minutes..."
	starttime=$(date +%s)
	CheckState
	finishtime=$(date +%s)
	seconds=$(expr $finishtime - $starttime)
	if [[ $DEBUGMODE = "1" ]]; then
		echo; echo "This took $(expr $seconds / 60) minutes."
	fi
	SnapshotID=$(echo "$AMIdescr" | jq '.Images | .[] | .BlockDeviceMappings | .[] | .Ebs | .SnapshotId' | cut -d \" -f2)
	if [ ! $? -eq 0 ]; then
		fail "$SnapshotID"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "SnapshotID: $SnapshotID"
	fi
	if [ -z "$SnapshotID" ]; then
		fail "Unable to get Snapshot ID or Tag Snapshot."
	fi
	SnapshotTag=$(aws ec2 create-tags --resources "$SnapshotID" --tags "Key=Name,Value=Encrypted $DESCR ($AMIID)" --region $Region --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$SnapshotTag"
	fi
	echo; echo "Tagged Snapshot: $SnapshotID"
	echo
}

# Check AMI State
function CheckState(){
	AMIdescr=$(aws ec2 describe-images --image-ids "$EncryptedAMI" --region $Region --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$AMIdescr"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "AMIdescr: $AMIdescr"
	fi
	AMIstate=$(echo "$AMIdescr" | jq '.Images | .[] | .State' | cut -d \" -f2)
	if [ ! $? -eq 0 ]; then
		fail "$AMIstate"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "AMIstate: $AMIstate"
	fi
	while [ $AMIstate != "available" ]; do
		for i in {1..30}; do
			printf "."
			sleep 1
		done
		CheckState
	done
}

# Run the script and call functions

# Check for required applications
check_command aws jq

ClientToken
GetRegion
GetAMI
EncryptAMI
TagAMI
QuicklyTagSnapshot
if [ ! $? -eq 0 ]; then
	SlowlyTagSnapshot
fi

completed
