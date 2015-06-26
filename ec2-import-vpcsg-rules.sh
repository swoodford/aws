#!/usr/bin/env bash

# This script will read from the list of IPs in the file iplist
# Then create an AWS VPC Security Group with rules to allow access to each IP at the port specified
# Due to AWS limits a group can only have 50 rules and will create multiple groups if greater than 50 rules
# Requires the AWS CLI

# Set Variables
GROUPNAME="YOUR GROUP NAME"
DESCR="YOUR GROUP DESCRIPTION"
VPCID="YOUR-VPC-ID-HERE"
PROTO="YOUR-PROTOCOL"
PORT="YOUR-PORT"

# Ensure Variables are set
if [ "$VPCID" = "YOUR-VPC-ID-HERE" ]; then
	tput setaf 1; echo "Failed to set variables!" && tput sgr0
	exit 1
fi

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
	if ! grep -q aws_access_key_id ~/.aws/credentials; then
		tput setaf 1; echo "Error: AWS config not found or CLI not installed. Please run \"aws configure\"." && tput sgr0
		exit 1
	fi
fi


TOTALIPS=$(wc -l iplist | cut -d " " -f7)

# Create one group with 50 rules or less
function addRules (){
	echo
	echo "====================================================="
	echo "Creating Security Group "$GROUPNAME
	aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCR" --vpc-id $VPCID
	echo "====================================================="
	echo
	echo
	echo "====================================================="
	echo "Adding rules to VPC Security Group "$GROUPNAME
	echo "Records to be created: "$TOTALIPS
	echo "====================================================="
	echo
	while read iplist
	do
		aws ec2 authorize-security-group-ingress --group-name "$GROUPNAME" --protocol $PROTO --port $PORT --cidr "$iplist/32"
	done < iplist
	echo "====================================================="
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

	echo
	echo "====================================================="
	echo "Creating Security Group "$GROUPNAME
	aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCR" --vpc-id $VPCID
	echo "====================================================="
	echo
	echo
	echo "====================================================="
	echo "Adding rules to VPC Security Group "$GROUPNAME
	echo "Records to be created: 50" #$TOTALIPS
	echo "====================================================="
	echo

	# Begin loop to create rules 1-50
	for (( COUNT=$START; COUNT<=50; COUNT++ ))
	do
		echo "Rule "\#$COUNT

		iplist=$(nl iplist | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
		echo "IP="$iplist

		aws ec2 authorize-security-group-ingress --group-name "$GROUPNAME" --protocol $PROTO --port $PORT --cidr "$iplist/32"
	done

	# Set Variables for Group #2
	GROUPNAME="YOUR GROUP NAME 2"
	DESCR="YOUR GROUP NAME 51-$TOTALIPS"
	START=51

	echo
	echo "====================================================="
	echo "Creating Security Group "$GROUPNAME
	aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCR" --vpc-id $VPCID
	echo "====================================================="
	echo
	echo
	echo "====================================================="
	echo "Adding rules to VPC Security Group "$GROUPNAME
	echo "Records to be created: "$(expr $TOTALIPS - 50)
	echo "====================================================="
	echo

	# Begin loop to create rules 51-n
	for (( COUNT=$START; COUNT<=$TOTALIPS; COUNT++ ))
	do
		echo "Rule "\#$COUNT

		iplist=$(nl iplist | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
		echo "IP="$iplist

		aws ec2 authorize-security-group-ingress --group-name "$GROUPNAME" --protocol $PROTO --port $PORT --cidr "$iplist/32"
	done
	echo "====================================================="
	echo
	tput setaf 2; echo "Completed!" && tput sgr0
	echo
}

# Create one group with 50 rules or less
if [ "$TOTALIPS" -lt "51" ]; then
	addRules
fi

# Create multiple groups for more than 50 rules
if [ "$TOTALIPS" -gt "50" ]; then
	addRules50
fi

# More than 100 rules
if [ "$TOTALIPS" -gt "100" ]; then
	tput setaf 1; echo "Too many IPs, Abort, Abort!" && tput sgr0
	exit 1
fi
