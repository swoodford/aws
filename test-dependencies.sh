#!/bin/bash
#
# Test script to verify all required dependencies are installed
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Dependency Verification Script"
echo "=========================================="
echo ""

MISSING_DEPS=0

# Check AWS CLI
echo -n "Checking AWS CLI... "
if command -v aws &> /dev/null; then
    VERSION=$(aws --version 2>&1 | cut -d' ' -f1)
    echo -e "${GREEN}OK${NC} (${VERSION})"
else
    echo -e "${RED}MISSING${NC}"
    echo "  Install: pip install awscli"
    MISSING_DEPS=$((MISSING_DEPS+1))
fi

# Check jq
echo -n "Checking jq... "
if command -v jq &> /dev/null; then
    VERSION=$(jq --version)
    echo -e "${GREEN}OK${NC} (${VERSION})"
else
    echo -e "${RED}MISSING${NC}"
    echo "  Install: brew install jq (macOS) or apt-get install jq (Linux)"
    MISSING_DEPS=$((MISSING_DEPS+1))
fi

# Check curl
echo -n "Checking curl... "
if command -v curl &> /dev/null; then
    VERSION=$(curl --version | head -n 1 | cut -d' ' -f2)
    echo -e "${GREEN}OK${NC} (${VERSION})"
else
    echo -e "${RED}MISSING${NC}"
    echo "  Usually pre-installed. If missing: brew install curl"
    MISSING_DEPS=$((MISSING_DEPS+1))
fi

# Check standard Unix tools
echo ""
echo "Checking standard Unix tools..."
for tool in sed grep cut sort date awk uniq; do
    echo -n "  $tool... "
    if command -v "$tool" &> /dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}MISSING${NC}"
        MISSING_DEPS=$((MISSING_DEPS+1))
    fi
done

echo ""
echo "=========================================="
if [ $MISSING_DEPS -eq 0 ]; then
    echo -e "${GREEN}✓ All dependencies are installed${NC}"
    echo "=========================================="
    exit 0
else
    echo -e "${RED}✗ $MISSING_DEPS dependency(ies) missing${NC}"
    echo "=========================================="
    echo "See DEPENDENCIES.md for installation instructions"
    exit 1
fi
