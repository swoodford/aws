#!/bin/bash

HOSTEDZONEID="id"
profile="xyz"

cat > change-batch.json << EOL
{"Comment":"test","Changes":[{"Action":"CREATE","ResourceRecordSet":{"Name":"mail.shawnwoodford.com","Type":"CNAME","Region":"us-east-1","TTL":300,"ResourceRecords":[{"Value":"ghs.googlehosted.com"}]}}]}
EOL

# aws route53 change-resource-record-sets --hosted-zone-id $HOSTEDZONEID --profile $profile --cli-input-json '
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

# aws route53 change-resource-record-sets --hosted-zone-id $HOSTEDZONEID --profile $profile --cli-input-json '{"HostedZoneId":"$HOSTEDZONEID","ChangeBatch":{"Comment":"test","Changes":[{"Action":"CREATE","ResourceRecordSet":{"Name":"mail.shawnwoodford.com","Type":"CNAME","Region":"us-east-1","TTL":300,"ResourceRecords":[{"Value":"ghs.googlehosted.com"}]}}]}}'

aws route53 change-resource-record-sets --hosted-zone-id $HOSTEDZONEID --profile $profile --change-batch file://change-batch.json 