aws
=======

A collection of shell scripts meant to be run in OS X for performing various tasks with AWS

- **create-cloudwatch-alarms.sh** Create AWS CloudWatch alarms for EC2, RDS, Load Balancer environments
- **ec2-create-snapshots.sh** Create a snapshot of each EC2 volume that is tagged with the backup flag
- **ec2-delete-snapshots.sh** Deletes snapshots for each EC2 volume that is tagged with the backup flag and matches the specified date
- **install-awscli.sh** Install and configure AWS CLI
- **install-s3cmd.sh** Install and setup s3cmd from the GitHub Repo
- **s3-buckets-file-size.sh** Count total size of all data stored in all S3 buckets