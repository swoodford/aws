#!/usr/bin/env bash
# Script to export S3 bucket ACL, CORS, Policy and Website JSON for auditing security of all buckets
# Each S3 bucket will have a JSON file generated in the subfolder specified
# Requires aws s3api, jq, (AWS CLI profile must have IAM permission to access all buckets)

SUBFOLDER=s3-bucket-audit-$(date +%Y-%m-%d)
# OUTPUTFILENAME=s3-bucket-audit-$(date +%Y-%m-%d).json

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

# Check required commands
check_command "jq"

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

if echo "$LS" | egrep -q "Error|error|not"; then
  fail "$LS"
fi

# Get list of all bucket names
BUCKETNAMES=$(echo "$LS" | cut -d ' ' -f 3 | nl)

# Count number of buckets
TOTALNUMBERS3BUCKETS=$(echo "$BUCKETNAMES" | wc -l | rev | cut -d " " -f1 | rev)

echo
HorizontalRule
echo "Exporting policies for $TOTALNUMBERS3BUCKETS S3 Buckets"
echo "Generating JSON files in subfolder: $SUBFOLDER"
HorizontalRule
echo

# # Check for existing report file
# if [ -f $OUTPUTFILENAME ]; then
#   tput setaf 1
#   echo "Report already generated!"
#   echo $OUTPUTFILENAME
#   read -r -p "Overwrite? (y/n) " OVERWRITE
#   if ! [[ $OVERWRITE =~ ^([yY][eE][sS]|[yY])$ ]]; then
#     fail "Report already generated."
#   else
#     rm $OUTPUTFILENAME
#   fi
#   tput sgr0
# fi

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

  OUTPUTFILENAME=$SUBFOLDER/$CURRENTBUCKET.json

  # Overwrite any existing file
  if [ -f $OUTPUTFILENAME ]; then
    rm $OUTPUTFILENAME
  fi

  # Determine the bucket region
  CURRENTBUCKETREGION=$(aws s3api get-bucket-location --bucket $CURRENTBUCKET --output text --profile $profile 2>&1)
  if echo $CURRENTBUCKETREGION | grep -q "None"; then
    REGION="us-east-1"
  else
    REGION=$CURRENTBUCKETREGION
  fi

  # Lookup the access control policy
  ACL=$(aws s3api get-bucket-acl --bucket $CURRENTBUCKET --region $REGION --profile $profile 2>&1)
  # ACL=$(aws s3api get-bucket-acl --bucket $CURRENTBUCKET --profile $profile 2>&1 | sed 's/\,/;/g')

  if echo "$ACL" | grep -q "error"; then
    ACL='{
    "ACL": [
    ]
}'
  fi

  # Lookup the CORS policy
  CORS=$(aws s3api get-bucket-cors --bucket $CURRENTBUCKET --region $REGION --profile $profile 2>&1)
  # CORS=$(aws s3api get-bucket-cors --bucket $CURRENTBUCKET --profile $profile 2>&1 | sed 's/\,/;/g')

  if echo "$CORS" | grep -q "error"; then
    CORS='{
    "CORSRules": [
    ]
}'
  fi

  # Lookup the bucket policy
  POLICY=$(aws s3api get-bucket-policy --bucket $CURRENTBUCKET --region $REGION --profile $profile --output text 2>&1)

  if echo "$POLICY" | grep -q "error"; then
    POLICY='{
    "Policy": [
    ]
}'
  else
    POLICY=$(echo $POLICY | jq .)
    # POLICY=$(echo $POLICY | jq . | sed 's/\,/;/g')
  fi

  # Lookup the website hosting policy
  WEBSITE=$(aws s3api get-bucket-website --bucket $CURRENTBUCKET --region $REGION --profile $profile 2>&1)

  if echo "$WEBSITE" | grep -q "error"; then
    WEBSITE='{
    "Website": [
    ]
}'
  fi

  # Combine everything into one JSON file
  OUTPUT=$(echo $ACL $CORS $POLICY $WEBSITE | jq -s add)
  echo "$OUTPUT" >> $OUTPUTFILENAME

done

completed
echo "JSON files generated under subfolder: $SUBFOLDER"
