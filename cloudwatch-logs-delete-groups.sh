#!/usr/bin/env bash

# This script will quickly delete all CloudWatch Log Groups with a specified prefix in all regions available
# Requires the AWS CLI and jq

# Set Variables

# Specify Prefix to DELETE
Prefix="/aws/example/logGroup"

# Optionally limit to a single AWS Region
Region="ALL"

# Debug Mode
DEBUGMODE="0"


# Functions

# Check Command
function check_command {
	type -P $1 &>/dev/null || fail "Unable to find $1, please install it and run this script again."
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
	tput setaf 1; echo "Failure: $*" && tput sgr0
	exit 1
}

# Error
function error(){
	tput setaf 1; echo "Error: $*" && tput sgr0
}

# Horizontal Rule
function HorizontalRule(){
	echo "============================================================"
}

# Pause
function pause(){
	# read -n 1 -s -p "Press any key to continue..."
	echo
}

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
	if ! grep -q aws_access_key_id ~/.aws/credentials; then
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

# Check required commands
check_command "aws"
check_command "jq"


# Warning
function Warning(){
	tput setaf 1
	echo
	HorizontalRule
	echo "Warning: This script will DELETE all CloudWatch Log Groups with a matching specified prefix."
	echo
	read -r -p "Are you sure you understand and want to continue? (y/n) " CONTINUE
	HorizontalRule
	if ! [[ $CONTINUE =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo "Canceled."
		tput sgr0
		exit 1
	fi
	tput sgr0
	echo
}

# Set Prefix
if [[ "$Prefix" == "/aws/example/logGroup" ]]; then
	read -r -p "Specify CloudWatch Log Groups Prefix to DELETE: " Prefix
	if [ -z "$Prefix" ]; then
		fail "Must specify Prefix."
	fi
fi

# Limit region
if [[ "$Region" == "ALL" ]]; then
	read -r -p "Enter a single Region name or press return to search all regions: " Region
fi

# Get list of all regions (using EC2)
function GetRegions(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin GetRegions Function"
	fi
	AWSregions=$(aws ec2 describe-regions --output=json --profile $profile 2>&1)
	if echo "$AWSregions" | egrep -iq "error|not"; then
		fail "$AWSregions"
	else
		ParseRegions=$(echo "$AWSregions" | jq '.Regions | .[] | .RegionName'| cut -d \" -f2 | sort)
	fi
	TotalRegions=$(echo "$ParseRegions" | wc -l | rev | cut -d " " -f1 | rev)
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Regions:"
		echo "$AWSregions"
		echo "$ParseRegions"
		echo "TotalRegions: $TotalRegions"
		pause
	fi
	LogGroupsInRegion
}

# Get list of all CloudWatch Log Groups in all regions
function LogGroupsInRegion(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin LogGroupsInRegion Function"
	fi
	LogGroupsInRegionStart=1
	for (( LogGroupsInRegionCount=$LogGroupsInRegionStart; LogGroupsInRegionCount<=$TotalRegions; LogGroupsInRegionCount++ ))
	do
		Region=$(echo "$ParseRegions" | nl | grep -w [^0-9][[:space:]]$LogGroupsInRegionCount | cut -f2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo "Debug Region: $Region"
		fi
		HorizontalRule
		ListLogGroups
		echo
	done
}

# Get list of all CloudWatch Log Groups in one region
function ListLogGroups(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin ListLogGroups Function"
	fi
	ListLogGroups=$(aws logs describe-log-groups --log-group-name-prefix "$Prefix" --region=$Region --output=json --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$ListLogGroups"
	# if echo "$ListLogGroups" | egrep -iq "error|not"; then
	# 	fail "$ListLogGroups"
	else
		ParseLogGroups=$(echo "$ListLogGroups" | jq '.logGroups | .[] | .logGroupName' | cut -d \" -f2)
	fi
	if [ -z "$ParseLogGroups" ]; then
		echo "No Log Groups found in $Region."
	else
		tput setaf 2; echo "Found Matching Log Groups in Region $Region..." && tput sgr0
		HorizontalRule
		echo "$ParseLogGroups"
		Warning
		DeleteLogGroup
	fi
}

# Delete Log Group
function DeleteLogGroup(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin DeleteLogGroup Function"
	fi


	TotalLogGroups=$(echo "$ParseLogGroups" | wc -l | rev | cut -d " " -f1 | rev)
	if [[ $DEBUGMODE = "1" ]]; then
		echo "~~~~"
		echo "Region: $Region"
		echo "TotalLogGroups: $TotalLogGroups"
		echo "~~~~"
		pause
	fi
	DeleteLogGroupStart=1
	for (( DeleteLogGroupCount=$DeleteLogGroupStart; DeleteLogGroupCount<=$TotalLogGroups; DeleteLogGroupCount++ ))
	do
		LogGroup=$(echo "$ParseLogGroups" | nl | grep -w [^0-9][[:space:]]$DeleteLogGroupCount | cut -f2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo "o0o0o0o"
			echo "Count: $DeleteLogGroupCount"
			echo "LogGroup: $LogGroup"
			echo "o0o0o0o"
			pause
		fi
		echo "Deleting Log Group: $LogGroup"
		DeleteLogGroup=$(aws logs delete-log-group --region $Region --log-group-name $LogGroup --output=json --profile $profile 2>&1)
		if [ ! $? -eq 0 ]; then
			fail "$DeleteLogGroup"
		fi
	done
}

Warning

if [ -z "$Region" ]; then
	GetRegions
else
	ListLogGroups
fi

completed
