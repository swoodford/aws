#!/usr/bin/env bash
# This script updates the hostname on Elastic Beanstalk servers with their environment name and IP address
# It also will restart New Relic monitoring if present
# Requires jq


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

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! [ -f ~/.aws/config ]; then
  if ! [ -f ~/.aws/credentials ]; then
    fail "Error: AWS config not found or CLI not installed."
    exit 1
  fi
fi

# Get Elastic Beanstalk Environments
function ebenvironments(){
	ebenvironments=$(aws elasticbeanstalk describe-environments | jq '.Environments | .[] | .EnvironmentName' | cut -d \" -f2 2>&1)
	if [ -z "$ebenvironments" ]; then
		fail "No Elastic Beanstalk Environments found."
	fi
	echo "EB Environments Found:"
	echo "----------------------"
	echo "$ebenvironments"
	echo "----------------------"
}

# Get Elastic Beanstalk Environment Resources
function ebresources(){
	while IFS= read -r ebenvironments
	do
		ebresources=$(aws elasticbeanstalk describe-environment-resources --environment-name $ebenvironments | jq '.EnvironmentResources | .Instances | .[] | .Id' | cut -d \" -f2 2>&1)
		if [ -z "$ebresources" ]; then
			fail "No Elastic Beanstalk Environment Resources found."
		fi
		echo "EB Server IDs Found for Environment $ebenvironments:"
		echo "----------------------------------------------------"
		echo "$ebresources"
		echo "----------------------------------------------------"

		ebresourcescount=$(echo "$ebresources" | wc -l)
		# echo ebresourcescount
		# echo "$ebresourcescount"
		ebresourceslist=$(echo "$ebresources" | nl)
		# echo ebresourceslist
		# echo "$ebresourceslist"

		# Get IP Address
		START=1
		# echo "Getting IP for" $ebresourcescount "instance(s)."
		for (( COUNT=$START; COUNT<=$ebresourcescount; COUNT++ ))
		do
			currentinstanceid=$(echo "$ebresourceslist" | grep -w [^0-9][[:space:]]$COUNT | cut -f2)
			# echo $currentinstanceid
			# echo Getting IP for Instance ID: $currentinstanceid
			getipaddr=$(aws ec2 describe-instances --instance-ids "$currentinstanceid" --query 'Reservations[*].Instances[*].PublicIpAddress' | jq '.[] | .[]' | cut -d \" -f2 2>&1)
			echo IP Address: "$getipaddr"
			# Set Hostname
			echo '#!/usr/bin/env bash' >> sethostname.sh
			echo "sudo sed -i 's/Defaults    requiretty/#Defaults    requiretty/g' /etc/sudoers" >> sethostname.sh
			echo sudo hostname "$ebenvironments"-"$getipaddr" >> sethostname.sh
			echo "chkconfig --list newrelic-sysmond &> /dev/null && sudo service newrelic-sysmond restart" >> sethostname.sh
			chmod +x sethostname.sh
			uploadhostnamescript=$(scp -o StrictHostKeyChecking=no sethostname.sh $getipaddr:~)
			sethostname=$(ssh -n $getipaddr '(./sethostname.sh)')
			# echo "$sethostname"
			rm sethostname.sh
		done
	done <<< "$ebenvironments"
}

check_command "jq"

ebenvironments
# ebenvironments="set one environment here to override the lookup"
ebresources
