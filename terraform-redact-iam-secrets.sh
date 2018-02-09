#!/usr/bin/env bash

# This script replaces AWS IAM Secret Keys and IAM SES SMTP Passwords with "REDACTED"
# in Terraform state files so they can be safely committed to git without exposing credentials.

# Update:
# A better workaround to this problem is to use the S3 backend type in Terraform to avoid
# committing your state files to git: https://www.terraform.io/docs/backends/types/s3.html

# Usage:
# Run from dir that contains environment subfolders. Requires Terraform and jq.
# Assumes three environments exist within subfolders: dev, staging, production.
# Must have an output.tf file with iam_secret and ses_smtp_password defined.


# Set Variables
devEnv="dev"
stagingEnv="staging"
productionEnv="production"

iamSecret="iam_secret"
sesPassword="ses_smtp_password"

redaction="REDACTED"

DEBUGMODE="0"


# Functions

# Check for command
function check_command {
	type -P $1 &>/dev/null || failExit "Unable to find $1, please install it and run this script again."
}

# Fail
function fail(){
	tput setaf 1; echo "Failure: $*" && tput sgr0
	return 1
	# exit 1
}

# Fail and exit
function failExit(){
	tput setaf 1; echo "Failure: $*" && tput sgr0
	exit 1
}

# Horizontal Rule
function horizontalRule(){
	echo "====================================================="
}

# Completed Message
function completed(){
	echo
	horizontalRule
	tput setaf 2; echo "Completed!" && tput sgr0
	horizontalRule
	echo
}

# Message
function message(){
	echo
	horizontalRule
	echo "$*"
	horizontalRule
	echo
}

# Pause
function pause(){
	read -n 1 -s -p "Press any key to continue..."
	echo
}


# Check required commands
check_command "terraform"
check_command "jq"


# Warning
horizontalRule
tput setaf 1; echo "WARNING: Running this script will remove AWS IAM Secret Keys and IAM SES SMTP Passwords in Terraform state files." && tput sgr0
horizontalRule
echo
pause


# TF State Dev

if [ -f "$devEnv"/terraform.tfstate ]; then
	message Redacting "$devEnv"
	TerraformOutputDev=$(cd "$devEnv" && terraform output -json)

	DevSecret=$(echo $TerraformOutputDev | jq '[."'"$iamSecret"'"|.value]' | cut -d '"' -f2 -s)
	if ! [ -z $DevSecret ]; then
		if [[ $DEBUGMODE = "1" ]]; then
			echo "$devEnv" IAM Secret: $DevSecret
		fi
		sed -i '' -e "s#$DevSecret#$redaction#g" "$devEnv"/terraform.tfstate
		if [ -f "$devEnv"/terraform.tfstate.backup ]; then
			sed -i '' -e "s#$DevSecret#$redaction#g" "$devEnv"/terraform.tfstate.backup
		fi
	fi

	DevSmtpSecret=$(echo $TerraformOutputDev | jq '[."'"$sesPassword"'"|.value]' | cut -d '"' -f2 -s)
	if ! [ -z $DevSmtpSecret ]; then
		if [[ $DEBUGMODE = "1" ]]; then
			echo "$devEnv" SMTP Secret: $DevSmtpSecret
		fi
		sed -i '' -e "s#$DevSmtpSecret#$redaction#g" "$devEnv"/terraform.tfstate
		if [ -f "$devEnv"/terraform.tfstate.backup ]; then
			sed -i '' -e "s#$DevSmtpSecret#$redaction#g" "$devEnv"/terraform.tfstate.backup
		fi
	fi
	TerraformRedactedDev=$(cd "$devEnv" && terraform output -json)
	echo "$devEnv" IAM Secret:
	echo $TerraformRedactedDev | jq '[."'"$iamSecret"'"]'
	echo
	echo "$devEnv" SMTP Secret:
	echo $TerraformRedactedDev | jq '[."'"$sesPassword"'"]'
else
	echo
	fail "No "$devEnv" Environment Found."
	echo
fi


# TF State Staging

if [ -f "$stagingEnv"/terraform.tfstate ]; then
	message Redacting "$stagingEnv"
	TerraformOutputStaging=$(cd "$stagingEnv" && terraform output -json)

	StagingSecret=$(echo $TerraformOutputStaging | jq '[."'"$iamSecret"'"|.value]' | cut -d '"' -f2 -s)
	if ! [ -z $StagingSecret ]; then
		if [[ $DEBUGMODE = "1" ]]; then
			echo "$stagingEnv" IAM Secret: $StagingSecret
		fi
		sed -i '' -e "s#$StagingSecret#$redaction#g" "$stagingEnv"/terraform.tfstate
		if [ -f "$stagingEnv"/terraform.tfstate.backup ]; then
			sed -i '' -e "s#$StagingSecret#$redaction#g" "$stagingEnv"/terraform.tfstate.backup
		fi
	fi

	StagingSmtpSecret=$(echo $TerraformOutputStaging | jq '[."'"$sesPassword"'"|.value]' | cut -d '"' -f2 -s)
	if ! [ -z $StagingSmtpSecret ]; then
		if [[ $DEBUGMODE = "1" ]]; then
			echo "$stagingEnv" SMTP Secret: $StagingSmtpSecret
		fi
		sed -i '' -e "s#$StagingSmtpSecret#$redaction#g" "$stagingEnv"/terraform.tfstate
		if [ -f "$stagingEnv"/terraform.tfstate.backup ]; then
			sed -i '' -e "s#$StagingSmtpSecret#$redaction#g" "$stagingEnv"/terraform.tfstate.backup
		fi
	fi
	TerraformRedactedStaging=$(cd "$stagingEnv" && terraform output -json)
	echo "$stagingEnv" IAM Secret:
	echo $TerraformRedactedStaging | jq '[."'"$iamSecret"'"]'
	echo
	echo "$stagingEnv" SMTP Secret:
	echo $TerraformRedactedStaging | jq '[."'"$sesPassword"'"]'
else
	echo
	fail "No "$stagingEnv" Environment Found."
	echo
fi


# TF State Production

if [ -f "$productionEnv"/terraform.tfstate ]; then
	message Redacting "$productionEnv"
	TerraformOutputProduction=$(cd "$productionEnv" && terraform output -json)

	ProductionSecret=$(echo $TerraformOutputProduction | jq '[."'"$iamSecret"'"|.value]' | cut -d '"' -f2 -s)
	if ! [ -z $ProductionSecret ]; then
		if [[ $DEBUGMODE = "1" ]]; then
			echo "$productionEnv" IAM Secret: $ProductionSecret
		fi
		sed -i '' -e "s#$ProductionSecret#$redaction#g" "$productionEnv"/terraform.tfstate
		if [ -f "$productionEnv"/terraform.tfstate.backup ]; then
			sed -i '' -e "s#$ProductionSecret#$redaction#g" "$productionEnv"/terraform.tfstate.backup
		fi
	fi

	ProductionSmtpSecret=$(echo $TerraformOutputProduction | jq '[."'"$sesPassword"'"|.value]' | cut -d '"' -f2 -s)
	if ! [ -z $ProductionSmtpSecret ]; then
		if [[ $DEBUGMODE = "1" ]]; then
			echo "$productionEnv" SMTP Secret: $ProductionSmtpSecret
		fi
		sed -i '' -e "s#$ProductionSmtpSecret#$redaction#g" "$productionEnv"/terraform.tfstate
		if [ -f "$productionEnv"/terraform.tfstate.backup ]; then
			sed -i '' -e "s#$ProductionSmtpSecret#$redaction#g" "$productionEnv"/terraform.tfstate.backup
		fi
	fi
	TerraformRedactedProduction=$(cd "$productionEnv" && terraform output -json)
	echo "$productionEnv" IAM Secret:
	echo $TerraformRedactedProduction | jq '[."'"$iamSecret"'"]'
	echo
	echo "$productionEnv" SMTP Secret:
	echo $TerraformRedactedProduction | jq '[."'"$sesPassword"'"]'
else
	echo
	fail "No "$productionEnv" Environment Found."
	echo
fi

completed
