#!/usr/bin/env bash

# This script will export each AWS WAF IP set match condition to a JSON file for backup
# Requires the AWS CLI and jq


# Set Variables
SUBFOLDER=waf-export-ip-sets-$(date +%Y-%m-%d)

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

# Get list of all IP Sets
function ListIPSets(){
	ListIPSets=$(aws waf list-ip-sets --output=json --profile $profile 2>&1 | jq '.IPSets | .[]')
	if echo $ListIPSets | egrep -iq "error|not"; then
		fail "$ListIPSets"
	fi
	if [ -z "$ListIPSets" ]; then
		fail "No WAF IP Sets Found!"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "ListIPSets: "$ListIPSets
	fi
	IPSETNAMES=$(echo "$ListIPSets" | jq '.Name' | cut -d \" -f2)
	IPSETIDS=$(echo "$ListIPSets" | jq '.IPSetId' | cut -d \" -f2)
	TOTALIPSETS=$(echo "$IPSETIDS" | wc -l | rev | cut -d " " -f1 | rev)

	HorizontalRule
	echo "IP Sets Found:" $TOTALIPSETS
	HorizontalRule
	echo

	if [[ $DEBUGMODE = "1" ]]; then
		echo "$IPSETNAMES"
		echo "$IPSETIDS"
	fi
}

# Get a single IP Set
function GetIPSet(){
	GetIPSet=$(aws waf get-ip-set --ip-set-id "$IPSETID" --output=json --profile $profile 2>&1)
	if echo $GetIPSet | egrep -iq "error|not"; then
		fail "$GetIPSet"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "GetIPSet: "$GetIPSet
	fi
}

# Exports a single IP Set to a JSON file
function ExportExistingIPSet(){
	ListIPSets

	# Make the subfolder directory
	if ! [ -d $SUBFOLDER ]; then
		echo
		echo "Making Subfolder:" $SUBFOLDER
		echo
		mkdir $SUBFOLDER
	fi

	START=1
	for (( COUNT=$START; COUNT<=$TOTALIPSETS; COUNT++ ))
	do
		IPSETID=$(echo "$IPSETIDS" | nl | grep -w [^0-9][[:space:]]$COUNT | cut -f2)
		IPSETNAME=$(echo "$IPSETNAMES" | nl | grep -w [^0-9][[:space:]]$COUNT | cut -f2)
		echo "Exporting IP Set:" $IPSETNAME
		GetIPSet
		OUTPUTFILENAME=$SUBFOLDER/$IPSETID.json
		echo "$GetIPSet" > $OUTPUTFILENAME
	done
	completed
	echo "JSON exports generated under subfolder: $SUBFOLDER"
}

# Check required commands
check_command "aws"
check_command "jq"

ExportExistingIPSet
