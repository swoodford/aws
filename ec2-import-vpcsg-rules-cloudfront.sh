#!/bin/bash

# Create VPC Security Group with Cloudfront IP ranges

# Get current list of Cloudfront IP ranges
IPLIST=$(curl -s https://ip-ranges.amazonaws.com/ip-ranges.json | jq '.prefixes | .[] | select(.service=="CLOUDFRONT") | .ip_prefix' | cut -d '"' -f2)

# Set Variables
GROUPNAME="Cloudfront"
DESCR="Cloudfront IP Ranges"
VPCID=$(aws ec2 describe-vpcs --output=json | jq '.Vpcs | .[] | .VpcId' | cut -d '"' -f2)
PROTO="tcp"
PORT="80"
TOTALIPS=$(echo "$IPLIST" | wc -l)

# Functions
function pause(){
	read -p "Press any key to continue..."
	echo
}

function check_command {
	type -P $1 &>/dev/null || fail "Unable to find $1, please install it and run this script again."
}

function fail(){
	tput setaf 1; echo "Failure: $*" && tput sgr0
	exit 1
}

function addRules (){
	# Check for existing security group or create new one
	if ! aws ec2 describe-security-groups --output=json | jq '.SecurityGroups | .[] | .GroupName' | grep -q Cloudfront; then
		echo
		echo "====================================================="
		echo "Creating Security Group "$GROUPNAME
		GROUPID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCR" --vpc-id $VPCID)
		echo $GROUPID
		aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json | jq '.SecurityGroups | .[] | select(.GroupName=="Cloudfront") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$GROUPNAME"
		echo "====================================================="
	else
		echo	 
		echo "====================================================="
		echo "Group $GROUPNAME Already Exists"
		GROUPID=$(aws ec2 describe-security-groups --output=json | jq '.SecurityGroups | .[] | select(.GroupName=="Cloudfront") | .GroupId' | cut -d '"' -f2)
		read -r -p "Do you want to delete the group and recreate it? (y/n) " DELETEGROUP
		if [[ $DELETEGROUP =~ ^([yY][eE][sS]|[yY])$ ]]; then
			echo
			echo "====================================================="
			echo "Deleting Group Name $GROUPNAME, Security Group ID $GROUPID"
			echo "====================================================="
			DELETEGROUP=$(aws ec2 delete-security-group --group-id "$GROUPID" 2>&1)
			if echo $DELETEGROUP | grep -q error; then
				fail $DELETEGROUP
			else
				echo
				echo "====================================================="
				echo "Creating Security Group "$GROUPNAME
				GROUPID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCR" --vpc-id $VPCID)
				echo $GROUPID
				aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json | jq '.SecurityGroups | .[] | select(.GroupName=="Cloudfront") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$GROUPNAME"
				echo "====================================================="
			fi
		else
			echo "Exiting"
			exit 1
		fi
	fi
	echo
	echo
	echo "====================================================="
	echo "Adding rules to VPC Security Group "$GROUPNAME
	echo "Records to be created: "$TOTALIPS
	echo "====================================================="
	echo
	for ip in $IPLIST
	do
		RESULT=$(aws ec2 authorize-security-group-ingress --group-id "$GROUPID" --protocol $PROTO --port $PORT --cidr "$ip" 2>&1)
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

# Ensure Variables are set
if [ "$VPCID" = "YOUR-VPC-ID-HERE" ]; then
	fail "Failed to set variables!"
fi

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
	if ! grep -q aws_access_key_id ~/.aws/credentials; then
		fail "Error: AWS config not found or CLI not installed. Please run \"aws configure\"."
	fi
fi

# Check required commands
check_command "curl"
check_command "jq"

addRules