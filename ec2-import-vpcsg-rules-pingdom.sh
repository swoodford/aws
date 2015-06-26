#!/usr/bin/env bash

# This script will save a list of current Pingdom probe server IPs in the file iplist
# Then create an AWS VPC Security Group with rules to allow access to each IP at the port specified
# Due to AWS limits a group can only have 50 rules and will create multiple groups if greater than 50 rules
# Requires the AWS CLI

# Set Variables
GROUPNAME="Pingdom"
DESCR="Pingdom Probe Servers"
VPCID="YOUR-VPC-ID-HERE"
PROTO="tcp"
PORT="443"

# TODO:
# Validate VPC ID


# Ensure Variables are set
if [ "$VPCID" = "YOUR-VPC-ID-HERE" ]; then
	tput setaf 1; echo "Please edit the variables in the bash script before running!" && tput sgr0
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

# Create list of the IPs of all Pingdom probe servers

# More info:
# https://support.pingdom.com/Knowledgebase/Article/View/16/0/where-can-i-find-a-list-of-ip-addresses-for-the-pingdom-probe-servers

wget --quiet -O- https://my.pingdom.com/probes/feed | \
grep "pingdom:ip" | \
sed -e 's|</.*||' -e 's|.*>||' | \
sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 > iplist


# Create AWS VPC Security Groups

TOTALIPS=$(wc -l iplist | cut -d " " -f7)

# Create one group with 50 rules or less
function addRules (){
	echo
	echo "====================================================="
	echo "Creating Security Group: "$GROUPNAME
	SGID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCR" --vpc-id $VPCID)
	echo "Security Group:" $SGID
	echo "====================================================="
	echo
	echo
	echo "====================================================="
	echo "Adding rules to VPC Security Group: "$GROUPNAME
	echo "Records to be created: "$TOTALIPS
	echo "====================================================="
	echo
	while read iplist
	do
		aws ec2 authorize-security-group-ingress --group-id "$SGID" --protocol $PROTO --port $PORT --cidr "$iplist/32"
		# aws ec2 authorize-security-group-ingress --group-name "$GROUPNAME" --protocol $PROTO --port $PORT --cidr "$iplist/32"
	done < iplist
	echo "====================================================="
	echo
	tput setaf 2; echo "Completed!" && tput sgr0
	echo
}

# Create multiple groups for more than 50 rules
function addRules50 (){
	# Set Variables for Group #1
	FIRSTGROUPNAME="$GROUPNAME 1"
	FIRSTDESCR="$DESCR 1-50"
	START=1

	echo
	echo "====================================================="
	echo "Creating Security Group: "$FIRSTGROUPNAME
	SGID1=$(aws ec2 create-security-group --group-name "$FIRSTGROUPNAME" --description "$FIRSTDESCR" --vpc-id $VPCID)
	echo "Security Group 1:" $SGID1
	echo "====================================================="
	echo
	echo
	echo "====================================================="
	echo "Adding rules to VPC Security Group: "$FIRSTGROUPNAME
	echo "Records to be created: 50" #$TOTALIPS
	echo "====================================================="
	echo

	# Begin loop to create rules 1-50
	for (( COUNT=$START; COUNT<=50; COUNT++ ))
	do
		echo "Rule "\#$COUNT

		iplist=$(nl iplist | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
		echo "IP="$iplist

		# ADDRULE=$(aws ec2 authorize-security-group-ingress --group-name $FIRSTGROUPNAME --protocol $PROTO --port $PORT --cidr "$IP/32")
		# echo "Record created: "$ADDRULE

		aws ec2 authorize-security-group-ingress --group-id "$SGID1" --protocol $PROTO --port $PORT --cidr "$iplist/32"
		# aws ec2 authorize-security-group-ingress --group-name "$FIRSTGROUPNAME" --protocol $PROTO --port $PORT --cidr "$iplist/32"
	done

	# Set Variables for Group #2
	SECONDGROUPNAME="$GROUPNAME 2"
	SECONDDESCR="$DESCR 51-$TOTALIPS"
	START=51

	echo
	echo "====================================================="
	echo "Creating Security Group: "$SECONDGROUPNAME
	SGID2=$(aws ec2 create-security-group --group-name "$SECONDGROUPNAME" --description "$SECONDDESCR" --vpc-id $VPCID)
	echo "Security Group 2:" $SGID2
	echo "====================================================="
	echo
	echo
	echo "====================================================="
	echo "Adding rules to VPC Security Group: "$SECONDGROUPNAME
	echo "Records to be created: "$(expr $TOTALIPS - 50)
	echo "====================================================="
	echo

	# Begin loop to create rules 51-n
	for (( COUNT=$START; COUNT<=$TOTALIPS; COUNT++ ))
	do
		echo "Rule "\#$COUNT

		iplist=$(nl iplist | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
		echo "IP="$iplist

		aws ec2 authorize-security-group-ingress --group-id "$SGID2" --protocol $PROTO --port $PORT --cidr "$iplist/32"
		# aws ec2 authorize-security-group-ingress --group-name "$SECONDGROUPNAME" --protocol $PROTO --port $PORT --cidr "$iplist/32"
	done
	echo "====================================================="
	echo
	tput setaf 2; echo "Completed!" && tput sgr0
	echo
}

# Pause
function pause(){
	read -p "Press any key to continue..."
	echo
}

function fail(){
	tput setaf 1; echo "$@" && tput sgr0
	exit 1
}

echo "This script will save a list of current Pingdom probe server IPs in the file iplist"
echo "then create an AWS VPC Security Group with rules to allow access to each IP at the port specified."
echo "Please verify all settings before continuing..."
echo "Group Name: "$GROUPNAME
echo "Group Description: "$DESCR
echo "VPC ID: "$VPCID
echo "Protocol: "$PROTO
echo "Port: "$PORT
pause

# Validate VPC ID
# CHECKVPC=$(aws ec2 describe-vpcs --vpc-ids "$VPCID")
# if echo "$CHECKVPC" | grep -qv "error"; then
# 	fail
# fi

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
	tput setaf 1; echo "Greater than 100 IPs not yet supported." && tput sgr0
	exit 1
fi
