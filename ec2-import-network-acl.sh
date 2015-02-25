#!/bin/bash
# This script will read from the list of CIDR IPs in the file ipblacklistmaster 
# Then create an AWS EC2 Classic ACL rule to deny access to each CIDR IP specified

# VERY IMPORTANT to set the correct Network ACL ID for the intended ACL
NETWORKACLID="YOUR-ACL-ID-HERE"

if [ "$NETWORKACLID" = "YOUR-ACL-ID-HERE" ]; then
	tput setaf 1; echo "Failed to set Network ACL ID!" && tput sgr0
	exit 1
fi

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
	if ! grep -q aws_access_key_id ~/.aws/credentials; then
		echo "Error: AWS config not found or CLI not installed. Please run \"aws configure\"."
		exit 1
	fi
fi

# exec &>> ~/vpcacl.log
echo "============================="
date '+%c'
echo "============================="

TOTALCIDR=$(wc -l ipblacklistmaster | cut -d " " -f5)

echo " "
echo "====================================================="
echo "Adding CIDR records to ACL"
echo "Records to be created: "$TOTALCIDR
echo "====================================================="
echo " "

START=1
for (( COUNT=$START; COUNT<=$TOTALCIDR; COUNT++ ))
do
	echo "====================================================="
	echo "Rule "\#$COUNT

	CIDR=$(nl ipblacklistmaster | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
	echo "CIDR="$CIDR

	# echo "Network ACL ID: "$NETWORKACLID

	ADDRECORD=$(aws ec2 create-network-acl-entry --network-acl-id $NETWORKACLID --rule-number $COUNT --protocol -1 --rule-action deny --ingress --cidr-block $CIDR)
	echo "Record created: "$ADDRECORD
done

echo "====================================================="
echo " "
echo "Completed!"
echo " "
