#!/usr/bin/env bash

# Create VPC Security Group with CloudFront IP ranges

# Get current list of CloudFront IP ranges
IPLIST=$(curl -s https://ip-ranges.amazonaws.com/ip-ranges.json | jq '.prefixes | .[] | select(.service=="CLOUDFRONT") | .ip_prefix' | cut -d \" -f2)

# Set Variables
GROUPNAME="CloudFront"
DESCR="CloudFront IP Ranges"
VPCID="YOUR-VPC-ID-HERE"
PROTO="tcp"
PORT="80"
TOTALIPS=$(echo "$IPLIST" | wc -l)


# Debug Mode
DEBUGMODE="0"


# Functions

# Check Command
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

# Fail
function fail(){
	tput setaf 1; echo "Failure: $*" && tput sgr0
	exit 1
}

# Horizontal Rule
function HorizontalRule(){
	echo "============================================================"
}

# Pause
function pause(){
	echo
	read -n 1 -s -p "Press any key to continue..."
	echo
	echo
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

# Validate VPC ID
function validateVPCID(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "function validateVPCID"
	fi
	if [ "$VPCID" = "YOUR-VPC-ID-HERE" ] || [ -z "$VPCID" ]; then
		# Count number of VPCs
		DESCRIBEVPCS=$(aws ec2 describe-vpcs --profile $profile 2>&1)
		if [ ! $? -eq 0 ]; then
			fail "$DESCRIBEVPCS"
		fi
		if echo $DESCRIBEVPCS | egrep -iq "error|not"; then
			fail "$DESCRIBEVPCS"
		fi
		NUMVPCS=$(echo $DESCRIBEVPCS | jq '.Vpcs | length')
		if [ ! $? -eq 0 ]; then
			fail "$NUMVPCS"
		fi
		if echo $NUMVPCS | egrep -iq "error|not|invalid"; then
			fail "$NUMVPCS"
		fi

		# If only one VPC, use that ID
		if [ "$NUMVPCS" -eq "1" ]; then
			VPCID=$(echo "$DESCRIBEVPCS" | jq '.Vpcs | .[] | .VpcId' | cut -d \" -f2)
			if [ ! $? -eq 0 ]; then
				fail "$VPCID"
			fi
		else
			FOUNDVPCS=$(echo "$DESCRIBEVPCS" | jq '.Vpcs | .[] | .VpcId' | cut -d \" -f2)
			if [ ! $? -eq 0 ]; then
				fail "$FOUNDVPCS"
			fi
			if echo $FOUNDVPCS | egrep -iq "error|not|invalid"; then
				fail "$FOUNDVPCS"
			fi

			HorizontalRule
			echo "Found VPCs:"
			HorizontalRule
			# Get VPC Names
			for vpcid in $FOUNDVPCS; do
				echo $vpcid - Name: $(aws ec2 describe-tags --filters "Name=resource-id,Values=$vpcid" "Name=key,Values=Name" | jq '.Tags | .[] | .Value' | cut -d \" -f2)
			done
			echo
			read -r -p "Please specify VPC ID (ex. vpc-abcd1234): " VPCID
			if [ -z "$VPCID" ]; then
				fail "Must specify a valid VPC ID."
			fi
		fi
	fi

	CHECKVPC=$(aws ec2 describe-vpcs --vpc-ids "$VPCID" --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$CHECKVPC"
	fi
	if ! echo "$CHECKVPC" | grep -q "available"; then
		fail $CHECKVPC
	else
		tput setaf 2; echo "VPC ID Validated" && tput sgr0
	fi
}

function addRules(){
	# Check for existing security group or create new one
	CHECKGROUP=$(aws ec2 describe-security-groups --output=json --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$CHECKGROUP"
	fi
	if ! echo "$CHECKGROUP" | jq '.SecurityGroups | .[] | .GroupName' | egrep -iq "$GROUPNAME"; then
		echo
		HorizontalRule
		echo "Creating Security Group "$GROUPNAME
		GROUPID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCR" --vpc-id $VPCID --profile $profile 2>&1)
		if [ ! $? -eq 0 ]; then
			fail "$GROUPID"
		else
			GROUPID=$(echo "$GROUPID" | jq '.GroupId' | cut -d \" -f2)
		fi
		echo "ID: $GROUPID"
		TAGS=$(aws ec2 create-tags --resources "$GROUPID" --tags Key=Name,Value="$GROUPNAME" --profile $profile 2>&1)
		if [ ! $? -eq 0 ]; then
			fail "$TAGS"
		fi
		HorizontalRule
	else
		echo
		HorizontalRule
		echo "Group $GROUPNAME Already Exists"
		CHECKGROUP=$(aws ec2 describe-security-groups --output=json --profile $profile 2>&1)
		if [ ! $? -eq 0 ]; then
			fail "$CHECKGROUP"
		fi
		GROUPID=$(echo "$CHECKGROUP" | jq '.SecurityGroups | .[] | select(.GroupName=="'$GROUPNAME'") | .GroupId' | cut -d \" -f2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo DEBUG GROUPID: "$GROUPID"
		fi
		read -r -p "Do you want to delete the group and recreate it? (y/n) " DELETEGROUP
		if [[ $DELETEGROUP =~ ^([yY][eE][sS]|[yY])$ ]]; then
			echo
			HorizontalRule
			echo "Deleting Group Name $GROUPNAME, Security Group ID $GROUPID"
			HorizontalRule
			DELETEGROUP=$(aws ec2 delete-security-group --group-id "$GROUPID" --profile $profile 2>&1)
			if echo $DELETEGROUP | grep -q error; then
				fail $DELETEGROUP
			else
				echo
				HorizontalRule
				echo "Creating Security Group "$GROUPNAME
				GROUPID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCR" --vpc-id $VPCID --profile $profile 2>&1)
				if [ ! $? -eq 0 ]; then
					fail "$GROUPID"
				else
					GROUPID=$(echo "$GROUPID" | jq '.GroupId' | cut -d \" -f2)
				fi
				echo "ID: $GROUPID"
				TAGS=$(aws ec2 create-tags --resources "$GROUPID" --tags Key=Name,Value="$GROUPNAME" --profile $profile 2>&1)
				if [ ! $? -eq 0 ]; then
					fail "$TAGS"
				fi
				HorizontalRule
			fi
		else
			echo "Exiting"
			exit 1
		fi
	fi
	echo
	echo
	HorizontalRule
	echo "Adding rules to VPC Security Group "$GROUPNAME
	echo "Records to be created: "$TOTALIPS
	HorizontalRule
	echo
	for ip in $IPLIST
	do
		RESULT=$(aws ec2 authorize-security-group-ingress --group-id "$GROUPID" --protocol $PROTO --port $PORT --cidr "$ip" --profile $profile 2>&1)
		if [ ! $? -eq 0 ]; then
			fail "$RESULT"
		fi
	done
	completed
}


# Check required commands
check_command "curl"
check_command "jq"

validateVPCID
addRules
