#!/bin/bash

set -ex

AZURE_SUBSCRIPTION_ID=b48a7187-f0b1-4b88-80b6-e776f65bfd6f
CLUSTER_NAME=torchserveCluster
RESOURCE_GROUP_NAME=torchserveResourceGroup

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

az login
az account set -s $AZURE_SUBSCRIPTION_ID

az group create --name $RESOURCE_GROUP_NAME --location eastus

# Select the Azure VM type and the number of nodes
az aks create --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --node-vm-size Standard_NC6 --node-count 1 --generate-ssh-keys

# Install kubectl 
sudo az aks install-cli

# Configure kubectl to connect to the Kubernetes cluster
az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME

# You should be in the torchserve source directory by this step
cd kubernetes/AKS

# Install NVIDIA device plugin
kubectl apply -f templates/nvidia-device-plugin-ds.yaml

# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh



kubectl apply -f templates/Azure_file_sc.yaml
kubectl apply -f templates/AKS_pv_claim.yaml

sleep 60 

kubectl get pvc,pv

kubectl apply -f templates/model_store_pod.yaml

sleep 30

wget https://torchserve.s3.amazonaws.com/mar_files/squeezenet1_1.mar
wget https://torchserve.s3.amazonaws.com/mar_files/mnist.mar

kubectl exec --tty pod/model-store-pod -- mkdir /mnt/azure/model-store/
kubectl cp squeezenet1_1.mar model-store-pod:/mnt/azure/model-store/squeezenet1_1.mar
kubectl cp mnist.mar model-store-pod:/mnt/azure/model-store/mnist.mar

kubectl exec --tty pod/model-store-pod -- find /mnt/azure/

cd ../Helm
helm install ts .

sleep 180

kubectl get po

kubectl get svc

curl http://your-external-IP:8081/models
