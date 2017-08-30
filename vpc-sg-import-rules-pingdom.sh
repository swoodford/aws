#!/usr/bin/env bash

# This script will save a list of current Pingdom IPv4 probe server IPs in the file pingdom-probe-servers.txt
# Then create an AWS VPC Security Group with rules to allow access to each IP at the port specified.
# Due to AWS limits a group can only have 50 rules. This script will create multiple groups if greater than 50 rules.
# Supports up to 150 rules
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

# Get Pingdom IPv4 IPs
# https://help.pingdom.com/hc/en-us/articles/203682601-How-to-get-all-Pingdom-probes-public-IP-addresses
function probeIPs(){
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

# Create Security Group
function createGroup(){
	echo
	HorizontalRule
	echo "Creating Security Group: "$GROUPNAME
	SGID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCRIPTION" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
	if echo $SGID | grep -q "error"; then
		fail "$SGID"
	fi
	echo "Security Group ID:" $SGID
	TAG=$(aws ec2 create-tags --resources $SGID --tags Key=Name,Value="$GROUPNAME" --profile $profile 2>&1)
	if echo $TAG | grep -q "error"; then
		fail "$TAG"
	fi
	HorizontalRule
	echo
}

# Builds the JSON for 50 rules or less
function buildJSON0(){
	(
	cat << EOP
{
    "GroupId": "$SGID",
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

	cat json1 json3 json4 > json
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json
	fi
}

# Builds the JSON for 51-100 rules
function buildJSON50(){
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
	for (( COUNT=$START; COUNT<=50; COUNT++ ))
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

	START=51
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



# Builds the JSON for 101-150 rules
function buildJSON100(){
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
	for (( COUNT=$START; COUNT<=50; COUNT++ ))
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

	START=51
	for (( COUNT=$START; COUNT<=100; COUNT++ ))
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

	START=101
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
	if ! [ -f json ]; then
		fail "Error building JSON."
	else
		json=$(cat json)
	fi
	AUTHORIZE=$(aws ec2 authorize-security-group-ingress --cli-input-json "$json" --profile $profile 2>&1)
	if echo $AUTHORIZE | grep -q error; then
		fail "$AUTHORIZE"
	fi
}

# Create AWS VPC Security Groups

# Create one group with 50 rules or less
function group0(){
	createGroup
	echo
	buildJSON0
	AuthorizeSecurityGroupIngress
	completed
}

# Create multiple groups for 51-100 rules
function group50(){
	# Set Variables for Group #1
	FIRSTGROUPNAME="$GROUPNAME 1"
	if [[ $DEBUGMODE = "1" ]]; then
		echo "FIRSTGROUPNAME: "$FIRSTGROUPNAME
	fi
	FIRSTDESCR="$DESCRIPTION 1-50"
	if [[ $DEBUGMODE = "1" ]]; then
		echo "FIRSTDESCR: "$FIRSTDESCR
	fi
	echo
	HorizontalRule
	echo "Creating Security Group: "$FIRSTGROUPNAME
	SGID1=$(aws ec2 create-security-group --group-name "$FIRSTGROUPNAME" --description "$FIRSTDESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
	if echo $SGID1 | grep -q "error"; then
		fail "$SGID1"
	fi
	echo "Security Group ID:" $SGID1
	TAG=$(aws ec2 create-tags --resources $SGID1 --tags Key=Name,Value="$FIRSTGROUPNAME" --profile $profile 2>&1)
	if echo $TAG | grep -q "error"; then
		fail "$TAG"
	fi
	HorizontalRule
	echo
	# Set Variables for Group #2
	SECONDGROUPNAME="$GROUPNAME 2"
	SECONDDESCR="$DESCRIPTION 51-$TOTALIPS"
	echo
	HorizontalRule
	echo "Creating Security Group: "$SECONDGROUPNAME
	SGID2=$(aws ec2 create-security-group --group-name "$SECONDGROUPNAME" --description "$SECONDDESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
	if echo $SGID2 | grep -q "error"; then
		fail "$SGID2"
	fi
	echo "Security Group ID:" $SGID2
	TAG=$(aws ec2 create-tags --resources $SGID2 --tags Key=Name,Value="$SECONDGROUPNAME" --profile $profile 2>&1)
	if echo $TAG | grep -q "error"; then
		fail "$TAG"
	fi
	HorizontalRule
	echo
	buildJSON50
	AuthorizeSecurityGroupIngress
	cp json6 json
	AuthorizeSecurityGroupIngress
	completed
}

# Create multiple groups for 101-150 rules
function group100(){
	# Set Variables for Group #1
	FIRSTGROUPNAME="$GROUPNAME 1"
	if [[ $DEBUGMODE = "1" ]]; then
		echo "FIRSTGROUPNAME: "$FIRSTGROUPNAME
	fi
	FIRSTDESCR="$DESCRIPTION 1-50"
	if [[ $DEBUGMODE = "1" ]]; then
		echo "FIRSTDESCR: "$FIRSTDESCR
	fi
	echo
	HorizontalRule
	echo "Creating Security Group: "$FIRSTGROUPNAME
	SGID1=$(aws ec2 create-security-group --group-name "$FIRSTGROUPNAME" --description "$FIRSTDESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
	if echo $SGID1 | grep -q "error"; then
		fail "$SGID1"
	fi
	echo "Security Group ID:" $SGID1
	TAG=$(aws ec2 create-tags --resources $SGID1 --tags Key=Name,Value="$FIRSTGROUPNAME" --profile $profile 2>&1)
	if echo $TAG | grep -q "error"; then
		fail "$TAG"
	fi
	HorizontalRule
	echo
	# Set Variables for Group #2
	SECONDGROUPNAME="$GROUPNAME 2"
	SECONDDESCR="$DESCRIPTION 51-100"
	echo
	HorizontalRule
	echo "Creating Security Group: "$SECONDGROUPNAME
	SGID2=$(aws ec2 create-security-group --group-name "$SECONDGROUPNAME" --description "$SECONDDESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
	if echo $SGID2 | grep -q "error"; then
		fail "$SGID2"
	fi
	echo "Security Group ID:" $SGID2
	TAG=$(aws ec2 create-tags --resources $SGID2 --tags Key=Name,Value="$SECONDGROUPNAME" --profile $profile 2>&1)
	if echo $TAG | grep -q "error"; then
		fail "$TAG"
	fi
	HorizontalRule
	echo
	# Set Variables for Group #3
	THIRDGROUPNAME="$GROUPNAME 3"
	THIRDDESCR="$DESCRIPTION 101-$TOTALIPS"
	echo
	HorizontalRule
	echo "Creating Security Group: "$THIRDGROUPNAME
	SGID3=$(aws ec2 create-security-group --group-name "$THIRDGROUPNAME" --description "$THIRDDESCR" --vpc-id $VPCID --profile $profile 2>&1 | jq '.GroupId' | cut -d \" -f2)
	if echo $SGID3 | grep -q "error"; then
		fail "$SGID3"
	fi
	echo "Security Group ID:" $SGID3
	TAG=$(aws ec2 create-tags --resources $SGID3 --tags Key=Name,Value="$THIRDGROUPNAME" --profile $profile 2>&1)
	if echo $TAG | grep -q "error"; then
		fail "$TAG"
	fi
	HorizontalRule
	echo
	buildJSON100
	AuthorizeSecurityGroupIngress
	cp json6 json
	AuthorizeSecurityGroupIngress
	cp json7 json
	AuthorizeSecurityGroupIngress
	completed
}

# Validate VPC ID
function validateVPCID(){
	if [ "$VPCID" = "YOUR-VPC-ID-HERE" ] || [ -z "$VPCID" ]; then
		# Count number of VPCs
		DESCRIBEVPCS=$(aws ec2 describe-vpcs --profile $profile 2>&1)
		if echo $DESCRIBEVPCS | egrep -q "Error|error|not"; then
			fail "$DESCRIBEVPCS"
		fi
		NUMVPCS=$(echo $DESCRIBEVPCS | jq '.Vpcs | length')
		if echo $NUMVPCS | egrep -q "Error|error|not|invalid"; then
			fail "$NUMVPCS"
		fi

		# If only one VPC, use that ID
		if [ "$NUMVPCS" -eq "1" ]; then
			VPCID=$(echo "$DESCRIBEVPCS" | jq '.Vpcs | .[] | .VpcId' | cut -d \" -f2)
		else
			FOUNDVPCS=$(aws ec2 describe-vpcs --profile $profile 2>&1 | jq '.Vpcs | .[] | .VpcId')
			if echo $FOUNDVPCS | egrep -q "Error|error|not|invalid"; then
				fail "$FOUNDVPCS"
			fi
			echo "Found VPCs:" $FOUNDVPCS
			echo
			read -r -p "Please specify VPC ID (ex. vpc-12345678): " VPCID
			if [ -z "$VPCID" ]; then
				fail "Must specify a valid VPC ID."
			fi
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

# Confirm the group with this name does not already exist in the VPC
function validateGroupName(){
	validateGroupName=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values="$VPCID" --output=json --profile $profile 2>&1 | jq '.SecurityGroups | .[] | .GroupName')
	if echo "$validateGroupName" | egrep -q "\b$GROUPNAME\b|\b$GROUPNAME 1\b"; then
		echo Warning: Security Group $(echo "$validateGroupName" | egrep "\b$GROUPNAME\b|\b$GROUPNAME 1\b") already exists in specified VPC.
	fi
}

# Run the script and call functions

# Check for required applications
check_command "jq"
check_command "wget"
check_command "perl"

validateVPCID

echo
HorizontalRule
echo "This script will save a list of current Pingdom probe server IPs in the file pingdom-probe-servers.txt"
echo "then create one or more AWS VPC Security Groups with rules to allow access to each IP in the port range specified."
HorizontalRule
echo
tput setaf 1; echo "Please verify all settings before continuing..." && tput sgr0
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

# Determine number of security groups needed since default AWS limit is 50 rules per group
# https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Appendix_Limits.html#vpc-limits-security-groups

# Create one group with 50 rules or less
if [ "$TOTALIPS" -gt "0" ]; then
	if [ "$TOTALIPS" -lt "51" ]; then
		group0
	fi
fi

# Create multiple groups for 51-100 rules
if [ "$TOTALIPS" -gt "50" ]; then
	if [ "$TOTALIPS" -lt "101" ]; then
		group50
	fi
fi

# Create multiple groups for 101-150 rules
if [ "$TOTALIPS" -gt "100" ]; then
	if [ "$TOTALIPS" -lt "151" ]; then
		group100
	fi
fi

# More than 150 rules not yet supported
if [ "$TOTALIPS" -gt "150" ]; then
	fail "Greater than 150 IPs not yet supported."
fi

# Cleanup temp JSON files
rm -f json json1 json2 json3 json4 json5 json6 json7
