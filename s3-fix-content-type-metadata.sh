#!/usr/bin/env bash

# Safely fix invalid content-type metadata on AWS S3 bucket website assets for some common filetypes
# Inclues CSS, JS, JPG, JPEG, GIF, PNG, SVG, PDF

BUCKET="YOUR-S3-BUCKET-NAME"


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

message "This script will safely fix invalid content-type metadata on AWS S3 bucket website assets."
pause

# Ensure Variables are set
if [ "$BUCKET" = "YOUR-S3-BUCKET-NAME" ]; then
	read -r -p "Enter the S3 bucket name: " BUCKET
	if [ -z "$BUCKET" ]; then
		fail "Failed to set variables!"
	fi
fi

message CSS
css=$(aws s3 cp --recursive --profile $profile s3://$BUCKET/ s3://$BUCKET/ --exclude "*" --include "*.css" --content-type "text/css" --metadata-directive "REPLACE" 2>&1)
if echo $css | grep -q error; then
	fail "$css"
else
	echo "$css"
fi

message JS
js=$(aws s3 cp --recursive --profile $profile s3://$BUCKET/ s3://$BUCKET/ --exclude "*" --include "*.js" --content-type "application/javascript" --metadata-directive "REPLACE" 2>&1)
if echo $js | grep -q error; then
	fail "$js"
else
	echo "$js"
fi

message JPG
jpg=$(aws s3 cp --recursive --profile $profile s3://$BUCKET/ s3://$BUCKET/ --exclude "*" --include "*.jpg" --content-type "image/jpeg" --metadata-directive "REPLACE" 2>&1)
if echo $jpg | grep -q error; then
	fail "$jpg"
else
	echo "$jpg"
fi
message JPEG
jpeg=$(aws s3 cp --recursive s3://$BUCKET/ s3://$BUCKET/ --exclude "*" --include "*.jpeg" --content-type "image/jpeg" --metadata-directive "REPLACE" 2>&1)
if echo $jpeg | grep -q error; then
	fail "$jpeg"
else
	echo "$jpeg"
fi

message GIF
gif=$(aws s3 cp --recursive --profile $profile s3://$BUCKET/ s3://$BUCKET/ --exclude "*" --include "*.gif" --content-type "image/gif" --metadata-directive "REPLACE" 2>&1)
if echo $gif | grep -q error; then
	fail "$gif"
else
	echo "$gif"
fi

message PNG
png=$(aws s3 cp --recursive --profile $profile s3://$BUCKET/ s3://$BUCKET/ --exclude "*" --include "*.png" --content-type "image/png" --metadata-directive "REPLACE" 2>&1)
if echo $png | grep -q error; then
	fail "$png"
else
	echo "$png"
fi

message SVG
svg=$(aws s3 cp --recursive --profile $profile s3://$BUCKET/ s3://$BUCKET/ --exclude "*" --include "*.svg" --content-type "image/svg+xml" --metadata-directive "REPLACE" 2>&1)
if echo $svg | grep -q error; then
	fail "$svg"
else
	echo "$svg"
fi

message PDF
pdf=$(aws s3 cp --recursive --profile $profile s3://$BUCKET/ s3://$BUCKET/ --exclude "*" --include "*.pdf" --content-type "application/pdf" --metadata-directive "REPLACE" 2>&1)
if echo $pdf | grep -q error; then
	fail "$pdf"
else
	echo "$pdf"
fi

completed
