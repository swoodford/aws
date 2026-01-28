#!/usr/bin/env bash

# Create VPC Security Group with Cloudflare IP ranges
# Requires curl, jq

# Set Variables
GROUPNAME="Cloudflare"
DESCRIPTION="Cloudflare IP Ranges"
VPCID="YOUR-VPC-ID-HERE"
# VPCID=$(aws ec2 describe-vpcs --output=json | jq '.Vpcs | .[] | .VpcId' | cut -d '"' -f2)
PROTO="tcp"
# port parameter should be of the form <from[-to]> (e.g. 22 or 22-25)
PORT="80,443"

DEBUG=FALSE

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

# # Ensure Variables are set
# if [ "$VPCID" = "YOUR-VPC-ID-HERE" ]; then
# 	fail "Failed to set variables!"
# fi

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

# Validate AWS CLI profile
if ! aws sts get-caller-identity --profile $profile 2>&1 | grep -q "UserId"; then
	fail "Invalid AWS CLI profile or credentials not setup. Please run \"aws configure\"."
fi

# Validate VPC ID
function validateVPCID(){
	if $DEBUGMODE; then
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
		tput setaf 2; echo "VPC ID $VPCID Validated" && tput sgr0
	fi
}

# Get current list of Cloudflare IP ranges
IPV4LIST=$(curl -s https://www.cloudflare.com/ips-v4)
if [ $? -ne 0 ]; then
    fail "Failed to fetch Cloudflare IP ranges. Please check your internet connection and try again."
fi
if [ -z "$IPV4LIST" ]; then
    fail "No IP ranges found. Please check the Cloudflare IP ranges URL."
fi
if $DEBUG; then
	echo "IPV4LIST: $IPV4LIST"
fi

IPV6LIST=$(curl -s https://www.cloudflare.com/ips-v6)
if [ $? -ne 0 ]; then
	fail "Failed to fetch Cloudflare IPv6 ranges. Please check your internet connection and try again."
fi
if [ -z "$IPV6LIST" ]; then
	fail "No IPv6 ranges found. Please check the Cloudflare IPv6 ranges URL."
fi
if $DEBUG; then
	echo "IPV6LIST: $IPV6LIST"
fi

IPLIST=$(echo "$IPV4LIST")
if $DEBUG; then
	echo "IPLIST: $IPLIST"
fi

TOTALIPS=$(echo "$IPLIST" "$IPV6LIST" | wc -l | tr -d ' ')

# Validate TOTALIPS variable
if ! [[ "$TOTALIPS" =~ ^[0-9]+$ ]] || [ "$TOTALIPS" -le 0 ]; then
    fail "Error fetching Cloudflare IP ranges: $IPLIST $TOTALIPS"
else
	echo "Number of Cloudflare IPs found: "$TOTALIPS
fi

# Validate PROTO variable
if ! [[ "$PROTO" =~ ^[a-zA-Z]+$ || "$PROTO" == "-1" ]]; then
    fail "Invalid PROTO value. It should contain only letters or be '-1'."
fi

# Validate PORT variable
if [[ "$PORT" =~ , ]]; then
    echo "PORT value: $PORT contains a comma, adding Inbound rules for more than one port value."
fi

function checkGroups (){
	# Check for existing security group or create new one
	checkGroups=$(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName')
	if ! echo "$checkGroups" | grep -q "$GROUPNAME"; then
		echo
		echo "====================================================="
		echo "Creating Security Group: "$GROUPNAME
		GROUPID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCRIPTION" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d '"' -f2)
		if $DEBUG; then
			echo "GROUPID: $GROUPID"
		fi
		aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="'"$GROUPNAME"'") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$GROUPNAME" --profile $profile 2>&1
		echo "====================================================="

		addRules
		addRulesV6
	else
		echo
		echo "====================================================="
		echo "Group $GROUPNAME Already Exists"
		GROUPID=$(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="'"$GROUPNAME"'") | .GroupId' | cut -d '"' -f2)
		echo "Security Group ID: $GROUPID"
		read -r -p "Do you want to delete the group and recreate it? (y/n) " DELETEGROUP
		if [[ $DELETEGROUP =~ ^([yY][eE][sS]|[yY])$ ]]; then
			echo
			echo "====================================================="
			echo "Deleting Group Name: $GROUPNAME"
			echo "Security Group ID: $GROUPID"
			echo "====================================================="
			DELETEGROUP=$(aws ec2 delete-security-group --group-id "$GROUPID" --profile $profile 2>&1)
			if echo $DELETEGROUP | grep -q error; then
				fail $DELETEGROUP
			else
				echo
				echo "====================================================="
				echo "Creating Security Group: "$GROUPNAME
				GROUPID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCRIPTION" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d '"' -f2)
				echo $GROUPID
				aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="'"$GROUPNAME"'") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$GROUPNAME" --profile $profile 2>&1
				echo "====================================================="

				addRules
				addRulesV6
			fi
		else
			read -r -p "Do you want to add additional IPs to the existing group? (y/n) " ADDGROUP
			if [[ $ADDGROUP =~ ^([yY][eE][sS]|[yY])$ ]]; then
				addRules
				addRulesV6
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
	echo "Adding rules to VPC Security Group: "$GROUPNAME
	echo "====================================================="
	echo
	if $DEBUG; then
		echo "GROUPNAME: $GROUPNAME"
		echo "DESCRIPTION: $DESCRIPTION"
		echo "VPCID: $VPCID"
		echo "PROTO: $PROTO"
		echo "PORT: $PORT"
	fi
	if [[ "$PORT" =~ , ]]; then
		# Split PORT into an array
		IFS=',' read -r -a PORTS <<< "$PORT"
		for PORT in "${PORTS[@]}"
		do
			if ! [[ "$PORT" =~ ^[0-9]+(-[0-9]+)?$ ]]; then
				fail "Invalid PORT value: $PORT It should be a single numeric value or a range in the form <from[-to]>."
			fi
			if $DEBUG; then
				echo "PORT: $PORT"
			fi
			for ip in $IPLIST
			do
				# if $DEBUG; then
				# 	echo "IP: $ip"
				# fi
				echo "IP: $ip Port: $PORT Protocol: $PROTO"
				RESULT=$(aws ec2 authorize-security-group-ingress --group-id "$GROUPID" --protocol $PROTO --port $PORT --cidr "$ip" --profile $profile 2>&1)
				# Check for errors
				if echo "$RESULT" | grep -q error; then
					echo "$RESULT"
				else
					if $DEBUG; then
						echo "$RESULT"
					fi
				fi
			done
		done
	else
		for ip in $IPLIST
		do
			# if $DEBUG; then
			# 	echo "IP: $ip"
			# fi
			if ! [[ "$PORT" =~ ^[0-9]+(-[0-9]+)?$ ]]; then
				fail "Invalid PORT value: $PORT It should be a single numeric value or a range in the form <from[-to]>."
			fi
			echo "IP: $ip Port: $PORT Protocol: $PROTO"
			RESULT=$(aws ec2 authorize-security-group-ingress --group-id "$GROUPID" --protocol $PROTO --port $PORT --cidr "$ip" --profile $profile 2>&1)
			# Check for errors
			if echo "$RESULT" | grep -q error; then
				echo "$RESULT"
			else
				if $DEBUG; then
					echo "$RESULT"
				fi
			fi
		done
	fi
}

function addRulesV6 (){
	IPLIST=$(echo "$IPV6LIST")
	echo
	echo "====================================================="
	echo "Adding IPv6 rules to VPC Security Group: "$GROUPNAME
	echo "====================================================="
	echo
	if $DEBUG; then
		echo "GROUPNAME: $GROUPNAME"
		echo "DESCRIPTION: $DESCRIPTION"
		echo "VPCID: $VPCID"
		echo "PROTO: $PROTO"
		echo "PORT: $PORT"
	fi
	if [[ "$PORT" =~ , ]]; then
		# Split PORT into an array
		IFS=',' read -r -a PORTS <<< "$PORT"
		for PORT in "${PORTS[@]}"
		do
			if ! [[ "$PORT" =~ ^[0-9]+(-[0-9]+)?$ ]]; then
				fail "Invalid PORT value: $PORT It should be a single numeric value or a range in the form <from[-to]>."
			fi
			if $DEBUG; then
				echo "PORT: $PORT"
			fi
			for ip in $IPLIST
			do
				echo "IP: $ip Port: $PORT Protocol: $PROTO"
				# RESULT=$(aws ec2 authorize-security-group-ingress --group-id "$GROUPID" --protocol $PROTO --port $PORT --cidr "$ip" --profile $profile 2>&1)
				RESULT=$(aws ec2 authorize-security-group-ingress --group-id "$GROUPID" --ip-permissions IpProtocol=$PROTO,FromPort=$PORT,ToPort=$PORT,Ipv6Ranges=[{CidrIpv6="$ip"}] --profile $profile 2>&1)
				# Check for errors
				if echo "$RESULT" | grep -q error; then
					echo "$RESULT"
				else
					if $DEBUG; then
						echo "$RESULT"
					fi
				fi
			done
		done
	else
		for ip in $IPLIST
		do
			if ! [[ "$PORT" =~ ^[0-9]+(-[0-9]+)?$ ]]; then
				fail "Invalid PORT value: $PORT It should be a single numeric value or a range in the form <from[-to]>."
			fi
			echo "IP: $ip Port: $PORT Protocol: $PROTO"
			# RESULT=$(aws ec2 authorize-security-group-ingress --group-id "$GROUPID" --protocol $PROTO --port $PORT --cidr "$ip" --profile $profile 2>&1)
			RESULT=$(aws ec2 authorize-security-group-ingress --group-id "$GROUPID" --ip-permissions IpProtocol=$PROTO,FromPort=$PORT,ToPort=$PORT,Ipv6Ranges=[{CidrIpv6="$ip"}] --profile $profile 2>&1)
			# Check for errors
			if echo "$RESULT" | grep -q error; then
				echo "$RESULT"
			else
				if $DEBUG; then
					echo "$RESULT"
				fi
			fi
		done
	fi
}

# Check required commands
check_command "curl"
check_command "jq"

validateVPCID
checkGroups

echo "====================================================="
echo

confirmGroups=$(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName')
if ! echo "$confirmGroups" | grep -q "$GROUPNAME"; then
	fail "Failed to create security group!"
else
	echo "Security Group Created: $GROUPNAME: $GROUPID"
	tput setaf 2; echo "Completed!" && tput sgr0
fi
