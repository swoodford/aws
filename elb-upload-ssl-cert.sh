#!/bin/bash
# This script will upload an SSL Certificate to AWS for use in setting up an ELB
# Requires AWS CLI Setup and jq

DEBUGMODE=0

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
  if ! grep -q aws_access_key_id ~/.aws/credentials; then
    echo "Error: AWS config not found or CLI not installed. Please run \"aws configure\"."
    exit 1
  fi
fi

# Test for optional variable passed as argument and set as AWS CLI profile name
if ! [ -z "$1" ]; then
	profile="$1"
else
	echo "Note: You can pass in an AWS CLI profile name as an argument when running the script."
	echo "Example: ./elb-upload-ssl-cert.sh profilename"
	pause
	echo
fi

# Functions

# Check required commands
function check_command {
	type -P $1 &>/dev/null || fail "Unable to find $1, please install it and run this script again."
}

# Fail
function fail(){
	tput setaf 1; echo "Failure: $*" && tput sgr0
	exit 1
}

# Pause
function pause(){
	read -p "Press any key to continue..."
	echo
}

# Prepare to import the SSL Certificate
function prepare(){
	echo "====================================================="
	tput setaf 2; echo "This script will import an SSL Certificate to AWS for use in setting up an ELB or CloudFront" && tput sgr0
	echo "====================================================="
	echo
	read -r -p "Enter the desired certificate name or website domain: (ex. domain.com): " DOMAIN
	# echo "Go to your SSL certificate issuing service account and see instructions to download certificates."
	# echo "Note you may need to seperate the public key from the certificate bundle chain into seperate files."
	# read -r -p "Enter the cert expiration date in MMDDYYYY format: (ex. 01162015) " EXPDATE
	echo
	read -r -p "Enter the path and file name of the public key file: (ex. STAR_domain_com_public.pem) " PUBKEY
	if [[ $DEBUGMODE = "1" ]]; then
		echo "PUB KEY FILE: $PUBKEY"
	fi
	PUBKEY=$(eval cat "$PUBKEY")
	if [[ $DEBUGMODE = "1" ]]; then
		echo "PUB KEY:"
		echo "$PUBKEY"
		pause
	fi
	echo
	read -r -p "Enter the path and file name of the private key file: (ex. STAR_domain_com.key) " PRIVATE
	if [[ $DEBUGMODE = "1" ]]; then
		echo "PRIVATE FILE: "$PRIVATE
	fi
	PRIVATE=$(eval cat $PRIVATE)
	if [[ $DEBUGMODE = "1" ]]; then
		echo "PRIVATE KEY:"
		echo "$PRIVATE"
	fi
	echo
	read -r -p "Enter the path and file name of the certificate chain file: (ex. STAR_domain_com.pem) " CHAIN
	if [[ $DEBUGMODE = "1" ]]; then
		echo "CHAIN FILE: "$CHAIN
	fi
	CHAIN=$(eval cat $CHAIN)
	if [[ $DEBUGMODE = "1" ]]; then
		echo "CHAIN:"
		echo "$CHAIN"
	fi
	echo
}

function import(){
	if [ -z "$profile" ]; then
		IMPORT=$(aws iam upload-server-certificate --server-certificate-name "$DOMAIN" --certificate-body "$PUBKEY" --private-key "$PRIVATE" --certificate-chain "$CHAIN" 2>&1)
	else
		IMPORT=$(aws iam upload-server-certificate --profile $profile --server-certificate-name "$DOMAIN" --certificate-body "$PUBKEY" --private-key "$PRIVATE" --certificate-chain "$CHAIN" 2>&1)
	fi
	# aws iam upload-server-certificate --server-certificate-name "$DOMAIN" --certificate-body file://"$PUBKEY" --private-key file://"$PRIVATE" --certificate-chain file://"$CHAIN"
	# aws iam upload-server-certificate --server-certificate-name $DOMAIN-$EXPDATE --certificate-body file://$PUBKEY --private-key file://$PRIVATE --certificate-chain file://$CHAIN
	if echo $IMPORT | grep -q error; then
		echo "====================================================="
		fail "$IMPORT"
	else
		echo "====================================================="
		tput setaf 2; echo "$IMPORT" | jq . && tput sgr0
		echo "====================================================="
		echo
		tput setaf 2; echo "Completed!" && tput sgr0
		echo
	fi
}

check_command "aws"
check_command "jq"

prepare
import

