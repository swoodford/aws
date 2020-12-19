#!/usr/bin/env bash

# This script will set CloudWatch Logs Retention Policy to x number of days for all log groups in all regions available
# Requires the AWS CLI and jq

# Set Variables

# The number of days to retain the log events in the specified log group. Possible values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, and 3653.
RetentionInDays=x


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


# Validate Variable
if [[ "$RetentionInDays" == "x" ]]; then
	echo "Enter the number of days to retain all CloudWatch Log Groups in all AWS regions. Possible values are:"
	echo "1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, and 3653."
	read -r -p "Retention in days: " RetentionInDays
fi

if [ -z "$RetentionInDays" ]; then
	fail "Variable RetentionInDays must be set."
fi

if ! [[ "$RetentionInDays" =~ ^1$|^3$|^5$|^7$|^14$|^30$|^60$|^90$|^120$|^150$|^180$|^365$|^400$|^545$|^731$|^1827$|^3653$ ]]; then
	fail "Variable RetentionInDays outside of possible range or invalid."
fi

# Get list of all regions (using EC2)
function GetRegions(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin GetRegions Function"
	fi
	AWSregions=$(aws ec2 describe-regions --output=json --profile $profile 2>&1)
	if echo "$AWSregions" | egrep -iq "error"; then
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
	ListLogGroups=$(aws logs describe-log-groups --region=$Region --output=json --profile $profile 2>&1)
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
		echo "Log Groups in Region $Region:"
		echo "$ParseLogGroups"
		echo
		echo "Setting Retention Policy for $Region."
		SetRetentionPolicy
	fi
}

# Set Retention Policy
function SetRetentionPolicy(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin SetRetentionPolicy Function"
	fi
	TotalLogGroups=$(echo "$ParseLogGroups" | wc -l | rev | cut -d " " -f1 | rev)
	if [[ $DEBUGMODE = "1" ]]; then
		echo "~~~~"
		echo "Region: $Region"
		echo "TotalLogGroups: $TotalLogGroups"
		echo "~~~~"
		pause
	fi
	SetRetentionPolicyStart=1
	for (( SetRetentionPolicyCount=$SetRetentionPolicyStart; SetRetentionPolicyCount<=$TotalLogGroups; SetRetentionPolicyCount++ ))
	do
		LogGroup=$(echo "$ParseLogGroups" | nl | grep -w [^0-9][[:space:]]$SetRetentionPolicyCount | cut -f2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo "o0o0o0o"
			echo "Count: $SetRetentionPolicyCount"
			echo "LogGroup: $LogGroup"
			echo "o0o0o0o"
			pause
		fi
		SetRetentionPolicy=$(aws logs put-retention-policy --region $Region --log-group-name $LogGroup --retention-in-days $RetentionInDays --output=json --profile $profile 2>&1)
		if echo "$SetRetentionPolicy" | egrep -iq "error|not"; then
			fail "$SetRetentionPolicy"
		fi
		if [ -z "$SetRetentionPolicy" ]; then
			echo "Set Retention Policy to $RetentionInDays days for $LogGroup"
		else
			fail "$SetRetentionPolicy"
		fi
	done
}

GetRegions

completed
