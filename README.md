<h1 align="center"><img src="/images/aws.png" alt="AWS" width=130 height=130></h1>

<h2 align="center">A collection of bash shell scripts for automating various tasks with <a href="https://aws.amazon.com/" target="_blank">Amazon Web Services</a> using the <a href="https://aws.amazon.com/cli/" target="_blank">AWS CLI</a> and <a href="https://stedolan.github.io/jq/" target="_blank">jq</a>.</h2>

[![Build Status](https://travis-ci.org/swoodford/aws.svg?branch=master)](https://travis-ci.org/swoodford/aws)

#### [https://github.com/swoodford/aws](https://github.com/swoodford/aws)

## Table of contents

- [Getting Started](#getting-started)
- [What's Included](#tools-included-in-this-repo)
- [Bugs and Feature Requests](#bugs-and-feature-requests)
- [Creator](#creator)
- [Copyright and License](#copyright-and-license)

## Getting Started

### What is the AWS Command Line Interface?

The AWS CLI is an open source tool built on top of the AWS SDK for Python (Boto) that provides commands for interacting with AWS services.

[Installing the AWS Command Line Interface](https://docs.aws.amazon.com/cli/latest/userguide/installing.html)

**Requirements:**
* Python 2 version 2.6.5+ or Python 3 version 3.3+
* macOS, Linux, or Unix

If you already have pip and a supported version of Python, you can install the AWS CLI with the following command:

`$ pip install awscli --upgrade --user`

[Configuring the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)

For general use, the aws configure command is the fastest way to set up your AWS CLI installation.

`$ aws configure`

The AWS CLI will prompt you for four pieces of information. AWS Access Key ID and AWS Secret Access Key are your account credentials.

[Named Profiles](https://docs.aws.amazon.com/cli/latest/userguide/cli-multiple-profiles.html)

The AWS CLI supports named profiles stored in the config and credentials files. You can configure additional profiles by using `aws configure` with the `--profile option` or by adding entries to the config and credentials files.

`$ aws configure --profile example`

### What is jq?

jq is a lightweight and flexible command-line JSON processor.

[Installing jq](https://stedolan.github.io/jq/download/)

OS X: Use [Homebrew](https://brew.sh/) to install jq:

`$ brew install jq`

Linux: jq is in the official [Amazon Linux AMI](https://aws.amazon.com/amazon-linux-ami/2017.03-packages/#j), [Debian](https://packages.debian.org/jq) and [Ubuntu](http://packages.ubuntu.com/jq) repositories.

Amazon Linux AMI, RHEL, CentOS:

`$ sudo yum install jq`

Debian/Ubuntu:

`$ sudo apt-get install jq`


## Tools included in this repo:

![cloudfront](/images/cf.png)
#### CloudFront
- **[cloudfront-invalidation-status.sh](cloudfront-invalidation-status.sh)** Checks CloudFront Distributions for cache invalidation status to complete

![cloudwatch](/images/cw.png)
#### CloudWatch
- **[cloudwatch-create-alarms.sh](cloudwatch-create-alarms.sh)** Create AWS CloudWatch alarms for EC2, RDS, Load Balancer environments
- **[cloudwatch-logs-retention-policy.sh](cloudwatch-logs-retention-policy.sh)** Set CloudWatch Logs Retention Policy for all log groups in all regions available

![ec2](/images/ec2.png)
#### EC2
- **[ec2-associate-elastic-ip.sh](ec2-associate-elastic-ip.sh)** Reassign a previously allocated Elastic IP to the instance which runs this script
- **[ec2-classic-import-network-acl.sh](ec2-classic-import-network-acl.sh)** Import CIDR IP list to AWS EC2 Classic ACL rules and deny access
- **[ec2-ebs-create-snapshots.sh](ec2-ebs-create-snapshots.sh)** Create a snapshot of each EC2 EBS volume that is tagged with the backup flag
- **[ec2-ebs-delete-snapshots.sh](ec2-ebs-delete-snapshots.sh)** Deletes snapshots for each EC2 EBS volume that is tagged with the backup flag and matches the specified date
- **[ec2-elb-export-template.sh](ec2-elb-export-template.sh)** Export an ELB to a JSON template file for version control, duplication or recreation
- **[ec2-elb-upload-ssl-cert.sh](ec2-elb-upload-ssl-cert.sh)** Upload an SSL Certificate to AWS for use in setting up an ELB

![elastic beanstalk](/images/eb.png)
#### Elastic Beanstalk
- **[elastic-beanstalk-set-hostname-within-instance.sh](elastic-beanstalk-set-hostname-within-instance.sh)** Set the hostname on Elastic Beanstalk servers from within the instance with their EB environment name and public IP address
- **[elastic-beanstalk-update-hostnames.sh](elastic-beanstalk-update-hostnames.sh)** Updates the hostname on Elastic Beanstalk servers with their environment name and IP address

![iam](/images/iam.png)
#### IAM
- **[iam-create-s3-users.sh](iam-create-s3-users.sh)** Create the S3 IAM user, generate IAM keys, add to IAM group, generate user policy

![route53](/images/route53.png)
#### Route53
- **[route53-export-zones.sh](route53-export-zones.sh)** Uses [cli53](https://github.com/barnybug/cli53) to export the zone file for each Hosted Zone domain in Route 53

![s3](/images/s3.png)
#### S3
- **[s3-buckets-file-size-s3api.sh](s3-buckets-file-size-s3api.sh)** Count total size of all data stored in all S3 buckets using [s3api](https://docs.aws.amazon.com/cli/latest/reference/s3api/index.html) (fastest)
- **[s3-buckets-file-size-s3cmd.sh](s3-buckets-file-size-s3cmd.sh)** Count total size of all data stored in all S3 buckets using [s3cmd](https://github.com/s3tools/s3cmd) (slower)
- **[s3-buckets-local-backup.sh](s3-buckets-local-backup.sh)** Backup all contents of all S3 buckets in AWS account locally
- **[s3-buckets-security-audit.sh](s3-buckets-security-audit.sh)** Export S3 bucket ACL, CORS, Policy and Website as JSON for auditing security of all buckets
- **[s3-fix-content-type-metadata.sh](s3-fix-content-type-metadata.sh)** Safely fix invalid content-type metadata on AWS S3 bucket website assets for some common filetypes
- **[s3-openbucketpolicy.sh](s3-openbucketpolicy.sh)** Set an S3 bucket policy to allow GetObject requests from any IP address
- **[s3-restrictbucketpolicy.sh](s3-restrictbucketpolicy.sh)** Set an S3 bucket policy to only allow GetObject requests from an IP whitelist file named iplist
- **[s3-setup-buckets.sh](s3-setup-buckets.sh)** Create S3 buckets, set CORS config and tag bucket with client name

![vpc](/images/vpc.png)
#### VPC
- **[vpc-eni-monitor.sh](vpc-eni-monitor.sh)** Generate an HTML page to monitor the number of AWS VPC Elastic Network Interfaces currently in use and upload it to an S3 bucket website
- **[vpc-sg-import-rules.sh](vpc-sg-import-rules.sh)** Create an AWS VPC Security Group with rules to allow access to each IP at the port specified
- **[vpc-sg-import-rules-cloudflare.sh](vpc-sg-import-rules-cloudflare.sh)** Create VPC Security Group with [Cloudflare](https://www.cloudflare.com/) IP ranges
- **[vpc-sg-import-rules-cloudfront.sh](vpc-sg-import-rules-cloudfront.sh)** Create VPC Security Group with CloudFront IP ranges
- **[vpc-sg-import-rules-pingdom.sh](vpc-sg-import-rules-pingdom.sh)** Create VPC Security Group with [Pingdom](https://www.pingdom.com/) probe server IP ranges
- **[vpc-sg-update-rules-pingdom.sh](vpc-sg-update-rules-pingdom.sh)** Update existing AWS VPC Security Groups with new IP rules to allow access to each [Pingdom](https://www.pingdom.com/) probe server IP at the port specified

![waf](/images/waf.png)
#### WAF
- **[waf-export-ip-sets.sh](waf-export-ip-sets.sh)** Export each AWS WAF IP set match condition to a JSON file for backup
- **[waf-import-ip-set-facebook.sh](waf-import-ip-set-facebook.sh)** Import list of current [Facebook](https://www.facebook.com/) crawl server IPs into AWS WAF IP Set - work in progress, currently not possible to execute
- **[waf-web-acl-pingdom.sh](waf-web-acl-pingdom.sh)** Manage WAF Web ACL to allow current [Pingdom](https://www.pingdom.com/) probe server IPs by creating or updating AWS WAF IP Addresses Set, Rules and Web ACLs

![other tools](/images/gears.png)
#### Other Tools
- **[convert-iplist-cidr-json-array.sh](convert-iplist-cidr-json-array.sh)** Converts an IPv4 iplist to CIDR block notation and JSON array format, sorting and de-duplicating IPs
- **[install-awscli.sh](install-awscli.sh)** Install and configure AWS CLI
- **[install-s3cmd.sh](install-s3cmd.sh)** Install and setup [s3cmd](https://github.com/s3tools/s3cmd) from the GitHub Repo
- **[terraform-redact-iam-secrets.sh](terraform-redact-iam-secrets.sh)** Replaces AWS IAM Secret Keys and IAM SES SMTP Passwords with "REDACTED" in [Terraform](https://www.terraform.io/) state files

## Bugs and feature requests
Have a bug or a feature request? The [issue tracker](https://github.com/swoodford/aws/issues) is the preferred channel for bug reports, feature requests and submitting pull requests.
If your problem or idea is not addressed yet, [please open a new issue](https://github.com/swoodford/aws/issues/new).

## Creator

**Shawn Woodford**

- <https://shawnwoodford.com>
- <https://github.com/swoodford>

## Copyright and License

Code and Documentation Copyright 2012-2018 Shawn Woodford. Code released under the [Apache License 2.0](https://github.com/swoodford/aws/blob/master/LICENSE).
