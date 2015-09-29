#!/usr/bin/env bash
# This script sets an S3 bucket policy to only allow GetObject requests from an IP whitelist file named iplist
# Usage: ./s3-restrictbucketpolicy.sh environment

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

# echo $s3bucketname


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

function setBucketName {
	# Check for environment argument passed into the script
	if [ $# -eq 0 ]; then
		echo "Usage: ./s3-restrictbucketpolicy.sh environment"
		read -rp "S3 Bucket Environment? (dev/staging/prod): " s3bucketenv
		# Set S3 bucket name
		s3bucketname="$s3bucketname"-"$s3bucketenv"
		# Get current directory
		# export dir=$(pwd | rev | cut -d/ -f1 | rev)
	else
		s3bucketname="$s3bucketname"-"$1"
	fi
}

# Validates CIDR notation
function validateCIDR {
	while read iplist
	do
		# echo $iplist
		if ! echo $iplist | egrep -q '/24$'; then
			if ! echo $iplist | egrep -q '/32$'; then
				echo $iplist/32 >> iplist3
			else echo $iplist >> iplist3
			fi
		else echo $iplist >> iplist3
		fi
	done < iplist

	mv iplist3 iplist

	if grep -qv '/[0-9]' iplist; then
		echo "One or more lines contain invalid or missing CIDR notation. Please fix line:"
		grep -vn '/[0-9]' iplist
		failed
	fi
}

# Cleanup list
function cleanup {
	sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 iplist | uniq > iplist2
	mv iplist2 iplist
	# echo "iplist cleanup completed."
}

# Output the list in JSON
function JSONize {
	while read iplist
	do
		echo \"$iplist\",>> iplistjson2
	done < iplist
	cat iplistjson2 | sed '$ s/.$//' >> iplistjson3
	rm iplistjson2 && mv iplistjson3 iplistjson

	iplistjson=$(cat iplistjson)

	# echo "$iplistjson"

	# Create the JSON policy document
	echo '{"Version":"2012-10-17","Id":"'"$s3bucketname"'","Statement":[{"Sid":"'"$s3bucketname"'","Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::'"$s3bucketname"'/*","Condition":{"IpAddress":{"aws:SourceIp":['"$iplistjson"']}}}]}' > policy.json
}

# Set the S3 bucket policy
function setS3Policy {
	setS3Policy=$(aws s3api put-bucket-policy --bucket $s3bucketname --policy file://policy.json)
}

# Validate the new policy
function validateS3Policy {
	bucketpolicy=$(aws s3api get-bucket-policy --bucket $s3bucketname | jq '.Statement | .[] | .Condition | .IpAddress | ."aws:SourceIp" | .[]' | cut -d \" -f2 | sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4)
	jsonpolicy=$(cat policy.json | tr -d '\n' | jq '.Statement | .[] | .Condition | .IpAddress | ."aws:SourceIp" | .[]' | cut -d \" -f2)

	# echo "$bucketpolicy" > bucketpolicy
	# echo "$jsonpolicy" > jsonpolicy

	if [ "$bucketpolicy" = "$jsonpolicy" ]; then
		echo "==========================================================="
		tput setaf 2; echo S3 Bucket: $s3bucketname Policy Set Successfully! && tput sgr0
		tput setaf 2; echo Set Conditional IP Allow List && tput sgr0
		echo "==========================================================="
		rm iplistjson
		# rm policy.json
	else
		fail $(echo $setS3Policy)
	fi
}

check_command "jq"
if [ "$s3bucketname" = "YOUR-S3-BUCKET-NAME" ]; then
	fail "You must set your S3 bucket name in the script variables."
fi
setBucketName
validateCIDR
cleanup
JSONize
setS3Policy
validateS3Policy
