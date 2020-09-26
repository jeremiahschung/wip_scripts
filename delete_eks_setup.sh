#!/bin/bash

set -ex

# Setup your AWS credentials / region
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_DEFAULT_REGION=

#aws efs delete-file-system --file-system-id $FILE_SYSTEM_ID
#aws ec2 delete-security-group --group-id $MOUNT_TARGET_GROUP_ID
#eksctl delete cluster -name $CLUSTER_NAME

groupIds="`aws ec2 describe-security-groups --filters Name=group-name,Values=*eks* --query "SecurityGroups[*].GroupId"`"
groupIds="${groupIds//\"}"
groupIds="${groupIds//[}"
groupIds="${groupIds//]}"

arrGroupId=(${groupIds//,/ })
for groupId in "${arrGroupId[@]}"; 
do
    perms="`aws ec2 describe-security-groups --output json --group-ids $groupId --query "SecurityGroups[0].IpPermissions"`"
    if [ -n $perms ]&&[ $perms != "[]" ]
	then
		aws ec2 revoke-security-group-ingress --group-id $groupId --ip-permissions $perms
	fi
done

for groupId in "${arrGroupId[@]}"; 
do
	aws ec2 delete-security-group --group-id $groupId
done
