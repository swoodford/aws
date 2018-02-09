# #!/usr/bin/env bash

##################################################################
# Depreciating this script since using the s3api is must faster! #
##################################################################

# # Script to count total size of all data stored in all s3 buckets (IAM account must have permission to access all buckets)
# # Requires s3cmd

# # Functions

# # Fail
# function fail(){
#   tput setaf 1; echo "Failure: $*" && tput sgr0
#   exit 1
# }

# # Check for command
# function check_command {
#   type -P $1 &>/dev/null || fail "Unable to find $1, please install it and run this script again."
# }

# # Completed
# function completed(){
#   echo
#   HorizontalRule
#   tput setaf 2; echo "Completed!" && tput sgr0
#   HorizontalRule
#   echo
# }

# # Horizontal Rule
# function HorizontalRule(){
#   echo "============================================================"
# }

# # Convert bytes to human readable
# function bytestohr(){
#     SLIST="bytes,KB,MB,GB,TB,PB,EB,ZB,YB"

#     POWER=1
#     VAL=$( echo "scale=2; $1 / 1" | bc)
#     VINT=$( echo $VAL / 1024 | bc )
#     while [ $VINT -gt 0 ]
#     do
#         let POWER=POWER+1
#         VAL=$( echo "scale=2; $VAL / 1024" | bc)
#         VINT=$( echo $VAL / 1024 | bc )
#     done

#     echo $VAL $( echo $SLIST | cut -f$POWER -d, )
# }

# # Check required commands
# check_command "s3cmd"

# # Verify s3cmd Credentials are setup
# # http://s3tools.org/s3cmd-howto
# if ! [ -f ~/.s3cfg ]; then
#   fail "Error: s3cmd config not found or not installed."
# fi

# # List buckets
# S3CMDLS=$(s3cmd ls 2>&1)

# # Count number of buckets
# TOTALNUMBERS3BUCKETS=$(echo "$S3CMDLS" | wc -l | rev | cut -d " " -f1 | rev)

# # Get list of all bucket names
# BUCKETNAMES=$(echo "$S3CMDLS" | cut -d ' ' -f 4 | nl)

# echo
# HorizontalRule
# echo "Counting Total Size of Data in $TOTALNUMBERS3BUCKETS S3 Buckets"
# echo "(This may take a very long time depending on number of files)"
# HorizontalRule
# echo

# START=1
# TOTALBUCKETSIZE=0

# for (( COUNT=$START; COUNT<=$TOTALNUMBERS3BUCKETS; COUNT++ ))
# do
#   CURRENTBUCKET=$(echo "$BUCKETNAMES" | grep -w [^0-9][[:space:]]$COUNT | cut -f 2)
#   HorizontalRule
#   echo \#$COUNT $CURRENTBUCKET

#   CURRENTBUCKETSIZE=$(s3cmd du $CURRENTBUCKET | cut -d ' ' -f 1)
#   TOTALBUCKETSIZE=$(($TOTALBUCKETSIZE + $CURRENTBUCKETSIZE))
#   echo "Size: "
#   bytestohr $CURRENTBUCKETSIZE
#   echo "Subtotal: "
#   bytestohr $TOTALBUCKETSIZE
# done

# completed
# echo "Total Size of Data in All $TOTALNUMBERS3BUCKETS S3 Buckets:"
# bytestohr $TOTALBUCKETSIZE
