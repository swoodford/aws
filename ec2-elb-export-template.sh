#!/usr/bin/env bash

# This script will export an AWS ELB to a JSON Template File for version control
# The ELB can then be duplicated or renamed or recreated from the JSON Template File
# An AWS CLI profile can be passed into the script as an argument
# Requires the AWS CLI and jq

# Step 1: Pull JSON data from AWS for existing ELB and save to Template file
# Step 2: Read JSON data from Template file and create new ELB
# Step 3: Register Instances, Configure Healthcheck, Configure Attributes

ELBname="YOUR-EXISTING-ELB-NAME-HERE"
NewELBname="YOUR-NEW-ELB-NAME-HERE"


# Options
CreateTemplateFile=true
TemplateFileName=$ELBname-template.json
CreateNewELB=true
RegisterInstances=true
ConfigureHealthCheck=true
ConfigureAttributes=true

# Debug
DEBUGMODE="0"

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
	if ! grep -q aws_access_key_id ~/.aws/credentials; then
		tput setaf 1; echo "AWS config not found or CLI not installed. Please run \"aws configure\"." && tput sgr0
		exit 1
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

# Functions

# Check for command
function check_command {
	type -P $1 &>/dev/null || fail "Unable to find $1, please install it and run this script again."
}

# Completed
function Completed(){
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

function HorizontalRule(){
	echo "====================================================="
}

# Check required commands
check_command "aws"
check_command "jq"

# Ensure Variables are set
if [ "$ELBname" = "YOUR-EXISTING-ELB-NAME-HERE" ] || [ -z "$ELBname" ]; then
	read -r -p "Enter name of your existing source EC2 ELB: " ELBname
	TemplateFileName=$ELBname-template.json
	if [ -z "$ELBname" ]; then
		fail "Must specify an existing ELB name!"
	fi
fi

if [ "$CreateNewELB" = "true" ]; then
	if [ "$NewELBname" = "YOUR-NEW-ELB-NAME-HERE" ] || [ -z "$NewELBname" ]; then
		read -r -p "Enter desired name of your new EC2 ELB: " NewELBname
		if [ -z "$NewELBname" ]; then
			fail "Must specify a new ELB name!"
		fi
	fi
fi

# Create Template File
if [ "$CreateTemplateFile" = "true" ]; then

	# Ensure Variables are set
	if [ -z "$TemplateFileName" ]; then
		fail "Must set variable for template file name!"
	fi

	# Check for existing Template file
	if [ -f $TemplateFileName ]; then
		tput setaf 1
		echo "Template File Already Exists!"
		echo $TemplateFileName
		read -r -p "Overwrite? (y/n) " OVERWRITE
		if ! [[ $OVERWRITE =~ ^([yY][eE][sS]|[yY])$ ]]; then
			echo "Canceled."
			tput sgr0
			exit 1
		fi
		tput sgr0
	fi



	DescribeLB=$(aws elb describe-load-balancers --load-balancer-names $ELBname --profile $profile 2>&1)
	if echo $DescribeLB | grep -q "could not be found"; then
		fail "$DescribeLB"
	fi
	if echo $DescribeLB | grep -q "error"; then
		fail "$DescribeLB"
	else
		echo
		HorizontalRule
		echo "Creating Template File"
		HorizontalRule
		echo
		echo "$DescribeLB" > "$TemplateFileName"1
	fi

	DescribeAttributes=$(aws elb describe-load-balancer-attributes --load-balancer-name $ELBname --profile $profile 2>&1)
	if echo $DescribeAttributes | grep -q "error"; then
		fail "$DescribeAttributes"
	else
		echo "$DescribeAttributes" > "$TemplateFileName"2
	fi

	# Combine output of describe-load-balancers and describe-load-balancer-attributes to a single JSON array
	jq -s add "$TemplateFileName"1 "$TemplateFileName"2 > $TemplateFileName && rm "$TemplateFileName"1 "$TemplateFileName"2

	# Verify Template file created
	if ! [ -f $TemplateFileName ]; then
		fail "Unable to create template file:" $TemplateFileName
	else
		echo $TemplateFileName
	fi
	Completed
fi


# Create New ELB
if [ "$CreateNewELB" = "true" ]; then
	# Ensure Variables are set
	if [ "$NewELBname" = "YOUR-NEW-ELB-NAME-HERE" ] || [ -z "$NewELBname" ]; then
		fail "Must set variable for new ELB name!"
	fi

	# Check for an existing ELB with the same name as the new ELB
	TestNewELB=$(aws elb describe-load-balancers --load-balancer-names $NewELBname --profile $profile 2>&1)
	if echo "$TestNewELB" | grep -q "An error occurred"; then
		echo
	else
		tput setaf 1
		echo "An ELB Named $NewELBname Already Exists!"
		read -r -p "Continue and update the existing ELB $NewELBname with configuration from ELB $ELBname? (y/n) " CONTINUE
		if ! [[ $CONTINUE =~ ^([yY][eE][sS]|[yY])$ ]]; then
			echo "Canceled."
			tput sgr0
			exit 1
		fi
	fi

	# Verify Template file exists
	if ! [ -f $TemplateFileName ]; then
		fail "Unable to find template file:" $TemplateFileName
	fi
	echo
	HorizontalRule
	echo "Creating New ELB"
	HorizontalRule
	echo

	# Read the Template file and store as var
	jsoninput=$(cat $TemplateFileName)

	LoadBalancerName=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .LoadBalancerName' | cut -d \" -f2)

	# Determine number of Listeners
	NumListeners=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | length')

	if [ "$NumListeners" -gt "2" ]; then
		fail "ELB with more than 2 listeners not yet supported."
	fi

	# Determine if Listeners include SSL
	if echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | .Protocol' | grep -qw "HTTPS"; then
		HTTPS=true
		if [ "$DEBUGMODE" -eq "1" ]; then
			echo "Found listener with SSL."
			echo
			echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | select(.Protocol!="HTTPS")'
			echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | select(.Protocol=="HTTPS")'
		fi
	fi

	if [ "$NumListeners" -eq "1" ]; then
		# One Listener
		if [ "$DEBUGMODE" -eq "1" ]; then
			echo "Found 1 listener."
		fi
		if [ "$HTTPS" = "true" ]; then
			# One Listener with SSL
			Protocol=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | .Protocol' | cut -d \" -f2)
			InstanceProtocol=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | .InstanceProtocol' | cut -d \" -f2)
			LoadBalancerPort=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | .LoadBalancerPort' | cut -d \" -f2)
			InstancePort=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | .InstancePort' | cut -d \" -f2)
			SSLCertificateId=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | .SSLCertificateId' | cut -d \" -f2)
		else
			# One Listener without SSL
			Protocol=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | .Protocol' | cut -d \" -f2)
			InstanceProtocol=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | .InstanceProtocol' | cut -d \" -f2)
			LoadBalancerPort=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | .LoadBalancerPort' | cut -d \" -f2)
			InstancePort=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | .InstancePort' | cut -d \" -f2)
		fi

	fi

	if [ "$NumListeners" -eq "2" ]; then
		# Two Listeners
		if [ "$DEBUGMODE" -eq "1" ]; then
			echo "Found 2 listeners."
		fi
		# Two Listeners one with SSL one without
		if [ "$HTTPS" = "true" ]; then
			Protocol=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | select(.Protocol=="HTTPS") | .Protocol' | cut -d \" -f2)
			InstanceProtocol=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | select(.Protocol=="HTTPS") | .InstanceProtocol' | cut -d \" -f2)
			LoadBalancerPort=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | select(.Protocol=="HTTPS") | .LoadBalancerPort' | cut -d \" -f2)
			InstancePort=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | select(.Protocol=="HTTPS") | .InstancePort' | cut -d \" -f2)
			SSLCertificateId=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | select(.Protocol=="HTTPS") | .SSLCertificateId' | cut -d \" -f2)

			Protocol2=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | select(.Protocol!="HTTPS") | .Protocol' | cut -d \" -f2)
			InstanceProtocol2=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | select(.Protocol!="HTTPS") | .InstanceProtocol' | cut -d \" -f2)
			LoadBalancerPort2=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | select(.Protocol!="HTTPS") | .LoadBalancerPort' | cut -d \" -f2)
			InstancePort2=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[] | .Listener | select(.Protocol!="HTTPS") | .InstancePort' | cut -d \" -f2)
		else
			# Two Listeners both without SSL
			Protocol=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[0] | .Listener | .Protocol' | cut -d \" -f2)
			InstanceProtocol=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[0] | .Listener | .InstanceProtocol' | cut -d \" -f2)
			LoadBalancerPort=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[0] | .Listener | .LoadBalancerPort' | cut -d \" -f2)
			InstancePort=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[0] | .Listener | .InstancePort' | cut -d \" -f2)

			Protocol2=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[1] | .Listener | .Protocol' | cut -d \" -f2)
			InstanceProtocol2=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[1] | .Listener | .InstanceProtocol' | cut -d \" -f2)
			LoadBalancerPort2=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[1] | .Listener | .LoadBalancerPort' | cut -d \" -f2)
			InstancePort2=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .ListenerDescriptions | .[1] | .Listener | .InstancePort' | cut -d \" -f2)
		fi
	fi

	Instances=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .Instances')
	AvailabilityZones=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .AvailabilityZones')
	Subnets=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .Subnets')
	SecurityGroups=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .SecurityGroups')
	Scheme=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .Scheme' | cut -d \" -f2)

	if [ "$DEBUGMODE" -eq "1" ]; then
		echo "$LoadBalancerName"
		echo "$Protocol"
		echo "$InstanceProtocol"
		echo "$LoadBalancerPort"
		echo "$InstancePort"
		echo "$Instances"
		echo "$AvailabilityZones"
		echo "$Subnets"
		echo "$SecurityGroups"
		echo "$Scheme"
		echo "$SSLCertificateId"
	fi

	# Store ELB as JSON
	LoadBalancerName=$NewELBname

	# Generate JSON based on one listener
	if [ "$NumListeners" -eq "1" ]; then
		if [ "$HTTPS" = "true" ]; then
			json='{
				"LoadBalancerName": "'$LoadBalancerName'",
				"Listeners": [
				{
					"Protocol": "'$Protocol'",
					"LoadBalancerPort": '$LoadBalancerPort',
					"InstanceProtocol": "'$InstanceProtocol'",
					"InstancePort": '$InstancePort',
					"SSLCertificateId": "'$SSLCertificateId'"
				}
				],
				"Subnets": '$Subnets',
				"SecurityGroups": '$SecurityGroups',
				"Scheme": "'$Scheme'"
			}' # > output.json
		else
			json='{
				"LoadBalancerName": "'$LoadBalancerName'",
				"Listeners": [
				{
					"Protocol": "'$Protocol'",
					"LoadBalancerPort": '$LoadBalancerPort',
					"InstanceProtocol": "'$InstanceProtocol'",
					"InstancePort": '$InstancePort'
				}
				],
				"Subnets": '$Subnets',
				"SecurityGroups": '$SecurityGroups',
				"Scheme": "'$Scheme'"
			}' # > output.json
		fi
	fi

	# Generate JSON based on two listeners
	if [ "$NumListeners" -eq "2" ]; then
		if [ "$HTTPS" = "true" ]; then
			json='{
				"LoadBalancerName": "'$LoadBalancerName'",
				"Listeners": [
				{
					"Protocol": "'$Protocol'",
					"LoadBalancerPort": '$LoadBalancerPort',
					"InstanceProtocol": "'$InstanceProtocol'",
					"InstancePort": '$InstancePort',
					"SSLCertificateId": "'$SSLCertificateId'"
				},
				{
					"Protocol": "'$Protocol2'",
					"LoadBalancerPort": '$LoadBalancerPort2',
					"InstanceProtocol": "'$InstanceProtocol2'",
					"InstancePort": '$InstancePort2'
				}
				],
				"Subnets": '$Subnets',
				"SecurityGroups": '$SecurityGroups',
				"Scheme": "'$Scheme'"
			}' # > output.json
		else
			json='{
				"LoadBalancerName": "'$LoadBalancerName'",
				"Listeners": [
				{
					"Protocol": "'$Protocol'",
					"LoadBalancerPort": '$LoadBalancerPort',
					"InstanceProtocol": "'$InstanceProtocol'",
					"InstancePort": '$InstancePort'
				},
				{
					"Protocol": "'$Protocol2'",
					"LoadBalancerPort": '$LoadBalancerPort2',
					"InstanceProtocol": "'$InstanceProtocol2'",
					"InstancePort": '$InstancePort2'
				}
				],
				"Subnets": '$Subnets',
				"SecurityGroups": '$SecurityGroups',
				"Scheme": "'$Scheme'"
			}' # > output.json
		fi
	fi

	# json=$(cat output.json)

	if [ "$DEBUGMODE" -eq "1" ]; then
		echo "Sending request to create new ELB with AWS now..."
	fi

	# Create new ELB from JSON
	CreateLoadBalancer=$(aws elb create-load-balancer --cli-input-json "$json" --profile $profile 2>&1)
	if ! echo "$CreateLoadBalancer" | grep -qw "DNSName"; then
		fail "$CreateLoadBalancer"
	else
		echo "$CreateLoadBalancer" | jq .
		Completed
	fi

	# Register Instances with ELB
	if [ "$RegisterInstances" = "true" ]; then

		HorizontalRule
		echo "Registering Instances with New ELB"
		HorizontalRule
		echo

		# Store Instances as JSON
		json1='{
		    "LoadBalancerName": "'$LoadBalancerName'",
		    "Instances": '$Instances'
		}' # > output1.json

		# json1=$(cat output1.json)

		# Register Instances with ELB
		RegisterInstances=$(aws elb register-instances-with-load-balancer --cli-input-json "$json1" --profile $profile 2>&1)
		if ! echo "$RegisterInstances" | grep -qw "Instances"; then
			fail "$RegisterInstances"
		else
			echo "$RegisterInstances" | jq .
			Completed
		fi
	fi

	# Healthcheck
	if [ "$ConfigureHealthCheck" = "true" ]; then

		HorizontalRule
		echo "Configuring ELB Healthcheck"
		HorizontalRule
		echo

		# Store Healthcheck as JSON
		Target=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .HealthCheck | .Target' | cut -d \" -f2)
		Interval=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .HealthCheck | .Interval' | cut -d \" -f2)
		Timeout=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .HealthCheck | .Timeout' | cut -d \" -f2)
		UnhealthyThreshold=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .HealthCheck | .UnhealthyThreshold' | cut -d \" -f2)
		HealthyThreshold=$(echo $jsoninput | jq '.LoadBalancerDescriptions | .[] | .HealthCheck | .HealthyThreshold' | cut -d \" -f2)

		if [ "$DEBUGMODE" -eq "1" ]; then
			echo "$Target"
			echo "$Interval"
			echo "$Timeout"
			echo "$UnhealthyThreshold"
			echo "$HealthyThreshold"
		fi

		json2='{
		    "LoadBalancerName": "'$LoadBalancerName'",
		    "HealthCheck": {
		        "Target": "'$Target'",
		        "Interval": '$Interval',
		        "Timeout": '$Timeout',
		        "UnhealthyThreshold": '$UnhealthyThreshold',
		        "HealthyThreshold": '$HealthyThreshold'
		    }
		}' # > output2.json

		# json2=$(cat output2.json)


		# Configure Healthcheck from JSON
		ConfigureHealthCheck=$(aws elb configure-health-check --cli-input-json "$json2" --profile $profile 2>&1)
		if ! echo "$ConfigureHealthCheck" | grep -qw "HealthCheck"; then
			fail "$ConfigureHealthCheck"
		else
			echo "$ConfigureHealthCheck" | jq .
			Completed
		fi
	fi

	# Attributes
	if [ "$ConfigureAttributes" = "true" ]; then

		HorizontalRule
		echo "Configuring ELB Attributes"
		HorizontalRule
		echo

		# Store Attributes as JSON
		ConnectionDraining=$(echo $jsoninput | jq '.LoadBalancerAttributes | .ConnectionDraining | .Enabled' | cut -d \" -f2)
		ConnectionDrainingTimeout=$(echo $jsoninput | jq '.LoadBalancerAttributes | .ConnectionDraining | .Timeout' | cut -d \" -f2)
		CrossZoneLoadBalancing=$(echo $jsoninput | jq '.LoadBalancerAttributes | .CrossZoneLoadBalancing | .Enabled' | cut -d \" -f2)
		ConnectionSettings=$(echo $jsoninput | jq '.LoadBalancerAttributes | .ConnectionSettings | .IdleTimeout' | cut -d \" -f2)
		AccessLog=$(echo $jsoninput | jq '.LoadBalancerAttributes | .AccessLog | .Enabled' | cut -d \" -f2)

		if [ "$DEBUGMODE" -eq "1" ]; then
			echo "$ConnectionDraining"
			echo "$ConnectionDrainingTimeout"
			echo "$CrossZoneLoadBalancing"
			echo "$ConnectionSettings"
			echo "$AccessLog"
		fi

		json3='{
		  "LoadBalancerName": "'$LoadBalancerName'",
		  "LoadBalancerAttributes": {
		    "CrossZoneLoadBalancing": {
		      "Enabled": '$CrossZoneLoadBalancing'
		    },
		    "AccessLog": {
		      "Enabled": '$AccessLog'
		    },
		    "ConnectionDraining": {
		      "Enabled": '$ConnectionDraining',
		      "Timeout": '$ConnectionDrainingTimeout'
		    },
		    "ConnectionSettings": {
		      "IdleTimeout": '$ConnectionSettings'
		    }
		  }
		}' # > output3.json

		# json3=$(cat output3.json)


		# Configure Attributes from JSON
		ConfigureAttributes=$(aws elb modify-load-balancer-attributes --cli-input-json "$json3" --profile $profile 2>&1)
		if ! echo "$ConfigureAttributes" | grep -qw "LoadBalancerAttributes"; then
			fail "$ConfigureAttributes"
		else
			echo "$ConfigureAttributes" | jq .
			Completed
		fi
	fi
	echo
	HorizontalRule
	echo Created new ELB: $NewELBname
	HorizontalRule
	echo
fi
