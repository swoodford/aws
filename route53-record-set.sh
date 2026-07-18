#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./aws-profile.sh
source "$SCRIPT_DIR/aws-profile.sh"
aws_profile_prepare_args "$@" || exit 1
set -- "${AWS_SCRIPT_LEGACY_ARGS[@]}"


HOSTEDZONEID="id"

cat > change-batch.json << EOL
{"Comment":"test","Changes":[{"Action":"CREATE","ResourceRecordSet":{"Name":"mail.shawnwoodford.com","Type":"CNAME","Region":"us-east-1","TTL":300,"ResourceRecords":[{"Value":"ghs.googlehosted.com"}]}}]}
EOL

# aws route53 change-resource-record-sets --hosted-zone-id $HOSTEDZONEID --cli-input-json '
# {
#   "HostedZoneId": "$HOSTEDZONEID",
#   "ChangeBatch": {
#     "Comment": "test",
#     "Changes": [{
#       "Action": "CREATE",
#       "ResourceRecordSet": {
#         "Name": "mail.shawnwoodford.com",
#         "Type": "CNAME",
#         "Region": "us-east-1",
#         "TTL": 300,
#         "ResourceRecords": [{
#           "Value": "ghs.googlehosted.com"
#         }]
#       }
#     }]
#   }
# }'

# rm change-batch.json

# aws route53 change-resource-record-sets --hosted-zone-id $HOSTEDZONEID --cli-input-json '{"HostedZoneId":"$HOSTEDZONEID","ChangeBatch":{"Comment":"test","Changes":[{"Action":"CREATE","ResourceRecordSet":{"Name":"mail.shawnwoodford.com","Type":"CNAME","Region":"us-east-1","TTL":300,"ResourceRecords":[{"Value":"ghs.googlehosted.com"}]}}]}}'

aws route53 change-resource-record-sets --hosted-zone-id $HOSTEDZONEID --change-batch file://change-batch.json
