#!/usr/bin/env bash
# This script sets an S3 bucket policy to allow GetObject requests from any IP.  Requires jq.
# Usage: ./s3-openbucketpolicy.sh environment

# Variables

s3bucketname="YOUR-S3-BUCKET-NAME"


# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! [ -f ~/.aws/config ]; then
  if ! [ -f ~/.aws/credentials ]; then
    echo "Error: AWS config not found or CLI not installed."
    exit 1
  fi
fi

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

# Create the JSON policy document
function JSONizePolicy {
	echo '{"Version":"2012-10-17","Id":"'"$s3bucketname"'","Statement":[{"Sid":"PublicReadForGetBucketObjects","Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::'"$s3bucketname"'/*"}]}' > policy.json
}

# Set the S3 bucket policy
function setS3Policy {
	setS3Policy=$(aws s3api put-bucket-policy --bucket $s3bucketname --policy file://policy.json 2>&1)
}

# Validate the new policy
function validateS3Policy {
	bucketpolicy=$(aws s3api get-bucket-policy --bucket $s3bucketname --output text)
	jsonpolicy=$(cat policy.json | tr -d '\n')

	# echo "$bucketpolicy" > bucketpolicy
	# echo "$jsonpolicy" > jsonpolicy

	if [ "$bucketpolicy" = "$jsonpolicy" ]; then
		echo "==========================================================="
		tput setaf 2; echo S3 Bucket: $s3bucketname Policy Set Successfully! && tput sgr0
		tput setaf 2; echo Set Public Read For GetBucketObjects && tput sgr0
		echo "==========================================================="
		# Remove the old policy file
		# rm policy.json
	else
		fail $(echo "$setS3Policy")
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
	# Check for environment argument passed into the script
	if [ $# -eq 0 ]; then
		echo "Usage: ./s3-openbucketpolicy.sh environment"
		read -rp "S3 Bucket Environment? (dev/staging/prod/all): " s3bucketenv
		if [ -z "$s3bucketenv" ]; then
			fail "Invalid environment."
		fi

		if [ $s3bucketenv = "all" ]; then
			s3bucketenv=all
		else
			s3bucketname="$s3bucketname"-"$s3bucketenv"
		fi
	fi

	# Test for variable passed as argument
	if [ -z "$1" ]; then
	    if [ $s3bucketenv = "all" ]; then
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
	else
		if [ $1 = "all" ]; then
			s3bucketname="$s3bucketname"-dev
			run
			s3bucketname="$s3bucketname"-staging
			run
			s3bucketname="$s3bucketname"-prod
			run
		else
			s3bucketname="$s3bucketname"-"$1"
			run
		fi
	fi
	# echo $s3bucketname
}


check_command "jq"

if [ "$s3bucketname" = "YOUR-S3-BUCKET-NAME" ]; then
	fail "You must set your S3 bucket name in the script variables."
fi

setBucketName $1
