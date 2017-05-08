aws
=======

A collection of shell scripts for automating various tasks with Amazon Web Services

Most require the AWS CLI: https://aws.amazon.com/cli/

and jq: https://stedolan.github.io/jq/

[![Build Status](https://travis-ci.org/swoodford/aws.svg?branch=master)](https://travis-ci.org/swoodford/aws)

- **cloudfront-invalidation-status.sh** Checks Cloudfront Distributions for cache invalidation status to complete
- **cloudwatch-create-alarms.sh** Create AWS CloudWatch alarms for EC2, RDS, Load Balancer environments
- **ec2-classic-import-network-acl.sh** Import CIDR IP list to AWS EC2 Classic ACL rules and deny access
- **ec2-ebs-create-snapshots.sh** Create a snapshot of each EC2 EBS volume that is tagged with the backup flag
- **ec2-ebs-delete-snapshots.sh** Deletes snapshots for each EC2 EBS volume that is tagged with the backup flag and matches the specified date
- **ec2-elb-export-template.sh** Export an ELB to a JSON template file for version control, duplication or recreation
- **ec2-elb-upload-ssl-cert.sh** Upload an SSL Certificate to AWS for use in setting up an ELB
- **elastic-beanstalk-set-hostname-within-instance.sh** Set the hostname on Elastic Beanstalk servers from within the instance with their EB environment name and public IP address
- **elastic-beanstalk-update-hostnames.sh** Updates the hostname on Elastic Beanstalk servers with their environment name and IP address
- **install-awscli.sh** Install and configure AWS CLI
- **install-s3cmd.sh** Install and setup s3cmd from the GitHub Repo
- **route53-export-zones.sh** Uses cli53 to export the zone file for each Hosted Zone domain in Route 53
- **s3-buckets-file-size.sh** Count total size of all data stored in all S3 buckets
- **s3-create-iam-user.sh** Create the S3 IAM user, generate IAM keys, add to IAM group, generate user policy
- **s3-fix-content-type-metadata.sh** Safely fix invalid content-type metadata on AWS S3 bucket website assets for some common filetypes
- **s3-openbucketpolicy.sh** Set an S3 bucket policy to allow GetObject requests from any IP address
- **s3-restrictbucketpolicy.sh** Set an S3 bucket policy to only allow GetObject requests from an IP whitelist file named iplist
- **s3-setup-buckets.sh** Create S3 buckets, set CORS config and tag bucket with client name
- **vpc-sg-import-rules.sh** Create an AWS VPC Security Group with rules to allow access to each IP at the port specified
- **vpc-sg-import-rules-cloudflare.sh** Create VPC Security Group with Cloudflare IP ranges
- **vpc-sg-import-rules-cloudfront.sh** Create VPC Security Group with CloudFront IP ranges
- **vpc-sg-import-rules-pingdom.sh** Create VPC Security Group with Pingdom probe server IP ranges
- **vpc-sg-update-rules-pingdom.sh** Update existing AWS VPC Security Groups with new IP rules to allow access to each Pingdom probe server IP at the port specified
- **waf-import-ip-set-pingdom.sh** Import list of current Pingdom probe server IPs into AWS WAF IP Set
