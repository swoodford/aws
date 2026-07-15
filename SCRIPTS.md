# AWS CLI Scripts - Quick Reference

Fast lookup guide for all scripts with command syntax and output.

---

## EC2 Scripts

### ec2-ami-encrypted-ebs-boot-volume.sh
Create AMI with encrypted boot volume

```bash
./ec2-ami-encrypted-ebs-boot-volume.sh
```

**Variables to set:**
- `AMITYPE="amzn-ami-hvm-x86_64-gp2"`
- `Region="us-east-1"`

**Creates:** Encrypted AMI ready for production use

---

### ec2-associate-elastic-ip.sh
Auto-assign Elastic IP to instance (for ASG)

```bash
# Add to EC2 Launch Template user data
curl -s https://raw.githubusercontent.com/kurupoo/aws-cli/master/ec2-associate-elastic-ip.sh | bash
```

**Requires:** IAM role with `ec2:AssociateAddress` permission

**Use case:** Auto Scaling Group with fixed IP

---

### ec2-classic-import-network-acl.sh
Import IP blacklist to EC2 Classic ACL

```bash
./ec2-classic-import-network-acl.sh
```

**Variables:** `NETWORKACLID`, `IPBLACKLISTFILE`

**Note:** EC2-Classic is deprecated

---

### ec2-ebs-create-snapshots.sh
Create snapshots from tagged volumes

```bash
# Tag volumes for backup
aws ec2 create-tags --resources vol-12345678 --tags Key=Backup,Value=1

# Run snapshot script
./ec2-ebs-create-snapshots.sh

# Add to cron
0 2 * * * /path/to/ec2-ebs-create-snapshots.sh
```

**Looks for:** Volumes tagged with `Backup=1`

---

### ec2-ebs-delete-snapshots.sh
Delete snapshots by date

```bash
./ec2-ebs-delete-snapshots.sh
```

**Deletes:** Snapshots tagged `SnapshotCreation=Automatic` matching specified date

---

### ec2-elb-export-template.sh
Export ELB configuration to JSON

```bash
./ec2-elb-export-template.sh my-load-balancer

# Output: my-load-balancer.json
git add my-load-balancer.json
git commit -m "Backup ELB config"
```

**Use case:** Version control load balancer configs

---

### ec2-elb-upload-ssl-cert.sh
Upload SSL certificate to IAM

```bash
./ec2-elb-upload-ssl-cert.sh

# Provide:
# - Private key path
# - Certificate path
# - Certificate chain path
```

**Uploads to:** AWS IAM certificate store

---

## S3 Scripts

### s3-buckets-security-audit.sh
Export bucket configurations for audit

```bash
./s3-buckets-security-audit.sh

# Output directory: s3-bucket-audit-YYYY-MM-DD/
# Contains JSON files for:
# - ACL
# - CORS
# - Bucket policy
# - Website config
```

**Use case:** Compliance reporting

---

### s3-buckets-total-file-size.sh
Calculate total S3 bucket sizes

```bash
# Size of all buckets
./s3-buckets-total-file-size.sh

# Size of specific bucket
./s3-buckets-total-file-size.sh my-bucket
```

**Output:**
```
Bucket: my-bucket         Size: 2.5 TB
Bucket: logs-bucket       Size: 45.3 GB
Total:                    2.57 TB
```

---

### s3-buckets-local-backup.sh
Backup all buckets locally

```bash
./s3-buckets-local-backup.sh

# Creates: ./backups/bucket-name/
```

**Note:** Uses `aws s3 sync`, respects existing files

---

### s3-buckets-file-size-s3cmd.sh
Calculate size using s3cmd (deprecated)

```bash
./s3-buckets-file-size-s3cmd.sh
```

**Deprecated:** Use `s3-buckets-total-file-size.sh` instead

---

### s3-fix-content-type-metadata.sh
Fix content-type headers on assets

```bash
./s3-fix-content-type-metadata.sh my-website-bucket

# Fixes:
# .css  -> text/css
# .js   -> application/javascript
# .jpg  -> image/jpeg
# .png  -> image/png
```

---

### s3-open-bucket-policy.sh
Allow public access from any IP

```bash
./s3-open-bucket-policy.sh my-public-bucket

# Sets policy to allow:
# s3:GetObject from Principal: "*"
```

**Use case:** Public website hosting

---

### s3-restrict-bucket-policy.sh
Restrict bucket to IP whitelist

```bash
# Create iplist file:
echo "203.0.113.0/24" > iplist
echo "198.51.100.0/24" >> iplist

./s3-restrict-bucket-policy.sh my-bucket

# Result: Only these IPs can access
```

**Use case:** Private bucket with allowlist

---

### s3-remove-glacier-objects.sh
Delete Glacier-stored objects

```bash
./s3-remove-glacier-objects.sh my-archive-bucket

# Removes all objects in GLACIER storage class
```

**Use case:** Clean up archived data

---

### s3-set-cache-control-max-age.sh
Set cache headers on assets

```bash
./s3-set-cache-control-max-age.sh my-website-bucket

# Sets: Cache-Control: public, max-age=2592000 (30 days)
```

**Use case:** CDN cache optimization

---

### s3-setup-buckets.sh
Create bucket with CORS

```bash
./s3-setup-buckets.sh my-new-bucket

# Creates bucket
# Enables CORS for cross-origin requests
# Tags bucket
```

---

## CloudWatch Scripts

### cloudwatch-create-alarms.sh
Create custom CloudWatch alarms

```bash
./cloudwatch-create-alarms.sh

# Creates alarms for:
# - CPU utilization
# - Network in/out
# - Disk usage
```

---

### cloudwatch-create-alarms-statuscheckfailed.sh
Auto-recover unhealthy EC2 instances

```bash
./cloudwatch-create-alarms-statuscheckfailed.sh

# For all running instances, creates:
# - StatusCheckFailed alarm
# - Auto-recovery action
```

**Use case:** High availability

---

### cloudwatch-create-alarms-unhealthyhost.sh
Alert on unhealthy load balancer targets

```bash
./cloudwatch-create-alarms-unhealthyhost.sh

# Creates alarms for all ELBs/ALBs
```

---

### cloudwatch-logs-cleanup.sh
Delete old log groups by retention policy

```bash
./cloudwatch-logs-cleanup.sh

# Deletes log groups with LastEventTime older than retention policy
```

---

### cloudwatch-logs-delete-groups.sh
Quickly delete log groups by prefix

```bash
./cloudwatch-logs-delete-groups.sh

# Variables: LogGroupPrefix
```

---

### cloudwatch-logs-retention-policy.sh
Set retention for all log groups

```bash
./cloudwatch-logs-retention-policy.sh

# Variables: RetentionInDays (1,3,5,7,14,30,60,90,120,150,180,365...)
```

**Cost Optimization:** 30 days reduces storage costs

---

### cloudwatch-logs-search.sh
Search logs across all regions

```bash
./cloudwatch-logs-search.sh

# Variables:
# - LogGroupName
# - FilterPattern (e.g., "ERROR")
# - Region
```

---

## CloudFront Scripts

### cloudfront-inprogress-status.sh
Monitor distribution deployment status

```bash
./cloudfront-inprogress-status.sh

# Checks all distributions for In-Progress status
# Alerts when deployment completes
```

---

### cloudfront-invalidation-status.sh
Monitor cache invalidation

```bash
./cloudfront-invalidation-status.sh

# Checks invalidation status
# Alerts when complete
```

**Use case:** Confirm cache cleared before announcing changes

---

## Route 53 Scripts

### route53-export-zones.sh
Export DNS zones for version control

```bash
./route53-export-zones.sh

# Exports: example.com.zone, api.example.com.zone, ...
```

**Requires:** cli53 tool

---

### route53-record-set.sh
Manage Route 53 records

```bash
./route53-record-set.sh

# Create/update/delete DNS records
```

---

## Elastic Beanstalk Scripts

### elastic-beanstalk-set-hostname-within-instance.sh
Set hostname from within EB instance

```bash
# Add to .ebextensions/01-set-hostname.config
commands:
  00_set_hostname:
    command: /opt/elasticbeanstalk/hooks/appdeploy/post/01_set_hostname.sh
```

**Result:** Hostname = `{EB_ENV_NAME}-{PUBLIC_IP}`

---

### elastic-beanstalk-update-hostnames.sh
Update EB instance hostnames from CLI

```bash
./elastic-beanstalk-update-hostnames.sh
```

---

## IAM Scripts

### iam-create-s3-users.sh
Create S3-only IAM users

```bash
./iam-create-s3-users.sh partner-name

# Creates:
# - IAM user: s3-partner-name
# - IAM group: s3-users
# - Access keys
# - S3 policy
```

---

## VPC Scripts

### vpc-eni-monitor.sh
Generate ENI usage dashboard

```bash
./vpc-eni-monitor.sh

# Generates HTML dashboard
# Uploads to S3 bucket website
```

---

### vpc-sg-import-rules.sh
Create security group from IP list

```bash
echo "203.0.113.0/24" > iplist

./vpc-sg-import-rules.sh

# Variables: GROUPNAME, VPCID, PROTO, PORT
```

---

### vpc-sg-import-rules-cloudflare.sh
Create SG with Cloudflare IPs

```bash
./vpc-sg-import-rules-cloudflare.sh

# Fetches latest Cloudflare IP ranges
# Creates security group rules
```

**Use case:** Allow only Cloudflare proxy traffic

---

### vpc-sg-import-rules-cloudfront.sh
Create SG with CloudFront IPs

```bash
./vpc-sg-import-rules-cloudfront.sh

# Creates rules for CloudFront edge locations
```

---

### vpc-sg-import-rules-pingdom.sh
Create SG for Pingdom health checks

```bash
./vpc-sg-import-rules-pingdom.sh

# Variables: VPCID, PROTO, PORT
# Creates multiple groups if needed (limits)
```

---

### vpc-sg-merge-groups.sh
Merge two security groups

```bash
./vpc-sg-merge-groups.sh

# Combines rules from two groups into one
# Must be in same VPC, total rules <= 50
```

---

### vpc-sg-rename-group.sh
Rename security group

```bash
./vpc-sg-rename-group.sh

# Creates new group with existing rules
# Old group remains (manual cleanup)
```

---

## WAF Scripts

### waf-export-ip-sets.sh
Export WAF IP sets for backup

```bash
./waf-export-ip-sets.sh

# Exports to JSON files
```

---

### waf-import-ip-set-facebook.sh
Import Facebook crawler IPs (deprecated)

```bash
./waf-import-ip-set-facebook.sh
```

**Note:** Facebook uses CIDR blocks outside AWS WAF /8,/16,/24,/32 range

---

### waf-web-acl-pingdom.sh
Manage WAF rules for Pingdom

```bash
./waf-web-acl-pingdom.sh

# Creates/updates:
# - IP set with Pingdom IPs
# - WAF rule
# - Web ACL
```

---

### wafv2-web-acl-pingdom.sh
WAFv2 variant of Pingdom rules

```bash
./wafv2-web-acl-pingdom.sh

# For AWS WAFv2 (newer)
```

---

## Utility Scripts

### convert-iplist-cidr-json-array.sh
Convert IPs to CIDR and JSON

```bash
./convert-iplist-cidr-json-array.sh

# Input: iplist (one IP per line)
# Output: JSON array with CIDR blocks
```

---

### terraform-redact-iam-secrets.sh
Redact credentials from Terraform state

```bash
./terraform-redact-iam-secrets.sh terraform.tfstate

# Replaces IAM keys with "REDACTED"
# Safe to commit to git
```

**Better:** Use S3 backend for Terraform

---

### install-awscli.sh
Install AWS CLI

```bash
./install-awscli.sh
```

---

### install-s3cmd.sh
Install s3cmd tool

```bash
./install-s3cmd.sh
```

---

## Installation Commands

### Set Executable
```bash
chmod +x *.sh
```

### Add to PATH
```bash
export PATH=$PATH:/path/to/aws-cli
```

### Run from Any Directory
```bash
~/aws-cli/ec2-ebs-create-snapshots.sh
```

---

## Environment Variables

```bash
# AWS CLI profile
export AWS_PROFILE=production

# AWS region
export AWS_DEFAULT_REGION=us-east-1

# Debug output
export DEBUGMODE=1

# Dry run (some scripts)
export DRY_RUN=1
```

---

## Common Errors & Solutions

| Error | Solution |
|-------|----------|
| `aws: command not found` | Install AWS CLI: `pip install awscli` |
| `jq: command not found` | Install jq: `brew install jq` |
| `Unable to locate credentials` | Run `aws configure` |
| `Not authorized to perform` | Check IAM permissions |
| `InvalidParameterValue` | Verify AWS region and parameter values |

---

**Last Updated**: January 2024
