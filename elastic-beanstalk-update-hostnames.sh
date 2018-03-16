#!/usr/bin/env bash

# This script updates the hostname on Elastic Beanstalk servers with their environment name and IP address
# It also will restart New Relic monitoring if present
# Requires the AWS CLI and jq


# Set Variables

# Debug Mode
DEBUGMODE="0"


# Functions

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
	tput setaf 1; echo "Failure: $*" && tput sgr0
	exit 1
}

# Horizontal Rule
function HorizontalRule(){
	echo "============================================================"
}

# Pause
function pause(){
	read -n 1 -s -p "Press any key to continue..."
	echo
}

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
	if ! grep -q aws_access_key_id ~/.aws/credentials; then
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

# Check required commands
check_command "aws"
check_command "jq"

# Get Elastic Beanstalk Environments
function ebenvironments(){
	describeenvironments=$(aws elasticbeanstalk describe-environments --output=json --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$describeenvironments"
	fi
	ebenvironments=$(echo "$describeenvironments" | jq '.Environments | .[] | .EnvironmentName' | cut -d \" -f2)
	if [ -z "$ebenvironments" ]; then
		fail "No Elastic Beanstalk Environments found."
	fi
	echo "EB Environments Found:"
	HorizontalRule
	echo "$ebenvironments"
	HorizontalRule
}

# Get Elastic Beanstalk Environment Resources
function ebresources(){
	while IFS= read -r ebenvironments
	do
		describeebresources=$(aws elasticbeanstalk describe-environment-resources --environment-name $ebenvironments --output=json --profile $profile 2>&1)
		if [ ! $? -eq 0 ]; then
			fail "$describeebresources"
		fi
		ebresources=$(echo "$describeebresources" | jq '.EnvironmentResources | .Instances | .[] | .Id' | cut -d \" -f2)
		if [ -z "$ebresources" ]; then
			fail "No Elastic Beanstalk Environment Resources found."
		fi
		echo "EB Server IDs Found for Environment $ebenvironments:"
		HorizontalRule
		echo "$ebresources"
		HorizontalRule

		ebresourcescount=$(echo "$ebresources" | wc -l)
		if [[ $DEBUGMODE = "1" ]]; then
			echo ebresourcescount "$ebresourcescount"
		fi
		ebresourceslist=$(echo "$ebresources" | nl)
		if [[ $DEBUGMODE = "1" ]]; then
			echo ebresourceslist "$ebresourceslist"
		fi
		# Get IP Address
		START=1
		if [[ $DEBUGMODE = "1" ]]; then
			echo "Getting IP for $ebresourcescount instance(s)."
		fi
		for (( COUNT=$START; COUNT<=$ebresourcescount; COUNT++ ))
		do
			currentinstanceid=$(echo "$ebresourceslist" | grep -w [^0-9][[:space:]]$COUNT | cut -f2)
			if [[ $DEBUGMODE = "1" ]]; then
				echo "Getting IP for Instance ID: $currentinstanceid"
			fi
			describeinstances=$(aws ec2 describe-instances --instance-ids "$currentinstanceid" --query 'Reservations[*].Instances[*].PublicIpAddress' --output=json --profile $profile 2>&1)
			if [ ! $? -eq 0 ]; then
				fail "$describeinstances"
			fi
			getipaddr=$(echo "$describeinstances" | jq '.[] | .[]' | cut -d \" -f2)
			echo "IP Address: $getipaddr"
			# Set Hostname
			echo '#!/usr/bin/env bash' >> sethostname.sh
			echo "sudo sed -i 's/Defaults    requiretty/#Defaults    requiretty/g' /etc/sudoers" >> sethostname.sh
			echo sudo hostname "$ebenvironments"-"$getipaddr" >> sethostname.sh
			echo "chkconfig --list newrelic-sysmond &> /dev/null && sudo service newrelic-sysmond restart" >> sethostname.sh
			chmod +x sethostname.sh
			uploadhostnamescript=$(scp -o StrictHostKeyChecking=no sethostname.sh $getipaddr:~)
			sethostname=$(ssh -n $getipaddr '(./sethostname.sh)')
			if [[ $DEBUGMODE = "1" ]]; then
				echo "$sethostname"
			fi
			rm sethostname.sh
		done
	done <<< "$ebenvironments"
	completed
}

ebenvironments
# ebenvironments="set one environment here to override the lookup"
ebresources
