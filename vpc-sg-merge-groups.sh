#!/usr/bin/env bash

# This script will merge two existing VPC Security Groups together into one single group
# Security Groups must exist in the same VPC, total rules must be 50 or less
# Any duplicate rules in the two groups will cause an error
# Note: this script is somewhat experimental and you should manually verify all results before applying the new group!!!
# Requires the AWS CLI and jq

# Set Variables
VPCID="YOUR-VPC-ID-HERE"

# Debug Mode
DEBUGMODE="0"


# Functions


# Check Command
function check_command(){
	for command in "$@"
	do
	    type -P $command &>/dev/null || fail "Unable to find $command, please install it and run this script again."
	done
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
	tput setaf 1; echo "Error: $*" && tput sgr0
	exit 1
}

# Horizontal Rule
function HorizontalRule(){
	echo "============================================================"
}

# Pause
function pause(){
	read -n 1 -s -p "Press any key to continue..."
	echo
}

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/credentials; then
	if ! grep -q aws_access_key_id ~/.aws/config; then
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
				echo $vpcid - Name: $(aws ec2 describe-tags --filters "Name=resource-id,Values=$vpcid" "Name=key,Values=Name" --profile $profile 2>&1 | jq '.Tags | .[] | .Value' | cut -d \" -f2)
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

# Describe Security Groups
function describeSGS(){
	describeSGS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPCID" --output=json --profile $profile 2>&1) # | jq '.SecurityGroups | .[] | .GroupName')
	if [ ! $? -eq 0 ]; then
		fail "$describeSGS"
	fi
	sgIDs=$(echo "$describeSGS" | jq '.SecurityGroups | .[] | .GroupId' | cut -d \" -f2)
	if [ ! $? -eq 0 ]; then
		fail "$sgIDs"
	fi

	HorizontalRule
	echo "Found Security Groups:"
	HorizontalRule
	# Get SG Names
	for sgid in $sgIDs; do
		echo $sgid - Group Name: $(aws ec2 describe-security-groups --group-ids $sgid --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName' | cut -d \" -f2)
		# echo $sgid - Name: $(aws ec2 describe-tags --filters "Name=resource-id,Values=$sgid" "Name=key,Values=Name" --profile $profile 2>&1 | jq '.Tags | .[] | .Value' | cut -d \" -f2)
	done
	echo
}

# Select Security Groups
function selectSGS(){
	HorizontalRule
	read -r -p "Please specify FIRST Security Group ID (ex. sg-abcd1234): " SGID1
	if [ -z "$SGID1" ]; then
		fail "Must specify a valid Security Group ID."
	fi
	describeSGID1=$(aws ec2 describe-security-groups --group-ids $SGID1 --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$describeSGID1"
	fi
	SGNAME1=$(echo "$describeSGID1" | jq '.SecurityGroups | .[] | .GroupName' | cut -d \" -f2)
	SGDESC1=$(echo "$describeSGID1" | jq '.SecurityGroups | .[] | .Description' | cut -d \" -f2)
	echo
	HorizontalRule
	read -r -p "Please specify SECOND Security Group ID (ex. sg-abcd1234): " SGID2
	if [ -z "$SGID2" ]; then
		fail "Must specify a valid Security Group ID."
	fi
	describeSGID2=$(aws ec2 describe-security-groups --group-ids $SGID2 --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$describeSGID2"
	fi
	SGNAME2=$(echo "$describeSGID2" | jq '.SecurityGroups | .[] | .GroupName' | cut -d \" -f2)
	SGDESC2=$(echo "$describeSGID2" | jq '.SecurityGroups | .[] | .Description' | cut -d \" -f2)
	SGNAME3="$SGNAME1 & $SGNAME2"
}

# Create Security Group
function createGroup(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "function createGroup"
		echo var1: "$1"
	fi
	echo
	HorizontalRule
	echo "Creating Security Group: $1"
	createGroup=$(aws ec2 create-security-group --group-name "$1" --description "$1" --vpc-id $VPCID --profile $profile 2>&1)
	if echo $createGroup | grep -q 'InvalidGroup.Duplicate'; then
		tput setaf 1; echo "Error: The security group $1 already exists." && tput sgr0
		HorizontalRule
		echo "Attepting to create group with todays date appended to the name."
		DATE=$(date +%m-%d-%Y)
		GROUPNAME="$1-$DATE"
		echo "Creating Security Group: $GROUPNAME"
		createGroup=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$1" --vpc-id $VPCID --profile $profile 2>&1)
	fi
	if [ ! $? -eq 0 ]; then
		fail "$createGroup"
	fi
	if echo $createGroup | grep -q "error"; then
		fail "$createGroup"
	fi
	SGID=$(echo "$createGroup" | jq '.GroupId' | cut -d \" -f2)
	if [ ! $? -eq 0 ]; then
		fail "$SGID"
	fi
	if echo $SGID | grep -q "error"; then
		fail "$SGID"
	fi
	echo "New Security Group ID:" $SGID
	TAG=$(aws ec2 create-tags --resources $SGID --tags Key=Name,Value="$1" --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$TAG"
	fi
	if echo $TAG | grep -q "error"; then
		fail "$TAG"
	fi
	HorizontalRule
	echo
}

# Request ingress authorization to a security group from JSON file
function AuthorizeSecurityGroupIngress(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "function AuthorizeSecurityGroupIngress"
	fi
	HorizontalRule
	echo "Adding ingress rules to security groups..."
	HorizontalRule
	echo
	json=$(cat "$1")
	AUTHORIZE=$(aws ec2 authorize-security-group-ingress --cli-input-json "$json" --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$AUTHORIZE"
	fi
	if echo $AUTHORIZE | grep -q error; then
		fail "$AUTHORIZE"
	fi
}

# Request egress authorization to a security group from JSON file
function AuthorizeSecurityGroupEgress(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "function AuthorizeSecurityGroupEgress"
	fi
	HorizontalRule
	echo "Adding egress rules to security groups..."
	HorizontalRule
	echo
	json=$(cat "$1")
	AUTHORIZE=$(aws ec2 authorize-security-group-egress --cli-input-json "$json" --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$AUTHORIZE"
	fi
	if echo $AUTHORIZE | grep -q error; then
		fail "$AUTHORIZE"
	fi
}

# Builds the JSON for new security group
function buildJSON(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "function buildJSON"
	fi

	SGINGRESS1=$(echo "$describeSGID1" | jq '.SecurityGroups | .[] | .IpPermissions')
	SGINGRESS2=$(echo "$describeSGID2" | jq '.SecurityGroups | .[] | .IpPermissions')
	SGEGRESS1=$(echo "$describeSGID1" | jq '.SecurityGroups | .[] | .IpPermissionsEgress')
	SGEGRESS2=$(echo "$describeSGID2" | jq '.SecurityGroups | .[] | .IpPermissionsEgress')

	(
	cat << EOP
{
    "GroupId": "$SGID",
    "IpPermissions":
        $SGINGRESS1
}
EOP
	) > SGINGRESS1
	if [[ $DEBUGMODE = "1" ]]; then
		echo built SGINGRESS1
	fi
	# rm -f SGINGRESS1
	(
	cat << EOP
{
    "GroupId": "$SGID",
    "IpPermissions":
        $SGINGRESS2
}
EOP
	) > SGINGRESS2
	if [[ $DEBUGMODE = "1" ]]; then
		echo built SGINGRESS2
	fi
	# rm -f SGINGRESS2
	(
	cat << EOP
{
    "GroupId": "$SGID",
    "IpPermissions":
        $SGEGRESS1
}
EOP
	) > SGEGRESS1
	if [[ $DEBUGMODE = "1" ]]; then
		echo built SGEGRESS1
	fi
	# rm -f SGEGRESS1
	(
	cat << EOP
{
    "GroupId": "$SGID",
    "IpPermissions":
        $SGEGRESS2
}
EOP
	) > SGEGRESS2
	if [[ $DEBUGMODE = "1" ]]; then
		echo built SGEGRESS2
	fi
	# rm -f SGEGRESS2
	if ! [ -f SGINGRESS1 ] || ! [ -f SGINGRESS2 ] || ! [ -f SGEGRESS1 ] || ! [ -f SGEGRESS2 ]; then
		fail "Error building JSON."
	fi
}


# Run the script and call functions

# Check for required applications
check_command aws jq

HorizontalRule
echo "This script will merge two existing VPC Security Groups together into one single group."
HorizontalRule
echo

validateVPCID

describeSGS

selectSGS

echo
tput setaf 1; echo "Please review before continuing..." && tput sgr0
echo
echo "VPC ID:" $VPCID
echo
echo "First Security Group ID:" $SGID1
echo "First Group Name:" $SGNAME1
echo "First Group Description:" $SGDESC1
echo
echo "Second Security Group ID:" $SGID2
echo "Second Group Name:" $SGNAME2
echo "Second Group Description:" $SGDESC2
echo
echo "New Group Name:" $SGNAME3
echo
pause
echo

createGroup "$SGNAME3"

buildJSON

AuthorizeSecurityGroupIngress SGINGRESS1
AuthorizeSecurityGroupIngress SGINGRESS2

SGEGRESSTEST1=$(cat SGEGRESS1 | jq '.IpPermissions' > SGEGRESSTEST1)
if [ ! $? -eq 0 ]; then
	fail "$SGEGRESSTEST1"
fi
SGEGRESSTEST2=$(aws ec2 describe-security-groups --group-ids "$SGID" --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .IpPermissionsEgress' > SGEGRESSTEST2)
if [ ! $? -eq 0 ]; then
	fail "$SGEGRESSTEST2"
fi
COMPARE1=$(cmp --silent SGEGRESSTEST1 SGEGRESSTEST2 || AuthorizeSecurityGroupEgress SGEGRESS1)
if [[ $DEBUGMODE = "1" ]]; then
	echo "$COMPARE1"
fi

COMPARE2=$(cmp --silent SGEGRESS1 SGEGRESS2 || AuthorizeSecurityGroupEgress SGEGRESS2)
if [[ $DEBUGMODE = "1" ]]; then
	echo "$COMPARE2"
fi

if ! [[ $DEBUGMODE = "1" ]]; then
	rm -f SGINGRESS1 SGINGRESS2 SGEGRESS1 SGEGRESS2 SGEGRESSTEST1 SGEGRESSTEST2
fi

completed
