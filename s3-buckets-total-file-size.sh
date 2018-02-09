#!/usr/bin/env bash
# Script to count total size of all data stored in a single or in all S3 buckets
# Requires aws s3api, jq, IAM account must have permission to access all buckets

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

# Convert bytes to human readable
function bytestohr(){
    SLIST="bytes,KB,MB,GB,TB,PB,EB,ZB,YB"

    POWER=1
    VAL=$( echo "scale=2; $1 / 1" | bc)
    VINT=$( echo $VAL / 1024 | bc )
    while [ $VINT -gt 0 ]
    do
        let POWER=POWER+1
        VAL=$( echo "scale=2; $VAL / 1024" | bc)
        VINT=$( echo $VAL / 1024 | bc )
    done

    echo $VAL $( echo $SLIST | cut -f$POWER -d, )
}

# One bucket or all buckets
function choiceMenu(){
  tput smul; echo "Single S3 bucket or all buckets?" && tput sgr0
  echo 1. Single bucket
  echo 2. All buckets
  echo
  read -r -p "Menu selection #: " menuSelection

  case $menuSelection in
    1)
      SingleBucket
    ;;
    2)
      AllBuckets
    ;;
    *)
      fail "Invalid selection!"
    ;;
  esac
}

function SingleBucket(){
  read -r -p "Bucket name: s3://" CURRENTBUCKET
  echo
  echo "Calculating size..."
  CURRENTBUCKETREGION=$(aws s3api get-bucket-location --bucket $CURRENTBUCKET --output text --profile $profile 2>&1)
  if echo $CURRENTBUCKETREGION | grep -q None; then
    REGION="us-east-1"
  else
    REGION=$CURRENTBUCKETREGION
  fi
  CURRENTBUCKETSIZE=$(aws s3api list-objects --bucket $CURRENTBUCKET --region $REGION --output json --query "[sum(Contents[].Size)]" --profile $profile 2>&1)
  if echo $CURRENTBUCKETSIZE | grep -q invalid; then
    CURRENTBUCKETSIZE="0"
  else
    CURRENTBUCKETSIZE=$(echo "$CURRENTBUCKETSIZE" | jq '.[]')
  fi
  echo
  echo "Size: "
  bytestohr $CURRENTBUCKETSIZE
  completed
}

function AllBuckets(){
  # List buckets
  LS=$(aws s3 ls --profile $profile 2>&1)

  # Count number of buckets
  TOTALNUMBERS3BUCKETS=$(echo "$LS" | wc -l | rev | cut -d " " -f1 | rev)

  # Get list of all bucket names
  BUCKETNAMES=$(echo "$LS" | cut -d ' ' -f3 | nl)

  echo
  HorizontalRule
  echo "Counting Total Size of Data in $TOTALNUMBERS3BUCKETS S3 Buckets"
  echo "(This may take a very long time depending on number of files)"
  HorizontalRule
  echo

  START=1
  TOTALBUCKETSIZE=0

  for (( COUNT=$START; COUNT<=$TOTALNUMBERS3BUCKETS; COUNT++ ))
  do
    CURRENTBUCKET=$(echo "$BUCKETNAMES" | grep -w [^0-9][[:space:]]$COUNT | cut -f2)
    HorizontalRule
    echo \#$COUNT $CURRENTBUCKET

    CURRENTBUCKETREGION=$(aws s3api get-bucket-location --bucket $CURRENTBUCKET --output text --profile $profile 2>&1)
    if echo $CURRENTBUCKETREGION | grep -q None; then
      REGION="us-east-1"
    else
      REGION=$CURRENTBUCKETREGION
    fi
    CURRENTBUCKETSIZE=$(aws s3api list-objects --bucket $CURRENTBUCKET --region $REGION --output json --query "[sum(Contents[].Size)]" --profile $profile 2>&1)
    if echo $CURRENTBUCKETSIZE | grep -q invalid; then
      CURRENTBUCKETSIZE="0"
    else
      CURRENTBUCKETSIZE=$(echo "$CURRENTBUCKETSIZE" | jq '.[]')
    fi
    TOTALBUCKETSIZE=$(($TOTALBUCKETSIZE + $CURRENTBUCKETSIZE))
    echo "Size: "
    bytestohr $CURRENTBUCKETSIZE
    echo "Subtotal: "
    bytestohr $TOTALBUCKETSIZE
  done

  completed
  echo "Total Size of Data in All $TOTALNUMBERS3BUCKETS S3 Buckets:"
  bytestohr $TOTALBUCKETSIZE
}

choiceMenu
