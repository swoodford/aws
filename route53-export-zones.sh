#!/bin/bash
# This script will use cli53 to export the zone file for each Hosted Zone domain in Route 53 for git version control
# Requires Python, pip, awscli, cli53
# For more info on cli53 see https://github.com/barnybug/cli53

# Test if cli53 already installed, else install it
command -v cli53 >/dev/null 2>&1 || {
	echo "Installing cli53."
	sudo pip install cli53
	echo "cli53 installed."
}

# Test for AWS Credentials
# if [[ -z $AWS_ACCESS_KEY_ID ]]; then
# 	echo "Error: AWS_ACCESS_KEY_ID not configured."
# 	# exit 1
# fi
# if [[ -z $AWS_SECRET_ACCESS_KEY ]]; then
# 	echo "Error: AWS_SECRET_ACCESS_KEY not configured."
# 	# exit 1
# fi

# Test for ~/.boto file
if ! [ -f ~/.boto ]; then
	# read -rp "Attempt to configure cli53 using AWS CLI credentials? (y/n) " CONFIGURE
	# if [[ $CONFIGURE =~ ^([yY][eE][sS]|[yY])$ ]]; then
	# Look for AWS CLI credentials
	echo "Attempting to configure cli53 using AWS CLI credentials..."
	if grep -q aws_access_key_id ~/.aws/config; then
		export AWS_ACCESS_KEY_ID=$(grep aws_access_key_id ~/.aws/config | cut -d ' ' -f3)
		export AWS_SECRET_ACCESS_KEY=$(grep aws_secret_access_key ~/.aws/config | cut -d ' ' -f3)
	elif grep -q aws_access_key_id ~/.aws/credentials; then
		export AWS_ACCESS_KEY_ID=$(grep aws_access_key_id ~/.aws/credentials | cut -d ' ' -f3)
		export AWS_SECRET_ACCESS_KEY=$(grep aws_secret_access_key ~/.aws/credentials | cut -d ' ' -f3)
	else
		echo "Error: AWS config not found or CLI not installed."
		exit 1
	fi

	echo "Found AWS_ACCESS_KEY_ID:" $AWS_ACCESS_KEY_ID
	echo "Found AWS_SECRET_ACCESS_KEY:" $AWS_SECRET_ACCESS_KEY
	echo "Building ~/.boto config file with these credentials..."

	# Build ~/.boto config file
	echo "[Credentials]" >> ~/.boto
	echo "aws_access_key_id = "$AWS_ACCESS_KEY_ID >> ~/.boto
	echo "aws_secret_access_key = "$AWS_SECRET_ACCESS_KEY >> ~/.boto

fi

# Get list of Hosted Zones in Route 53
DOMAINLIST=$(aws route53 list-hosted-zones --output text | cut -f 4 | rev | cut -c 2- | rev | grep -v '^$')
# Count domains found
TOTALDOMAINS=$(echo "$DOMAINLIST" | wc -l)

echo " "
echo "=============================================="
echo "Exporting Zone Files for Route 53 Hosted Zones"
echo "Total number of Hosted Zones: "$TOTALDOMAINS
echo "=============================================="

echo "$DOMAINLIST"
echo " "

if ! [ -d route53zones/ ]; then
	mkdir route53zones
fi

# Export Hosted Zones
START=1
for (( COUNT=$START; COUNT<=$TOTALDOMAINS; COUNT++ ))
do
	echo "========================================="
	echo \#$COUNT
	DOMAIN_ID=$(echo "$DOMAINLIST" | nl | grep -w $COUNT | cut -f 2)
	cli53 export --full $DOMAIN_ID > route53zones/$DOMAIN_ID.zone
	echo "Exported: "$DOMAIN_ID
done

# Remove any empty zone file created
if [ -f route53zones/.zone ]; then
	rm route53zones/.zone
fi

echo "========================================="
echo " "
echo "Completed!"
echo " "
