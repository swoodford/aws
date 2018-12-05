#!/usr/bin/env bash
# Script to delete all Glacier storage type objects in a single S3 bucket
# Requires aws s3api, jq


# Set Variables
S3BUCKET="YOUR-S3-BUCKET-NAME"


# Functions

# Fail
function fail(){
  tput setaf 1; echo "Failure: $*" && tput sgr0
  exit 1
}

# Check for command
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

# Check required commands
check_command "aws"
check_command "jq"

# Validate Variable
if [[ "$S3BUCKET" == "YOUR-S3-BUCKET-NAME" ]]; then
	read -r -p "Enter S3 Bucket name: " S3BUCKET
fi

if [ -z "$S3BUCKET" ]; then
	fail "S3 Bucket name must be set."
fi

read -r -p "Warning: this will delete all objects from the S3 bucket with storage type Glacier!  Proceed? (y/n) " Proceed
if ! [[ $Proceed =~ ^([yY][eE][sS]|[yY])$ ]]; then
	fail "Canceled."
fi

S3BUCKETREGION=$(aws s3api get-bucket-location --bucket "$S3BUCKET" --output text --profile $profile 2>&1)
if [ ! $? -eq 0 ]; then
	fail "$S3BUCKETREGION"
else
	if echo $S3BUCKETREGION | grep -q None; then
	REGION="us-east-1"
	else
	REGION=$S3BUCKETREGION
	fi
fi

LISTGLACIER=$(aws s3api list-objects-v2 --bucket "$S3BUCKET" --query "Contents[?StorageClass=='GLACIER'].Key" --output json --profile $profile --max-items 9999 --region $REGION 2>&1)

if [ ! $? -eq 0 ]; then
	fail "$LISTGLACIER"
else
	if [ -z "$LISTGLACIER" ] || [ "$LISTGLACIER" == "[]" ]; then
		fail "No Glacier objects found in this S3 bucket."
	fi
	PARSEGLACIER=$(echo "$LISTGLACIER" | jq .[] | cut -d \" -f2 > GLACIER.txt)
fi

while read glacier
do
	RM=$(aws s3 rm s3://"$S3BUCKET"/"$glacier" --profile $profile --region $REGION 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$RM"
	else
		echo "Deleted object:" "$glacier"
	fi
done < GLACIER.txt

rm GLACIER.txt
completed
