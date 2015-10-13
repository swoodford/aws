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

	# Remove any empty lines
	while read iplist
	do
		if echo $iplist | egrep -q '^/32$'; then
			echo $iplist | sed -i '/\/32/d' |  cat -s >> iplist4
		else echo $iplist >> iplist4
		fi
	done < iplist
	mv iplist4 iplist
	
	if grep -qv '/[0-9]' iplist; then
		echo "One or more lines contain invalid or missing CIDR notation. Please fix line:"
		grep -vn '/[0-9]' iplist
		failed
	fi
}

# New Validate CIDR notation
function newValidateCIDR(){
	while read iplist
	do
		if ! echo $iplist | egrep -q '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$'; then
			echo $iplist/32 >> iplist3
		else echo $iplist >> iplist3
		fi
	done < iplist
	mv iplist3 iplist
}

# Remove any empty lines
function removeEmptyLines(){
	while read iplist
	do
		if echo $iplist | egrep -q '^/32$'; then
			echo $iplist | sed -i '/\/32/d' |  cat -s >> iplist4
		else echo $iplist >> iplist4
		fi
	done < iplist
	mv iplist4 iplist

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
function JSONizeiplist {
	while read iplist
	do
		echo \"$iplist\",>> iplistjson2
	done < iplist
	cat iplistjson2 | sed '$ s/.$//' >> iplistjson3
	rm iplistjson2 && mv iplistjson3 iplistjson

	iplistjson=$(cat iplistjson)

	# echo "$iplistjson"
}

# Create the JSON policy document
function JSONizePolicy {
	echo '{"Version":"2012-10-17","Id":"'"$s3bucketname"'","Statement":[{"Sid":"'"$s3bucketname"'","Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::'"$s3bucketname"'/*","Condition":{"IpAddress":{"aws:SourceIp":['"$iplistjson"']}}}]}' > policy.json
}

# Set the S3 bucket policy
function setS3Policy {
	setS3Policy=$(aws s3api put-bucket-policy --bucket $s3bucketname --policy file://policy.json 2>&1)
}

# Validate the new policy
function validateS3Policy {
	bucketpolicy=$(aws s3api get-bucket-policy --bucket $s3bucketname --output text | jq '.Statement | .[] | .Condition | .IpAddress | ."aws:SourceIp" | .[]' | cut -d \" -f2 | sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4)
	jsonpolicy=$(cat policy.json | tr -d '\n' | jq '.Statement | .[] | .Condition | .IpAddress | ."aws:SourceIp" | .[]' | cut -d \" -f2)

	# echo "$bucketpolicy" > bucketpolicy
	# echo "$jsonpolicy" > jsonpolicy

	if [ "$bucketpolicy" = "$jsonpolicy" ]; then
		echo "==========================================================="
		tput setaf 2; echo S3 Bucket: $s3bucketname Policy Set Successfully! && tput sgr0
		tput setaf 2; echo Set Conditional IP Allow List && tput sgr0
		echo "==========================================================="
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
		echo "Usage: ./s3-restrictbucketpolicy.sh environment"
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

# validateCIDR
newValidateCIDR
removeEmptyLines
cleanup
JSONizeiplist
setBucketName $1
rm iplistjson
