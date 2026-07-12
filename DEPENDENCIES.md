# Dependencies

This document outlines the external tools and dependencies required to run the AWS CLI shell scripts in this repository.

## Required Tools

### AWS CLI
- **Usage**: 41 scripts
- **Minimum Version**: 1.18.0 (2019-09)
- **Recommended Version**: Latest stable (2.x)
- **Installation**: `pip install awscli` or `brew install awscli`
- **Verification**: `aws --version`

### jq (JSON Query)
- **Usage**: 29 scripts
- **Minimum Version**: 1.5
- **Recommended Version**: Latest stable (1.7+)
- **Installation**: `brew install jq` or `apt-get install jq`
- **Verification**: `jq --version`

### curl
- **Usage**: 4 scripts
- **Minimum Version**: 7.0
- **Recommended Version**: Latest stable
- **Installation**: Usually pre-installed on macOS/Linux
- **Verification**: `curl --version`

### Standard Unix Tools
The following tools must be available in the system PATH:
- `sed` - Stream editor (used in 35 scripts)
- `grep` - Text search (used in 40 scripts)
- `cut` - Text column extraction (used in 33 scripts)
- `sort` - Sort lines (used in 14 scripts)
- `date` - Date/time handling (used in 29 scripts)
- `awk` - Text processing (used in 1 script)
- `uniq` - Remove duplicates (used in 3 scripts)

These are typically pre-installed on POSIX-compliant systems.

## Installation Instructions

### macOS
```bash
# Install Homebrew dependencies
brew install awscli jq curl

# Verify installations
aws --version
jq --version
curl --version
```

### Linux (Ubuntu/Debian)
```bash
# Install packages
sudo apt-get update
sudo apt-get install -y awscli jq curl

# Verify installations
aws --version
jq --version
curl --version
```

### Linux (RHEL/CentOS)
```bash
# Install packages
sudo yum install -y aws-cli jq curl

# Verify installations
aws --version
jq --version
curl --version
```

## Verification

Run the verification script to ensure all dependencies are installed:
```bash
bash test-dependencies.sh
```

## Version Update Compatibility

### AWS CLI 2.x Migration Notes
- AWS CLI 2.x is a major version bump with breaking changes
- Most scripts are compatible with both 1.x and 2.x
- If issues arise, refer to AWS official migration guide: https://docs.aws.amazon.com/cli/latest/userguide/cliv2-migration.html

### Security Updates
Keep tools updated regularly for security patches:
```bash
# macOS
brew upgrade awscli jq

# Ubuntu/Debian
sudo apt-get upgrade awscli jq

# Pip
pip install --upgrade awscli
```
