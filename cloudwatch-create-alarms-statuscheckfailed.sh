#!/usr/bin/env bash

# This script will set CloudWatch StatusCheckFailed Alarms with Recovery Action for all running EC2 Instances in all regions available
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/UsingAlarmActions.html#AddingRecoverActions

# Requires the AWS CLI and jq and you must setup your ALARMACTION

# Set Variables

# ALARMACTION="arn:aws:sns:us-east-1:YOURACCOUNTNUMBER:YOURSNSALERTNAME"

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


# ToDo: in order to use an SNS Topic it must be within the same region as the instance

# # Verify ALARMACTION is setup with some alert mechanism
# if [[ -z $ALARMACTION ]] || [[ "$ALARMACTION" == "arn:aws:sns:us-east-1:YOURACCOUNTNUMBER:YOURSNSALERTNAME" ]]; then
# 	SNSTopics=$(aws sns list-topics --profile $profile 2>&1)
# 	if [ ! $? -eq 0 ]; then
# 		fail "$SNSTopics"
# 	fi
# 	TopicArns=$(echo "$SNSTopics" | jq '.Topics | .[] | .TopicArn' | cut -d \" -f2)
# 	if [ ! $? -eq 0 ]; then
# 		fail "$TopicArns"
# 	fi
# 	echo "Specify Action for CloudWatch Alarm"
# 	echo "SNS Topics Found:"
# 	HorizontalRule
# 	echo "$TopicArns"
# 	HorizontalRule
# 	echo
# 	read -r -p "ARN: " ALARMACTION
# 	if [[ -z $ALARMACTION ]]; then
# 		fail "Alarm Action must be configured."
# 	fi
# fi

if [[ "$Region" == "x" ]]; then
	echo
	HorizontalRule
	read -r -p "Enter a single region name or press return for all regions: " Region
	HorizontalRule
	echo
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
		# echo "$AWSregions"
		echo "$ParseRegions"
		echo "TotalRegions: $TotalRegions"
		pause
	fi
}

# Get list of all EC2 Instance IDs in all regions
function InstancesInRegion(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin InstancesInRegion Function"
	fi
	InstancesInRegionStart=1
	for (( InstancesInRegionCount=$InstancesInRegionStart; InstancesInRegionCount<=$TotalRegions; InstancesInRegionCount++ ))
	do
		Region=$(echo "$ParseRegions" | nl | grep -w [^0-9][[:space:]]$InstancesInRegionCount | cut -f2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo "Debug Region: $Region"
		fi
		HorizontalRule
		ListInstances
		echo
	done
}

# Get list of all EC2 Instances in one region
function ListInstances(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin ListInstances Function"
	fi
	Instances=$(aws ec2 describe-instances --filters Name=instance-state-name,Values=running --region $Region --output=json --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$Instances"
	else
		if [[ $DEBUGMODE = "1" ]]; then
			echo Instances: "$Instances"
		fi
		ParseInstances=$(echo "$Instances" | jq '.Reservations | .[] | .Instances | .[] | .InstanceId' | cut -d \" -f2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo ParseInstances: "$ParseInstances"
		fi
	fi
	if [ -z "$ParseInstances" ]; then
		echo "No Instances found in $Region."
	else
		HorizontalRule
		echo "Setting Alarms for Region: $Region"
		SetAlarms
	fi
}

function SetAlarms(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin SetAlarms Function"
	fi
	TotalInstancess=$(echo "$ParseInstances" | wc -l | rev | cut -d " " -f1 | rev)
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Region: $Region"
		echo "TotalInstancess: $TotalInstancess"
		pause
	fi
	Start=1
	for (( Count=$Start; Count<=$TotalInstancess; Count++ ))
	do
		InstanceID=$(echo "$ParseInstances" | nl | grep -w [^0-9][[:space:]]$Count | cut -f2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo "Count: $Count"
			echo "Instance: $InstanceID"
			pause
		fi
		InstanceNameTag=$(aws ec2 describe-tags --filters Name=key,Values=Name Name=resource-id,Values="$InstanceID" --region $Region --output=json --profile $profile 2>&1)
		if [ ! $? -eq 0 ]; then
			fail "$InstanceNameTag"
		fi
		if [ -z "$InstanceNameTag" ]; then
			echo "No InstanceName."
		fi
		if [[ $DEBUGMODE = "1" ]]; then
			echo "InstanceNameTag: $InstanceNameTag"
		fi
		InstanceName=$(echo "$InstanceNameTag" | jq '.Tags | .[] | .Value' | cut -d \" -f2)
		if [ ! $? -eq 0 ]; then
			fail "$InstanceName"
		fi
		if [ -z "$InstanceName" ]; then
			echo "No InstanceName."
		fi
		echo
		HorizontalRule
		echo "Instance Name: $InstanceName"
		echo "Setting CloudWatch Alarm"
		if [[ $DEBUGMODE = "1" ]]; then
			echo ALARMACTION="arn:aws:automate:$Region:ec2:recover"
		fi
		ALARMACTION="arn:aws:automate:$Region:ec2:recover"
		if [[ $DEBUGMODE = "1" ]]; then
			echo aws cloudwatch put-metric-alarm --alarm-name "$InstanceName - Status Check Failed - $InstanceID" --metric-name StatusCheckFailed --namespace AWS/EC2 --statistic Maximum --dimensions Name=InstanceId,Value="$InstanceID" --unit Count --period 300 --evaluation-periods 1 --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold --alarm-actions \'"$ALARMACTION"\' --output=json --profile $profile --region $Region 2>&1
		fi
		SetAlarm=$(aws cloudwatch put-metric-alarm --alarm-name "$InstanceName - Status Check Failed - $InstanceID" --metric-name StatusCheckFailed --namespace AWS/EC2 --statistic Maximum --dimensions Name=InstanceId,Value="$InstanceID" --unit Count --period 300 --evaluation-periods 1 --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold --alarm-actions "$ALARMACTION" --output=json --profile $profile --region $Region 2>&1)
		if [ ! $? -eq 0 ]; then
			fail "$SetAlarm"
		fi
		VerifyAlarm=$(aws cloudwatch describe-alarms --alarm-names "$InstanceName - Status Check Failed - $InstanceID" --output=json --profile $profile --region $Region 2>&1)
		if [ ! $? -eq 0 ]; then
			fail "$VerifyAlarm"
		fi
		AlarmName=$(echo "$VerifyAlarm" | jq '.MetricAlarms | .[] | .AlarmName')
		if [ ! $? -eq 0 ]; then
			fail "$AlarmName"
		fi
		echo "Alarm set: $AlarmName"
	done
}


if [ -z "$Region" ]; then
	GetRegions
	InstancesInRegion
else
	ListInstances
fi

completed
