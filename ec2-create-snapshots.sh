#!/bin/bash
# This script takes a snapshot of each EC2 volume that is tagged with Backup=1
# TODO: Add error handling and loop breaks

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
  if ! grep -q aws_access_key_id ~/.aws/credentials; then
    echo "Error: AWS config not found or CLI not installed. Please run \"aws configure\"."
    exit 1
  fi
fi

DESCRIBEVOLUMES=$(aws ec2 describe-volumes --filter Name=tag:Backup,Values="1")

TOTALBACKUPVOLUMES=$(echo "$DESCRIBEVOLUMES" | grep Name | cut -f 3 | nl | wc -l)

echo " "
echo "====================================================="
echo "Creating EC2 Snapshots for Volumes with tag Backup=1"
echo "Snapshots to be created:"$TOTALBACKUPVOLUMES
echo "====================================================="
echo " "

START=1
for (( COUNT=$START; COUNT<=$TOTALBACKUPVOLUMES; COUNT++ ))
do
  echo "====================================================="
  echo \#$COUNT
  
  VOLUME=$(echo "$DESCRIBEVOLUMES" | cut -f 9 | nl | grep -w $COUNT | cut -f 2)
  echo "Volume ID: "$VOLUME
  
  NAME=$(echo "$DESCRIBEVOLUMES" | grep Name | cut -f 3 | nl | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
  echo "Volume Name: "$NAME
  
  CLIENT=$(echo "$DESCRIBEVOLUMES" | grep Client | cut -f 3 | nl | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
  echo "Client: "$CLIENT
  
  DESCRIPTION=$NAME-$(date +%m-%d-%Y)
  echo "Snapshot Description: "$DESCRIPTION

  SNAPSHOTRESULT=$(aws ec2 create-snapshot --volume-id $VOLUME --description $DESCRIPTION)
  # echo "Snapshot result is: "$SNAPSHOTRESULT

  SNAPSHOTID=$(echo $SNAPSHOTRESULT | cut -d ' ' -f5)
  echo "Snapshot ID: "$SNAPSHOTID
  # echo $SNAPSHOTID | grep -E "snap-........"
  # sleep 3

  TAGRESULT=$(aws ec2 create-tags --resources $SNAPSHOTID --tags Key=Name,Value=$NAME Key=Client,Value=$CLIENT Key=SnapshotCreation,Value=Automatic Key=SnapshotDate,Value=$(date +%m-%d-%Y))
  # echo "Tag Result is: "$TAGRESULT
done

echo "====================================================="
echo " "
echo "Completed!"
echo " "
