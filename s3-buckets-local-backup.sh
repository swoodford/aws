#!/usr/bin/env bash
# Script to backup all S3 bucket contents locally
# Contents of each S3 bucket will be copied to the local subfolder specified
# Requires aws cli (AWS CLI profile must have IAM permission to access all buckets)

SUBFOLDER=s3-bucket-local-backup-$(date +%Y-%m-%d)

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
  SUBFOLDER=$SUBFOLDER-$1
fi

# List buckets
LS=$(aws s3 ls --profile $profile 2>&1)
if [ ! $? -eq 0 ]; then
  fail "$LS"
fi
if echo "$LS" | egrep -q "Error|error|not"; then
  fail "$LS"
fi

# Get list of all bucket names
BUCKETNAMES=$(echo "$LS" | cut -d ' ' -f3 | nl)

# Count number of buckets
TOTALNUMBERS3BUCKETS=$(echo "$BUCKETNAMES" | wc -l | rev | cut -d " " -f1 | rev)

echo
HorizontalRule
echo "Local backup running for $TOTALNUMBERS3BUCKETS S3 Buckets"
echo "Copying files to subfolder: $SUBFOLDER"
HorizontalRule
echo

# Make the subfolder directory
if ! [ -d $SUBFOLDER ]; then
  mkdir $SUBFOLDER
fi

START=1

for (( COUNT=$START; COUNT<=$TOTALNUMBERS3BUCKETS; COUNT++ ))
do
  CURRENTBUCKET=$(echo "$BUCKETNAMES" | grep -w [^0-9][[:space:]]$COUNT | cut -f2)
  HorizontalRule
  echo \#$COUNT $CURRENTBUCKET

  # Determine the bucket region
  REGION=$(aws s3api get-bucket-location --bucket $CURRENTBUCKET --output text --profile $profile 2>&1)
  if [ ! $? -eq 0 ]; then
    fail "$REGION"
  fi
  if echo $REGION | grep -q "None"; then
    REGION="us-east-1"
  fi

  # Backup the S3 bucket contents
  BACKUP=$(aws s3 sync s3://$CURRENTBUCKET $SUBFOLDER/$CURRENTBUCKET/ --region $REGION --profile $profile --quiet 2>&1)
  if [ ! $? -eq 0 ]; then
    fail "$BACKUP"
  fi
  if echo "$BACKUP" | egrep -iq "error|not"; then
    fail "$BACKUP"
  fi
done

completed
echo "Backup files saved under subfolder: $SUBFOLDER"
