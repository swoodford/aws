#!/usr/bin/env bash

# This script will Manage WAF Web ACL to allow current Pingdom probe server IPs
# Allows creating or updating AWS WAF IP Addresses Set, Rules and Web ACLs
# Saves a list of current Pingdom probe server IPs in the file iplist
# Creates a WAF IP Address Set with all Pingdom IPs
# Creates a WAF Rule with the IP Address Set
# Creates a WAF Web ACL with the WAF Rule to allow Pingdom access
# Requires the AWS CLI and jq, wget, perl


# Set Variables
CONDITIONNAME="Pingdom"
DATE=$(date "+%Y-%m-%d")
CONDITIONNAME=$CONDITIONNAME-$DATE

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

# Get Pingdom IPv4 IPs
function GetProbeIPs(){
	wget --quiet -O- https://www.pingdom.com/rss/probe_servers.xml | \
	perl -nle 'print $1 if /IP: (([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5]));/' | \
	sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 > iplist

	TOTALIPS=$(cat iplist | wc -l | tr -d ' ')

	if ! [ "$TOTALIPS" -gt "0" ]; then
		fail "Error getting Pingdom IPs."
	fi

	echo
	tput setaf 2
	HorizontalRule
	echo "Total Pingdom IPs: "$TOTALIPS
	HorizontalRule
	tput sgr0
	echo
}

# Gets a Change Token
function ChangeToken(){
	CHANGETOKEN=$(aws waf get-change-token --profile $profile 2>&1 | jq '.ChangeToken' | cut -d '"' -f2)
	if [ ! $? -eq 0 ]; then
		fail "$CHANGETOKEN"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "CHANGETOKEN: "$CHANGETOKEN
	fi
}

# Checks the status of a single changetoken
function ChangeTokenStatus(){
	CHANGETOKENSTATUS=$(aws waf get-change-token-status --change-token $CHANGETOKEN --profile $profile 2>&1 | jq '.ChangeTokenStatus' | cut -d '"' -f2)
	if [ ! $? -eq 0 ]; then
		fail "$CHANGETOKENSTATUS"
	fi
}

# Checks the status of all changetokens in the changetokenlist
function CheckStatus(){
	echo
	HorizontalRule
	echo "Checking Status:"
	while read CHANGETOKEN
	do
		ChangeTokenStatus
		echo $CHANGETOKENSTATUS
	done < changetokenlist
	HorizontalRule
	echo
}

# Builds the JSON for a single large insert to update IP set
function BuildUpdateSetInsertJSON(){
	ChangeToken
(
cat << EOP
{
    "IPSetId": "$IPSETID",
    "ChangeToken": "$CHANGETOKEN",
    "Updates": [
EOP
) > json1
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json1
	fi
	if [ -f json2 ]; then
		rm json2
	fi

	while read iplist
	do
(
cat << EOP
        {
            "Action": "INSERT",
            "IPSetDescriptor": {
                "Type": "IPV4",
                "Value": "$iplist/32"
            }
        },
EOP
) >> json2
	done < iplist
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
EOP
) > json4

	if [[ $DEBUGMODE = "1" ]]; then
		echo built json4
	fi

	cat json1 json3 json4 > json5
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json5
	fi

	rm json1 json2 json3 json4
}

# Builds the JSON for a single large delete to update IP set
function BuildUpdateSetDeleteJSON(){
	ChangeToken
(
cat << EOP
{
    "IPSetId": "$IPSETID",
    "ChangeToken": "$CHANGETOKEN",
    "Updates": [
EOP
) > json1
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json1
	fi
	if [ -f json2 ]; then
		rm json2
	fi

	while read iplist
	do
(
cat << EOP
        {
            "Action": "DELETE",
            "IPSetDescriptor": {
                "Type": "IPV4",
                "Value": "$iplist"
            }
        },
EOP
) >> json2
	done < iplist-existing
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
EOP
) > json4

	if [[ $DEBUGMODE = "1" ]]; then
		echo built json4
	fi

	cat json1 json3 json4 > json5
	if [[ $DEBUGMODE = "1" ]]; then
		echo built json5
	fi

	rm json1 json2 json3 json4
}

# Inserts a JSON file into the IP Set
function UpdateSetInsertJSON(){
	json=$(cat json5)
	UPDATESET=$(aws waf update-ip-set --cli-input-json "$json" --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$UPDATESET"
	fi
}

# Deletes a JSON file from the IP Set
function UpdateSetDeleteJSON(){
	json=$(cat json5)
	UPDATESET=$(aws waf update-ip-set --cli-input-json "$json" --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$UPDATESET"
	fi
}

# Inserts a single IP into the IP Set
function UpdateSetInsert(){
	UPDATESET=$(aws waf update-ip-set --ip-set-id $IPSETID --change-token $CHANGETOKEN --updates 'Action=INSERT,IPSetDescriptor={Type=IPV4,Value="'"$iplist/32"'"}' --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$UPDATESET"
	fi
}

# Deletes a single IP from the IP Set
function UpdateSetDelete(){
	UPDATESET=$(aws waf update-ip-set --ip-set-id $IPSETID --change-token $CHANGETOKEN --updates 'Action=DELETE,IPSetDescriptor={Type=IPV4,Value="'"$iplist"'"}' --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$UPDATESET"
	fi
}

# Create IP Set
function CreateIPSet(){
	ChangeToken
	IPSETID=$(aws waf create-ip-set --name "$CONDITIONNAME" --change-token $CHANGETOKEN --profile $profile 2>&1 | jq '.IPSet | .IPSetId' | cut -d '"' -f2)
	if [ ! $? -eq 0 ]; then
		fail "$IPSETID"
	fi
	echo "IP Set ID:" "$IPSETID"
}

# Get list of all IP Sets
function ListIPSets(){
	IPSETID=$(aws waf list-ip-sets --limit 99 --output=json --profile $profile 2>&1 | jq '.IPSets | .[] | select(.Name=="'"$CONDITIONNAME"'") | .IPSetId' | cut -d '"' -f2)
	if [ ! $? -eq 0 ]; then
		fail "$IPSETID"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "ListIPSets IPSETID: "$IPSETID
	fi
}

# Get list of IPs in a single IP Set
function GetIPSet(){
	GetIPSet=$(aws waf get-ip-set --ip-set-id "$IPSETID" --profile $profile 2>&1 | jq '.IPSet | .IPSetDescriptors | .[] | .Value' | cut -d '"' -f2)
	if [ ! $? -eq 0 ]; then
		fail "$GetIPSet"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "GetIPSet: "$GetIPSet
	fi
}

# Creates a WAF Rule
function CreateRule(){
	ChangeToken
	CreateRule=$(aws waf create-rule --metric-name "$(echo $CONDITIONNAME | sed 's/[\._-]//g')" --name "Allow From $CONDITIONNAME" --change-token $CHANGETOKEN --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$CreateRule"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "CreateRule: "$CreateRule
	fi
	RULEID=$(echo "$CreateRule" | jq '.Rule | .RuleId' | cut -d '"' -f2)
	if [ ! $? -eq 0 ]; then
		fail "$RULEID"
	fi
	echo
	HorizontalRule
	echo "Created WAF Rule ID: "$RULEID
	HorizontalRule
	echo
}

# Updates a WAF Rule
function UpdateRule(){
	ChangeToken
	UPDATERULE=$(aws waf update-rule --rule-id "$RULEID" --change-token $CHANGETOKEN --updates 'Action=INSERT,Predicate={Negated=false,Type=IPMatch,DataId="'"$IPSETID"'"}' --profile $profile 2>&1) # | jq '.Rule | .RuleId' | cut -d '"' -f2)
	if [ ! $? -eq 0 ]; then
		fail "$UPDATERULE"
	fi
	if echo $UPDATERULE | jq '.ChangeToken' | grep -q error; then
		fail "$UPDATERULE"
	else
		echo
		HorizontalRule
		echo "Attached IP Addresses Set to WAF Rule."
		HorizontalRule
		echo
	fi
}

# Creates a WAF Web ACL
function CreateACL(){
	ChangeToken
	ACLID=$(aws waf create-web-acl --metric-name "$CONDITIONNAME" --name "Allow From $CONDITIONNAME" --default-action 'Type=BLOCK' --change-token $CHANGETOKEN --profile $profile 2>&1 | jq '.WebACL | .WebACLId' | cut -d '"' -f2)
	if [ ! $? -eq 0 ]; then
		fail "$ACLID"
	fi
	echo
	HorizontalRule
	echo "Created WAF Web ACL ID: "$ACLID
	HorizontalRule
	echo
}

# Updates a WAF Web ACL
function UpdateACL(){
	ChangeToken
	UPDATEACL=$(aws waf update-web-acl --web-acl-id "$ACLID" --change-token $CHANGETOKEN --updates 'Action=INSERT,ActivatedRule={Priority=0,RuleId="'"$RULEID"'",Action={Type=ALLOW}}' --profile $profile 2>&1) # | jq '.Rule | .RuleId' | cut -d '"' -f2)
	if [ ! $? -eq 0 ]; then
		fail "$UPDATEACL"
	fi
	if echo $UPDATEACL | jq '.ChangeToken' | grep -q error; then
		fail "$UPDATEACL"
	else
		echo
		HorizontalRule
		echo "Attached Rule to WAF Web ACL."
		HorizontalRule
		echo
	fi
}

# Inserts a single IP into the IP Set from the var iplist and reports status using the changetoken
function InsertIPSet(){
	ChangeToken
	if [[ $DEBUGMODE = "1" ]]; then
		echo "IPSETID: "$IPSETID
		echo "IP: "$iplist
	fi
	UpdateSetInsert
	if [[ $DEBUGMODE = "1" ]]; then
		echo "UPDATESET: "$UPDATESET
	fi
	echo $CHANGETOKEN >> changetokenlist
	ChangeTokenStatus
	echo $CHANGETOKENSTATUS: $iplist/32
}

# Deletes a single IP from the IP Set using the var iplist and reports status using the changetoken
function DeleteIPSet(){
	ChangeToken
	if [[ $DEBUGMODE = "1" ]]; then
		echo "IPSETID: "$IPSETID
		echo "IP: "$iplist
	fi
	UpdateSetDelete
	if [[ $DEBUGMODE = "1" ]]; then
		echo "UPDATESET: "$UPDATESET
	fi
	echo $CHANGETOKEN >> changetokenlist
	ChangeTokenStatus
	echo $CHANGETOKENSTATUS: $iplist
}

# Exports a list of IPs in existing IP Set to the file iplist
function ExportExistingIPSet(){
	ListIPSets
	GetIPSet
	if [ -z "$GetIPSet" ]; then
		echo "No IPs in Set!"
	fi
	# Delete any existing file iplist-existing
	if [ -f iplist-existing ]; then
		rm iplist-existing
	fi
	echo "$GetIPSet" >> iplist-existing
	CountIPSetIPs=$(echo "$GetIPSet" | wc -l)
	if [[ $DEBUGMODE = "1" ]]; then
		echo IPs in set $CONDITIONNAME: $CountIPSetIPs
	fi
}

# Main function to manage WAF IP Set
function WAF(){
	GetProbeIPs
	# Delete any existing changetokenlist
	if [ -f changetokenlist ]; then
		rm changetokenlist
	fi
	# Check for existing IP Set with the same name and create the set if none exists
	if ! aws waf list-ip-sets --limit 99 --output=json --profile $profile 2>&1 | jq '.IPSets | .[] | .Name' | grep -q "$CONDITIONNAME"; then
		echo
		HorizontalRule
		echo "Creating IP Addresses Set: "$CONDITIONNAME
		CreateIPSet
		HorizontalRule
		echo
		echo
		HorizontalRule
		echo "Adding IP match conditions to IP Addresses Set"
		echo "IPs to be added: "$TOTALIPS
		HorizontalRule
		echo
		BuildUpdateSetInsertJSON
		UpdateSetInsertJSON
		# while read iplist
		# do
		# 	InsertIPSet
		# done < iplist
		completed
	else
		tput setaf 1
		echo
		HorizontalRule
		echo "IP Set: $CONDITIONNAME Already Exists"
		ListIPSets
		echo IPSetID: "$IPSETID"
		HorizontalRule
		tput sgr0
		echo
		read -r -p "Do you want to delete the set and recreate it? (y/n) " DELETESET
		if [[ $DELETESET =~ ^([yY][eE][sS]|[yY])$ ]]; then
			ExportExistingIPSet
			echo
			if ! [ -z "$GetIPSet" ]; then
				HorizontalRule
				echo "Deleting IPs from IP Set: "$CONDITIONNAME
				echo "IPs to be deleted: "$CountIPSetIPs
				HorizontalRule
				echo
				BuildUpdateSetDeleteJSON
				UpdateSetDeleteJSON
				# while read iplist
				# do
				# 	DeleteIPSet
				# done < iplist-existing
				# Verifying list is empty
				ExportExistingIPSet
				if [ "$CountIPSetIPs" -eq "1" ]; then
					completed
				else
					fail "Error deleting IPs from IP Set."
				fi
			fi
			echo
			HorizontalRule
			echo "Adding IPs to IP Set: "$CONDITIONNAME
			echo "IPs to be added: "$TOTALIPS
			HorizontalRule
			echo
			BuildUpdateSetInsertJSON
			UpdateSetInsertJSON
			# while read iplist
			# do
			# 	InsertIPSet
			# done < iplist
			# Verifying all IPs added
			ExportExistingIPSet
			if [ "$CountIPSetIPs" -eq "$TOTALIPS" ]; then
				completed
			else
				fail "Error adding IPs to IP Set."
			fi
		else
			read -r -p "Do you want to update the set with new IPs? (y/n) " UPDATESET
			if [[ $UPDATESET =~ ^([yY][eE][sS]|[yY])$ ]]; then
				echo
				HorizontalRule
				echo "Adding IPs to IP Set: "$CONDITIONNAME
				echo "IPs to be added: "$TOTALIPS
				HorizontalRule
				echo
				BuildUpdateSetInsertJSON
				UpdateSetInsertJSON
				# while read iplist
				# do
				# 	InsertIPSet
				# done < iplist
				# Verifying all IPs added
				ExportExistingIPSet
				if [ "$CountIPSetIPs" -eq "$TOTALIPS" ]; then
					completed
				else
					fail "Error adding IPs to IP Set."
				fi
			else
				return
			fi
		fi
	fi
	read -r -p "Do you want to create a new WAF Rule with the new IP Address Set? (y/n) " RULE
	if [[ $RULE =~ ^([yY][eE][sS]|[yY])$ ]]; then
		CreateRule
		UpdateRule
		read -r -p "Do you want to create a new WAF Web ACL and attach the new WAF Rule? (y/n) " ACL
		if [[ $ACL =~ ^([yY][eE][sS]|[yY])$ ]]; then
			CreateACL
			UpdateACL
		fi
	fi
}
		# You can't delete an IPSet if it's still used in any Rules or if it still includes any IP addresses.
		# You can't delete a Rule if it's still used in any WebACL objects.

			# RULENAME=$(aws waf list-rules --limit 99 --output=json --profile $profile 2>&1 | jq '.Rules | .[] | .Name' | grep "$CONDITIONNAME" | cut -d '"' -f2)
			# RULEID=$(aws waf list-rules --limit 99 --output=json --profile $profile 2>&1 | jq '.Rules | .[] | select(.Name=="'"$RULENAME"'") | .RuleId' | cut -d '"' -f2)
			# echo
			# echo "====================================================="
			# echo "Deleting Rule Name $RULENAME, Rule ID $RULEID"
			# echo "====================================================="
			# DELETERULE=$(aws waf delete-rule --rule-id "$RULEID" --profile $profile 2>&1)
			# if [ ! $? -eq 0 ]; then
			# 	fail "$DELETERULE"
			# else
			# 	echo "$DELETERULE"
			# fi

			# echo
			# echo "====================================================="
			# echo "Deleting Set $CONDITIONNAME, Set ID $IPSETID"
			# echo "====================================================="
			# DELETESET=$(aws waf delete-ip-set --ip-set-id "$IPSETID" --profile $profile 2>&1)
			# if [ ! $? -eq 0 ]; then
			# 	fail "$DELETESET"
			# else
			# 	echo "$DELETESET"
			# 	# echo
			# 	# echo "====================================================="
			# 	# echo "Creating Security Group "$GROUPNAME
			# 	# GROUPID=$(aws ec2 create-security-group --group-name "$GROUPNAME" --description "$DESCRIPTION" --vpc-id $VPCID --profile $profile 2>&1)
			# 	# echo $GROUPID
			# 	# aws ec2 create-tags --resources $(aws ec2 describe-security-groups --output=json | jq '.SecurityGroups | .[] | select(.GroupName=="$GROUPNAME") | .GroupId' | cut -d '"' -f2) --tags Key=Name,Value="$GROUPNAME"
			# 	# echo "====================================================="
			# fi


# Check required commands
check_command "aws"
check_command "jq"
check_command "wget"
check_command "perl"

# Ensure Variables are set
if [ "$CONDITIONNAME" = "YOUR-CONDITION-NAME-HERE" ]; then
	fail "Must set variables!"
fi

# TOTALIPS=$(wc -l iplist | cut -d " " -f7)

WAF

# CheckStatus

# open https://console.aws.amazon.com/waf/home?region=global#/ipsets/$IPSETID
