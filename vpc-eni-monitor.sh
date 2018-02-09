#!/usr/bin/env bash

# This script will generate an HTML page to monitor the number of AWS VPC Elastic Network Interfaces currently in use and upload it to an S3 bucket website
# Requires the AWS CLI, jq

# Set Variables
VPCID="YOUR-VPC-ID-HERE"
# AWS CLI Profile for VPC ID
PROFILE1="CLI-PROFILE-FOR-VPC"
# AWS CLI Profile for S3 Bucket
PROFILE2="CLI-PROFILE-FOR-S3-BUCKET"
HTMLFILENAME="vpc-eni-monitor.html"
S3BUCKETPATH="s3://YOUR-S3-BUCKET-HERE/"

minENI=0
maxENI=0


# Functions

# Check Command
function check_command {
	type -P $1 &>/dev/null || fail "Unable to find $1, please install it and run this script again."
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

# Validate VPC ID
function validateVPCID(){
	if [ "$VPCID" = "YOUR-VPC-ID-HERE" ] || [ -z "$VPCID" ]; then
		# Count number of VPCs
		DESCRIBEVPCS=$(aws ec2 describe-vpcs --profile $PROFILE1 2>&1)
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
			FOUNDVPCS=$(aws ec2 describe-vpcs --profile $PROFILE1 2>&1 | jq '.Vpcs | .[] | .VpcId')
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
	CHECKVPC=$(aws ec2 describe-vpcs --vpc-ids "$VPCID" --profile $PROFILE1 2>&1)

	# Test for error
	if ! echo "$CHECKVPC" | grep -q "available"; then
		fail $CHECKVPC
	else
		HorizontalRule
		tput setaf 2; echo "VPC ID Validated" && tput sgr0
		HorizontalRule
	fi
}

# Main function to generate the HTML and upload to S3
function generateHTML(){
	while :
	do
		ENI=$(aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=$VPCID --profile $PROFILE1 2>&1 | jq '.NetworkInterfaces | .[] | .NetworkInterfaceId' | wc -l | rev | cut -d ' ' -f1 | rev)
		if echo $ENI | grep -q error; then
			fail "$ENI"
		fi
		date
		echo ENIs: $ENI
		(
		cat << 'EOP'
<html>
	<head>
		<meta http-equiv="refresh" content="5">
		<title>Elastic Network Interface Count
		</title>
	</head>
	<body>
		<center><p style="font-size:15vmax;font-family:courier,serif">ENIs:
EOP
		) > $HTMLFILENAME

		echo '		'$ENI >> $HTMLFILENAME
		(
		cat << 'EOP'
		</p>
		<center><p style="font-size:3vmax;font-family:courier,serif">Updated:
EOP
		) >> $HTMLFILENAME
		echo '		'$(date) >> $HTMLFILENAME

		if [ $minENI -eq "0" ]; then
			minENI=$ENI
			maxENI=$ENI
		fi
		if [ $ENI -eq $minENI ] && [ $ENI -eq $maxENI ]; then
			trend=flat
		fi
		if [ $ENI -lt $minENI ]; then
			minENI=$ENI
			trend=down
		fi
		if [ $ENI -gt $maxENI ]; then
			maxENI=$ENI
			trend=up
		fi

		echo minENIs: $minENI
		echo maxENIs: $maxENI
		echo trending: $trend

		echo '		<br><br>'minENI = $minENI >> $HTMLFILENAME
		echo '		<br>'maxENI = $maxENI >> $HTMLFILENAME
		echo '		<br>' >> $HTMLFILENAME

		if [ "$trend" = "flat" ]; then
			echo '		<p style="font-size:4vmax;color:black">---' >> $HTMLFILENAME
		fi
		if [ "$trend" = "up" ]; then
			echo '		<p style="font-size:4vmax;color:green">/\' >> $HTMLFILENAME
		fi
		if [ "$trend" = "down" ]; then
			echo '		<p style="font-size:4vmax;color:red">\/' >> $HTMLFILENAME
		fi

		(
		cat << 'EOP'
		</p></center>
	</body>
</html>
EOP
		) >> $HTMLFILENAME

		UPLOAD=$(aws s3 cp $HTMLFILENAME $S3BUCKETPATH --profile $PROFILE2 2>&1)
		if echo $UPLOAD | egrep -q "Error|error|not"; then
			fail "$UPLOAD"
		fi
		echo $UPLOAD

		if [ $ENI -lt "100" ]; then
			sleep=60
			echo "sleeping $sleep seconds..."
			HorizontalRule
			echo
			sleep $sleep
		else
			sleep=3
			echo "sleeping $sleep seconds..."
			HorizontalRule
			echo
			sleep $sleep
		fi
	done
}


# Check for required applications
check_command "aws"
check_command "jq"

validateVPCID
generateHTML
