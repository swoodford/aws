#!/bin/bash
# This script will create the S3 IAM user, generate IAM keys, add to IAM group, generate user policy
# You will want to modify for your own naming conventions and IAM user group name
# Requires awscli and local IAM account with sufficient permissions

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
  if ! grep -q aws_access_key_id ~/.aws/credentials; then
    echo "Error: AWS config not found or CLI not installed. Please run \"aws configure\"."
    exit 1
  fi
fi

echo "This script will create the S3 IAM user, generate IAM keys, add to IAM group, generate user policy."
read -r -p "Enter the client name: " CLIENT

echo " "
echo "====================================================="
echo "Creating IAM User: "s3-$CLIENT
aws iam create-user --user-name s3-$CLIENT --output json
echo "====================================================="
echo " "
echo "====================================================="
echo "Generating IAM Access Keys"
aws iam create-access-key --user-name s3-$CLIENT --output json
echo "====================================================="
echo " "
echo "====================================================="
echo "Adding to IAM Group"
aws iam add-user-to-group --user-name s3-$CLIENT --group-name s3-users

cat > userpolicy.json << EOL
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::$CLIENT-dev",
                "arn:aws:s3:::$CLIENT-dev/*",
                "arn:aws:s3:::$CLIENT-production",
                "arn:aws:s3:::$CLIENT-production/*",
                "arn:aws:s3:::$CLIENT-staging",
                "arn:aws:s3:::$CLIENT-staging/*"
            ]
        }
    ]
}
EOL
echo " "
echo "====================================================="
echo "Generating User Policy"
aws iam put-user-policy --user-name s3-$CLIENT --policy-name $CLIENT-s3-buckets --policy-document file://userpolicy.json
rm userpolicy.json
echo " "
echo "====================================================="
echo "Completed!  Created user: "s3-$CLIENT
echo "====================================================="