# AWS CLI Scripts: Use Cases & Examples

This guide provides detailed use cases for all AWS CLI scripts in this repository, organized by AWS service.

---

## Table of Contents

1. [EC2 - Elastic Compute Cloud](#ec2)
2. [S3 - Simple Storage Service](#s3)
3. [CloudWatch - Monitoring & Logging](#cloudwatch)
4. [VPC & Security Groups](#vpc)
5. [CloudFront - Content Delivery](#cloudfront)
6. [Route 53 - DNS](#route53)
7. [Elastic Beanstalk](#elasticbeanstalk)
8. [IAM - Identity & Access](#iam)
9. [WAF - Web Application Firewall](#waf)
10. [Utilities](#utilities)

---

## EC2 - Elastic Compute Cloud

### Creating Encrypted AMIs

**Script**: `ec2-ami-encrypted-ebs-boot-volume.sh`

**Purpose**: Creates an AMI with an encrypted EBS boot volume from the latest Amazon Linux 2 AMI.

**Use Case**: Security compliance requires all EC2 instances to boot from encrypted volumes. This script automates the process of creating a compliant base AMI.

**Example**:
```bash
./ec2-ami-encrypted-ebs-boot-volume.sh
```

**Key AWS CLI Commands**:
```bash
# Query latest Amazon Linux AMI
aws ssm get-parameters \
  --names /aws/service/ami-amazon-linux-latest/amzn-ami-hvm-x86_64-gp2

# Copy AMI with encryption
aws ec2 copy-image \
  --source-region us-east-1 \
  --source-image-id ami-12345678 \
  --region us-west-2 \
  --encrypted
```

**Related AWS Docs**: [Encrypted EBS Boot Volumes](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/CopyingAMIs.html)

---

### EBS Snapshots Management

**Scripts**:
- `ec2-ebs-create-snapshots.sh` - Create snapshots from tagged volumes
- `ec2-ebs-delete-snapshots.sh` - Delete snapshots by date

**Purpose**: Automate backup and retention policies for EBS volumes.

**Use Case**: Implement automatic daily backups of EC2 volumes and clean up old snapshots per retention policy.

**Example - Create Snapshots**:
```bash
# Create snapshots for all volumes tagged with Backup=1
./ec2-ebs-create-snapshots.sh

# This will query tagged volumes:
aws ec2 describe-volumes \
  --filters "Name=tag:Backup,Values=1"
```

**Example - Delete Old Snapshots**:
```bash
# Delete snapshots created on a specific date
./ec2-ebs-delete-snapshots.sh

# Query snapshots with automation tag:
aws ec2 describe-snapshots \
  --filters "Name=tag:SnapshotCreation,Values=Automatic"
```

**Recommended Tagging Strategy**:
```bash
# Tag volumes for backup
aws ec2 create-tags \
  --resources vol-12345678 \
  --tags Key=Backup,Value=1

# Tag snapshots with creation timestamp
aws ec2 create-tags \
  --resources snap-12345678 \
  --tags Key=SnapshotCreation,Value=Automatic
```

---

### Elastic IP Management

**Script**: `ec2-associate-elastic-ip.sh`

**Purpose**: Auto-assign a previously allocated Elastic IP to EC2 instances in an Auto Scaling Group.

**Use Case**: When an instance in an ASG fails and a replacement spins up, automatically reassign the same EIP to maintain DNS/traffic routing.

**Example - User Data Script**:
```bash
# Add to EC2 Launch Template user data:
#!/bin/bash
curl -s https://raw.githubusercontent.com/your-repo/ec2-associate-elastic-ip.sh | bash
```

**Example - Allocate EIP**:
```bash
# Pre-allocate EIP
aws ec2 allocate-address --domain vpc
# Output: AllocationId: eipalloc-12345678

# Tag for easy identification
aws ec2 create-tags \
  --resources eipalloc-12345678 \
  --tags Key=Environment,Value=production
```

**Key AWS CLI Commands**:
```bash
aws ec2 associate-address \
  --instance-id i-12345678 \
  --allocation-id eipalloc-12345678
```

**Required IAM Permission**:
```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:AssociateAddress",
    "ec2:DescribeAddresses"
  ],
  "Resource": "*"
}
```

---

### Load Balancer (ELB) Management

**Scripts**:
- `ec2-elb-export-template.sh` - Export ELB configuration
- `ec2-elb-upload-ssl-cert.sh` - Upload SSL certificates

**Purpose**: Version control ELB configurations and manage SSL certificates.

**Use Case**: Disaster recovery - export ELB configs to JSON, store in git, and recreate quickly if needed.

**Example - Export ELB**:
```bash
./ec2-elb-export-template.sh my-load-balancer

# Queries ELB configuration:
aws elb describe-load-balancers \
  --load-balancer-names my-load-balancer
```

**Example - Upload SSL Certificate**:
```bash
./ec2-elb-upload-ssl-cert.sh \
  --cert-path ./my-cert.pem \
  --key-path ./my-key.pem \
  --chain-path ./ca-chain.pem

# Equivalent AWS CLI:
aws iam upload-server-certificate \
  --server-certificate-name my-cert \
  --certificate-body file://my-cert.pem \
  --private-key file://my-key.pem \
  --certificate-chain file://ca-chain.pem
```

---

## S3 - Simple Storage Service

### S3 Security Audit

**Script**: `s3-buckets-security-audit.sh`

**Purpose**: Export ACL, CORS, bucket policies, and website configs for all S3 buckets.

**Use Case**: Compliance audit - Generate snapshots of all bucket configurations, store in version control, and detect unauthorized changes.

**Example**:
```bash
./s3-buckets-security-audit.sh

# Creates s3-bucket-audit-2024-01-15/ directory with one JSON file per bucket
# Example output:
# s3-bucket-audit-2024-01-15/
# ├── my-app-bucket.json
# ├── backup-bucket.json
# └── logs-bucket.json
```

**Included in Audit**:
```bash
# Bucket ACL
aws s3api get-bucket-acl --bucket my-bucket

# Bucket Policy
aws s3api get-bucket-policy --bucket my-bucket

# CORS Configuration
aws s3api get-bucket-cors --bucket my-bucket

# Website Configuration
aws s3api get-bucket-website --bucket my-bucket
```

**Use in CI/CD**:
```bash
# Run audit, commit to git, detect drift
./s3-buckets-security-audit.sh
git add s3-bucket-audit-*/
git commit -m "S3 security audit $(date +%Y-%m-%d)"
```

---

### S3 Bucket Size Analysis

**Scripts**:
- `s3-buckets-total-file-size.sh` - Get total size of all buckets
- `s3-buckets-file-size-s3cmd.sh` - Alternative using s3cmd (deprecated)

**Purpose**: Calculate storage costs and identify large buckets.

**Use Case**: Cost optimization - Find which S3 buckets consume the most storage.

**Example**:
```bash
# Get size of all S3 buckets
./s3-buckets-total-file-size.sh

# Output:
# Bucket: my-app-bucket      Size: 2.5 TB
# Bucket: backup-bucket      Size: 45.3 GB
# Bucket: logs-bucket        Size: 12.8 GB
# Total:                      Size: 2.57 TB
```

**Key AWS CLI Commands**:
```bash
# List objects with storage class info
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --query 'Contents[].{Key:Key,Size:Size,StorageClass:StorageClass}'

# Use CloudWatch metrics for near-real-time data
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name BucketSizeBytes \
  --dimensions Name=BucketName,Value=my-bucket \
               Name=StorageType,Value=StandardStorage \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-31T23:59:59Z \
  --period 86400 \
  --statistics Average
```

---

### S3 Backup & Lifecycle

**Scripts**:
- `s3-buckets-local-backup.sh` - Backup all bucket contents locally
- `s3-remove-glacier-objects.sh` - Delete Glacier storage objects

**Purpose**: Backup S3 data locally and manage storage transitions.

**Use Case**: Implement disaster recovery - backup production S3 buckets to local storage.

**Example - Local Backup**:
```bash
./s3-buckets-local-backup.sh

# Uses sync to copy all buckets locally:
aws s3 sync s3://my-bucket ./backups/my-bucket/
aws s3 sync s3://backup-bucket ./backups/backup-bucket/
```

**Example - Remove Glacier Objects**:
```bash
./s3-remove-glacier-objects.sh my-archive-bucket

# Deletes all objects in Glacier storage class:
aws s3api list-objects-v2 \
  --bucket my-archive-bucket \
  --query 'Contents[?StorageClass==`GLACIER`].Key' \
  --output text | xargs -I {} aws s3 rm s3://my-archive-bucket/{}
```

---

### S3 Bucket Policies & Access Control

**Scripts**:
- `s3-open-bucket-policy.sh` - Allow public access from any IP
- `s3-restrict-bucket-policy.sh` - Restrict to IP whitelist
- `s3-setup-buckets.sh` - Create buckets with CORS

**Purpose**: Manage bucket access policies programmatically.

**Use Case**: Website hosting - restrict S3 bucket access to CloudFront distribution only.

**Example - Restrict to IP Whitelist**:
```bash
# Create iplist file with allowed IPs:
echo "203.0.113.0/24" > iplist
echo "198.51.100.0/24" >> iplist

./s3-restrict-bucket-policy.sh my-bucket

# Creates policy allowing only these IPs:
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::my-bucket/*",
    "Condition": {
      "IpAddress": {
        "aws:SourceIp": [
          "203.0.113.0/24",
          "198.51.100.0/24"
        ]
      }
    }
  }]
}
```

**Example - Setup Buckets with CORS**:
```bash
./s3-setup-buckets.sh my-new-bucket

# Creates bucket with CORS for web assets:
aws s3api put-bucket-cors \
  --bucket my-new-bucket \
  --cors-configuration '{
    "CORSRules": [{
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET"],
      "AllowedOrigins": ["*"]
    }]
  }'
```

---

### S3 Metadata Management

**Script**: `s3-fix-content-type-metadata.sh`

**Purpose**: Fix incorrect content-type metadata on S3 bucket website assets.

**Use Case**: Website assets (CSS, JS, images) are returning incorrect MIME types, breaking browser rendering.

**Example**:
```bash
./s3-fix-content-type-metadata.sh my-website-bucket

# Automatically fixes content-types for:
# .css  -> text/css
# .js   -> application/javascript
# .json -> application/json
# .svg  -> image/svg+xml
# .png  -> image/png
# .jpg  -> image/jpeg
# .gif  -> image/gif
# .pdf  -> application/pdf
```

**Key AWS CLI Command**:
```bash
aws s3api copy-object \
  --bucket my-website-bucket \
  --key path/to/style.css \
  --copy-source my-website-bucket/path/to/style.css \
  --content-type text/css \
  --metadata-directive REPLACE
```

---

### S3 Cache Control

**Script**: `s3-set-cache-control-max-age.sh`

**Purpose**: Set Cache-Control headers on S3 bucket assets for optimal CDN caching.

**Use Case**: Website performance - cache static assets on CloudFront for 30 days.

**Example**:
```bash
./s3-set-cache-control-max-age.sh my-website-bucket

# Sets Cache-Control: public, max-age=2592000 (30 days)
# for all website assets

# Equivalent AWS CLI:
aws s3api copy-object \
  --bucket my-website-bucket \
  --key index.html \
  --copy-source my-website-bucket/index.html \
  --cache-control "public, max-age=2592000" \
  --metadata-directive REPLACE
```

---

## CloudWatch - Monitoring & Logging

### CloudWatch Alarms

**Scripts**:
- `cloudwatch-create-alarms.sh` - Create custom CloudWatch alarms
- `cloudwatch-create-alarms-statuscheckfailed.sh` - Auto-recover unhealthy EC2 instances
- `cloudwatch-create-alarms-unhealthyhost.sh` - Monitor ELB health

**Purpose**: Automatically create CloudWatch alarms for monitoring.

**Use Case**: Setup infrastructure monitoring - create alarms for CPU, disk, and ELB health.

**Example - EC2 Status Check Alarms**:
```bash
./cloudwatch-create-alarms-statuscheckfailed.sh

# For all running EC2 instances, creates alarms that:
# 1. Alert when StatusCheckFailed > 0
# 2. Trigger automatic EC2 recovery

# AWS CLI equivalent:
aws cloudwatch put-metric-alarm \
  --alarm-name i-12345678-StatusCheckFailed \
  --alarm-description "Trigger recovery for failed status check" \
  --namespace AWS/EC2 \
  --metric-name StatusCheckFailed_System \
  --dimensions Name=InstanceId,Value=i-12345678 \
  --statistic Maximum \
  --period 60 \
  --threshold 0 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions arn:aws:ec2:us-east-1:123456789012:recover
```

**Example - ELB Unhealthy Host Alarms**:
```bash
./cloudwatch-create-alarms-unhealthyhost.sh

# Creates alarms for all ELBs to alert on unhealthy backends
aws cloudwatch put-metric-alarm \
  --alarm-name my-elb-UnhealthyHostCount \
  --namespace AWS/ELB \
  --metric-name UnhealthyHostCount \
  --dimensions Name=LoadBalancerName,Value=my-elb \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold
```

---

### CloudWatch Logs Management

**Scripts**:
- `cloudwatch-logs-search.sh` - Search log groups for patterns
- `cloudwatch-logs-retention-policy.sh` - Set retention policies
- `cloudwatch-logs-delete-groups.sh` - Delete old log groups
- `cloudwatch-logs-cleanup.sh` - Cleanup based on retention policy

**Purpose**: Manage CloudWatch Logs retention and search.

**Use Case**: Centralized logging - search application logs across all regions, set retention to 30 days to manage costs.

**Example - Search Logs**:
```bash
./cloudwatch-logs-search.sh \
  --log-group "/aws/application" \
  --pattern "ERROR" \
  --region us-east-1

# Queries CloudWatch Logs Insights:
aws logs filter-log-events \
  --log-group-name /aws/application \
  --filter-pattern "ERROR"
```

**Example - Set Retention Policy**:
```bash
./cloudwatch-logs-retention-policy.sh \
  --days 30

# Sets 30-day retention for all log groups:
aws logs put-retention-policy \
  --log-group-name /aws/lambda/my-function \
  --retention-in-days 30
```

**Retention Options**:
- 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653 days

---

## VPC & Security Groups

### Security Group Management

**Scripts**:
- `vpc-sg-import-rules.sh` - Create SG from IP list
- `vpc-sg-merge-groups.sh` - Merge two security groups
- `vpc-sg-rename-group.sh` - Rename security group

**Purpose**: Programmatically manage VPC security group rules.

**Use Case**: Whitelist external service IPs (Pingdom, Cloudflare) to security group rules.

**Example - Import IP Rules**:
```bash
# Create iplist file:
echo "192.0.2.0/24" > iplist
echo "198.51.100.0/24" >> iplist

./vpc-sg-import-rules.sh \
  --group-name "web-servers" \
  --protocol tcp \
  --port 80 \
  --vpc-id vpc-12345678

# Creates security group rules from IP list
# Note: AWS limits ~50 rules per SG, script creates multiple groups if needed
```

**Example - Import Cloudflare IPs**:
```bash
./vpc-sg-import-rules-cloudflare.sh

# Fetches latest Cloudflare IP ranges and creates SG rules
# Useful for allowing Cloudflare proxy traffic only
```

**Example - Import Pingdom IPs**:
```bash
./vpc-sg-import-rules-pingdom.sh

# Creates security group allowing Pingdom health check probes
# Useful for monitoring without exposing to internet
```

---

### VPC ENI Monitoring

**Script**: `vpc-eni-monitor.sh`

**Purpose**: Generate HTML dashboard showing VPC Elastic Network Interface usage.

**Use Case**: Track VPC capacity - some instance types limit ENI count, monitor usage to prevent scaling issues.

**Example**:
```bash
./vpc-eni-monitor.sh

# Generates HTML dashboard and uploads to S3 bucket website
# Shows ENI usage per instance type, per AZ, per VPC
```

**AWS CLI Command**:
```bash
aws ec2 describe-network-interfaces \
  --query 'NetworkInterfaces[].{ENI:NetworkInterfaceId,Status:Status,Type:InterfaceType}'
```

---

## CloudFront - Content Delivery

### CloudFront Invalidation Monitoring

**Scripts**:
- `cloudfront-invalidation-status.sh` - Monitor cache invalidation status
- `cloudfront-inprogress-status.sh` - Monitor distribution deployment

**Purpose**: Monitor CloudFront cache invalidation and deployment status.

**Use Case**: After updating website assets, invalidate CDN cache and wait for completion before announcing.

**Example - Invalidate and Monitor**:
```bash
# Invalidate cache
DISTRIBUTION_ID="E12345ABCD"
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/index.html" "/css/*" "/js/*"

# Monitor status:
./cloudfront-invalidation-status.sh $DISTRIBUTION_ID

# Check deployment progress:
./cloudfront-inprogress-status.sh $DISTRIBUTION_ID
```

**AWS CLI Monitoring**:
```bash
# Check invalidation status
aws cloudfront list-invalidations \
  --distribution-id E12345ABCD

# Check distribution status
aws cloudfront get-distribution \
  --id E12345ABCD \
  --query 'Distribution.Status'
```

---

## Route 53 - DNS

### Route 53 Zone Export

**Script**: `route53-export-zones.sh`

**Purpose**: Export DNS zones for version control using cli53.

**Use Case**: Disaster recovery - version control DNS configurations, restore zones quickly.

**Example**:
```bash
./route53-export-zones.sh

# Exports all Route 53 hosted zones to text files:
# example.com.zone
# api.example.com.zone
# cdn.example.com.zone
```

---

### Route 53 Record Management

**Script**: `route53-record-set.sh`

**Purpose**: Create/update Route 53 record sets programmatically.

**Use Case**: Blue-green deployment - switch traffic between two environments via DNS.

**Example - Failover**:
```bash
# Update A record to point to new environment
aws route53 change-resource-record-sets \
  --hosted-zone-id Z12345ABCD \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.example.com",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [{"Value": "192.0.2.1"}]
      }
    }]
  }'
```

---

## Elastic Beanstalk

### Elastic Beanstalk Hostname Management

**Scripts**:
- `elastic-beanstalk-set-hostname-within-instance.sh` - Set hostname from within instance
- `elastic-beanstalk-update-hostnames.sh` - Update hostnames from outside

**Purpose**: Set meaningful hostnames on EB instances for easier identification.

**Use Case**: Operations - EC2 instances show descriptive names like `prod-app-us-east-1a` instead of generic IPs.

**Example - Set Hostname Within Instance**:
```bash
# Add to .ebextensions/set-hostname.config:
commands:
  00_set_hostname:
    command: /opt/elasticbeanstalk/tasks/bundlelogs.d/set-hostname.sh

# Script sets hostname to: {EB_ENV_NAME}-{PUBLIC_IP}
```

**Example - Update Hostnames from CLI**:
```bash
./elastic-beanstalk-update-hostnames.sh \
  --environment prod-api \
  --region us-east-1
```

---

## IAM - Identity & Access

### S3 User Creation

**Script**: `iam-create-s3-users.sh`

**Purpose**: Create IAM users with S3-only permissions.

**Use Case**: Onboarding - quickly create S3 access credentials for partners/contractors.

**Example**:
```bash
./iam-create-s3-users.sh partner-name

# Creates:
# 1. IAM user: s3-partner-name
# 2. IAM group: s3-users
# 3. Access keys
# 4. S3 inline policy
```

**Generated IAM Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ],
    "Resource": "arn:aws:s3:::partner-bucket/*"
  }]
}
```

---

## WAF - Web Application Firewall

### WAF IP Set Management

**Scripts**:
- `waf-export-ip-sets.sh` - Export WAF IP sets
- `waf-import-ip-set-facebook.sh` - Import Facebook crawler IPs (deprecated)
- `waf-web-acl-pingdom.sh` - Manage Pingdom probe IPs
- `wafv2-web-acl-pingdom.sh` - WAFv2 variant

**Purpose**: Manage WAF IP address sets and allow-lists.

**Use Case**: Allow monitoring service IPs through WAF - whitelist Pingdom health check IPs.

**Example - Setup Pingdom Monitoring**:
```bash
./waf-web-acl-pingdom.sh

# Creates:
# 1. IP Address Set with Pingdom probe IPs
# 2. WAF Rule to allow Pingdom IPs
# 3. Web ACL to associate rule

# AWS CLI equivalent:
aws wafv2 create-ip-set \
  --name pingdom-ips \
  --scope REGIONAL \
  --ip-address-version IPV4 \
  --addresses file://pingdom-ips.txt
```

---

## Utilities

### IP List Conversion

**Script**: `convert-iplist-cidr-json-array.sh`

**Purpose**: Convert IP list to CIDR notation and JSON array format.

**Use Case**: Transform firewall rules to AWS WAF/Security Group compatible format.

**Example**:
```bash
# Input file (iplist):
192.0.2.0
192.0.2.1
192.0.2.2
198.51.100.0
198.51.100.1

./convert-iplist-cidr-json-array.sh

# Output:
[
  "192.0.2.0/24",
  "198.51.100.0/24"
]
```

---

### Terraform State Security

**Script**: `terraform-redact-iam-secrets.sh`

**Purpose**: Redact AWS credentials from Terraform state files before committing to git.

**Use Case**: Prevent accidental credential exposure in version control.

**Example**:
```bash
./terraform-redact-iam-secrets.sh terraform.tfstate

# Replaces:
# - IAM Secret Keys
# - SES SMTP Passwords
# with "REDACTED"

# Safe to commit to git after this
```

**Better Alternative**:
```hcl
# Use Terraform S3 backend instead of local state:
terraform {
  backend "s3" {
    bucket = "my-tf-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}
```

---

## Common Patterns & Best Practices

### 1. AWS CLI Profile Usage

All scripts support AWS CLI profiles:
```bash
export AWS_PROFILE=prod
./ec2-ebs-create-snapshots.sh

# Or:
AWS_PROFILE=staging ./s3-buckets-total-file-size.sh
```

### 2. Region Selection

Scripts typically query all regions, but can be limited:
```bash
# Set region before running:
export AWS_DEFAULT_REGION=us-east-1
./cloudwatch-logs-search.sh --pattern "ERROR"
```

### 3. Error Handling

Scripts include common checks:
```bash
# Check AWS credentials
if ! grep -q aws_access_key_id ~/.aws/credentials; then
  echo "AWS credentials not configured"
  exit 1
fi

# Verify required commands
type -P aws jq curl || exit 1
```

### 4. Debugging

Enable debug output:
```bash
# In script: set DEBUGMODE="1"
# Or via environment:
export DEBUGMODE=1
./ec2-ebs-create-snapshots.sh
```

---

## Setup & Configuration

### Prerequisites

- AWS CLI v2
- jq (JSON query)
- curl (for some scripts)
- Valid AWS credentials (~/.aws/credentials or ~/.aws/config)

### IAM Permissions Required

Different scripts need different permissions:

**EC2 Scripts**:
```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:Describe*",
    "ec2:CreateImage",
    "ec2:CopyImage",
    "ec2:CreateSnapshot",
    "ec2:AssociateAddress",
    "ec2:AuthorizeSecurityGroupIngress"
  ],
  "Resource": "*"
}
```

**S3 Scripts**:
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject",
    "s3:GetBucketPolicy",
    "s3:PutBucketPolicy",
    "s3:GetBucketCors",
    "s3:ListAllMyBuckets"
  ],
  "Resource": "*"
}
```

**CloudWatch Scripts**:
```json
{
  "Effect": "Allow",
  "Action": [
    "cloudwatch:PutMetricAlarm",
    "cloudwatch:DescribeAlarms",
    "logs:FilterLogEvents",
    "logs:PutRetentionPolicy"
  ],
  "Resource": "*"
}
```

---

## Contributing

To add new use cases or examples:

1. Run the relevant script
2. Document the use case in this file
3. Include actual AWS CLI commands used
4. Add expected output/behavior
5. Submit PR with examples

---

## License

See LICENSE.md

---

**Last Updated**: January 2024
