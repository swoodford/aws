![aws](/images/aws.png)
=======
### [https://github.com/swoodford/aws](https://github.com/swoodford/aws)


A collection of bash shell scripts for automating various tasks with [Amazon Web Services](https://aws.amazon.com/).

Most require the [AWS CLI](https://aws.amazon.com/cli/) and [jq](https://stedolan.github.io/jq/)

[![Build Status](https://travis-ci.org/swoodford/aws.svg?branch=master)](https://travis-ci.org/swoodford/aws)

![cloudfront](/images/cf.png)
- **[cloudfront-invalidation-status.sh](cloudfront-invalidation-status.sh)** Checks CloudFront Distributions for cache invalidation status to complete

![cloudwatch](/images/cw.png)
- **[cloudwatch-create-alarms.sh](cloudwatch-create-alarms.sh)** Create AWS CloudWatch alarms for EC2, RDS, Load Balancer environments

![ec2](/images/ec2.png)
- **[ec2-associate-elastic-ip.sh](ec2-associate-elastic-ip.sh)** Reassign a previously allocated Elastic IP to the instance which runs this script
- **[ec2-classic-import-network-acl.sh](ec2-classic-import-network-acl.sh)** Import CIDR IP list to AWS EC2 Classic ACL rules and deny access
- **[ec2-ebs-create-snapshots.sh](ec2-ebs-create-snapshots.sh)** Create a snapshot of each EC2 EBS volume that is tagged with the backup flag
- **[ec2-ebs-delete-snapshots.sh](ec2-ebs-delete-snapshots.sh)** Deletes snapshots for each EC2 EBS volume that is tagged with the backup flag and matches the specified date
- **[ec2-elb-export-template.sh](ec2-elb-export-template.sh)** Export an ELB to a JSON template file for version control, duplication or recreation
- **[ec2-elb-upload-ssl-cert.sh](ec2-elb-upload-ssl-cert.sh)** Upload an SSL Certificate to AWS for use in setting up an ELB

![elastic beanstalk](/images/eb.png)
- **[elastic-beanstalk-set-hostname-within-instance.sh](elastic-beanstalk-set-hostname-within-instance.sh)** Set the hostname on Elastic Beanstalk servers from within the instance with their EB environment name and public IP address
- **[elastic-beanstalk-update-hostnames.sh](elastic-beanstalk-update-hostnames.sh)** Updates the hostname on Elastic Beanstalk servers with their environment name and IP address

![iam](/images/iam.png)
- **[iam-create-s3-users.sh](iam-create-s3-users.sh)** Create the S3 IAM user, generate IAM keys, add to IAM group, generate user policy

![route53](/images/route53.png)
- **[route53-export-zones.sh](route53-export-zones.sh)** Uses [cli53](https://github.com/barnybug/cli53) to export the zone file for each Hosted Zone domain in Route 53

![s3](/images/s3.png)
- **[s3-buckets-local-backup.sh](s3-buckets-local-backup.sh)** Backup all contents of all S3 buckets in AWS account locally
- **[s3-buckets-file-size-s3api.sh](s3-buckets-file-size-s3api.sh)** Count total size of all data stored in all S3 buckets using [s3api](https://docs.aws.amazon.com/cli/latest/reference/s3api/index.html) (fastest)
- **[s3-buckets-file-size-s3cmd.sh](s3-buckets-file-size-s3cmd.sh)** Count total size of all data stored in all S3 buckets using [s3cmd](https://github.com/s3tools/s3cmd) (slower)
- **[s3-buckets-security-audit.sh](s3-buckets-security-audit.sh)** Export S3 bucket ACL, CORS, Policy and Website as JSON for auditing security of all buckets
- **[s3-fix-content-type-metadata.sh](s3-fix-content-type-metadata.sh)** Safely fix invalid content-type metadata on AWS S3 bucket website assets for some common filetypes
- **[s3-openbucketpolicy.sh](s3-openbucketpolicy.sh)** Set an S3 bucket policy to allow GetObject requests from any IP address
- **[s3-restrictbucketpolicy.sh](s3-restrictbucketpolicy.sh)** Set an S3 bucket policy to only allow GetObject requests from an IP whitelist file named iplist
- **[s3-setup-buckets.sh](s3-setup-buckets.sh)** Create S3 buckets, set CORS config and tag bucket with client name

![vpc](/images/vpc.png)
- **[vpc-eni-monitor.sh](vpc-eni-monitor.sh)** Generate an HTML page to monitor the number of AWS VPC Elastic Network Interfaces currently in use and upload it to an S3 bucket website
- **[vpc-sg-import-rules.sh](vpc-sg-import-rules.sh)** Create an AWS VPC Security Group with rules to allow access to each IP at the port specified
- **[vpc-sg-import-rules-cloudflare.sh](vpc-sg-import-rules-cloudflare.sh)** Create VPC Security Group with [Cloudflare](https://www.cloudflare.com/) IP ranges
- **[vpc-sg-import-rules-cloudfront.sh](vpc-sg-import-rules-cloudfront.sh)** Create VPC Security Group with CloudFront IP ranges
- **[vpc-sg-import-rules-pingdom.sh](vpc-sg-import-rules-pingdom.sh)** Create VPC Security Group with [Pingdom](https://www.pingdom.com/) probe server IP ranges
- **[vpc-sg-update-rules-pingdom.sh](vpc-sg-update-rules-pingdom.sh)** Update existing AWS VPC Security Groups with new IP rules to allow access to each [Pingdom](https://www.pingdom.com/) probe server IP at the port specified

![waf](/images/waf.png)
- **[waf-export-ip-sets.sh](waf-export-ip-sets.sh)** Export each AWS WAF IP set match condition to a JSON file for backup
- **[waf-import-ip-set-facebook.sh](waf-import-ip-set-facebook.sh)** Import list of current [Facebook](https://www.facebook.com/) crawl server IPs into AWS WAF IP Set - work in progress, currently not possible to execute
- **[waf-web-acl-pingdom.sh](waf-web-acl-pingdom.sh)** Manage WAF Web ACL to allow current [Pingdom](https://www.pingdom.com/) probe server IPs by creating or updating AWS WAF IP Addresses Set, Rules and Web ACLs

![other tools](/images/gears.png)
- **[convert-iplist-cidr-json-array.sh](convert-iplist-cidr-json-array.sh)** Converts an IPv4 iplist to CIDR block notation and JSON array format, sorting and de-duplicating IPs
- **[install-awscli.sh](install-awscli.sh)** Install and configure AWS CLI
- **[install-s3cmd.sh](install-s3cmd.sh)** Install and setup [s3cmd](https://github.com/s3tools/s3cmd) from the GitHub Repo
- **[terraform-redact-iam-secrets.sh](terraform-redact-iam-secrets.sh)** Replaces AWS IAM Secret Keys and IAM SES SMTP Passwords with "REDACTED" in [Terraform](https://www.terraform.io/) state files


