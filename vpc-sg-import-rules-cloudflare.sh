#!/usr/bin/env bash

# Create VPC Security Group with CloudFlare IP ranges
# Requires curl, jq

# Get current list of CloudFlare IP ranges
IPLIST=$(curl -s https://www.cloudflare.com/ips-v4)

# Set Variables
GROUPNAME="CloudFlare"
DESCR="CloudFlare IP Ranges"
VPCID="YOUR-VPC-ID-HERE"
# VPCID=$(aws ec2 describe-vpcs --output=json | jq '.Vpcs | .[] | .VpcId' | cut -d '"' -f2)
PROTO="tcp"
PORT="443"
TOTALIPS=$(echo "$IPLIST" | wc -l | tr -d ' ')

# Functions
function pause(){
	read -n 1 -s -p "Press any key to continue..."
	echo
}

function check_command {
	type -P $1 &>/dev/null || fail "Unable to find $1, please install it and run this script again."
}

function fail(){
	tput setaf 1; echo "Failure: $*" && tput sgr0
	exit 1
}

# Ensure Variables are set
if [ "$VPCID" = "YOUR-VPC-ID-HERE" ]; then
	fail "Failed to set variables!"
fi

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
	profile=default
else
	profile=$1
fi


function checkGroups (){
	# Check for existing security group or create new one
	if ! aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName' | grep -q CloudFlare; then
		echo
		echo "====================================================="
		echo "Creating Security Group "$GROUPNAME
		GROUPID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d '"' -f2)
		echo $GROUPID
		aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="CloudFlare") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$GROUPNAME" --profile $profile 2>&1
		echo "====================================================="

		addRules
	else
		echo
		echo "====================================================="
		echo "Group $GROUPNAME Already Exists"
		GROUPID=$(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="CloudFlare") | .GroupId' | cut -d '"' -f2)
		read -r -p "Do you want to delete the group and recreate it? (y/n) " DELETEGROUP
		if [[ $DELETEGROUP =~ ^([yY][eE][sS]|[yY])$ ]]; then
			echo
			echo "====================================================="
			echo "Deleting Group Name $GROUPNAME, Security Group ID $GROUPID"
			echo "====================================================="
			DELETEGROUP=$(aws ec2 delete-security-group --group-id "$GROUPID" --profile $profile 2>&1)
			if echo $DELETEGROUP | grep -q error; then
				fail $DELETEGROUP
			else
				echo
				echo "====================================================="
				echo "Creating Security Group "$GROUPNAME
				GROUPID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d '"' -f2)
				echo $GROUPID
				aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="CloudFlare") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$GROUPNAME" --profile $profile 2>&1
				echo "====================================================="

				addRules
			fi
		else
			read -r -p "Do you want to add additional IPs to the existing group? (y/n) " ADDGROUP
			if [[ $ADDGROUP =~ ^([yY][eE][sS]|[yY])$ ]]; then
				addRules
			else
				echo "Exiting"
				exit 1
			fi
		fi
	fi
}

function addRules (){
	echo
	echo "====================================================="
	echo "Adding rules to VPC Security Group "$GROUPNAME
	echo "Records to be created: "$TOTALIPS
	echo "====================================================="
	echo
	for ip in $IPLIST
	do
		RESULT=$(aws ec2 authorize-security-group-ingress --group-id "$GROUPID" --protocol $PROTO --port $PORT --cidr "$ip" --profile $profile 2>&1)
		# Check for errors
		if echo $RESULT | grep -q error; then
			fail $RESULT
		# else echo $RESULT
		fi
	done
	echo "====================================================="
	echo
	tput setaf 2; echo "Completed!" && tput sgr0
	echo
}



# Check required commands
check_command "curl"
check_command "jq"

checkGroups
