#!/usr/bin/env bash

# This script will set CloudWatch UnhealthyHost Alarms for all ELBs in all regions available
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/UsingAlarmActions.html#AddingRecoverActions

# Requires the AWS CLI and jq and you must setup your ALARMACTION

# Set Variables

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

# Get list of all ELB and ALB names in all regions
function LBsInRegion(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin LBsInRegion Function"
	fi
	LBsInRegionStart=1
	for (( LBsInRegionCount=$LBsInRegionStart; LBsInRegionCount<=$TotalRegions; LBsInRegionCount++ ))
	do
		Region=$(echo "$ParseRegions" | nl | grep -w [^0-9][[:space:]]$LBsInRegionCount | cut -f2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo "Debug Region: $Region"
		fi
		HorizontalRule
		ListELBs
		ListALBs
		SetAlarms
		echo
	done
}

# Get list of all Classic EC2 ELBs in one region
function ListELBs(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin ListELBs Function"
	fi
	ELBs=$(aws elb describe-load-balancers --region $Region --output=json --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$ELBs"
	else
		if [[ $DEBUGMODE = "1" ]]; then
			echo ELBs: "$ELBs"
		fi
		ParseELBs=$(echo "$ELBs" | jq '.LoadBalancerDescriptions | .[] | .LoadBalancerName' | cut -d \" -f2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo ParseELBs: "$ParseELBs"
		fi
	fi
	if [ -z "$ParseELBs" ]; then
		echo "No ELBs found in $Region."
		TotalELBs="0"
	else
		TotalELBs=$(echo "$ParseELBs" | wc -l | rev | cut -d " " -f1 | rev)
	fi
}

# Get list of all ALBs in one region
function ListALBs(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin ListALBs Function"
	fi
	ALBs=$(aws elbv2 describe-load-balancers --region $Region --output=json --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$ALBs"
	else
		if [[ $DEBUGMODE = "1" ]]; then
			echo ALBs: "$ALBs"
		fi
		ParseALBs=$(echo "$ALBs" | jq '.LoadBalancers | .[] | .LoadBalancerName' | cut -d \" -f2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo ParseALBs: "$ParseALBs"
		fi
	fi
	if [ -z "$ParseALBs" ]; then
		echo "No ALBs found in $Region."
		TotalALBs="0"
	else
		TotalALBs=$(echo "$ParseALBs" | wc -l | rev | cut -d " " -f1 | rev)
	fi
}

function ListSNSTopics(){
	SNSTopics=$(aws sns list-topics --region $Region --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$SNSTopics"
	fi
	TopicArns=$(echo "$SNSTopics" | jq '.Topics | .[] | .TopicArn' | cut -d \" -f2)
	if [ ! $? -eq 0 ]; then
		fail "$TopicArns"
	fi
	echo "SNS Topics Found in Region $Region"
	echo "Specify Action for CloudWatch Alarm:"
	HorizontalRule
	echo "$TopicArns"
	HorizontalRule
	echo
	read -r -p "ARN: " ALARMACTION
	if [[ -z $ALARMACTION ]]; then
		fail "Alarm Action must be configured."
	fi
}

function SetAlarms(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Begin SetAlarms Function"
	fi
	if [ "$TotalELBs" -gt "0" ] || [ "$TotalALBs" -gt "0" ]; then
		HorizontalRule
		echo "Setting Alarms for Region: $Region"
		HorizontalRule
		echo
		ListSNSTopics
	else
		return
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "Region: $Region"
		echo "TotalELBs: $TotalELBs"
		echo "TotalALBs: $TotalALBs"
		pause
	fi
	if [ "$TotalELBs" -gt "0" ]; then
		ELBStart=1
		for (( ELBCount=$ELBStart; ELBCount<=$TotalELBs; ELBCount++ ))
		do
			ELBName=$(echo "$ParseELBs" | nl | grep -w [^0-9][[:space:]]$ELBCount | cut -f2)
			if [[ $DEBUGMODE = "1" ]]; then
				echo "Count: $ELBCount"
				echo "ELB: $ELBName"
				pause
			fi
			echo
			HorizontalRule
			echo "ELB Name: $ELBName"
			echo "Setting CloudWatch Alarm"
			if [[ $DEBUGMODE = "1" ]]; then
				echo "$ALARMACTION"
				echo aws cloudwatch put-metric-alarm --alarm-name "$ELBName - ELB Unhealthy Hosts" --metric-name UnHealthyHostCount --namespace AWS/ELB --statistic Maximum --dimensions Name=LoadBalancerName,Value="$ELBName" --unit Count --period 300 --evaluation-periods 1 --threshold 0 --comparison-operator GreaterThanThreshold --alarm-actions \'"$ALARMACTION"\' --output=json --profile $profile --region $Region 2>&1
			fi
			SetAlarm=$(aws cloudwatch put-metric-alarm --alarm-name "$ELBName - ELB Unhealthy Hosts" --metric-name UnHealthyHostCount --namespace AWS/ELB --statistic Maximum --dimensions Name=LoadBalancerName,Value="$ELBName" --unit Count --period 300 --evaluation-periods 1 --threshold 0 --comparison-operator GreaterThanThreshold --alarm-actions "$ALARMACTION" --output=json --profile $profile --region $Region 2>&1)
			if [ ! $? -eq 0 ]; then
				fail "$SetAlarm"
			fi
			VerifyAlarm=$(aws cloudwatch describe-alarms --alarm-names "$ELBName - ELB Unhealthy Hosts" --output=json --profile $profile --region $Region 2>&1)
			if [ ! $? -eq 0 ]; then
				fail "$VerifyAlarm"
			fi
			AlarmName=$(echo "$VerifyAlarm" | jq '.MetricAlarms | .[] | .AlarmName')
			if [ ! $? -eq 0 ]; then
				fail "$AlarmName"
			fi
			echo "Alarm set: $AlarmName"
		done
	fi
	if [ "$TotalALBs" -gt "0" ]; then
		ALBStart=1
		for (( ALBCount=$ALBStart; ALBCount<=$TotalALBs; ALBCount++ ))
		do
			ALBName=$(echo "$ParseALBs" | nl | grep -w [^0-9][[:space:]]$ALBCount | cut -f2)
			if [[ $DEBUGMODE = "1" ]]; then
				echo "Count: $ALBCount"
				echo "ALB: $ALBName"
				pause
			fi
			echo
			HorizontalRule
			echo "ALB Name: $ALBName"
			echo "Setting CloudWatch Alarm"
			if [[ $DEBUGMODE = "1" ]]; then
				echo "$ALARMACTION"
				echo aws cloudwatch put-metric-alarm --alarm-name "$ALBName - ALB Unhealthy Hosts" --metric-name UnHealthyHostCount --namespace AWS/ApplicationELB --statistic Maximum --dimensions Name=LoadBalancerName,Value="$ALBName" --unit Count --period 300 --evaluation-periods 1 --threshold 0 --comparison-operator GreaterThanThreshold --alarm-actions \'"$ALARMACTION"\' --output=json --profile $profile --region $Region 2>&1
			fi
			SetAlarm=$(aws cloudwatch put-metric-alarm --alarm-name "$ALBName - ALB Unhealthy Hosts" --metric-name UnHealthyHostCount --namespace AWS/ApplicationELB --statistic Maximum --dimensions Name=LoadBalancerName,Value="$ALBName" --unit Count --period 300 --evaluation-periods 1 --threshold 0 --comparison-operator GreaterThanThreshold --alarm-actions "$ALARMACTION" --output=json --profile $profile --region $Region 2>&1)
			if [ ! $? -eq 0 ]; then
				fail "$SetAlarm"
			fi
			VerifyAlarm=$(aws cloudwatch describe-alarms --alarm-names "$ALBName - ALB Unhealthy Hosts" --output=json --profile $profile --region $Region 2>&1)
			if [ ! $? -eq 0 ]; then
				fail "$VerifyAlarm"
			fi
			AlarmName=$(echo "$VerifyAlarm" | jq '.MetricAlarms | .[] | .AlarmName')
			if [ ! $? -eq 0 ]; then
				fail "$AlarmName"
			fi
			echo "Alarm set: $AlarmName"
		done
	fi
}


if [ -z "$Region" ]; then
	GetRegions
	LBsInRegion
else
	ListELBs
	ListALBs
	if [ "$TotalELBs" -gt "0" ] || [ "$TotalALBs" -gt "0" ]; then
		SetAlarms
	fi
fi

completed
