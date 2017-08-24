#!/usr/bin/env bash

# This script is meant to be run as EC2 user-data for an Auto Scaling Group Launch Configuration
# It will reassign a previously allocated Elastic IP to the instance which runs the script
# This is useful if a single instance inside an ASG dies and a new instance must spin up with the same EIP
# The instance must have an IAM role that allows "ec2 associate-address"

# Set the allocated Elastic IP here
ELASTIC_IP="1.2.3.4"

# Determine and set region
EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
aws configure set region $EC2_REGION

# Determine Instance ID
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Associate Elastic IP
aws ec2 associate-address --instance-id $INSTANCE_ID --public-ip $ELASTIC_IP --allow-reassociation
