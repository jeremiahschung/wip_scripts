#!/bin/bash

set -ex

# Setup your AWS credentials / region
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_DEFAULT_REGION=

# Setup cluster name
CLUSTER_NAME=
# Setup EFS ID
FILE_SYSTEM_ID=


kubectl delete pods --all
helm ls --all --short | xargs -L1 helm delete

# Delete EFS mount targets
for id in `aws --region=$AWS_DEFAULT_REGION efs describe-mount-targets --file-system-id $FILE_SYSTEM_ID | jq -r ".MountTargets[]|{id: .MountTargetId} | .id"` ; do
	if [ -z "$id" ] ; then
        continue
    fi
    echo "Deleting efs mount target $AWS_DEFAULT_REGION $id"
    aws --region=$AWS_DEFAULT_REGION efs delete-mount-target --mount-target-id $id
done

# Delete Secure Group dependencies
SecureGroupIDs=$(aws --region=$AWS_DEFAULT_REGION ec2 describe-security-groups --filters Name=group-name,Values=*eks* | jq -r ".SecurityGroups[]|{id: .GroupId} | .id")
for id in $SecureGroupIDs ; do
    if [ -z "$id" ] ; then
        continue
    fi

    perms="`aws ec2 describe-security-groups --output json --group-ids $id --query "SecurityGroups[0].IpPermissions"`"
    if [ "$perms" != [] ]
        then
                aws ec2 revoke-security-group-ingress --cli-input-json "{\"GroupId\": \"$id\", \"IpPermissions\": $perms}"
        fi
done

sleep 60 

# Delete EFSs
echo "Deleting EFS: $id"
aws efs delete-file-system --file-system-id $FILE_SYSTEM_ID

# Delete the EKS cluster
echo "Deleting EKS Cluster: $CLUSTER_NAME"
eksctl delete cluster --name $CLUSTER_NAME --wait

sleep 300

# delete VPCs
export IDs=$(aws --region=$AWS_DEFAULT_REGION ec2 describe-vpcs | jq -r ".Vpcs[]|{is_default: .IsDefault, id: .VpcId} | select(.is_default==false) | .id")
for id in $IDs ; do
    if [ -z "$id" ] ; then
        continue
    fi

    # Delete subnets
    for sub in `aws --region=$AWS_DEFAULT_REGION ec2 describe-subnets | jq -r ".Subnets[] | {id: .SubnetId, vpc: .VpcId} | select(.vpc == \"$id\") | .id"` ; do
        echo "Deleting subnet: $AWS_DEFAULT_REGION $id, $sub"
        aws --region=$AWS_DEFAULT_REGION ec2 delete-subnet --subnet-id=$sub
    done

    #Delete network interfaces
    for ni in `aws ec2 describe-network-interfaces --filters Name=description,Values=*EFS* | jq -r ".NetworkInterfaces[] | {id: .NetworkInterfaceId, vpc: .VpcId} | select(.vpc == \"$id\") | .id"` ; do
        echo "Deleting Network Interface: $AWS_DEFAULT_REGION $id, $ni"
        aws --region=$AWS_DEFAULT_REGION ec2 delete-network-interface --network-interface-id $ni
    done

    # Delete igws
    for igw in `aws --region=$AWS_DEFAULT_REGION ec2 describe-internet-gateways | jq -r ".InternetGateways[] | {id: .InternetGatewayId, vpc: .Attachments[0].VpcId} | select(.vpc == \"$id\") | .id"` ; do
        echo "Deleting Internet Gateway: $AWS_DEFAULT_REGION $id, $igw"
        aws --region=$AWS_DEFAULT_REGION ec2 detach-internet-gateway --internet-gateway-id=$igw --vpc-id=$id
        aws --region=$AWS_DEFAULT_REGION ec2 delete-internet-gateway --internet-gateway-id=$igw
    done
done

# Delete remaining groups
SecureGroupIDs=$(aws --region=$AWS_DEFAULT_REGION ec2 describe-security-groups --filters Name=group-name,Values=*eks* | jq -r ".SecurityGroups[]|{id: .GroupId} | .id")
for id in $SecureGroupIDs ; do
    if [ -z "$id" ] ; then
        continue
    fi
    aws ec2 delete-security-group --group-id $id
done

# delete VPCs
IDs=$(aws --region=$AWS_DEFAULT_REGION ec2 describe-vpcs | jq -r ".Vpcs[]|{is_default: .IsDefault, id: .VpcId} | select(.is_default==false) | .id")
for id in $IDs ; do
    echo "Deleting vpc: $AWS_DEFAULT_REGION $id"
    aws --region=$AWS_DEFAULT_REGION ec2 delete-vpc --vpc-id=$id
done



# Delete the EKS cluster
echo "Deleting EKS Cluster: $CLUSTER_NAME"
eksctl delete cluster --name $CLUSTER_NAME
