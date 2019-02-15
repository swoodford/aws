#!/usr/bin/env bash

# This script will save a list of current Pingdom IPv4 probe server IPs in the file pingdom-probe-servers.txt
# Then create an AWS VPC Security Group with rules to allow access to each IP at the port specified.

# Pingdom currently has 114 IPv4 probe IPs. Due to AWS limits a security group can only have 60 rules,
# Therefore multiple groups will be needed to contain all IPs for Pingdom probes.
# (https://docs.aws.amazon.com/vpc/latest/userguide/amazon-vpc-limits.html#vpc-limits-security-groups)

# If security groups have already been created for Pingdom, the script will remove all the IP rules and
# add new rules to the same groups so they are not deleted and groups are still assigned to your resources.

# This script currently supports up to 180 probe IPs (three security groups).
# Requires the AWS CLI, jq, wget, perl

# Set Variables
GROUPNAME="Pingdom"
DESCRIPTION="Pingdom Probe Servers"
VPCID="YOUR-VPC-ID-HERE"
PROTOCOL="tcp"
# If allowing only one port use the same port number for both from and to vars below
FROMPORT="80"
TOPORT="443"

# Debug Mode
DEBUGMODE="0"


# Functions


# Pause
function pause(){
	read -n 1 -s -p "Press any key to continue..."
	echo
}

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

# Get Pingdom IPv4 IPs
# https://help.pingdom.com/hc/en-us/articles/203682601-How-to-get-all-Pingdom-probes-public-IP-addresses
function probeIPs(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "function probeIPs"
	fi
	wget --quiet -O- https://www.pingdom.com/rss/probe_servers.xml | \
	perl -nle 'print $1 if /IP: (([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5]));/' | \
	sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 | \
	uniq > pingdom-probe-servers.txt

	TOTALIPS=$(cat pingdom-probe-servers.txt | wc -l | tr -d ' ')

	if ! [ "$TOTALIPS" -gt "0" ]; then
		fail "Unable to lookup Pingdom IPs."
	fi
	echo
	HorizontalRule
	echo "Total Pingdom IPs: "$TOTALIPS
	HorizontalRule
	echo
}

# Create Security Groups
function createGroups(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "function createGroups"
		echo var1: "$1"
		echo var2: "$2"
	fi
	echo
	HorizontalRule
	echo "Creating Security Group: "$1
	SGID=$(aws ec2 create-security-group --group-name "$1" --description "$2" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
	if [ ! $? -eq 0 ]; then
		fail "$SGID"
	fi
	if echo $SGID | grep -q "error"; then
		fail "$SGID"
	fi
	echo "Security Group ID:" $SGID
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

# Builds the JSON for 61-120 rules
function buildJSON120(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "function buildJSON120"
	fi
	(
	cat << EOP
{
    "GroupId": "$SGID1",
    "IpPermissions": [
        {
            "IpProtocol": "$PROTOCOL",
            "FromPort": $FROMPORT,
            "ToPort": $TOPORT,
            "IpRanges": [
EOP
	) > json1
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json1
	fi
	rm -f json2

	START=1
	for (( COUNT=$START; COUNT<=60; COUNT++ ))
	do
	iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
	# if [[ $DEBUGMODE = "1" ]]; then
	# 	echo iplist:
	# 	echo
	# 	echo "$iplist"
	# 	echo
	# 	# pause
	# fi
	(
	cat << EOP
                {
                    "CidrIp": "$iplist/32"
                },
EOP
	) >> json2
	done

	if [[ $DEBUGMODE = "1" ]]; then
		echo built json2
	fi

	# Remove the last comma to close JSON array
	cat json2 | sed '$ s/.$//' > json3
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json3
	fi

	(
	cat << 'EOP'
            ]
        }
    ]
}
EOP
	) > json4

	if [[ $DEBUGMODE = "1" ]]; then
		echo built json4
	fi

	cat json1 json3 json4 > json
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json
	fi

	# GROUP 2
	(
	cat << EOP
{
    "GroupId": "$SGID2",
    "IpPermissions": [
        {
            "IpProtocol": "$PROTOCOL",
            "FromPort": $FROMPORT,
            "ToPort": $TOPORT,
            "IpRanges": [
EOP
	) > json1
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json1
	fi
	rm -f json2

	START=61
	for (( COUNT=$START; COUNT<=$TOTALIPS; COUNT++ ))
	do
	iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
	(
	cat << EOP
                {
                    "CidrIp": "$iplist/32"
                },
EOP
	) >> json2
	done

	if [[ $DEBUGMODE = "1" ]]; then
		echo built json2
	fi

	# Remove the last comma to close JSON array
	cat json2 | sed '$ s/.$//' > json3
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json3
	fi

	(
	cat << 'EOP'
            ]
        }
    ]
}
EOP
	) > json4

	if [[ $DEBUGMODE = "1" ]]; then
		echo built json4
	fi

	cat json1 json3 json4 > json6
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json6
	fi

}


# Builds the JSON for 121-180 rules
function buildJSON180(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "function buildJSON100"
	fi
	(
	cat << EOP
{
    "GroupId": "$SGID1",
    "IpPermissions": [
        {
            "IpProtocol": "$PROTOCOL",
            "FromPort": $FROMPORT,
            "ToPort": $TOPORT,
            "IpRanges": [
EOP
	) > json1
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json1
	fi
	rm -f json2

	START=1
	for (( COUNT=$START; COUNT<=60; COUNT++ ))
	do
	iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
	(
	cat << EOP
                {
                    "CidrIp": "$iplist/32"
                },
EOP
	) >> json2
	done

	if [[ $DEBUGMODE = "1" ]]; then
		echo built json2
	fi

	# Remove the last comma to close JSON array
	cat json2 | sed '$ s/.$//' > json3
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json3
	fi

	(
	cat << 'EOP'
            ]
        }
    ]
}
EOP
	) > json4

	if [[ $DEBUGMODE = "1" ]]; then
		echo built json4
	fi

	cat json1 json3 json4 > json
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json
	fi

	# GROUP 2
	(
	cat << EOP
{
    "GroupId": "$SGID2",
    "IpPermissions": [
        {
            "IpProtocol": "$PROTOCOL",
            "FromPort": $FROMPORT,
            "ToPort": $TOPORT,
            "IpRanges": [
EOP
	) > json1
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json1
	fi
	rm -f json2

	START=61
	for (( COUNT=$START; COUNT<=120; COUNT++ ))
	do
	iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
	(
	cat << EOP
                {
                    "CidrIp": "$iplist/32"
                },
EOP
	) >> json2
	done

	if [[ $DEBUGMODE = "1" ]]; then
		echo built json2
	fi

	# Remove the last comma to close JSON array
	cat json2 | sed '$ s/.$//' > json3
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json3
	fi

	(
	cat << 'EOP'
            ]
        }
    ]
}
EOP
	) > json4

	if [[ $DEBUGMODE = "1" ]]; then
		echo built json4
	fi

	cat json1 json3 json4 > json6
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json6
	fi

	# GROUP 3
	(
	cat << EOP
{
    "GroupId": "$SGID3",
    "IpPermissions": [
        {
            "IpProtocol": "$PROTOCOL",
            "FromPort": $FROMPORT,
            "ToPort": $TOPORT,
            "IpRanges": [
EOP
	) > json1
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json1
	fi
	rm -f json2

	START=121
	for (( COUNT=$START; COUNT<=$TOTALIPS; COUNT++ ))
	do
	iplist=$(nl pingdom-probe-servers.txt | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
	(
	cat << EOP
                {
                    "CidrIp": "$iplist/32"
                },
EOP
	) >> json2
	done

	if [[ $DEBUGMODE = "1" ]]; then
		echo built json2
	fi

	# Remove the last comma to close JSON array
	cat json2 | sed '$ s/.$//' > json3
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json3
	fi

	(
	cat << 'EOP'
            ]
        }
    ]
}
EOP
	) > json4

	if [[ $DEBUGMODE = "1" ]]; then
		echo built json4
	fi

	cat json1 json3 json4 > json7
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json7
	fi
}

# Request ingress authorization to a security group from JSON file
function AuthorizeSecurityGroupIngress(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "function AuthorizeSecurityGroupIngress"
	fi
	if ! [ -f json ]; then
		fail "Error building JSON."
	else
		json=$(cat json)
	fi
	HorizontalRule
	echo "Adding rules to security groups..."
	HorizontalRule
	echo
	AUTHORIZE=$(aws ec2 authorize-security-group-ingress --cli-input-json "$json" --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$AUTHORIZE"
	fi
	if echo $AUTHORIZE | grep -q error; then
		fail "$AUTHORIZE"
	fi
}

# Create AWS VPC Security Groups

# Create multiple groups for 61-120 rules
function group120(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "function group120"
	fi

	if ! [[ "$GroupsAlreadyExist" -eq "1" ]]; then
		if [[ $DEBUGMODE = "1" ]]; then
			echo "Groups Do Not Already Exist..."
		fi
		# Set Variables for Group #1
		FIRSTGROUPNAME="$GROUPNAME 1"
		if [[ $DEBUGMODE = "1" ]]; then
			echo "FIRSTGROUPNAME: "$FIRSTGROUPNAME
		fi
		FIRSTDESCR="$DESCRIPTION 1-60"
		if [[ $DEBUGMODE = "1" ]]; then
			echo "FIRSTDESCR: "$FIRSTDESCR
		fi

		createGroups "$FIRSTGROUPNAME" "$FIRSTDESCR"
		SGID1="$SGID"

		# Set Variables for Group #2
		SECONDGROUPNAME="$GROUPNAME 2"
		SECONDDESCR="$DESCRIPTION 61-$TOTALIPS"

		createGroups "$SECONDGROUPNAME" "$SECONDDESCR"
		SGID2="$SGID"
	fi

	buildJSON120
	AuthorizeSecurityGroupIngress
	cp json6 json
	AuthorizeSecurityGroupIngress
	completed
}

# Create multiple groups for 121-180 rules
function group180(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "function group100"
	fi

	if ! [[ "$GroupsAlreadyExist" -eq "1" ]]; then
		if [[ $DEBUGMODE = "1" ]]; then
			echo "Groups Do Not Already Exist..."
		fi
		# Set Variables for Group #1
		FIRSTGROUPNAME="$GROUPNAME 1"
		if [[ $DEBUGMODE = "1" ]]; then
			echo "FIRSTGROUPNAME: "$FIRSTGROUPNAME
		fi
		FIRSTDESCR="$DESCRIPTION 1-60"
		if [[ $DEBUGMODE = "1" ]]; then
			echo "FIRSTDESCR: "$FIRSTDESCR
		fi

		createGroups "$FIRSTGROUPNAME" "$FIRSTDESCR"
		SGID1="$SGID"

		# Set Variables for Group #2
		SECONDGROUPNAME="$GROUPNAME 2"
		SECONDDESCR="$DESCRIPTION 61-120"

		createGroups "$SECONDGROUPNAME" "$SECONDDESCR"
		SGID2="$SGID"

		# Set Variables for Group #3
		THIRDGROUPNAME="$GROUPNAME 3"
		THIRDDESCR="$DESCRIPTION 121-$TOTALIPS"

		createGroups "$THIRDGROUPNAME" "$THIRDDESCR"
		SGID3="$SGID"
	fi

	buildJSON180
	AuthorizeSecurityGroupIngress
	cp json6 json
	AuthorizeSecurityGroupIngress
	cp json7 json
	AuthorizeSecurityGroupIngress
	completed
}

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

# Confirm the group with this name does not already exist in the VPC
function validateGroupName(){
	if [[ $DEBUGMODE = "1" ]]; then
		echo "function validateGroupName"
		echo "GROUPNAME $GROUPNAME"
	fi
	validateGroupName=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values="$VPCID" --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName')
	if [ ! $? -eq 0 ]; then
		fail "$validateGroupName"
	fi
	if echo "$validateGroupName" | egrep -iq "\b$GROUPNAME\b|\b$GROUPNAME 1\b"; then
		tput setaf 1; echo Security Group\(s\) $(echo "$validateGroupName" | egrep -i "\b$GROUPNAME\b|\b$GROUPNAME 1\b" | sort) already exist in specified VPC. && tput sgr0

		# TODO: This part is too complicated to handle smoothly...
		tput setaf 1; read -r -p "Do you want to remove the existing IPs and add new IPs? (y/n) " deleteIPs && tput sgr0
		if [[ $deleteIPs =~ ^([yY][eE][sS]|[yY])$ ]]; then
			deleteIPs
		else
			GroupsAlreadyExist="1"
			findGroups
		# 	echo "Exiting"
		# 	exit 1
		fi
	fi
}

# Look up the security group IDs
function findGroups(){
	FindGroups=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values="$VPCID" --output=json --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$FindGroups"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "$FindGroups" | jq .
	fi

	# Assuming there are exactly 2 groups
	SGID1=$(echo "$FindGroups" | jq -r --arg GROUPNAME "$GROUPNAME 1" '.SecurityGroups | .[] | select(.GroupName==$GROUPNAME) | .GroupId' | cut -d \" -f2)
	SGID2=$(echo "$FindGroups" | jq -r --arg GROUPNAME "$GROUPNAME 2" '.SecurityGroups | .[] | select(.GroupName==$GROUPNAME) | .GroupId' | cut -d \" -f2)
	# SGID3=$(echo "$FindGroups" | jq -r --arg GROUPNAME "$GROUPNAME 3" '.SecurityGroups | .[] | select(.GroupName==$GROUPNAME) | .GroupId' | cut -d \" -f2)

	# if [[ -z $SGID1 ]] || [[ -z $SGID2 ]] || [[ -z $SGID3 ]]; then
	if [[ -z $SGID1 ]] || [[ -z $SGID2 ]]; then
		echo "Unable to lookup $GROUPNAME Security Group IDs."
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo DEBUG SGID1: "$SGID1"
		echo DEBUG SGID2: "$SGID2"
		# echo DEBUG SGID3: "$SGID3"
	fi
}

# Remove the existing IPs and add new IPs
function deleteIPs(){
	FindGroups=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values="$VPCID" --output=json --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$FindGroups"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "$FindGroups" | jq .
	fi

	# Assuming there are exactly 2 groups
	SGID1=$(echo "$FindGroups" | jq -r --arg GROUPNAME "$GROUPNAME 1" '.SecurityGroups | .[] | select(.GroupName==$GROUPNAME) | .GroupId' | cut -d \" -f2)
	SGID2=$(echo "$FindGroups" | jq -r --arg GROUPNAME "$GROUPNAME 2" '.SecurityGroups | .[] | select(.GroupName==$GROUPNAME) | .GroupId' | cut -d \" -f2)
	# SGID3=$(echo "$FindGroups" | jq -r --arg GROUPNAME "$GROUPNAME 3" '.SecurityGroups | .[] | select(.GroupName==$GROUPNAME) | .GroupId' | cut -d \" -f2)

	# if [[ -z $SGID1 ]] || [[ -z $SGID2 ]] || [[ -z $SGID3 ]]; then
	if [[ -z $SGID1 ]] || [[ -z $SGID2 ]]; then
		echo "Unable to lookup $GROUPNAME Security Group IDs."
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo DEBUG SGID1: "$SGID1"
		echo DEBUG SGID2: "$SGID2"
		# echo DEBUG SGID3: "$SGID3"
	fi

	Group1IPs=$(aws ec2 describe-security-groups --output=json --group-id "$SGID1" --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$Group1IPs"
	fi
	Group2IPs=$(aws ec2 describe-security-groups --output=json --group-id "$SGID2" --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$Group2IPs"
	fi
	# Group3IPs=$(aws ec2 describe-security-groups --output=json --group-id "$SGID3" --profile $profile 2>&1)
	# if [ ! $? -eq 0 ]; then
	# 	fail "$Group3IPs"
	# fi

	# if [[ -z $Group1IPs ]] || [[ -z $Group2IPs ]] || [[ -z $Group3IPs ]]; then
	if [[ -z $Group1IPs ]] || [[ -z $Group2IPs ]]; then
		fail "Unable to parse $GROUPNAME Security Groups."
	fi

	Group1IPs=$(echo "$Group1IPs" | jq '.SecurityGroups | .[] | .IpPermissions')
	Group2IPs=$(echo "$Group2IPs" | jq '.SecurityGroups | .[] | .IpPermissions')
	# Group3IPs=$(echo "$Group3IPs" | jq '.SecurityGroups | .[] | .IpPermissions')
	if [[ $DEBUGMODE = "1" ]]; then
		echo DEBUG Group1IPs: "$Group1IPs"
		echo DEBUG Group2IPs: "$Group2IPs"
		# echo DEBUG Group3IPs: "$Group3IPs"
	fi

	echo
	HorizontalRule
	echo "Removing IPs from $GROUPNAME 1, Security Group ID $SGID1"
	RemoveGroup1IPs=$(aws ec2 revoke-security-group-ingress --output=json --group-id "$SGID1" --profile $profile --ip-permissions "$Group1IPs" 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$RemoveGroup1IPs"
	fi
	HorizontalRule

	echo
	HorizontalRule
	echo "Removing IPs from $GROUPNAME 2, Security Group ID $SGID2"
	RemoveGroup2IPs=$(aws ec2 revoke-security-group-ingress --output=json --group-id "$SGID2" --profile $profile --ip-permissions "$Group2IPs" 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$RemoveGroup2IPs"
	fi
	HorizontalRule

	# echo
	# HorizontalRule
	# echo "Removing IPs from $GROUPNAME 3, Security Group ID $SGID3"
	# RemoveGroup3IPs=$(aws ec2 revoke-security-group-ingress --output=json --group-id "$SGID3" --profile $profile --ip-permissions "$Group3IPs" 2>&1)
	# if [ ! $? -eq 0 ]; then
	# 	fail "$RemoveGroup3IPs"
	# fi
	# HorizontalRule

	# Set flag so there is no attempt to create the groups again
	GroupsAlreadyExist="1"
}

# Run the script and call functions

# Check for required applications
check_command jq wget perl

validateVPCID

echo
HorizontalRule
echo "This script will create or update AWS VPC Security Groups with rules"
echo "to allow access to each Pingdom probe IP in the port range specified."
HorizontalRule
echo
tput setaf 1; echo "Please review all settings before continuing..." && tput sgr0
echo
echo "AWS CLI Profile Name: "$profile
echo "Group Name: "$GROUPNAME
echo "Group Description: "$DESCRIPTION
echo "VPC ID: "$VPCID
echo "Protocol: "$PROTOCOL
if [ "$FROMPORT" -eq "$TOPORT" ]; then
	echo "Port: "$FROMPORT
else
	echo "Port Range: "$FROMPORT-$TOPORT
fi
echo
pause
echo

validateGroupName

probeIPs

# Determine number of security groups needed since default AWS limit is 60 rules per group
# https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Appendix_Limits.html#vpc-limits-security-groups

# Create one group with 60 rules or less
if [ "$TOTALIPS" -gt "0" ]; then
	if [ "$TOTALIPS" -lt "61" ]; then
		fail "Support for 60 IPs or fewer has been depreciated."
	fi
fi

# Create multiple groups for 61-120 rules
if [ "$TOTALIPS" -gt "60" ]; then
	if [ "$TOTALIPS" -lt "121" ]; then
		group120
	fi
fi

# Create multiple groups for 121-180 rules
if [ "$TOTALIPS" -gt "120" ]; then
	if [ "$TOTALIPS" -lt "181" ]; then
		group180
	fi
fi

# More than 180 rules not yet supported
if [ "$TOTALIPS" -gt "180" ]; then
	fail "Greater than 180 IPs not yet supported."
fi

# Cleanup temp JSON files
rm -f json json1 json2 json3 json4 json5 json6 json7
