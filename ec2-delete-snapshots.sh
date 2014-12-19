#!/bin/bash
# This script deletes snapshots for each EC2 volume that is tagged with SnapshotCreation=Automatic that matches the specified date

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
  if ! grep -q aws_access_key_id ~/.aws/credentials; then
    echo "Error: AWS config not found or CLI not installed. Please run \"aws configure\"."
    exit 1
  fi
fi

SNAPSHOTDATES=$(aws ec2 describe-snapshots --filters Name=tag:SnapshotCreation,Values="Automatic" --output text | grep SnapshotDate | cut -f 3 | sort -u)

echo "List of Automatic Snapshot Dates:"
echo "$SNAPSHOTDATES"

read -r -p "Enter Date for Snapshot Deletion: (MM-DD-YYYY) " DELETEDATE

if [[ -z $DELETEDATE ]]; then
	echo "Failed to set Date!"
	exit 1
fi

DESCRIBESNAPSHOTS=$(aws ec2 describe-snapshots --filters Name=tag:SnapshotDate,Values="$DELETEDATE" Name=tag:SnapshotCreation,Values="Automatic" --output text)

TOTALSNAPSHOTS=$(echo "$DESCRIBESNAPSHOTS" | grep Name | cut -f 3 | nl | wc -l)

echo " "
echo "====================================================="
echo "Deleting EC2 Snapshots for date specified."
echo "Snapshots to be deleted:"$TOTALSNAPSHOTS
echo "====================================================="
echo " "

START=1
for (( COUNT=$START; COUNT<=$TOTALSNAPSHOTS; COUNT++ ))
do
	echo "====================================================="
	echo \#$COUNT

	DELETESNAPSHOTID=$(echo "$DESCRIBESNAPSHOTS" | cut -f 6 | grep -w snap | nl | grep -w $COUNT | cut -f 2)

	DELETESNAPSHOTDESC=$(echo "$DESCRIBESNAPSHOTS" | grep $DELETESNAPSHOTID | cut -f 2 | nl | grep -w 1 | cut -f 2)

	DELETESNAP=$(aws ec2 delete-snapshot --snapshot-id $DELETESNAPSHOTID --output text)
	echo "Successful: "$DELETESNAP
	echo "Deleted: "$DELETESNAPSHOTDESC
done

echo "====================================================="
echo " "
echo "Completed!"
echo " "
