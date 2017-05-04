#!/usr/bin/env bash

# This script will save a list of current Pingdom probe server IPs in the file iplist
# Then update an AWS VPC Security Group with rules to allow access to each IP at the port specified
# Due to current AWS limits a VPC Security Group can only have 50 rules and will require multiple groups if greater than 50 rules
# It is assumed the number of Pingdom IPs will be greater than 50 and less than 100 which requires exactly two AWS security groups
# Group Modifier variables are used for VPC Security Groups named "Pingdom 1" and "Pingdom 2" or "Pingdom A" and "Pingdom B"
# Requires the AWS CLI, jq, wget, perl

# Set Variables

GROUPNAME="Pingdom"
GROUPMODIFIERA="1"
GROUPMODIFIERB="2"
PROTOCOL="tcp"
PORT="80-443"

# Debug Mode
DEBUGMODE="0"


# Functions

function Pause(){
	read -n 1 -s -p "Press any key to continue..."
	echo
}

# Check for command
function CheckCommand {
	type -P $1 &>/dev/null || Fail "Unable to find $1, please install it and run this script again."
}

# Completed
function Completed(){
	echo
	HorizontalRule
	tput setaf 2; echo "Completed!" && tput sgr0
	HorizontalRule
	echo
}

# Message
function Message(){
	echo
	HorizontalRule
	echo "$*"
	HorizontalRule
	echo
}

# Fail
function Fail(){
	tput setaf 1; echo "Failure: $*" && tput sgr0
	exit 1
}

function HorizontalRule(){
	echo "====================================================="
}

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
	if ! grep -q aws_access_key_id ~/.aws/credentials; then
		Fail "AWS config not found or CLI not installed. Please run \"aws configure\"."
	fi
fi

# Test for optional variable passed as argument and set as AWS CLI profile name
if ! [ -z "$1" ]; then
	profile="$1"
else
	Message "Note: You can pass in an AWS CLI profile name as an argument when running the script.
Example: ./ec2-update-vpcsg-rules-pingdom.sh profilename"
	Pause
	echo
fi

# Get Pingdom IPv4 IPs
function GetProbeIPs(){
	wget --quiet -O- https://www.pingdom.com/rss/probe_servers.xml | \
	perl -nle 'print $1 if /IP: (([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5]));/' | \
	sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 > iplist

	TOTALIPS=$(cat iplist | wc -l | tr -d ' ')
	# TOTALIPS=$(cat pingdom-probe-servers.txt | wc -l | cut -d " " -f7)

	Message "Total Pingdom IPs: $TOTALIPS"
}

# Authorizes a single IP into the Security Group from the var iplist
function AuthorizeIP(){
	if [ -z "$profile" ]; then
		AUTHORIZE=$(aws ec2 authorize-security-group-ingress --group-id $GROUPID --protocol $PROTOCOL --port $PORT --cidr $iplist/32 2>&1) # | jq .)
		if echo $AUTHORIZE | grep -q error; then
			Fail "$AUTHORIZE"
		else
			echo Authorized: $iplist
		fi
	else
		AUTHORIZE=$(aws ec2 authorize-security-group-ingress --profile $profile --group-id $GROUPID --protocol $PROTOCOL --port $PORT --cidr $iplist/32 2>&1) # | jq .)
		if echo $AUTHORIZE | grep -q error; then
			Fail "$AUTHORIZE"
		else
			echo Authorized: $iplist
		fi
	fi
}

# Revokes a single IP from the Security Group using the var iplist
function RevokeIP(){
	if [ -z "$profile" ]; then
		REVOKE=$(aws ec2 revoke-security-group-ingress --group-id $GROUPID --protocol $PROTOCOL --port $PORT --cidr $iplist 2>&1) # | jq .)
		if echo $REVOKE | grep -q error; then
			Fail "$REVOKE"
		else
			echo Revoked: $iplist
		fi
	else
		REVOKE=$(aws ec2 revoke-security-group-ingress --profile $profile --group-id $GROUPID --protocol $PROTOCOL --port $PORT --cidr $iplist 2>&1) # | jq .)
		if echo $REVOKE | grep -q error; then
			Fail "$REVOKE"
		else
			echo Revoked: $iplist
		fi
	fi
}

# Exports a list of IPs in existing Pingdom security groups A and B to the files iplist-existing-A and iplist-existing-B
function ExportExistingIPs(){
	if [ -z "$profile" ]; then
		Message "Exporting existing IPs from Security Groups"
		GROUPA=$(aws ec2 describe-security-groups --output=json --group-names "$GROUPNAME $GROUPMODIFIERA" 2>&1)
		if echo "$GROUPA" | grep -q error; then
			if echo $GROUPA | grep -q "does not exist in default VPC"; then
				GROUPA=$(aws ec2 describe-security-groups --output=json --filters Name=tag-value,Values="$GROUPNAME $GROUPMODIFIERA" 2>&1)
				if ! echo $GROUPA | grep -q IpRanges; then
					Fail "No matching Security Groups found in any VPC."
				fi
			fi
			if echo $GROUPA | grep -q "You may not reference Amazon VPC security groups by name"; then
				GROUPAID=$(aws ec2 describe-security-groups --output=json | jq '.SecurityGroups | .[] | select(.GroupName=="'"$GROUPNAME"' '"$GROUPMODIFIERA"'") | .GroupId' | cut -d '"' -f2)
				GROUPA=$(aws ec2 describe-security-groups --output=json --group-id $GROUPAID 2>&1)
			fi
		fi
		GROUPB=$(aws ec2 describe-security-groups --output=json --group-names "$GROUPNAME $GROUPMODIFIERB" 2>&1)
		if echo $GROUPB | grep -q error; then
			if echo $GROUPB | grep -q "does not exist in default VPC"; then
				GROUPB=$(aws ec2 describe-security-groups --output=json --filters Name=tag-value,Values="$GROUPNAME $GROUPMODIFIERB" 2>&1)
				if ! echo $GROUPB | grep -q IpRanges; then
					Fail "No matching Security Groups found in any VPC."
				fi
			fi
			if echo $GROUPB | grep -q "You may not reference Amazon VPC security groups by name"; then
				GROUPBID=$(aws ec2 describe-security-groups --output=json | jq '.SecurityGroups | .[] | select(.GroupName=="'"$GROUPNAME"' '"$GROUPMODIFIERB"'") | .GroupId' | cut -d '"' -f2)
				GROUPB=$(aws ec2 describe-security-groups --output=json --group-id $GROUPBID 2>&1)
			fi
		fi
	else
		Message "Exporting existing IPs from Security Groups"
		GROUPA=$(aws ec2 describe-security-groups --profile $profile --output=json --group-names "$GROUPNAME $GROUPMODIFIERA" 2>&1)
		if echo $GROUPA | grep -q error; then
			if echo $GROUPA | grep -q "does not exist in default VPC"; then
				GROUPA=$(aws ec2 describe-security-groups --profile $profile --output=json --filters Name=tag-value,Values="$GROUPNAME $GROUPMODIFIERA" 2>&1)
				if ! echo $GROUPA | grep -q IpRanges; then
					Fail "No matching Security Groups found in any VPC."
				fi
			fi
			if echo $GROUPA | grep -q "You may not reference Amazon VPC security groups by name"; then
				GROUPAID=$(aws ec2 describe-security-groups --profile $profile --output=json | jq '.SecurityGroups | .[] | select(.GroupName=="'"$GROUPNAME"' '"$GROUPMODIFIERA"'") | .GroupId' | cut -d '"' -f2)
				GROUPA=$(aws ec2 describe-security-groups --profile $profile --output=json --group-id $GROUPAID 2>&1)
			fi
		fi
		GROUPB=$(aws ec2 describe-security-groups --profile $profile --output=json --group-names "$GROUPNAME $GROUPMODIFIERB" 2>&1)
		if echo $GROUPB | grep -q error; then
			if echo $GROUPB | grep -q "does not exist in default VPC"; then
				GROUPB=$(aws ec2 describe-security-groups --profile $profile --output=json --filters Name=tag-value,Values="$GROUPNAME $GROUPMODIFIERB" 2>&1)
				if ! echo $GROUPB | grep -q IpRanges; then
					Fail "No matching Security Groups found in any VPC."
				fi
			fi
			if echo $GROUPB | grep -q "You may not reference Amazon VPC security groups by name"; then
				GROUPBID=$(aws ec2 describe-security-groups --profile $profile --output=json | jq '.SecurityGroups | .[] | select(.GroupName=="'"$GROUPNAME"' '"$GROUPMODIFIERB"'") | .GroupId' | cut -d '"' -f2)
				GROUPB=$(aws ec2 describe-security-groups --profile $profile --output=json --group-id $GROUPBID 2>&1)
			fi
		fi
	fi

	if [[ $DEBUGMODE = "1" ]]; then
		echo "GROUPA: "$GROUPA
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "GROUPB: "$GROUPB
	fi

	if [ -z "$GROUPAID" ]; then
		GROUPAID=$(echo "$GROUPA" | jq '.SecurityGroups | .[] | .GroupId' | cut -d '"' -f2)
	fi
	if [ -z "$GROUPBID" ]; then
		GROUPBID=$(echo "$GROUPB" | jq '.SecurityGroups | .[] | .GroupId' | cut -d '"' -f2)
	fi

	if [[ $DEBUGMODE = "1" ]]; then
		echo "GROUPAID: "$GROUPAID
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "GROUPBID: "$GROUPBID
	fi

	if [ -z "$GROUPAID" ]; then
		Fail "Unable to find $GROUPNAME Security Groups."
	fi
	if [ -z "$GROUPBID" ]; then
		Fail "Unable to find $GROUPNAME Security Groups."
	fi

	GROUPAIPS=$(echo "$GROUPA" | jq '.SecurityGroups | .[] | .IpPermissions | .[] | .IpRanges | .[] | .CidrIp' | cut -d '"' -f2)
	GROUPBIPS=$(echo "$GROUPB" | jq '.SecurityGroups | .[] | .IpPermissions | .[] | .IpRanges | .[] | .CidrIp' | cut -d '"' -f2)

	# Delete any existing file iplist-existing
	if [ -f iplist-existing-A ]; then
		rm iplist-existing-A
	fi
	if [ -f iplist-existing-B ]; then
		rm iplist-existing-B
	fi
	echo "$GROUPAIPS" >> iplist-existing-A
	echo "$GROUPBIPS" >> iplist-existing-B
	CountGroupA=$(echo "$GROUPAIPS" | wc -l)
	CountGroupB=$(echo "$GROUPBIPS" | wc -l)

	if [[ $DEBUGMODE = "1" ]]; then
		echo "CountGroupA: "$CountGroupA
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "CountGroupB: "$CountGroupB
	fi

	TotalGroupIPs=$(($CountGroupA+$CountGroupB))

	if [ $TotalGroupIPs -eq "2" ]; then
		Fail "Unable to get IPs from existing $GROUPNAME group."
	fi

	Message "Total IPs in existing groups: $TotalGroupIPs"
	# Pause
}


# Delete all existing IPs from Security Groups
function DeleteAllIPs(){
	if [ "$TotalGroupIPs" -gt "2" ]; then
		Message "Deleting all existing IPs from Security Groups"
		GROUPID=$GROUPAID
		for (( COUNT=1; COUNT<=$CountGroupA; COUNT++ ))
		do
			echo "Rule "\#$COUNT

			iplist=$(nl iplist-existing-A | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
			if [[ $DEBUGMODE = "1" ]]; then
				echo "IP="$iplist
			fi
			RevokeIP
		done
		GROUPID=$GROUPBID
		for (( COUNT=1; COUNT<=$CountGroupB; COUNT++ ))
		do
			echo "Rule "\#$(($COUNT+$CountGroupA))

			iplist=$(nl iplist-existing-B | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
			if [[ $DEBUGMODE = "1" ]]; then
				echo "IP="$iplist
			fi
			RevokeIP
		done
		Completed
	fi
}


# Update AWS VPC Security Groups

# Update one group with 50 rules or less
# function addIPs(){
# 	Message "Adding IPs to Security Groups"
# 	# Begin loop to create rules 1-50
# 	for (( COUNT=1; COUNT<=50; COUNT++ ))
# 	do
# 		echo "Rule "\#$COUNT

# 		iplist=$(nl iplist | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
# 		if [[ $DEBUGMODE = "1" ]]; then
# 			echo "IP="$iplist
# 		fi
# 		AuthorizeIP
# 	done
# 	Completed
# }

# Update multiple groups for more than 50 rules
function addIPs50(){
	Message "Adding IPs to Security Groups"
	GROUPID=$GROUPAID
	for (( COUNT=1; COUNT<=50; COUNT++ ))
	do
		echo "Rule "\#$COUNT

		iplist=$(nl iplist | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo "IP="$iplist
		fi
		AuthorizeIP
	done
	GROUPID=$GROUPBID
	for (( COUNT=51; COUNT<=$TOTALIPS; COUNT++ ))
	do
		echo "Rule "\#$COUNT
		# echo "Rule "\#$(($COUNT+$CountGroupA))

		iplist=$(nl iplist | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
		if [[ $DEBUGMODE = "1" ]]; then
			echo "IP="$iplist
		fi
		AuthorizeIP
	done
	Completed
}

# Check required commands
CheckCommand "jq"
CheckCommand "wget"
CheckCommand "perl"
CheckCommand "aws"

GetProbeIPs

ExportExistingIPs

# TOTALIPS=$(wc -l iplist | cut -d " " -f7)


# Determine number of security groups needed since AWS limit is 50 rules per group

# More than 100 rules
# if [ "$TOTALIPS" -gt "100" ]; then
# 	Fail "Greater than 100 IPs not yet supported."
# fi

# # Create one group with 50 rules or less
# if [ "$TOTALIPS" -lt "51" ]; then
# 	DeleteAllIPs
# 	addIPs
# fi

# Create multiple groups for more than 50 rules
if [ "$TOTALIPS" -gt "50" ]; then
	DeleteAllIPs
	addIPs50
fi

