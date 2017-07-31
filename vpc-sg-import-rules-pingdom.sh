#!/usr/bin/env bash

# This script will save a list of current Pingdom IPv4 probe server IPs in the file pingdom-probe-servers.txt
# Then create an AWS VPC Security Group with rules to allow access to each IP at the port specified
# Due to AWS limits a group can only have 50 rules and will create multiple groups if greater than 50 rules
# Supports up to 150 rules
# Requires the AWS CLI, jq, wget, perl

# Set Variables
GROUPNAME="Pingdom"
DESCRIPTION="Pingdom Probe Servers"
VPCID="YOUR-VPC-ID-HERE"
PROTOCOL="tcp"
PORT="443"

# Debug Mode
DEBUGMODE="0"


# Functions


# Pause
function pause(){
	read -n 1 -s -p "Press any key to continue..."
	echo
}

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
	tput setaf 1; echo "Error: $*" && tput sgr0
	exit 1
}

# Horizontal Rule
function HorizontalRule(){
	echo "============================================================"
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


# Create list of the IPs of all Pingdom probe servers
# https://help.pingdom.com/hc/en-us/articles/203682601-How-to-get-all-Pingdom-probes-public-IP-addresses

# IPV4 AND IPV6
# function probeIPs(){
# 	wget --quiet -O- https://my.pingdom.com/probes/feed | \
# 	grep "pingdom:ip" | \
# 	sed -e 's|</.*||' -e 's|.*>||' | \
# 	sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 > pingdom-probe-servers.txt

# 	TOTALIPS=$(cat pingdom-probe-servers.txt | wc -l | cut -d " " -f6)
# }

# Get Pingdom IPv4 IPs
function probeIPs(){
	wget --quiet -O- https://www.pingdom.com/rss/probe_servers.xml | \
	perl -nle 'print $1 if /IP: (([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5]));/' | \
	sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 | \
	uniq > pingdom-probe-servers.txt

	TOTALIPS=$(cat pingdom-probe-servers.txt | wc -l | tr -d ' ')

	if ! [ "$TOTALIPS" -gt "0" ]; then
		fail "Error getting Pingdom IPs."
	fi

	if [[ $DEBUGMODE = "1" ]]; then
		echo "Total Pingdom IPs: "$TOTALIPS
	fi
}


# Create AWS VPC Security Groups

# Create one group with 50 rules or less
function addRules(){
	# Check for existing security group or create new one
	if ! aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName' | grep -q "$GROUPNAME"; then
		echo
		HorizontalRule
		echo "Creating Security Group: "$GROUPNAME
		SGID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCRIPTION" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d '"' -f2)
		if echo $SGID | grep -q "error"; then
			fail "$SGID"
		fi
		echo "Security Group:" $SGID
		TAG=$(aws ec2 create-tags --resources $SGID --tags Key=Name,Value="$GROUPNAME" --profile $profile 2>&1)
		if echo $TAG | grep -q "error"; then
			fail "$TAG"
		fi
		# aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json --profile $profile | jq '.SecurityGroups | .[] | select(.GroupName=="$GROUPNAME") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$GROUPNAME"
		HorizontalRule
		echo
		echo
		HorizontalRule
		echo "Adding rules to VPC Security Group: "$GROUPNAME
		echo "Rules to be created: "$TOTALIPS
		HorizontalRule
		echo
		while read iplist
		do
			AUTHORIZE=$(aws ec2 authorize-security-group-ingress --group-id "$SGID" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32" --profile $profile 2>&1)
			if echo $AUTHORIZE | grep -q "error"; then
				fail "$AUTHORIZE"
			fi
			# aws ec2 authorize-security-group-ingress --group-name "$GROUPNAME" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32"
		done < pingdom-probe-servers.txt
		completed
	else
		echo
		HorizontalRule
		echo "Group $GROUPNAME Already Exists"
		GROUPID=$(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="$GROUPNAME") | .GroupId' | cut -d '"' -f2)
		if echo $GROUPID | grep -q "error"; then
			fail "$GROUPID"
		fi
		echo "$GROUPID"
		read -r -p "Do you want to delete the group and recreate it? (y/n) " DELETEGROUP
		if [[ $DELETEGROUP =~ ^([yY][eE][sS]|[yY])$ ]]; then
			echo
			HorizontalRule
			echo "Deleting Group Name $GROUPNAME, Security Group ID $GROUPID"
			HorizontalRule
			DELETEGROUP=$(aws ec2 delete-security-group --group-id "$GROUPID" --profile $profile 2>&1)
			if echo $DELETEGROUP | grep -q "error"; then
				fail "$DELETEGROUP"
			fi
			echo
			HorizontalRule
			echo "Creating Security Group "$GROUPNAME
			SGID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCRIPTION" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d '"' -f2)
			if echo $SGID | grep -q "error"; then
				fail "$SGID"
			fi
			echo "Security Group:" $SGID
			TAG=$(aws ec2 create-tags --resources $SGID --tags Key=Name,Value="$GROUPNAME" --profile $profile 2>&1)
			if echo $TAG | grep -q "error"; then
				fail "$TAG"
			fi
			# TAG=$(aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="$GROUPNAME") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$GROUPNAME")
			completed
		else
			echo "Exiting"
			exit 1
		fi
	fi
}

# Create multiple groups for 51-100 rules
function addRules50(){
	# Set Variables for Group #1
	FIRSTGROUPNAME="$GROUPNAME 1"
	if [[ $DEBUGMODE = "1" ]]; then
		echo "FIRSTGROUPNAME: "$FIRSTGROUPNAME
	fi
	FIRSTDESCR="$DESCRIPTION 1-50"
	if [[ $DEBUGMODE = "1" ]]; then
		echo "FIRSTDESCR: "$FIRSTDESCR
	fi
	START=1

	if ! aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName' | grep -q "$FIRSTGROUPNAME"; then
		echo
		HorizontalRule
		echo "Creating Security Group: "$FIRSTGROUPNAME
		SGID1=$(aws ec2 create-security-group --group-name "$FIRSTGROUPNAME" --description "$FIRSTDESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
		if echo $SGID1 | grep -q "error"; then
			fail "$SGID1"
		fi
		echo "Security Group 1:" $SGID1
		TAG=$(aws ec2 create-tags --resources $SGID1 --tags Key=Name,Value="$FIRSTGROUPNAME" --profile $profile 2>&1)
		if echo $TAG | grep -q "error"; then
			fail "$TAG"
		fi
		HorizontalRule
		echo
		echo
		HorizontalRule
		echo "Adding rules to VPC Security Group: "$FIRSTGROUPNAME
		echo "Rules to be created: 50" #$TOTALIPS
		HorizontalRule
		echo

		# Begin loop to create rules 1-50
		for (( COUNT=$START; COUNT<=50; COUNT++ ))
		do
			echo "Rule "\#$COUNT

			iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
			echo "IP="$iplist

			# ADDRULE=$(aws ec2 authorize-security-group-ingress --group-name $FIRSTGROUPNAME --protocol $PROTOCOL --port $PORT --cidr "$IP/32")
			# echo "Record created: "$ADDRULE

			AUTHORIZE=$(aws ec2 authorize-security-group-ingress --group-id "$SGID1" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32" --profile $profile 2>&1)
			if echo $AUTHORIZE | grep -q "error"; then
				fail "$AUTHORIZE"
			fi
			# aws ec2 authorize-security-group-ingress --group-name "$FIRSTGROUPNAME" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32"
		done

		# Set Variables for Group #2
		SECONDGROUPNAME="$GROUPNAME 2"
		SECONDDESCR="$DESCRIPTION 51-$TOTALIPS"
		START=51

		echo
		HorizontalRule
		echo "Creating Security Group: "$SECONDGROUPNAME
		SGID2=$(aws ec2 create-security-group --group-name "$SECONDGROUPNAME" --description "$SECONDDESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
		if echo $SGID2 | grep -q "error"; then
			fail "$SGID2"
		fi
		echo "Security Group 2:" $SGID2
		TAG=$(aws ec2 create-tags --resources $SGID2 --tags Key=Name,Value="$SECONDGROUPNAME" --profile $profile 2>&1)
		if echo $TAG | grep -q "error"; then
			fail "$TAG"
		fi
		# aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="$SECONDGROUPNAME") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$SECONDGROUPNAME"
		HorizontalRule
		echo
		echo
		HorizontalRule
		echo "Adding rules to VPC Security Group: "$SECONDGROUPNAME
		echo "Rules to be created: "$(expr $TOTALIPS - 50)
		HorizontalRule
		echo

		# Begin loop to create rules 51-n
		for (( COUNT=$START; COUNT<=$TOTALIPS; COUNT++ ))
		do
			echo "Rule "\#$COUNT

			iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
			echo "IP="$iplist

			AUTHORIZE=$(aws ec2 authorize-security-group-ingress --group-id "$SGID2" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32" --profile $profile 2>&1)
			if echo $AUTHORIZE | grep -q "error"; then
				fail "$AUTHORIZE"
			fi
			# aws ec2 authorize-security-group-ingress --group-name "$SECONDGROUPNAME" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32"
		done
		completed
	else
		if [[ $DEBUGMODE = "1" ]]; then
			aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName' | grep "$FIRSTGROUPNAME"
		fi
		fail "Security Group already exists!"
	fi
}


# Create multiple groups for 101-150 rules
function addRules100(){
	# Set Variables for Group #1
	FIRSTGROUPNAME="$GROUPNAME 1"
	if [[ $DEBUGMODE = "1" ]]; then
		echo "FIRSTGROUPNAME: "$FIRSTGROUPNAME
	fi
	FIRSTDESCR="$DESCRIPTION 1-50"
	if [[ $DEBUGMODE = "1" ]]; then
		echo "FIRSTDESCR: "$FIRSTDESCR
	fi
	START=1

	if ! aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName' | grep -q "$FIRSTGROUPNAME"; then
		echo
		HorizontalRule
		echo "Creating Security Group: "$FIRSTGROUPNAME
		SGID1=$(aws ec2 create-security-group --group-name "$FIRSTGROUPNAME" --description "$FIRSTDESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
		if echo $SGID1 | grep -q "error"; then
			fail "$SGID1"
		fi
		echo "Security Group 1:" $SGID1
		TAG=$(aws ec2 create-tags --resources $SGID1 --tags Key=Name,Value="$FIRSTGROUPNAME" --profile $profile 2>&1)
		if echo $TAG | grep -q "error"; then
			fail "$TAG"
		fi
		# aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="$FIRSTGROUPNAME") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$FIRSTGROUPNAME"
		HorizontalRule
		echo
		echo
		HorizontalRule
		echo "Adding rules to VPC Security Group: "$FIRSTGROUPNAME
		echo "Rules to be created: 50" #$TOTALIPS
		HorizontalRule
		echo

		# Begin loop to create rules 1-50
		for (( COUNT=$START; COUNT<=50; COUNT++ ))
		do
			echo "Rule "\#$COUNT

			iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
			echo "IP="$iplist

			# ADDRULE=$(aws ec2 authorize-security-group-ingress --group-name $FIRSTGROUPNAME --protocol $PROTOCOL --port $PORT --cidr "$IP/32")
			# echo "Record created: "$ADDRULE

			AUTHORIZE=$(aws ec2 authorize-security-group-ingress --group-id "$SGID1" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32" --profile $profile 2>&1)
			if echo $AUTHORIZE | grep -q "error"; then
				fail "$AUTHORIZE"
			fi
			# aws ec2 authorize-security-group-ingress --group-name "$FIRSTGROUPNAME" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32"
		done

		# Set Variables for Group #2
		SECONDGROUPNAME="$GROUPNAME 2"
		SECONDDESCR="$DESCRIPTION 51-100"
		START=51

		echo
		HorizontalRule
		echo "Creating Security Group: "$SECONDGROUPNAME
		SGID2=$(aws ec2 create-security-group --group-name "$SECONDGROUPNAME" --description "$SECONDDESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
		if echo $SGID2 | grep -q "error"; then
			fail "$SGID2"
		fi
		echo "Security Group 2:" $SGID2
		TAG=$(aws ec2 create-tags --resources $SGID2 --tags Key=Name,Value="$SECONDGROUPNAME" --profile $profile 2>&1)
		if echo $TAG | grep -q "error"; then
			fail "$TAG"
		fi
		# aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="$SECONDGROUPNAME") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$SECONDGROUPNAME"
		HorizontalRule
		echo
		echo
		HorizontalRule
		echo "Adding rules to VPC Security Group: "$SECONDGROUPNAME
		echo "Rules to be created: 50"
		HorizontalRule
		echo

		# Begin loop to create rules 51-n
		for (( COUNT=$START; COUNT<=100; COUNT++ ))
		do
			echo "Rule "\#$COUNT

			iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
			echo "IP="$iplist

			AUTHORIZE=$(aws ec2 authorize-security-group-ingress --group-id "$SGID2" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32" --profile $profile 2>&1)
			if echo $AUTHORIZE | grep -q "error"; then
				fail "$AUTHORIZE"
			fi
			# aws ec2 authorize-security-group-ingress --group-name "$SECONDGROUPNAME" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32"
		done

		# Set Variables for Group #3
		THIRDGROUPNAME="$GROUPNAME 3"
		THIRDDESCR="$DESCRIPTION 101-$TOTALIPS"
		START=101

		echo
		HorizontalRule
		echo "Creating Security Group: "$THIRDGROUPNAME
		SGID3=$(aws ec2 create-security-group --group-name "$THIRDGROUPNAME" --description "$THIRDDESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
		if echo $SGID3 | grep -q "error"; then
			fail "$SGID3"
		fi
		echo "Security Group 3:" $SGID3
		TAG=$(aws ec2 create-tags --resources $SGID3 --tags Key=Name,Value="$THIRDGROUPNAME" --profile $profile 2>&1)
		if echo $TAG | grep -q "error"; then
			fail "$TAG"
		fi
		# aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="$THIRDGROUPNAME") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$THIRDGROUPNAME"
		HorizontalRule
		echo
		echo
		HorizontalRule
		echo "Adding rules to VPC Security Group: "$THIRDGROUPNAME
		echo "Rules to be created: "$(expr $TOTALIPS - 100)
		HorizontalRule
		echo

		# Begin loop to create rules 101-n
		for (( COUNT=$START; COUNT<=$TOTALIPS; COUNT++ ))
		do
			echo "Rule "\#$COUNT

			iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
			echo "IP="$iplist

			AUTHORIZE=$(aws ec2 authorize-security-group-ingress --group-id "$SGID3" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32" --profile $profile 2>&1)
			if echo $AUTHORIZE | grep -q "error"; then
				fail "$AUTHORIZE"
			fi
			# aws ec2 authorize-security-group-ingress --group-name "$THIRDGROUPNAME" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32"
		done
		completed
	else
		if [[ $DEBUGMODE = "1" ]]; then
			aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName' | grep "$FIRSTGROUPNAME"
		fi
		fail "Security Group already exists!"
	fi
}

# Validate VPC ID
function validateVPCID(){
	if [ "$VPCID" = "YOUR-VPC-ID-HERE" ]; then
		# Count number of VPCs
		DESCRIBEVPCS=$(aws ec2 describe-vpcs --profile $profile 2>&1)
		NUMVPCS=$(echo $DESCRIBEVPCS | jq '.Vpcs | length')

		# If only one VPC, use that ID
		if [ "$NUMVPCS" -eq "1" ]; then
			VPCID=$(echo "$DESCRIBEVPCS" | jq '.Vpcs | .[] | .VpcId' | cut -d '"' -f2)
		else
			read -r -p "Please specify VPC ID (ex. vpc-12345678): " VPCID
		fi
	fi

	CHECKVPC=$(aws ec2 describe-vpcs --vpc-ids "$VPCID" --profile $profile 2>&1)

	# Test for error
	if ! echo "$CHECKVPC" | grep -q "available"; then
		fail $CHECKVPC
	else
		tput setaf 2; echo "VPC ID Validated" && tput sgr0
	fi
}


# Run the script and call functions

# Check for required applications
check_command "jq"
check_command "wget"
check_command "perl"

validateVPCID

echo "This script will save a list of current Pingdom probe server IPs in the file pingdom-probe-servers.txt"
echo "then create an AWS VPC Security Group with rules to allow access to each IP at the port specified."
echo
tput setaf 1; echo "Please verify all settings before continuing..." && tput sgr0
echo
if ! [ -z "$profile" ]; then
	echo "AWS CLI Profile Name: "$profile
fi
echo "Group Name: "$GROUPNAME
echo "Group Description: "$DESCRIPTION
echo "VPC ID: "$VPCID
echo "Protocol: "$PROTOCOL
echo "Port: "$PORT
echo
pause



probeIPs

# Determine number of security groups needed since AWS limit is 50 rules per group

# Create one group with 50 rules or less
if [ "$TOTALIPS" -gt "0" ]; then
	if [ "$TOTALIPS" -lt "51" ]; then
		addRules
	fi
fi

# Create multiple groups for 51-100 rules
if [ "$TOTALIPS" -gt "50" ]; then
	if [ "$TOTALIPS" -lt "101" ]; then
		addRules50
	fi
fi

# Create multiple groups for 101-150 rules
if [ "$TOTALIPS" -gt "100" ]; then
	if [ "$TOTALIPS" -lt "151" ]; then
		addRules100
	fi
fi

# More than 150 rules not yet supported
if [ "$TOTALIPS" -gt "150" ]; then
	fail "Greater than 100 IPs not yet supported."
fi
