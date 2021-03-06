#  fluxcdv1-gcsr

Customized fluxcd/flux v1 Docker container that can access Google Cloud Source Repositories (GCSR).

GCSR does not support ssh-key or token authentication and can not be used directly as Git source.

This container adds support for using serviceaccount based authentication with Google Cloud SDK.

Follow the instructions below to install fluxcd v1 using Helm on GCP:


## Usage

In order to get access to GCSR workload-identity has to be enabled (https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#gcloud_1).

The following examples will create a Kubernetes namespace flux, a Kubernetes serviceaccount kfluxaccount and a GCP serviceaccount gserviceaccount
on an already existing regional Kubernetes cluster gke-cluster with a node pool named node-pool1.
It's also assumed that you have a Source Repository named demorepo.

### Prepare Kubernetes cluster

```
# setup gcloud
export PROJECT_ID=your-project-id
gcloud config set project $PROJECT_ID

# prepare K8s cluster
gcloud  container clusters get-credentials  gke-cluster --region europe-west3
gcloud container clusters update --region europe-west3 gke-cluster --workload-pool=$PROJECT_ID.svc.id.goog 
gcloud container node-pools update --region europe-west3 node-pool1  --cluster=gke-cluster --workload-metadata=GKE_METADATA

# Create namespace and serviceaccounts
kubectl create namespace flux
kubectl create serviceaccount --namespace flux kfluxaccount
gcloud iam service-accounts create gfluxaccount

# Allow kserviceaccount to act as gserviceaccount (Gcloud part)
gcloud iam service-accounts add-iam-policy-binding --role roles/iam.workloadIdentityUser  --member "serviceAccount:$PROJECT_ID.svc.id.goog[flux/kfluxaccount]" gfluxaccount@$PROJECT_ID.iam.gserviceaccount.com

# Allow kserviceaccount to act as gserviceaccount (K8S part)
kubectl annotate serviceaccount --namespace flux kfluxaccount iam.gke.io/gcp-service-account=gfluxaccount@$PROJECT_ID.iam.gserviceaccount.com

# Give serviceaccount permissions (as for this demo "roles/editor" might be fine, but set appropriate permissions in production)
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:gfluxaccount@$PROJECT_ID.iam.gserviceaccount.com --role=roles/editor

### wait a minute or to for metadata containers to get ready

# Verify correct configuration so far:
kubectl run -it  --rm --image google/cloud-sdk:slim --namespace flux --serviceaccount kfluxaccount workload-identity-test
gcloud  auth list ## should show gserviceaccount
git clone https://source.developers.google.com/p/$PROJECT_ID/r/demorepo
```


### Deploy Fluxcd using Helm

Original instruction here: https://docs.fluxcd.io/en/1.21.1/tutorials/get-started-helm/

```
kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/master/deploy/crds.yaml

 helm upgrade -i helm-operator fluxcd/helm-operator --set image.repository=nerdicbynature/fluxcdv1-gcsr-helm-operator \
     --set image.tag=latest --set git.ssh.secretName=flux-git-deploy --set serviceAccount.create=false \
     --set serviceAccount.name=kfluxaccount --set helm.versions=v3 --namespace flux


helm upgrade -i flux fluxcd/flux --set image.repository=docker.io/nerdicbynature/fluxcdv1-gcsr \
     --set image.tag=latest --set serviceAccount.create=false --set serviceAccount.name=kfluxaccount \
     --set git.url=https://source.developers.google.com/p/$PROJECT_ID/r/demorepo --namespace flux
```
