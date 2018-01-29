#!/usr/bin/env bash

# This script monitors CloudFront distributions for cache invalidation status and alerts when it has completed
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

# List Distributions
function listDistributions(){
	distributions=$(aws cloudfront list-distributions --profile $profile 2>&1 | jq '.DistributionList | .Items | .[] | .Id' | cut -d \" -f2)
	names=$(aws cloudfront list-distributions --profile $profile 2>&1 | jq '.DistributionList | .Items | .[] | .Origins | .Items | .[] | .Id' | cut -d \" -f2)

	if [ -z "$distributions" ]; then
		echo "$distributions"
		fail "No CloudFront distributions found."
	else
		HorizontalRule
		echo Found CloudFront Distributions:
		HorizontalRule

		if [[ $DEBUGMODE = "1" ]]; then
			echo "Debug distribution IDs:"
			echo "$distributions"
		fi
		echo "$names"
		echo
	fi
	TOTALDISTRIBUTIONS=$(echo "$distributions" | wc -l | rev | cut -d " " -f1 | rev)
	if [[ $DEBUGMODE = "1" ]]; then
		echo "$TOTALDISTRIBUTIONS"
	fi
}

# List Invalidations
function listInvalidations(){
	# while IFS= read -r distributionid
	# do
	HorizontalRule
	echo "Checking for Invalidations In Progress..."
	HorizontalRule

	START=1
	for (( COUNT=$START; COUNT<=$TOTALDISTRIBUTIONS; COUNT++ ))
	do
		distributionid=$(echo "$distributions" | nl | grep -w [^0-9][[:space:]]$COUNT | cut -f2)

		if [[ $DEBUGMODE = "1" ]]; then
			echo "Debug distribution ID: $distributionid"
		fi
		invalidations=$(aws cloudfront list-invalidations --distribution-id $distributionid --profile $profile 2>&1 | jq '.InvalidationList | .Items | .[] | select(.Status != "Completed") | .Id' | cut -d \" -f2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo invalidations "$invalidations"
		fi

		if ! [ -z "$invalidations" ]; then
			HorizontalRule
			echo "Invalidation in progress: $invalidations"
			HorizontalRule
		fi
	done

	# done <<< "$distributions"
}

# Check the Invalidation Status
function checkInvalidationstatus(){
	if [ -z "$invalidations" ]; then
		echo No CloudFront Invalidations In Progress.
		HorizontalRule
		return 1
	else
		while IFS= read -r invalidationid
		do
			echo Invalidation ID: $invalidationid
			invalidationStatus=$(aws cloudfront get-invalidation --distribution-id $distributionid --id $invalidationid --profile $profile 2>&1 | jq '.Invalidation | .Status' | cut -d \" -f2)

			while [ $invalidationStatus = "InProgress" ]; do
				HorizontalRule
				echo "Invalidation Status:" $invalidationStatus
				echo "Waiting for invalidation to complete..."
				HorizontalRule
				sleep 30
				checkInvalidationstatus
			done

			if [ "$(uname)" == "Darwin" ]; then
				if [[ $DEBUGMODE = "1" ]]; then
					echo MACOS
				fi
				osascript -e 'tell app "Terminal" to display dialog " CloudFront Invalidation ID: '$invalidationid' Status: '$invalidationStatus'"'
			elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
				if [[ $DEBUGMODE = "1" ]]; then
					LINUX
				fi
				echo "CloudFront Invalidation $invalidationStatus"
				completed
			fi
		done <<< "$invalidations"
	fi
}

check_command "jq"
distributionsCheck
listDistributions
listInvalidations
checkInvalidationstatus
