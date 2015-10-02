#!/usr/bin/env bash
# This script checks Cloudfront Distributions for cache invalidation status
# Requires jq

# If you use an AWS CLI profile set it here:
# profile=profilename


# Functions


# Check required commands
function check_command {
	type -P $1 &>/dev/null || fail "Unable to find $1, please install it and run this script again."
}

# Fail
function fail(){
	tput setaf 1; echo "Failure: $*" && tput sgr0
	exit 1
}

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! [ -f ~/.aws/config ]; then
  if ! [ -f ~/.aws/credentials ]; then
    fail "Error: AWS config not found or CLI not installed."
    exit 1
  fi
fi

# Check for Distributions
function distributionsCheck(){
	if [ -z "$profile" ]; then
		distributions=$(aws cloudfront list-distributions)
		# echo "$distributions"
	else
		distributions=$(aws cloudfront list-distributions --profile $profile)
		# echo "$distributions"
	fi
	if echo "$distributions" | grep -q False; then
		fail "No CloudFront distributions found."
		exit 1
	fi
}

# List Distributions
function listDistributions(){
	if [ -z "$profile" ]; then
		distributions=$(aws cloudfront list-distributions | jq '.DistributionList | .Items | .[] | .Id' | cut -d '"' -f2)
		names=$(aws cloudfront list-distributions | jq '.DistributionList | .Items | .[] | .Origins | .Items | .[] | .Id' | cut -d '"' -f2)
	else
		distributions=$(aws cloudfront list-distributions --profile $profile | jq '.DistributionList | .Items | .[] | .Id' | cut -d '"' -f2)
		names=$(aws cloudfront list-distributions --profile $profile | jq '.DistributionList | .Items | .[] | .Origins | .Items | .[] | .Id' | cut -d '"' -f2)
	fi
	if [ -z "$distributions" ]; then
		fail "No CloudFront distributions found."
		exit 1
	else
		echo ===============================
		echo Found CloudFront Distributions:
		# echo "$distributions"
		echo "$names"
		echo ===============================
	fi
}

# List Invalidations
function listInvalidations(){
	while IFS= read -r distributionid
	do
		# echo Distribution ID: "$distributionid"
		if [ -z "$profile" ]; then
			invalidations=$(aws cloudfront list-invalidations --distribution-id $distributionid | jq '.InvalidationList | .Items | .[] | select(.Status != "Completed") | .Id' | cut -d '"' -f2)
		else
			invalidations=$(aws cloudfront list-invalidations --distribution-id $distributionid --profile $profile | jq '.InvalidationList | .Items | .[] | select(.Status != "Completed") | .Id' | cut -d '"' -f2)
		fi
		if [ -z "$invalidations" ]; then
			return 1
			# echo No CloudFront Invalidations In Progress.
			# echo ========================================
		else
			echo ===============================
			echo Invalidations not Completed:
			echo "$invalidations"
			echo ===============================
		fi
	done <<< "$distributions"
}

# Check the Invalidation Status
function checkInvalidationstatus(){
	if [ -z "$invalidations" ]; then
		echo No CloudFront Invalidations In Progress.
		echo ========================================
		return 1
	else
		while IFS= read -r invalidationid
		do
			echo Invalidation ID: $invalidationid
			if [ -z "$profile" ]; then
			invalidationStatus=$(aws cloudfront get-invalidation --distribution-id $distributionid --id $invalidationid | jq '.Invalidation | .Status' | cut -d '"' -f2)
			else
				invalidationStatus=$(aws cloudfront get-invalidation --distribution-id $distributionid --id $invalidationid --profile $profile | jq '.Invalidation | .Status' | cut -d '"' -f2)
			fi
			while [ $invalidationStatus = "InProgress" ]; do
				echo ==========================================
				echo "Invalidation Status: "$invalidationStatus
				echo "Waiting for invalidation to complete..."
				echo ==========================================
				sleep 30
				checkInvalidationstatus
			done
			osascript -e 'tell app "Terminal" to display dialog " CloudFront Invalidation '$invalidationStatus'"'
		done <<< "$invalidations"
	fi
}

check_command "jq"
distributionsCheck
listDistributions
listInvalidations
checkInvalidationstatus
