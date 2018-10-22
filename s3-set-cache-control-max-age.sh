#!/usr/bin/env bash

# Set Cache-Control public with max-age value on AWS S3 bucket website assets for all filetypes
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control

BUCKET="YOUR-S3-BUCKET-NAME"
MAXAGE="SET-SECONDS-VALUE-HERE"

# Functions

function check_command {
	type -P $1 &>/dev/null || fail "Unable to find $1, please install it and run this script again."
}

function completed(){
	echo
	horizontalRule
	tput setaf 2; echo "Completed!" && tput sgr0
	horizontalRule
	echo
}

function fail(){
	tput setaf 1; echo "Failure: $*" && tput sgr0
	exit 1
}

function horizontalRule(){
	echo "====================================================="
}

function message(){
	echo
	horizontalRule
	echo "$*"
	horizontalRule
	echo
}

function pause(){
	read -n 1 -s -p "Press any key to continue..."
	echo
}


# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/credentials; then
	if ! grep -q aws_access_key_id ~/.aws/config; then
		fail "AWS config not found or CLI not installed. Please run \"aws configure\"."
	fi
fi

check_command "aws"

# Check for AWS CLI profile argument passed into the script
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-multiple-profiles
if [ $# -eq 0 ]; then
	scriptname=`basename "$0"`
	echo "Usage: ./$scriptname profile"
	echo "Where profile is the AWS CLI profile name"
	echo "Using default profile"
	profile=default
else
	profile=$1
fi

message "This script will set Cache-Control public with max-age value on AWS S3 bucket website assets."
echo
# pause

# Ensure Variables are set
if [ "$BUCKET" = "YOUR-S3-BUCKET-NAME" ]; then
	read -r -p "Enter the S3 bucket name: " BUCKET
	if [ -z "$BUCKET" ]; then
		fail "Failed to set variables!"
	fi
fi
if [ "$MAXAGE" = "SET-SECONDS-VALUE-HERE" ]; then
	read -r -p "Enter the new Cache-Control Max-Age value in seconds: " MAXAGE
	if [ -z "$MAXAGE" ]; then
		fail "Failed to set variables!"
	fi
fi

# Validate max-age range 0-31536000
if ! [ "$MAXAGE" -ge "0" ] || ! [ "$MAXAGE" -le "31536000" ]; then
	fail "Invalid Cache-Control Max-Age value: $MAXAGE"
fi

# Determine the bucket region
REGION=$(aws s3api get-bucket-location --bucket $BUCKET --output text --profile $profile 2>&1)
if [ ! $? -eq 0 ]; then
	fail "$REGION"
fi
if echo $REGION | grep -q "None"; then
	REGION="us-east-1"
fi

message "Setting Cache-Control Max-Age $MAXAGE for all assets in S3 Bucket $BUCKET"
set=$(aws s3 cp --recursive --profile $profile --region $REGION s3://$BUCKET/ s3://$BUCKET/ --cache-control "public, max-age=$MAXAGE" --metadata-directive "REPLACE" 2>&1)
if [ ! $? -eq 0 ]; then
	fail "$set"
fi
if echo $set | egrep -iq "error"; then
	fail "$set"
else
	echo "$set"
fi

completed
