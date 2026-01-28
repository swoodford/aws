#!/usr/bin/env bash

# This script will Manage WAFV2 Web ACL to allow current Pingdom probe server IPs
# Allows creating or updating AWS WAFV2 IP Addresses Set and Web ACLs
# Saves a list of current Pingdom probe server IPs in the file iplist
# Creates a WAFV2 IP Address Set with all Pingdom IPs
# Creates a WAFV2 Web ACL with rules to allow Pingdom access
# Requires the AWS CLI and jq, wget

# Set Variables
CONDITIONNAME="Pingdom"
DATE=$(date "+%Y-%m-%d")
CONDITIONNAME=$CONDITIONNAME-$DATE

# Debug Mode
DEBUGMODE=false


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

# Ensure AWS profile has necessary permissions
function preflightChecks(){
	# Test WAFv2 access with a simple list command
	# We'll check the specific scope later after user selects it
	echo "Checking AWS CLI and credentials..."
}

# Scope of WAF CloudFront or Regional
function scopeMenu(){
  tput smul; echo "Scope of WAF CloudFront or Regional?" && tput sgr0
  echo "1. Global CloudFront distribution"
  echo "2. Regional Application (ALB, API Gateway, AppSync, Cognito, etc.)"
  echo
  read -r -p "Menu selection #: " scope

  case $scope in
    1)
      WAFSCOPE="CLOUDFRONT"
    ;;
    2)
      WAFSCOPE="REGIONAL"
    ;;
    *)
      fail "Invalid selection!"
    ;;
  esac
}

# Get Pingdom IPv4 IPs
function GetProbeIPs(){
	wget --quiet -O- https://my.pingdom.com/probes/ipv4 | \
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

# Builds the addresses array for WAFv2 IP set
function BuildIPAddressArray(){
	if [ -f ipaddresses.json ]; then
		rm ipaddresses.json
	fi

	echo '[' > ipaddresses.json
	while read iplist
	do
		echo "  \"$iplist/32\"," >> ipaddresses.json
	done < iplist
	
	# Remove the last comma (compatible with both macOS and Linux)
	if [[ "$OSTYPE" == "darwin"* ]]; then
		sed -i '' '$ s/,$//' ipaddresses.json
	else
		sed -i '$ s/,$//' ipaddresses.json
	fi
	echo ']' >> ipaddresses.json
	
	if [[ $DEBUGMODE ]]; then
		echo "Built IP addresses array"
	fi
}

# Create IP Set
function CreateIPSet(){
	BuildIPAddressArray
	ADDRESSES=$(cat ipaddresses.json | jq -c .)
	
	CREATESET=$(aws wafv2 create-ip-set \
		--scope "$WAFSCOPE" \
		--name "$CONDITIONNAME" \
		--description "Pingdom Probe Server IPs - $WAFSCOPE" \
		--ip-address-version IPV4 \
		--addresses "$ADDRESSES" \
		--profile "$profile" 2>&1)
	
	if [ ! $? -eq 0 ]; then
		if [[ $DEBUGMODE ]]; then
			echo "CREATE ERROR: $CREATESET"
		fi
		fail "$CREATESET"
	fi
	
	IPSETID=$(echo "$CREATESET" | jq -r '.Summary.Id')
	IPSETARN=$(echo "$CREATESET" | jq -r '.Summary.ARN')
	
	if [[ $DEBUGMODE ]]; then
		echo "IP Set ID: $IPSETID"
		echo "IP Set ARN: $IPSETARN"
	fi
	
	echo
	HorizontalRule
	echo "Created IP Set: $CONDITIONNAME"
	echo "IP Set ID: $IPSETID"
	HorizontalRule
	echo
}

# Get list of all IP Sets
function ListIPSets(){
	LISTSETS=$(aws wafv2 list-ip-sets --scope "$WAFSCOPE" --limit 100 --profile "$profile" 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$LISTSETS"
	fi
	
	IPSETID=$(echo "$LISTSETS" | jq -r '.IPSets[] | select(.Name=="'"$CONDITIONNAME"'") | .Id')
	IPSETARN=$(echo "$LISTSETS" | jq -r '.IPSets[] | select(.Name=="'"$CONDITIONNAME"'") | .ARN')
	
	if [[ $DEBUGMODE ]]; then
		echo "ListIPSets ID: $IPSETID"
		echo "ListIPSets ARN: $IPSETARN"
	fi
}

# Get list of IPs in a single IP Set
function GetIPSet(){
	GETSET=$(aws wafv2 get-ip-set --scope $WAFSCOPE --id "$IPSETID" --name "$CONDITIONNAME" --profile $profile 2>&1)
	if [ ! $? -eq 0 ]; then
		fail "$GETSET"
	fi
	
	GetIPSet=$(echo "$GETSET" | jq -r '.IPSet.Addresses[]')
	LOCKTOKEN=$(echo "$GETSET" | jq -r '.LockToken')
	
	if [[ $DEBUGMODE ]]; then
		echo "GetIPSet Addresses: $GetIPSet"
		echo "Lock Token: $LOCKTOKEN"
	fi
}

# Update IP Set with new addresses
function UpdateIPSet(){
	GetIPSet
	
	BuildIPAddressArray
	ADDRESSES=$(cat ipaddresses.json | jq -c .)
	
	UPDATESET=$(aws wafv2 update-ip-set \
		--scope $WAFSCOPE \
		--id "$IPSETID" \
		--name "$CONDITIONNAME" \
		--addresses "$ADDRESSES" \
		--lock-token "$LOCKTOKEN" \
		--profile $profile 2>&1)
	
	if [ ! $? -eq 0 ]; then
		fail "$UPDATESET"
	fi
	
	echo
	HorizontalRule
	echo "IP Set Updated Successfully"
	HorizontalRule
	echo
}

# Creates a WAFv2 Web ACL
function CreateWebACL(){
	# Create rules JSON
	cat > rules.json << EOF
[
  {
    "Name": "AllowPingdom",
    "Priority": 0,
    "Statement": {
      "IPSetReferenceStatement": {
        "ARN": "$IPSETARN"
      }
    },
    "Action": {
      "Allow": {}
    },
    "VisibilityConfig": {
      "SampledRequestsEnabled": true,
      "CloudWatchMetricsEnabled": true,
      "MetricName": "AllowPingdom"
    }
  }
]
EOF

	RULES=$(cat rules.json | jq -c .)
	
	CREATEACL=$(aws wafv2 create-web-acl \
		--scope $WAFSCOPE \
		--name "$CONDITIONNAME-WebACL" \
		--default-action Block={} \
		--rules "$RULES" \
		--visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName="$CONDITIONNAME" \
		--profile $profile 2>&1)
	
	if [ ! $? -eq 0 ]; then
		fail "$CREATEACL"
	fi
	
	ACLID=$(echo "$CREATEACL" | jq -r '.Summary.Id')
	ACLARN=$(echo "$CREATEACL" | jq -r '.Summary.ARN')
	
	echo
	HorizontalRule
	echo "Created Web ACL: $CONDITIONNAME-WebACL"
	echo "Web ACL ID: $ACLID"
	echo "Web ACL ARN: $ACLARN"
	HorizontalRule
	echo
}

# Exports a list of IPs in existing IP Set to the file iplist-existing
function ExportExistingIPSet(){
	ListIPSets
	GetIPSet
	if [ -z "$GetIPSet" ]; then
		echo "No IPs in Set!"
		CountIPSetIPs=0
	else
		# Delete any existing file iplist-existing
		if [ -f iplist-existing ]; then
			rm iplist-existing
		fi
		echo "$GetIPSet" >> iplist-existing
		CountIPSetIPs=$(echo "$GetIPSet" | wc -l | tr -d ' ')
		if [[ $DEBUGMODE ]]; then
			echo "IPs in set $CONDITIONNAME: $CountIPSetIPs"
		fi
	fi
}

# Main function to manage WAFv2 IP Set
function WAF(){
	GetProbeIPs
	
	# Check for existing IP Set with the same name
	ListIPSets
	
	if [ -z "$IPSETID" ]; then
		# Create new IP set
		echo
		HorizontalRule
		echo "Creating IP Addresses Set: $CONDITIONNAME"
		HorizontalRule
		echo
		CreateIPSet
		completed
	else
		# IP Set already exists
		tput setaf 1
		echo
		HorizontalRule
		echo "IP Set: $CONDITIONNAME Already Exists"
		echo "IP Set ID: $IPSETID"
		HorizontalRule
		tput sgr0
		echo
		
		read -r -p "Do you want to update the IP set with new IPs? (y/n) " UPDATEIPSET
		if [[ $UPDATEIPSET =~ ^([yY][eE][sS]|[yY])$ ]]; then
			echo
			HorizontalRule
			echo "Updating IP Set: $CONDITIONNAME"
			echo "IPs to be updated: $TOTALIPS"
			HorizontalRule
			echo
			UpdateIPSet
			completed
		else
			echo "Skipping IP Set update."
		fi
	fi
	
	# Ask about creating Web ACL
	read -r -p "Do you want to create a new WAFv2 Web ACL with the IP Set? (y/n) " CREATEACL
	if [[ $CREATEACL =~ ^([yY][eE][sS]|[yY])$ ]]; then
		# Make sure we have the ARN
		if [ -z "$IPSETARN" ]; then
			ListIPSets
		fi
		CreateWebACL
	fi
}
		# You can't delete an IPSet if it's still used in any Rules or if it still includes any IP addresses.
		# You can't delete a Rule if it's still used in any WebACL objects.

			# RULENAME=$(aws wafv2 list-rules --limit 99 --output=json --profile $profile 2>&1 | jq '.Rules | .[] | .Name' | grep "$CONDITIONNAME" | cut -d '"' -f2)
			# RULEID=$(aws wafv2 list-rules --limit 99 --output=json --profile $profile 2>&1 | jq '.Rules | .[] | select(.Name=="'"$RULENAME"'") | .RuleId' | cut -d '"' -f2)
			# echo
			# echo "====================================================="
			# echo "Deleting Rule Name $RULENAME, Rule ID $RULEID"
			# echo "====================================================="
			# DELETERULE=$(aws wafv2 delete-rule --rule-id "$RULEID" --profile $profile 2>&1)
			# if [ ! $? -eq 0 ]; then
			# 	fail "$DELETERULE"
			# else
			# 	echo "$DELETERULE"
			# fi

			# echo
			# echo "====================================================="
			# echo "Deleting Set $CONDITIONNAME, Set ID $IPSETID"
			# echo "====================================================="
			# DELETESET=$(aws wafv2 delete-ip-set --ip-set-id "$IPSETID" --profile $profile 2>&1)
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

# Ensure Variables are set
if [ "$CONDITIONNAME" = "YOUR-CONDITION-NAME-HERE" ]; then
	fail "Must set variables!"
fi

preflightChecks
scopeMenu
WAF

# Cleanup temp files
rm -f ipaddresses.json rules.json 2>/dev/null

# Open console URL if desired
# Regional: https://console.aws.amazon.com/wafv2/homev2/ip-sets
# CloudFront: https://console.aws.amazon.com/wafv2/homev2/ip-sets?region=global
