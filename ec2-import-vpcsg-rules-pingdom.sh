#!/usr/bin/env bash

# This script will save a list of current Pingdom probe server IPs in the file pingdom-probe-servers.txt
# Then create an AWS VPC Security Group with rules to allow access to each IP at the port specified
# Due to AWS limits a group can only have 50 rules and will create multiple groups if greater than 50 rules
# Requires the AWS CLI, jq, wget, perl

# Set Variables
GROUPNAME="Pingdom"
DESCRIPTION="Pingdom Probe Servers"
VPCID="YOUR-VPC-ID-HERE"
PROTOCOL="tcp"
PORT="443"

# Debug Mode
DEBUGMODE=1



# Functions
function pause(){
	read -p "Press any key to continue..."
	echo
}

function check_command {
	type -P $1 &>/dev/null || fail "Unable to find $1, please install it and run this script again."
}

function fail(){
	tput setaf 1; echo "Error: $*" && tput sgr0
	exit 1
}


# Ensure Variables are set
if [ "$VPCID" = "YOUR-VPC-ID-HERE" ]; then
	fail "Please edit the variables in the bash script before running!"
fi

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
	if ! grep -q aws_access_key_id ~/.aws/credentials; then
		fail "Error: AWS config not found or CLI not installed. Please run \"aws configure\"."
	fi
fi

# Test for optional variable passed as argument and set as AWS CLI profile name
if ! [ -z "$1" ]; then
	profile="$1"
else
	echo "Note: You can pass in an AWS CLI profile name as an argument when running the script."
	echo "Example: ./ec2-import-vpcsg-rules-pingdom.sh profilename"
	pause
	echo
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

# JUST IPV4
function probeIPs(){
	wget --quiet -O- https://www.pingdom.com/rss/probe_servers.xml | \
	perl -nle 'print $1 if /IP: (([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5]));/' | \
	sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 > pingdom-probe-servers.txt

	TOTALIPS=$(cat pingdom-probe-servers.txt | wc -l | tr -d ' ')
	# TOTALIPS=$(cat pingdom-probe-servers.txt | wc -l | cut -d " " -f7)

	if [[ $DEBUGMODE = "1" ]]; then
		echo "Total Pingdom IPs: "$TOTALIPS
	fi
}


# Create AWS VPC Security Groups

# Create one group with 50 rules or less
function addRules(){
	# Check for existing security group or create new one
	if [ -z "$profile" ]; then
		if ! aws ec2 describe-security-groups --output=json | jq '.SecurityGroups | .[] | .GroupName' | grep -q "$GROUPNAME"; then
			echo
			echo "====================================================="
			echo "Creating Security Group: "$GROUPNAME
			SGID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCRIPTION" --vpc-id $VPCID 2>&1)
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
				aws ec2 authorize-security-group-ingress --group-id "$SGID" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32" 2>&1
				# aws ec2 authorize-security-group-ingress --group-name "$GROUPNAME" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32"
			done < pingdom-probe-servers.txt
			echo "====================================================="
			echo
			tput setaf 2; echo "Completed!" && tput sgr0
			echo
		else
			echo
			echo "====================================================="
			echo "Group $GROUPNAME Already Exists"
			GROUPID=$(aws ec2 describe-security-groups --output=json | jq '.SecurityGroups | .[] | select(.GroupName=="$GROUPNAME") | .GroupId' | cut -d '"' -f2)
			echo "$GROUPID"
			read -r -p "Do you want to delete the group and recreate it? (y/n) " DELETEGROUP
			if [[ $DELETEGROUP =~ ^([yY][eE][sS]|[yY])$ ]]; then
				echo
				echo "====================================================="
				echo "Deleting Group Name $GROUPNAME, Security Group ID $GROUPID"
				echo "====================================================="
				DELETEGROUP=$(aws ec2 delete-security-group --group-id "$GROUPID" 2>&1)
				if echo $DELETEGROUP | grep -q error; then
					fail "$DELETEGROUP"
				else
					echo
					echo "====================================================="
					echo "Creating Security Group "$GROUPNAME
					GROUPID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCRIPTION" --vpc-id $VPCID 2>&1)
					echo $GROUPID
					aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json | jq '.SecurityGroups | .[] | select(.GroupName=="$GROUPNAME") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$GROUPNAME"
					echo "====================================================="
				fi
			else
				echo "Exiting"
				exit 1
			fi
		fi
	else
		if ! aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName' | grep -q "$GROUPNAME"; then
			echo
			echo "====================================================="
			echo "Creating Security Group: "$GROUPNAME
			SGID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCRIPTION" --vpc-id $VPCID --profile $profile 2>&1)
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
				aws ec2 authorize-security-group-ingress --group-id "$SGID" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32" --profile $profile 2>&1
				# aws ec2 authorize-security-group-ingress --group-name "$GROUPNAME" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32"
			done < pingdom-probe-servers.txt
			echo "====================================================="
			echo
			tput setaf 2; echo "Completed!" && tput sgr0
			echo
		else
			echo
			echo "====================================================="
			echo "Group $GROUPNAME Already Exists"
			GROUPID=$(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="$GROUPNAME") | .GroupId' | cut -d '"' -f2)
			echo "$GROUPID"
			read -r -p "Do you want to delete the group and recreate it? (y/n) " DELETEGROUP
			if [[ $DELETEGROUP =~ ^([yY][eE][sS]|[yY])$ ]]; then
				echo
				echo "====================================================="
				echo "Deleting Group Name $GROUPNAME, Security Group ID $GROUPID"
				echo "====================================================="
				DELETEGROUP=$(aws ec2 delete-security-group --group-id "$GROUPID" --profile $profile 2>&1)
				if echo $DELETEGROUP | grep -q error; then
					fail "$DELETEGROUP"
				else
					echo
					echo "====================================================="
					echo "Creating Security Group "$GROUPNAME
					GROUPID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCRIPTION" --vpc-id $VPCID --profile $profile 2>&1)
					echo $GROUPID
					aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | select(.GroupName=="$GROUPNAME") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$GROUPNAME"
					echo "====================================================="
				fi
			else
				echo "Exiting"
				exit 1
			fi
		fi
	fi
}

# Create multiple groups for more than 50 rules
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

	if [ -z "$profile" ]; then
		if [[ $DEBUGMODE = "1" ]]; then
			echo "No AWS CLI profile"
		fi
		if ! aws ec2 describe-security-groups --output=json 2>&1 | jq '.SecurityGroups | .[] | .GroupName' | grep -q "$FIRSTGROUPNAME"; then
			if [[ $DEBUGMODE = "1" ]]; then
				echo "$FIRSTGROUPNAME doesn't already exist"
			fi
			echo
			echo "====================================================="
			echo "Creating Security Group: "$FIRSTGROUPNAME
			SGID1=$(aws ec2 create-security-group --group-name "$FIRSTGROUPNAME" --description "$FIRSTDESCR" --vpc-id $VPCID 2>&1)
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

				iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
				echo "IP="$iplist

				# ADDRULE=$(aws ec2 authorize-security-group-ingress --group-name $FIRSTGROUPNAME --protocol $PROTOCOL --port $PORT --cidr "$IP/32")
				# echo "Record created: "$ADDRULE

				aws ec2 authorize-security-group-ingress --group-id "$SGID1" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32" 2>&1
				# aws ec2 authorize-security-group-ingress --group-name "$FIRSTGROUPNAME" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32"
			done

			# Set Variables for Group #2
			SECONDGROUPNAME="$GROUPNAME 2"
			SECONDDESCR="$DESCRIPTION 51-$TOTALIPS"
			START=51

			echo
			echo "====================================================="
			echo "Creating Security Group: "$SECONDGROUPNAME
			SGID2=$(aws ec2 create-security-group --group-name "$SECONDGROUPNAME" --description "$SECONDDESCR" --vpc-id $VPCID 2>&1)
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

				iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
				echo "IP="$iplist

				aws ec2 authorize-security-group-ingress --group-id "$SGID2" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32" 2>&1
				# aws ec2 authorize-security-group-ingress --group-name "$SECONDGROUPNAME" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32"
			done

			echo "====================================================="
			echo
			tput setaf 2; echo "Completed!" && tput sgr0
			echo
		fi
	else
		if ! aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName' | grep -q "$FIRSTGROUPNAME"; then
			echo
			echo "====================================================="
			echo "Creating Security Group: "$FIRSTGROUPNAME
			SGID1=$(aws ec2 create-security-group --group-name "$FIRSTGROUPNAME" --description "$FIRSTDESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
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

				iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
				echo "IP="$iplist

				# ADDRULE=$(aws ec2 authorize-security-group-ingress --group-name $FIRSTGROUPNAME --protocol $PROTOCOL --port $PORT --cidr "$IP/32")
				# echo "Record created: "$ADDRULE

				aws ec2 authorize-security-group-ingress --group-id "$SGID1" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32" --profile $profile 2>&1
				# aws ec2 authorize-security-group-ingress --group-name "$FIRSTGROUPNAME" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32"
			done

			# Set Variables for Group #2
			SECONDGROUPNAME="$GROUPNAME 2"
			SECONDDESCR="$DESCRIPTION 51-$TOTALIPS"
			START=51

			echo
			echo "====================================================="
			echo "Creating Security Group: "$SECONDGROUPNAME
			SGID2=$(aws ec2 create-security-group --group-name "$SECONDGROUPNAME" --description "$SECONDDESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
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

				iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
				echo "IP="$iplist

				aws ec2 authorize-security-group-ingress --group-id "$SGID2" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32" --profile $profile 2>&1
				# aws ec2 authorize-security-group-ingress --group-name "$SECONDGROUPNAME" --protocol $PROTOCOL --port $PORT --cidr "$iplist/32"
			done
			echo "====================================================="
			echo
			tput setaf 2; echo "Completed!" && tput sgr0
			echo
		else
			aws ec2 describe-security-groups --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName' | grep "$FIRSTGROUPNAME"
			fail "Security Group already exists!"
		fi
	fi
}


# Validate VPC ID
function validateVPCID(){
	if [ -z "$profile" ]; then
		CHECKVPC=$(aws ec2 describe-vpcs --vpc-ids "$VPCID" 2>&1)
	else
		CHECKVPC=$(aws ec2 describe-vpcs --vpc-ids "$VPCID" --profile $profile 2>&1)
	fi

	# Test for error
	if ! echo "$CHECKVPC" | grep -qv "available"; then
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
check_command "aws"

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

validateVPCID

probeIPs

# Assume we're always going to have > 50 rules
# addRules50

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
	fail "Greater than 100 IPs not yet supported."
fi
