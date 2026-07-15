# AWS CLI Scripts - Practical Examples

Real-world examples and command snippets for common AWS automation tasks.

---

## Quick Start Examples

### Backup All S3 Buckets Locally

```bash
# Full backup with progress
./s3-buckets-local-backup.sh

# Equivalent commands if you want to do it manually:
for bucket in $(aws s3 ls | awk '{print $3}'); do
  aws s3 sync s3://$bucket ./backups/$bucket/
done
```

**Expected Output**:
```
Backing up s3://my-app-bucket to ./backups/my-app-bucket/
Backed up: 1,245 files, 2.5 GB
Backing up s3://logs-bucket to ./backups/logs-bucket/
...
Total: 4,321 files, 12.8 GB
```

---

### Security Audit - Check All S3 Bucket Permissions

```bash
# Generate security audit
./s3-buckets-security-audit.sh

# Check results
ls -lah s3-bucket-audit-*/
cat s3-bucket-audit-2024-01-15/my-bucket.json | jq '.Policy'
```

**Checking for Public Buckets**:
```bash
# Look for "Principal": "*" indicating public access
for file in s3-bucket-audit-*//*.json; do
  if grep -q '"Principal".*"\*"' "$file"; then
    echo "⚠️  POTENTIAL PUBLIC BUCKET: $file"
  fi
done
```

---

### Cost Optimization - Find Large S3 Buckets

```bash
# Identify expensive buckets
./s3-buckets-total-file-size.sh

# Output helps prioritize which buckets to optimize
# Look for opportunities to:
# - Transition old objects to Glacier
# - Enable compression
# - Use intelligent-tiering
```

---

### Infrastructure Monitoring - Setup CloudWatch Alarms

```bash
# Create alarms for all EC2 instances
./cloudwatch-create-alarms-statuscheckfailed.sh

# Create alarms for all load balancers
./cloudwatch-create-alarms-unhealthyhost.sh

# Verify alarms were created:
aws cloudwatch describe-alarms \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table
```

---

### Log Analysis - Search Application Logs

```bash
# Search for errors in specific log group
./cloudwatch-logs-search.sh \
  --log-group "/aws/lambda/my-function" \
  --pattern "ERROR" \
  --region us-east-1

# Manual equivalent:
aws logs filter-log-events \
  --log-group-name /aws/lambda/my-function \
  --filter-pattern "ERROR" \
  --start-time 1704067200000 \
  --end-time 1704153600000
```

---

### Cost Control - Set CloudWatch Logs Retention

```bash
# Set 30-day retention globally (reduces costs)
./cloudwatch-logs-retention-policy.sh

# Verify retention was set:
aws logs describe-log-groups \
  --query 'logGroups[*].[logGroupName,retentionInDays]' \
  --output table
```

---

### Disaster Recovery - Export ELB Configuration

```bash
# Export current load balancer
./ec2-elb-export-template.sh my-production-elb

# Output: my-production-elb.json
# Store in git for version control
git add my-production-elb.json
git commit -m "Backup ELB configuration"

# If needed, recreate ELB from template later
```

---

### Backup Automation - Create Daily EBS Snapshots

```bash
# Tag volumes you want to backup
aws ec2 create-tags \
  --resources vol-12345678 vol-87654321 \
  --tags Key=Backup,Value=1

# Add to cron for daily backups
# 0 2 * * * /path/to/ec2-ebs-create-snapshots.sh

# Run manually to test
./ec2-ebs-create-snapshots.sh

# Verify snapshots
aws ec2 describe-snapshots \
  --owner-ids self \
  --query 'Snapshots[*].[SnapshotId,VolumeSize,StartTime]' \
  --output table
```

---

### IP Whitelisting - Allow Pingdom Monitoring

```bash
# Create security group rules for Pingdom probes
./vpc-sg-import-rules-pingdom.sh

# Verify rules were added:
aws ec2 describe-security-groups \
  --filters Name=group-name,Values=pingdom* \
  --query 'SecurityGroups[*].[GroupId,GroupName,IpPermissions]' \
  --output json | jq .
```

**Without the script (using raw AWS CLI)**:
```bash
# Get Pingdom IPs (from their docs)
curl -s https://documentation.pingdom.com/api/sites/probes \
  | jq -r '.probes[].ip' > pingdom-ips.txt

# Create security group
SG_ID=$(aws ec2 create-security-group \
  --group-name pingdom-monitoring \
  --description "Allow Pingdom probes" \
  --vpc-id vpc-12345678 \
  --query 'GroupId' --output text)

# Add rules (limited to 60 rules per SG)
cat pingdom-ips.txt | while read ip; do
  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr $ip/32
done
```

---

### Encryption - Create Encrypted AMI

```bash
# Create encrypted base image
./ec2-ami-encrypted-ebs-boot-volume.sh

# Find the new AMI
aws ec2 describe-images \
  --owners self \
  --query 'Images[?RootDeviceType==`ebs`].[ImageId,Name,Encrypted]' \
  --output table

# Launch instance from encrypted AMI
aws ec2 run-instances \
  --image-id ami-encrypted123 \
  --instance-type t3.medium \
  --security-group-ids sg-12345678 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=prod-app-01}]'
```

---

## Advanced Examples

### Cross-Region Disaster Recovery

```bash
# Backup to multiple regions
for region in us-east-1 us-west-2 eu-west-1; do
  AWS_DEFAULT_REGION=$region ./s3-buckets-local-backup.sh
done
```

---

### Compliance Reporting - Monthly Security Audit

```bash
#!/bin/bash
# Save this as monthly-audit.sh

AUDIT_DATE=$(date +%Y-%m-%d)

# Create audit directory
mkdir -p audits/$AUDIT_DATE

# Run security audits
cd audits/$AUDIT_DATE

# S3 security audit
/path/to/s3-buckets-security-audit.sh
mv s3-bucket-audit-*/* .

# Document bucket sizes
/path/to/s3-buckets-total-file-size.sh > s3-sizes.txt

# CloudWatch alarms status
aws cloudwatch describe-alarms \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  > cloudwatch-alarms.json

# Commit to git for audit trail
cd ..
git add $AUDIT_DATE/
git commit -m "Monthly security audit - $AUDIT_DATE"
git push
```

---

### Automated Failover - Elastic IP Recovery

```bash
#!/bin/bash
# For Auto Scaling Group with reserved Elastic IP

# 1. Allocate and tag an EIP
EIP=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
aws ec2 create-tags --resources $EIP --tags Key=Environment,Value=prod Key=Purpose,Value=app-server

# 2. Store EIP in SSM Parameter Store
aws ssm put-parameter \
  --name /ec2/prod/eip \
  --value $EIP \
  --type String \
  --overwrite

# 3. Add to EC2 Launch Template user data:
cat > user-data.sh << 'EOF'
#!/bin/bash
set -e

# Get EIP from Parameter Store
EIP=$(aws ssm get-parameter \
  --name /ec2/prod/eip \
  --query 'Parameter.Value' \
  --output text)

# Associate EIP with this instance
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
aws ec2 associate-address \
  --instance-id $INSTANCE_ID \
  --allocation-id $EIP

# Notify of successful association
echo "EIP associated: $EIP" | mail -s "EC2 Instance $INSTANCE_ID recovery" ops@example.com
EOF

# 4. Use in Launch Template
aws ec2 create-launch-template \
  --launch-template-name prod-app \
  --version-description "With automatic EIP association" \
  --launch-template-data file://launch-template.json
```

---

### Policy-as-Code - S3 Bucket Compliance

```bash
#!/bin/bash
# Enforce S3 bucket policies across organization

# Read expected policy from file
EXPECTED_POLICY=$(cat s3-approved-policy.json)

# Check all buckets
for bucket in $(aws s3 ls | awk '{print $3}'); do
  ACTUAL=$(aws s3api get-bucket-policy --bucket $bucket 2>/dev/null || echo "{}")
  
  if [ "$ACTUAL" != "$EXPECTED_POLICY" ]; then
    echo "⚠️  Policy mismatch on bucket: $bucket"
    
    # Auto-fix if policy is missing/incorrect
    aws s3api put-bucket-policy \
      --bucket $bucket \
      --policy file://s3-approved-policy.json
  fi
done

echo "S3 bucket policies verified and corrected"
```

---

### Bulk IP Whitelisting

```bash
#!/bin/bash
# Create security group rules from external IP list

# Download trusted IP list
curl -s https://company-vpn-ips.example.com/cidrs.txt > trusted-ips.txt

# Create security group
SG_ID=$(aws ec2 create-security-group \
  --group-name trusted-vpn \
  --description "VPN access" \
  --vpc-id vpc-12345678 \
  --query 'GroupId' \
  --output text)

# Convert to array and batch authorize (10 at a time for efficiency)
mapfile -t IPS < trusted-ips.txt

for ((i=0; i<${#IPS[@]}; i+=10)); do
  RULES=()
  for ((j=0; j<10 && i+j<${#IPS[@]}; j++)); do
    RULES+=("{
      \"IpProtocol\": \"tcp\",
      \"FromPort\": 22,
      \"ToPort\": 22,
      \"IpRange\": {\"CidrIp\": \"${IPS[$i+$j]}\"}
    }")
  done
  
  # Batch authorize rules
  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --ip-permissions "{\"IpProtocol\": \"tcp\", \"FromPort\": 22, \"ToPort\": 22}"
done
```

---

### Lambda Integration - Automatic Daily Backups

```python
# Save as lambda_handler.py
import subprocess
import os

def lambda_handler(event, context):
    """Triggered daily by EventBridge to backup S3"""
    
    # Execute backup script
    result = subprocess.run([
        '/opt/python/ec2-ebs-create-snapshots.sh'
    ], capture_output=True, text=True)
    
    return {
        'statusCode': 200 if result.returncode == 0 else 500,
        'body': result.stdout + result.stderr
    }

# Lambda Dockerfile
FROM public.ecr.aws/lambda/python:3.11

# Install dependencies
RUN yum install -y aws-cli jq

# Copy scripts
COPY ec2-ebs-create-snapshots.sh ${LAMBDA_TASK_ROOT}/

CMD ["lambda_handler.lambda_handler"]
```

---

## Troubleshooting Examples

### AWS Credentials Not Found

```bash
# Check if credentials are configured
aws sts get-caller-identity

# Error: "Unable to locate credentials"

# Solution 1: Set environment variables
export AWS_ACCESS_KEY_ID=YOUR_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET
export AWS_DEFAULT_REGION=us-east-1

# Solution 2: Configure AWS CLI
aws configure

# Solution 3: Use IAM role (on EC2/ECS/Lambda)
# Credentials fetched automatically from instance metadata
```

---

### Permission Denied Errors

```bash
# Error: "User is not authorized to perform: ec2:RunInstances"

# Solution 1: Check caller identity
aws sts get-caller-identity

# Solution 2: Review IAM policy
aws iam list-user-policies --user-name my-user
aws iam get-user-policy --user-name my-user --policy-name MyPolicy

# Solution 3: Check resource-based policies (for S3, etc)
aws s3api get-bucket-policy --bucket my-bucket
```

---

### Region Issues

```bash
# Error: "InvalidParameterValue - The given zone does not exist"

# Solution: Check available regions
aws ec2 describe-regions --query 'Regions[*].[RegionName]' --output text

# Solution: Set correct region
export AWS_DEFAULT_REGION=us-east-1
./script.sh

# Or use profile with region
aws configure set region us-east-1 --profile my-profile
AWS_PROFILE=my-profile ./script.sh
```

---

## Performance Tips

### Parallelizing Operations

```bash
# Process multiple regions in parallel
for region in us-east-1 us-west-2 eu-west-1; do
  AWS_DEFAULT_REGION=$region ./script.sh &
done
wait

# Use xargs for parallel processing
aws s3 ls | awk '{print $3}' | \
  xargs -P 4 -I {} aws s3 sync s3://{} ./backups/{}/
```

---

### Batch Operations

```bash
# Instead of looping, use jq to batch
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType]' \
  --output json | jq -r '.[][] | @csv' | \
  while IFS=, read -r id type; do
    echo "Instance: $id Type: $type"
  done
```

---

## Additional Resources

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/)
- [jq Manual](https://stedolan.github.io/jq/manual/)
- [AWS SDK Examples](https://github.com/aws/aws-cli)

---

**Last Updated**: January 2024
