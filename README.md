aws
=======

A collection of shell scripts for automating various tasks with Amazon Web Services

- **create-cloudwatch-alarms.sh** Create AWS CloudWatch alarms for EC2, RDS, Load Balancer environments
- **ec2-create-snapshots.sh** Create a snapshot of each EC2 volume that is tagged with the backup flag
- **ec2-delete-snapshots.sh** Deletes snapshots for each EC2 volume that is tagged with the backup flag and matches the specified date
- **ec2-import-network-acl.sh** Import CIDR IP list to AWS VPC ACL rule and deny access
- **install-awscli.sh** Install and configure AWS CLI
- **install-s3cmd.sh** Install and setup s3cmd from the GitHub Repo
- **route53-export-zones.sh** Uses cli53 to export the zone file for each Hosted Zone domain in Route 53
- **s3-buckets-file-size.sh** Count total size of all data stored in all S3 buckets