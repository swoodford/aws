#!/usr/bin/env bash

# This script will search all CloudWatch Logs (all log groups in all regions available) for a filter string
# Requires the AWS CLI and jq

# Set Variables

# Log Group Prefix
LogGroupName="x"

# The string to filter logs
FilterPattern="x"

# Optionally limit to a single AWS Region
Region="x"


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
	echo
	read -n 1 -s -p "Press any key to continue..."
	echo
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


# Validate Variables
if [[ "$LogGroupName" == "x" ]]; then
	read -r -p "Enter Log Group name or press return to search all groups: " LogGroupName
fi

if [[ "$FilterPattern" == "x" ]]; then
	read -r -p "Enter filter pattern to search logs: " FilterPattern
fi

if [ -z "$FilterPattern" ]; then
	fail "Filter pattern must be set."
fi

if [[ "$Region" == "x" ]]; then
	read -r -p "Enter a single Region name or press return to search all regions: " Region
fi

# Get list of all regions (using EC2)
function GetRegions(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin GetRegions Function"
	fi
	AWSregions=$(aws ec2 describe-regions --output=json --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$AWSregions"
	else
		ParseRegions=$(echo "$AWSregions" | jq '.Regions | .[] | .RegionName'| cut -d \" -f2 | sort)
		if [ ! $? -eq 0 ]; then
			fail "$ParseRegions"
		fi
	fi
	TotalRegions=$(echo "$ParseRegions" | wc -l | rev | cut -d " " -f1 | rev)
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Regions:"
		# echo "$AWSregions"
		echo "$ParseRegions"
		echo "TotalRegions: $TotalRegions"
		pause
	fi
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
	else
		if [[ $DEBUGMODE = "1" ]]; then
			echo ListLogGroups: "$ListLogGroups"
		fi
		ParseLogGroups=$(echo "$ListLogGroups" | jq '.logGroups | .[] | .logGroupName' | cut -d \" -f2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo ParseLogGroups: "$ParseLogGroups"
		fi
	fi
	if [ -z "$ParseLogGroups" ]; then
		echo "No Log Groups found in $Region."
	else
		if [ -z "$LogGroupName" ]; then
			echo "Log Groups in Region $Region:"
			echo "$ParseLogGroups"
		fi
		echo
		FilterLogEvents
	fi
}

# Filter Log Events
function FilterLogEvents(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin FilterLogEvents Function"
	fi
	TotalLogGroups=$(echo "$ParseLogGroups" | wc -l | rev | cut -d " " -f1 | rev)
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Region: $Region"
		echo "TotalLogGroups: $TotalLogGroups"
		echo "Log Group Name: $LogGroupName"
		pause
	fi
	if ! [ -z "$LogGroupName" ]; then
		if [[ $DEBUGMODE = "1" ]]; then
			echo "$LogGroupName"
			pause
		fi
		if echo "$ParseLogGroups" | egrep -iq "$LogGroupName"; then
			echo "Located Matching Log Group in Region $Region."
			echo "Searching Log Events... this may take a very long time..."
			if [[ $DEBUGMODE = "1" ]]; then
				echo "Searching Single Log Group: $LogGroupName"
			fi
			FilterLogEvents=$(aws logs filter-log-events --region $Region --log-group-name "$LogGroupName" --filter-pattern \""$FilterPattern"\" --output=json --profile $profile 2>&1)
			if [ ! $? -eq 0 ]; then
				fail "$FilterLogEvents"
			fi
			if [[ $DEBUGMODE = "1" ]]; then
				echo "FilterLogEvents: $FilterLogEvents"
				pause
			fi
			Events=$(echo "$FilterLogEvents" | jq '.events | .[]')
			if [ -z "$Events" ]; then
				echo "No matching events found for $LogGroupName in region $Region."
			else
				echo "Found matching events for $LogGroupName in region $Region:"
				echo "$Events" | jq .
			fi
		else
			echo "No matching events found for $LogGroupName in region $Region."
		fi
	else
		FilterLogEventsStart=1
		for (( FilterLogEventsCount=$FilterLogEventsStart; FilterLogEventsCount<=$TotalLogGroups; FilterLogEventsCount++ ))
		do
			LogGroup=$(echo "$ParseLogGroups" | nl | grep -w [^0-9][[:space:]]$FilterLogEventsCount | cut -f2)
			if [[ $DEBUGMODE = "1" ]]; then
				echo "Count: $FilterLogEventsCount"
				echo "LogGroup: $LogGroup"
				pause
			fi
			FilterLogEvents=$(aws logs filter-log-events --region $Region --log-group-name "$LogGroup" --filter-pattern \""$FilterPattern"\" --output=json --profile $profile 2>&1)
			if [ ! $? -eq 0 ]; then
				fail "$FilterLogEvents"
			fi
			if [[ $DEBUGMODE = "1" ]]; then
				echo "FilterLogEvents: $FilterLogEvents"
				pause
			fi
			Events=$(echo "$FilterLogEvents" | jq '.events | .[]')
			if [ -z "$Events" ]; then
				echo "No matching events found for $LogGroup in region $Region."
			else
				echo "Found matching events for $LogGroup in region $Region:"
				echo "$Events" | jq .
			fi
		done
	fi
}

if [ -z "$Region" ]; then
	GetRegions
	LogGroupsInRegion
else
	ListLogGroups
fi

completed
