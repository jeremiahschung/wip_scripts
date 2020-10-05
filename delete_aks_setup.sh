#!/bin/bash

set -ex

# CLUSTER_NAME=torchserveCluster
# RESOURCE_GROUP_NAME=torchserveResourceGroup

# yes | sudo apt-get install jq

# kubectl delete pods --all
# helm ls --all --short | xargs -L1 helm delete

# az aks delete --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP_NAME --yes

# az group delete --name $RESOURCE_GROUP_NAME --yes




# Delete instance setup
# az disk delete --ids `az disk list | jq -r ".[]|{id: .id} | .id"` --yes


# Delete network interfaces
# az network nic delete --ids `az network nic list | jq -r ".[]|{id: .id} | .id"`


# Delete Secure Group dependencies
# vnetNames=$(az network vnet list | jq -r ".[]|{name: .name} | .name")
# for name in $vnetNames ; do
#     if [ -z "$name" ] ; then
#         continue
#     fi

#     subnetIDs=`az network vnet subnet list --vnet-name $name --resource-group akstest1_group  | jq -r ".[]|{id: .id} | .id"`
#     if [ -z "$subnetIDs" ]
#         then
#                az network vnet subnet delete --ids $subnetIDs
#         fi
    
# done

# az network vnet delete --ids `az network vnet list | jq -r ".[]|{id: .id} | .id"`

# az network nsg delete --ids `az network nsg list | jq -r ".[]|{id: .id} | .id"`

# az network public-ip delete --ids `az network public-ip list | jq -r ".[]|{id: .id} | .id"`

# Delete Network Watchers
nwInfo=$(az network watcher list | jq -r ".[]|{name: .name, location: .location} | \"--name \" + .name + \" --location \" + .location")
IFS=$'\n'
for line in $nwInfo ; do
    if [ -z "$line" ] ; then
        continue
    fi

    az network watcher connection-monitor delete "$line"
done
unset IFS