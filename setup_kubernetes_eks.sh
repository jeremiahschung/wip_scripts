#!/bin/bash

# This file contains the installation steps for setting up Kubernetes with EKS on AWS.
# To run on a machine with GPU : ./setup_kubernetes_eks.sh True
# To run on a machine with CPU : ./setup_kubernetes_eks.sh False


# Preparation steps needed:
# cloned the TorchServe repo 
#   git clone https://github.com/pytorch/serve
# Configure templates/eks_cluster.yaml wth desired cluster name/region/instance properties
# Configure setup_efs.sh with the cluster name from above and the MOUNT_TARGET_GROUP_NAME
# Configure templates/efs_pv_claim.yaml

set -ex

sudo apt-get update
sudo apt-get install unzip

# Install AWS CLI & Set Credentials
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify your aws cli installation
aws --version

# Setup your AWS credentials / region
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_DEFAULT_REGION=

# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Verify your eksctl installation
eksctl version

# Install kubectl
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Verify your kubectl installation
kubectl version --client

# Install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh


# Install jq
sudo apt-get install jq

# Create EKS cluster
eksctl create cluster -f templates/eks_cluster.yaml

# Verify clusters created
eksctl get clusters
kubectl get service,po,daemonset,pv,pvc --all-namespaces

# Install NVIDIA plugin
if [[ $1 = True ]]
then
	helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
	helm repo update
	helm install \
	    --version=0.6.0 \
	    --generate-name \
	    nvdp/nvidia-device-plugin
fi

# Setup PersistentVolume with EFS 
source ./setup_efs.sh
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm install stable/efs-provisioner --set efsProvisioner.efsFileSystemId=$FILE_SYSTEM_ID --set efsProvisioner.awsRegion=us-west-2 --set efsProvisioner.reclaimPolicy=Retain --generate-name
kubectl get pods
kubectl apply -f templates/efs_pv_claim.yaml
kubectl get service,po,daemonset,pv,pvc --all-namespaces
kubectl exec --tty pod/model-store-pod -- find /pv/
kubectl delete pod/model-store-pod

# Print variables
echo $EFS_FS_ID
echo $EFS_DNS_NAME
echo $MOUNT_TARGET_GROUP_ID
echo $CLUSTER_NAME
