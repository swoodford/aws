#!/usr/bin/env bash

# This script will read from the list of IPs in the file iplist
# Then create an AWS VPC Security Group with rules to allow access to each IP at the port specified
# Due to AWS limits a group can only have 50 rules and will create multiple groups if greater than 50 rules
# Requires the AWS CLI and jq

# Set Variables
GROUPNAME="YOUR GROUP NAME"
DESCR="YOUR GROUP DESCRIPTION"
VPCID="YOUR-VPC-ID-HERE"
PROTO="YOUR-PROTOCOL"
PORT="YOUR-PORT"

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

# Check required commands
check_command "aws"
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
fi

# Validate VPC ID
function validateVPCID(){
	if [ "$VPCID" = "YOUR-VPC-ID-HERE" ] || [ -z "$VPCID" ]; then
		# Count number of VPCs
		DESCRIBEVPCS=$(aws ec2 describe-vpcs --profile $profile 2>&1)
		if echo $DESCRIBEVPCS | egrep -iq "error|not|invalid"; then
			fail "$DESCRIBEVPCS"
		fi
		NUMVPCS=$(echo $DESCRIBEVPCS | jq '.Vpcs | length')
		if echo $NUMVPCS | egrep -iq "error|not|invalid"; then
			fail "$NUMVPCS"
		fi

		# If only one VPC, use that ID
		if [ "$NUMVPCS" -eq "1" ]; then
			VPCID=$(echo "$DESCRIBEVPCS" | jq '.Vpcs | .[] | .VpcId' | cut -d \" -f2)
		else
			FOUNDVPCS=$(aws ec2 describe-vpcs --profile $profile 2>&1 | jq '.Vpcs | .[] | .VpcId')
			if echo $FOUNDVPCS | egrep -iq "error|not|invalid"; then
				fail "$FOUNDVPCS"
			fi
			echo "Found VPCs:" $FOUNDVPCS
			echo
			read -r -p "Please specify VPC ID (ex. vpc-12345678): " VPCID
			if [ -z "$VPCID" ]; then
				fail "Must specify a valid VPC ID."
			fi
		fi
	fi
	CHECKVPC=$(aws ec2 describe-vpcs --vpc-ids "$VPCID" --profile $profile 2>&1)

	# Test for error
	if ! echo "$CHECKVPC" | grep -q "available"; then
		fail $CHECKVPC
	else
		HorizontalRule
		tput setaf 2; echo "VPC ID Validated" && tput sgr0
		HorizontalRule
	fi
}

function createGroup(){
	echo
	HorizontalRule
	echo "Creating Security Group "$GROUPNAME
	creategroup=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCR" --vpc-id $VPCID --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$creategroup"
	fi
	SGID=$(echo "$creategroup" | jq '.GroupId' | cut -d \" -f2)
	if [ ! $? -eq 0 ]; then
		fail "$SGID"
	fi
	echo "Security Group ID: $SGID"
	TAG=$(aws ec2 create-tags --resources $SGID --tags Key=Name,Value="$GROUPNAME" --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$TAG"
	fi
	HorizontalRule
	echo
}

function addRule(){
	addrule=$(aws ec2 authorize-security-group-ingress --group-name "$GROUPNAME" --protocol $PROTO --port $PORT --cidr "$iplist/32" --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$addrule"
	fi
}

# Create one group with 50 rules or less
function addRules (){
	createGroup
	echo
	HorizontalRule
	echo "Adding rules to VPC Security Group "$GROUPNAME
	echo "Records to be created: "$TOTALIPS
	HorizontalRule
	echo
	while read iplist
	do
		addRule
	done < iplist
	HorizontalRule
	echo
	tput setaf 2; echo "Completed!" && tput sgr0
	echo
}

# Create multiple groups for more than 50 rules
function addRules50 (){
	# Set Variables for Group #1
	GROUPNAME="YOUR GROUP NAME 1"
	DESCR="YOUR GROUP NAME 1-50"
	START=1

	createGroup
	echo
	HorizontalRule
	echo "Adding rules to VPC Security Group "$GROUPNAME
	echo "Records to be created: 50" #$TOTALIPS
	HorizontalRule
	echo

	# Begin loop to create rules 1-50
	for (( COUNT=$START; COUNT<=50; COUNT++ ))
	do
		echo "Rule "\#$COUNT

		iplist=$(nl iplist | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
		echo "IP="$iplist

		addRule
	done

	# Set Variables for Group #2
	GROUPNAME="YOUR GROUP NAME 2"
	DESCR="YOUR GROUP NAME 51-$TOTALIPS"
	START=51

	createGroup
	echo
	HorizontalRule
	echo "Adding rules to VPC Security Group "$GROUPNAME
	echo "Records to be created: "$(expr $TOTALIPS - 50)
	HorizontalRule
	echo

	# Begin loop to create rules 51-n
	for (( COUNT=$START; COUNT<=$TOTALIPS; COUNT++ ))
	do
		echo "Rule "\#$COUNT

		iplist=$(nl iplist | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
		echo "IP="$iplist

		addRule
	done
	HorizontalRule
	echo
	tput setaf 2; echo "Completed!" && tput sgr0
	echo
}

validateVPCID

if [ -f "iplist" ]; then
	TOTALIPS=$(cat iplist | wc -l | tr -d ' ')
else
	fail "Missing file: iplist"
fi

# Create one group with 50 rules or less
if [ "$TOTALIPS" -lt "51" ]; then
	addRules
	completed
fi

# Create multiple groups for more than 50 rules
if [ "$TOTALIPS" -gt "50" ]; then
	addRules50
	completed
fi

# More than 100 rules
if [ "$TOTALIPS" -gt "100" ]; then
	fail "More than 100 IPs not yet supported."
fi
