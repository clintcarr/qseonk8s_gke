#!/bin/bash

# GKE variables
REGION="australia-southeast1-b"
CLUSTER_NAME="qsek8s"
DISK_NAME="gce-nfs-disk"
DISK_SIZE="100GB"
MACHINE_TYPE="n1-standard-2"

#Set the region
gcloud config set compute/zone $REGION

#Create the cluster
gcloud container clusters create $CLUSTER_NAME --machine-type=$MACHINE_TYPE

#Set Kubectl context
gcloud container clusters get-credentials $CLUSTER_NAME 

#Create a disk for NFS
gcloud compute disks create --size=$DISK_SIZE --zone=$REGION $DISK_NAME

#Init Helm
helm init --upgrade --wait

#Create the RBAC config
kubectl create -f ./rbac-config.yaml

#Init helm with the new service account
helm init --upgrade --service-account tiller

#Create the NFS deployment
kubectl create -f ./dep-nfs.yaml

#Create the PV & PVC
kubectl create -f ./pvc-nfs.yaml

#Create the NFS Server
kubectl create -f ./srv-nfs.yaml

#Wait for the NFS pod to start
pods=1; while [ $pods -gt 0 ]; do sleep 10; pods=$(kubectl get pods | awk '{if(NR>1)print}' | grep -iv 'running' | wc -l); echo "Waiting for NFS pod to start..."; done

#Get the NFS pod name and set the permissions on the /exports folder
nfs_pod_name=$(kubectl get pods | awk '{if(NR>1){print $1}}')
kubectl exec $nfs_pod_name chmod 777 /exports

# #Add the stable repo
helm repo add qlik https://qlik.bintray.com/stable

# #Install the pre-reqs
helm install --name qliksense-init qlik/qliksense-init

# #Install QSEoK8s
helm upgrade --install qliksense qlik/qliksense -f values.yaml
