#!/usr/bin/env bash

# This script monitors CloudFront distributions for In-Progress Status and alerts when it has completed and is Deployed
# Requires the AWS CLI and jq

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

# Check for Distributions
function distributionsCheck(){
	distributions=$(aws cloudfront list-distributions --profile $profile 2>&1 | jq '.DistributionList | .Items | .[] | .ARN')
	if [[ $DEBUGMODE = "1" ]]; then
		echo "$distributions"
	fi
	if echo "$distributions" | egrep -iq "error|not|false"; then
		echo "$distributions"
		fail "No CloudFront distributions found."
	fi
}

# List In-Progress
function listInProgress(){

	HorizontalRule
	echo "Checking for In-Progress Status..."
	HorizontalRule

	inprogress=$(aws cloudfront list-distributions --profile $profile 2>&1 | jq '.DistributionList | .Items | .[] | select(.Status == "InProgress") | .Id' | cut -d \" -f2)
	name=$(aws cloudfront list-distributions --profile $profile 2>&1 | jq '.DistributionList | .Items | .[] | select(.Status == "InProgress") | .Origins | .Items | .[] | .Id' | cut -d \" -f2)

	if [[ $DEBUGMODE = "1" ]]; then
		echo inprogress "$inprogress"
	fi

	if ! [ -z "$inprogress" ]; then
		HorizontalRule
		echo "Distributions In-Progress: $inprogress"
		echo "$name"
		HorizontalRule
	fi
}

# Check the status
function checkStatus(){
	if [ -z "$inprogress" ]; then
		echo No CloudFront Distributions with In-Progress Status.
		HorizontalRule
		return 1
	else
		status=$(aws cloudfront get-distribution --id $inprogress --profile $profile 2>&1 | jq '.Distribution | .Status' | cut -d \" -f2)

		while [ $status = "InProgress" ]; do
			HorizontalRule
			echo "Status:" $status
			echo "Waiting for Deployed Status..."
			HorizontalRule
			sleep 30
			checkStatus
		done

		if [ "$(uname)" == "Darwin" ]; then
			if [[ $DEBUGMODE = "1" ]]; then
				echo MACOS
			fi
			osascript -e 'tell app "Terminal" to display dialog " CloudFront Distribution ID: '$inprogress' Status: '$status'"'
		elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
			if [[ $DEBUGMODE = "1" ]]; then
				LINUX
			fi
			echo "CloudFront Distribution $status"
			completed
		fi
	fi
}

check_command "jq"

distributionsCheck
listInProgress
checkStatus
