#!/bin/bash

# This file contains the installation steps for setting up Kubernetes with EKS on AWS.

# Preparation steps needed:
# - Setup AWS credentials (key/secret/region) in this file below
# - Subscribe to EKS-optimimized AMI with GPU Suport: https://aws.amazon.com/marketplace/pp/B07GRHFXGM
# - Configure templates/eks_cluster.yaml wth desired cluster name/region/instance properties
# - Configure setup_efs.sh with the cluster name from above and the MOUNT_TARGET_GROUP_NAME
# - Configure templates/efs_pv_claim.yaml

set -ex

# Setup your AWS credentials / region
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_DEFAULT_REGION=

sudo apt-get update
sudo apt-get install unzip

# Install AWS CLI & Set Credentials
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify your aws cli installation
aws --version

# Setup your AWS credentials / region in credentials.sh
source ./credentials.sh

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
yes | sudo apt-get install jq

# TODO: make this path agnostic
cd serve/kubernetes

# Create EKS cluster
eksctl create cluster -f templates/eks_cluster.yaml

# Verify clusters created
eksctl get clusters
kubectl get service,po,daemonset,pv,pvc --all-namespaces

# Install NVIDIA plugin
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update
helm install --version=0.6.0 --generate-name nvdp/nvidia-device-plugin


# Setup PersistentVolume with EFS 
source ./setup_efs.sh

echo "Waiting 60s for EFS to come online"
sleep 60

helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm install stable/efs-provisioner --set efsProvisioner.efsFileSystemId=$FILE_SYSTEM_ID --set efsProvisioner.awsRegion=us-west-2 --set efsProvisioner.reclaimPolicy=Retain --generate-name

echo "Waiting 300s for EFS to come online"
sleep 300

kubectl get pods
kubectl apply -f templates/efs_pv_claim.yaml
kubectl get service,po,daemonset,pv,pvc --all-namespaces
wget https://torchserve.pytorch.org/mar_files/squeezenet1_1.mar
wget https://torchserve.pytorch.org/mar_files/mnist.mar
kubectl exec --tty pod/model-store-pod -- mkdir /pv/model-store/
kubectl cp squeezenet1_1.mar model-store-pod:/pv/model-store/squeezenet1_1.mar
kubectl cp mnist.mar model-store-pod:/pv/model-store/mnist.mar
kubectl exec --tty pod/model-store-pod -- mkdir /pv/config/
kubectl cp config.properties model-store-pod:/pv/config/config.properties
kubectl exec --tty pod/model-store-pod -- find /pv/
kubectl delete pod/model-store-pod

helm install ts .

sleep 60

# Print up variables
echo $EFS_FS_ID
echo $EFS_DNS_NAME
echo $MOUNT_TARGET_GROUP_ID
echo $CLUSTER_NAME

# TODO: automate this
kubectl get po --all-namespaces
kubectl exec pod/torchserve-fff -- cat logs/ts_log.log
kubectl get svc
curl http://your_elb.us-west-2.elb.amazonaws.com:8081/models
wget https://raw.githubusercontent.com/pytorch/serve/master/docs/images/kitten_small.jpg
curl -X POST  http://your_elb.us-west-2.elb.amazonaws.com.us-west-2.elb.amazonaws.com:8080/predictions/squeezenet1_1 -T kitten_small.jpg
