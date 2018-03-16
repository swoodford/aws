#!/usr/bin/env bash

# This script sets an S3 bucket policy to allow GetObject requests from any IP.
# Requires the AWS CLI and jq

# Set Variables

s3bucketname="YOUR-S3-BUCKET-NAME"


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
scriptname=`basename "$0"`
if [ $# -eq 0 ]; then
	echo "Usage: ./$scriptname profile environment"
	echo "Where profile is the AWS CLI profile name"
	echo "And environment is the environment name (dev/staging/prod/all)"
	echo
	echo "Using default profile and no environment name"
	echo
	profile=default
elif [ $# -eq 1 ]; then
	echo "Usage: ./$scriptname profile environment"
	echo "Where profile is the AWS CLI profile name"
	echo "And environment is the environment name (dev/staging/prod/all)"
	echo
	echo "Using profile $1 and no environment name"
	echo
	profile=$1
elif [ $# -eq 2 ]; then
	echo "Using profile $1 and environment $2"
	profile=$1
	s3bucketenv=$2
fi

# Check required commands
check_command "aws"
check_command "jq"


# Validate Variables

if [ "$s3bucketname" = "YOUR-S3-BUCKET-NAME" ]; then
	read -r -p "Enter S3 Bucket Name: " s3bucketname
fi
if [ -z "$s3bucketname" ]; then
	fail "S3 Bucket Name must be set."
fi

# Create the JSON policy document
function JSONizePolicy {
	echo '{"Version":"2012-10-17","Id":"'"$s3bucketname"'","Statement":[{"Sid":"PublicReadForGetBucketObjects","Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::'"$s3bucketname"'/*"}]}' > policy.json
}

# Set the S3 bucket policy
function setS3Policy {
	setS3Policy=$(aws s3api put-bucket-policy --bucket $s3bucketname --policy file://policy.json --output=json --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$setS3Policy"
	fi
}

# Validate the new policy
function validateS3Policy {
	bucketpolicy=$(aws s3api get-bucket-policy --bucket $s3bucketname --output=text --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$bucketpolicy"
	fi
	jsonpolicy=$(cat policy.json | tr -d '\n')

	# echo "$bucketpolicy" > bucketpolicy
	# echo "$jsonpolicy" > jsonpolicy

	if [ "$bucketpolicy" = "$jsonpolicy" ]; then
		HorizontalRule
		tput setaf 2; echo "S3 Bucket: $s3bucketname Policy Set Successfully!" && tput sgr0
		HorizontalRule
		# Remove the old policy file
		# rm policy.json
	else
		fail "Unable to verify bucket policy was set correctly."
	fi
}

# Run functions
function run {
	JSONizePolicy
	setS3Policy
	validateS3Policy
}

# Set S3 bucket name
function setBucketName (){
	# # Check for environment argument passed into the script
	# if [ $# -eq 0 ]; then
	# 	read -rp "S3 Bucket Environment? (dev/staging/prod/all): " s3bucketenv
	# 	if [ -z "$s3bucketenv" ]; then
	# 		fail "Invalid environment."
	# 	fi

	# 	if [ $s3bucketenv = "all" ]; then
	# 		s3bucketenv=all
	# 	else
	# 		s3bucketname="$s3bucketname"-"$s3bucketenv"
	# 	fi
	# fi

	# Test for variable passed as argument
	if [ -z "$s3bucketenv" ]; then
		run
	elif [ "$s3bucketenv" = "all" ]; then
		s3bucketname="$s3bucketname"-dev
		run
		s3bucketname="$s3bucketname"-staging
		run
		s3bucketname="$s3bucketname"-prod
		run
	else
		s3bucketname="$s3bucketname"-"$s3bucketenv"
		run
	fi
}

setBucketName $s3bucketenv
