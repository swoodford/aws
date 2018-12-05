#!/usr/bin/env bash

# This script will delete all CloudWatch Log Groups with a Last Event that is older than the Retention Policy in all regions available
# Requires the AWS CLI and jq

# Set Variables

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
	echo "Warning: This script will DELETE all CloudWatch Log Groups with a Last Event Timestamp"
	echo "that is older than the Retention Policy set on the Log Group in all regions available."
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
		tput setaf 2; echo "Reviewing Log Groups in Region $Region..." && tput sgr0
		HorizontalRule
		# echo "$ParseLogGroups"
		CheckRetentionPolicy
	fi
}

# Check Retention Policy
function CheckRetentionPolicy(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin CheckRetentionPolicy Function"
	fi
	TotalLogGroups=$(echo "$ParseLogGroups" | wc -l | rev | cut -d " " -f1 | rev)
	if [[ $DEBUGMODE = "1" ]]; then
		echo "~~~~"
		echo "Region: $Region"
		echo "TotalLogGroups: $TotalLogGroups"
		echo "~~~~"
		pause
	fi
	CheckRetentionPolicyStart=1
	for (( CheckRetentionPolicyCount=$CheckRetentionPolicyStart; CheckRetentionPolicyCount<=$TotalLogGroups; CheckRetentionPolicyCount++ ))
	do
		LogGroup=$(echo "$ParseLogGroups" | nl | grep -w [^0-9][[:space:]]$CheckRetentionPolicyCount | cut -f2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo "o0o0o0o"
			echo "Count: $CheckRetentionPolicyCount"
			echo "LogGroup: $LogGroup"
			echo "o0o0o0o"
			pause
		fi
		CheckRetentionPolicy=$(aws logs describe-log-groups --region $Region --log-group-name-prefix $LogGroup --output=json --profile $profile 2>&1)
		if [ ! $? -eq 0 ]; then
			fail "$CheckRetentionPolicy"
		fi
		# if echo "$CheckRetentionPolicy" | egrep -iq "error|not"; then
		# 	fail "$CheckRetentionPolicy"
		# fi
		countLogGroups=$(echo "$CheckRetentionPolicy" | jq '.logGroups | length')
		if [ $countLogGroups -gt 1 ]; then
			error "Multiple Log Groups Match this Prefix: $LogGroup in Region: $Region"
		else
			retentionInDays=$(echo "$CheckRetentionPolicy" | jq '.logGroups | .[] | .retentionInDays' | cut -d \" -f2)
			if [[ $DEBUGMODE = "1" ]]; then
				echo "start test"
				echo "retentionInDays: $retentionInDays"
				echo "end test"
				echo "$CheckRetentionPolicy" | jq .
			fi
			if [ -z "$retentionInDays" ]; then
				error "Error checking Retention Policy for Log Group $LogGroup in Region: $Region"
			else
				if [[ "$retentionInDays" == "null" ]]; then
					error "No Retention Policy set for Log Group $LogGroup in Region: $Region"
				else
					CheckLogStream
				fi
			fi
		fi
	done
}

# Check Log Stream
function CheckLogStream(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin CheckLogStream Function"
	fi
	CheckLogStream=$(aws logs describe-log-streams --region $Region --log-group-name $LogGroup --max-items 1 --order-by LastEventTime --descending --output=json --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$CheckLogStream"
	fi
	# if echo "$CheckLogStream" | egrep -iq "error|not"; then
	# 	fail "$CheckLogStream"
	# fi
	lastEventTimestamp=$(echo "$CheckLogStream" | jq '.logStreams | .[] | .lastEventTimestamp' | cut -d \" -f2)
	if [[ $DEBUGMODE = "1" ]]; then
		echo "lastEventTimestamp: $lastEventTimestamp"
	fi
	CheckTimestamp
}

# Convert Retention Days to MS
function convertDaystoMS(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin convertDaystoMS Function"
	fi
	if [ $retentionInDays -eq 1 ]; then
		retentionInDaysToMS=86400000
	elif [ $retentionInDays -eq 3 ]; then
		retentionInDaysToMS=259200000
	elif [ $retentionInDays -eq 5 ]; then
		retentionInDaysToMS=432000000
	elif [ $retentionInDays -eq 7 ]; then
		retentionInDaysToMS=604800000
	elif [ $retentionInDays -eq 14 ]; then
		retentionInDaysToMS=1209600000
	elif [ $retentionInDays -eq 30 ]; then
		retentionInDaysToMS=2592000000
	elif [ $retentionInDays -eq 60 ]; then
		retentionInDaysToMS=5184000000
	elif [ $retentionInDays -eq 90 ]; then
		retentionInDaysToMS=7776000000
	elif [ $retentionInDays -eq 120 ]; then
		retentionInDaysToMS=10368000000
	elif [ $retentionInDays -eq 150 ]; then
		retentionInDaysToMS=12960000000
	elif [ $retentionInDays -eq 180 ]; then
		retentionInDaysToMS=15552000000
	elif [ $retentionInDays -eq 365 ]; then
		retentionInDaysToMS=31536000000
	elif [ $retentionInDays -eq 400 ]; then
		retentionInDaysToMS=34560000000
	elif [ $retentionInDays -eq 545 ]; then
		retentionInDaysToMS=47088000000
	elif [ $retentionInDays -eq 731 ]; then
		retentionInDaysToMS=63158400000
	elif [ $retentionInDays -eq 1827 ]; then
		retentionInDaysToMS=157852800000
	elif [ $retentionInDays -eq 3653 ]; then
		retentionInDaysToMS=315619200000
	fi
}

# Milliseconds in a day
msInaDay="86400000"

# Check Timestamp
function CheckTimestamp(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin CheckTimestamp Function"
	fi
	# retentionInDaysToMS=$(($retentionInDays * $msInaDay))
	convertDaystoMS
	now=$(date +%s000)
	difference=$(($now - $lastEventTimestamp))
	days=$(($difference / $msInaDay))

	if [[ $DEBUGMODE = "1" ]]; then
		echo "retentionInDaysToMS: $retentionInDaysToMS"
		echo "now: $now"
		echo "difference: $difference"
	fi

	# echo "Region: $Region"
	if [ $difference -gt $retentionInDaysToMS ]; then
		HorizontalRule
		tput setaf 1; echo "PAST RETENTION TIME:"
		echo "LogGroup: $LogGroup"
		echo "Days Since Last Event: $days" && tput sgr0
		DeleteLogGroup
		HorizontalRule
	fi
}

# Delete Log Group
function DeleteLogGroup(){
	echo "Deleting Log Group..."
	DeleteLogGroup=$(aws logs delete-log-group --region $Region --log-group-name $LogGroup --output=json --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$DeleteLogGroup"
	fi
}

Warning

if [ -z "$Region" ]; then
	GetRegions
else
	ListLogGroups
fi

completed
