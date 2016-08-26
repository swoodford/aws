#!/usr/bin/env bash

# This script will save a list of current Pingdom probe server IPs in the file iplist
# Then create an AWS WAF IP Set with rules to allow access to each IP
# Requires the AWS CLI and jq

# Set Variables
CONDITIONNAME="Pingdom"
DEBUGMODE="1"

# Functions

# Check for command
function check_command {
	type -P $1 &>/dev/null || fail "Unable to find $1, please install it and run this script again."
}

# Fail
function fail(){
	tput setaf 1; echo "Failure: $*" && tput sgr0
	exit 1
}

# Ensure Variables are set
if [ "$CONDITIONNAME" = "YOUR-CONDITION-NAME-HERE" ]; then
	fail "Must set variables!"
	exit 1
fi

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
	if ! grep -q aws_access_key_id ~/.aws/credentials; then
		tput setaf 1; echo "Error: AWS config not found or CLI not installed. Please run \"aws configure\"." && tput sgr0
		exit 1
	fi
fi

# Get Pingdom IPv4 IPs
function GetProbeIPs(){
	wget --quiet -O- https://www.pingdom.com/rss/probe_servers.xml | \
	perl -nle 'print $1 if /IP: (([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5]));/' | \
	sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 > iplist

	TOTALIPS=$(cat iplist | wc -l | tr -d ' ')
	# TOTALIPS=$(cat pingdom-probe-servers.txt | wc -l | cut -d " " -f7)

	if [[ $DEBUGMODE = "1" ]]; then
		echo "Total Pingdom IPs: "$TOTALIPS
	fi
}

function InsertIPSet(){
	CHANGETOKEN=$(aws waf get-change-token | jq '.ChangeToken' | cut -d '"' -f2)
	# echo "$CHANGETOKEN"
	UPDATESET=$(aws waf update-ip-set --ip-set-id $IPSETID --change-token $CHANGETOKEN --updates 'Action=INSERT,IPSetDescriptor={Type=IPV4,Value="'"$iplist/32"'"}' 2>&1) # | jq .)
	echo $CHANGETOKEN >> changetokenlist
	CHANGETOKENSTATUS=$(aws waf get-change-token-status --change-token $CHANGETOKEN | jq '.ChangeTokenStatus' | cut -d '"' -f2)
	echo $CHANGETOKENSTATUS: $iplist/32
	# echo "$UPDATESET"
}

function DeleteIPSet(){
	CHANGETOKEN=$(aws waf get-change-token | jq '.ChangeToken' | cut -d '"' -f2)
	# echo "$CHANGETOKEN"
	UPDATESET=$(aws waf update-ip-set --ip-set-id $IPSETID --change-token $CHANGETOKEN --updates 'Action=DELETE,IPSetDescriptor={Type=IPV4,Value="'"$iplist/32"'"}' 2>&1) # | jq .)
	echo $CHANGETOKEN >> changetokenlist
	CHANGETOKENSTATUS=$(aws waf get-change-token-status --change-token $CHANGETOKEN | jq '.ChangeTokenStatus' | cut -d '"' -f2)
	echo $CHANGETOKENSTATUS: $iplist/32
	# echo "$UPDATESET"
}

function CleanUpIPSet(){
	while read iplist
	do
		#####################
		# Need to remove CIDR from end of iplist?
		#####################
		DeleteIPSet
	done < iplist-existing
}

function CheckStatus(){
	echo
	echo "====================================================="
	echo "Checking Status:"
	while read CHANGETOKEN
	do
		CHANGETOKENSTATUS=$(aws waf get-change-token-status --change-token $CHANGETOKEN | jq '.ChangeTokenStatus' | cut -d '"' -f2)
		echo $CHANGETOKENSTATUS
	done < changetokenlist
	echo "====================================================="
	echo
}

function CountRulesInIPSet (){
	IPSETID=$(aws waf list-ip-sets --limit 99 --output=json 2>&1 | jq '.IPSets | .[] | select(.Name=="'"$CONDITIONNAME"'") | .IPSetId' | cut -d '"' -f2)
	GetIPSet=$(aws waf get-ip-set --ip-set-id "$IPSETID" 2>&1 | jq '.IPSet | .IPSetDescriptors | .[] | .Value' | cut -d '"' -f2)

	if [ -f iplist-existing ]; then
		rm iplist-existing
	fi

	echo "$GetIPSet" >> iplist-existing
	CountIPSetIPs=$(echo "$GetIPSet" | wc -l)
	echo IPs in set $CONDITIONNAME: $CountIPSetIPs
}


# Check required commands
check_command "aws"
check_command "jq"


GetProbeIPs

# TOTALIPS=$(wc -l iplist | cut -d " " -f7)

function WAF(){

	if [ -f changetokenlist ]; then
		rm changetokenlist
	fi


	if ! aws waf list-ip-sets --limit 99 --output=json | jq '.IPSets | .[] | .Name' | grep -q "$CONDITIONNAME"; then
		echo
		echo "====================================================="
		echo "Creating IP Set: "$CONDITIONNAME
		IPSETID=$(aws waf create-ip-set --name "$CONDITIONNAME" 2>&1)
		echo "IP Set ID:" "$IPSETID"
		echo "====================================================="
		echo
		echo
		echo "====================================================="
		echo "Adding IPs to IP Set: "$CONDITIONNAME
		echo "IPs to be added: "$TOTALIPS
		echo "====================================================="
		echo
		while read iplist
		do
			InsertIPSet
		done < iplist
		echo
		echo "====================================================="
		tput setaf 2; echo "Completed!" && tput sgr0
		echo "====================================================="
		echo
	else
		tput setaf 1
		echo
		echo "====================================================="
		echo "IP Set: $CONDITIONNAME Already Exists"
		IPSETID=$(aws waf list-ip-sets --limit 99 --output=json 2>&1 | jq '.IPSets | .[] | select(.Name=="'"$CONDITIONNAME"'") | .IPSetId' | cut -d '"' -f2)
		echo IPSetID: "$IPSETID"
		echo "====================================================="
		tput sgr0
		echo
		read -r -p "Do you want to update the set with new IPs? (y/n) " UPDATESET
		if [[ $UPDATESET =~ ^([yY][eE][sS]|[yY])$ ]]; then
			echo
			echo "====================================================="
			echo "Adding IPs to IP Set: "$CONDITIONNAME
			echo "IPs to be added: "$TOTALIPS
			echo "====================================================="
			echo
			while read iplist
			do
				InsertIPSet
			done < iplist
			echo "====================================================="
			echo
			tput setaf 2; echo "Completed!" && tput sgr0
			echo
			return 1
		fi

		# You can't delete an IPSet if it's still used in any Rules or if it still includes any IP addresses.
		# You can't delete a Rule if it's still used in any WebACL objects.

		read -r -p "Do you want to delete the set and recreate it? (y/n) " DELETESET
		if [[ $DELETESET =~ ^([yY][eE][sS]|[yY])$ ]]; then
			RULENAME=$(aws waf list-rules --limit 99 --output=json 2>&1 | jq '.Rules | .[] | .Name' | grep "$CONDITIONNAME" | cut -d '"' -f2)
			RULEID=$(aws waf list-rules --limit 99 --output=json 2>&1 | jq '.Rules | .[] | select(.Name=="'"$RULENAME"'") | .RuleId' | cut -d '"' -f2)
			echo
			echo "====================================================="
			echo "Deleting Rule Name $RULENAME, Rule ID $RULEID"
			echo "====================================================="
			DELETERULE=$(aws waf delete-rule --rule-id "$RULEID" 2>&1)
			if echo $DELETERULE | grep -q error; then
				fail "$DELETERULE"
			else
				echo "$DELETERULE"
			fi

			echo
			echo "====================================================="
			echo "Deleting Set $CONDITIONNAME, Set ID $IPSETID"
			echo "====================================================="
			DELETESET=$(aws waf delete-ip-set --ip-set-id "$IPSETID" 2>&1)
			if echo $DELETESET | grep -q error; then
				fail "$DELETESET"
			else
				echo "$DELETESET"
				# echo
				# echo "====================================================="
				# echo "Creating Security Group "$GROUPNAME
				# GROUPID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCRIPTION" --vpc-id $VPCID 2>&1)
				# echo $GROUPID
				# aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json | jq '.SecurityGroups | .[] | select(.GroupName=="$GROUPNAME") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$GROUPNAME"
				# echo "====================================================="
			fi
		else
			echo "Exiting."
			exit 1
		fi
	fi
}


WAF
# CheckStatus
CountRulesInIPSet
# CleanUpIPSet
