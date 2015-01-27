#!/bin/bash
# This script will upload an SSL Certificate to AWS for use in setting up an ELB
# Requires AWS CLI Setup

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
  if ! grep -q aws_access_key_id ~/.aws/credentials; then
    echo "Error: AWS config not found or CLI not installed. Please run \"aws configure\"."
    exit 1
  fi
fi

echo "This script will upload an SSL Certificate to AWS for use in setting up an ELB"

read -r -p "Enter the website domain: (ex. domain.com) " DOMAIN

echo "Go to your SSL certificate issuing service account and see instructions to download certificates."
echo "Note you may need to seperate the public key from the certificate bundle chain into seperate files."

read -r -p "Enter the cert expiration date in MMDDYYYY format: (ex. 01162015) " EXPDATE

read -r -p "Enter the file name of the public key file: (ex. STAR_domain_com_public.pem) " PUBKEY

read -r -p "Enter the file name of the private key file: (ex. STAR_domain_com.key) " PRIVATE

read -r -p "Enter the file name of the certificate chain file: (ex. STAR_domain_com.pem) " CHAIN

aws iam upload-server-certificate --server-certificate-name $DOMAIN-$EXPDATE --certificate-body file://$PUBKEY --private-key file://$PRIVATE --certificate-chain file://$CHAIN