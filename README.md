# Cloud Agnostic Kubernetes Deployment

GCP, AWS, Azure, Kubernetes, Istio, Helm, Kustomize, and Terraform.

## Contents

This repository uses a split-responsibility model:

* **Terraform**: cloud infrastructure, Kubernetes clusters, IAM, container registries, and Istio installation.
* **Kustomize**: portable Kubernetes workload manifests with per-cloud overlays.
* **Application code**: cloud-neutral containerized workloads.

## Istio Gateway

The Istio `Gateway` describes ingress traffic entering the mesh, while the `VirtualService` routes that traffic to services.

This model is portable across GKE, EKS, and AKS because it targets Istio and Kubernetes APIs instead of cloud-specific ingress resources.

## Cloud-Specific Decisions

### GCP

GKE Workload Identity Federation lets Kubernetes workloads authenticate to Google Cloud APIs without static service account keys.

The cloud-specific configuration belongs in the GCP overlay, not in the base manifests.

Example:

```text
k8s/overlays/gcp/kustomization.yaml
```

### AWS

On EKS, IAM Roles for Service Accounts use a Kubernetes service account annotation that points to the IAM role ARN.

### Azure

AKS Workload Identity uses OIDC with Microsoft Entra Workload ID.

Azure-specific service account labels and annotations, such as `azure.workload.identity/client-id`, belong in the Azure overlay.

## Repository Layout

```text
repo/
├── infra/
│   ├── modules/
│   │   ├── gke/
│   │   ├── eks/
│   │   ├── aks/
│   │   └── istio/
│   └── envs/
│       ├── gcp/dev/
│       ├── aws/dev/
│       └── azure/dev/
│
└── k8s/
    ├── base/
    │   ├── namespace.yaml
    │   ├── serviceaccount.yaml
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── gateway.yaml
    │   ├── virtualservice.yaml
    │   └── kustomization.yaml
    │
    └── overlays/
        ├── gcp/
        ├── aws/
        └── azure/
```

## Installation

### GCP

```bash
terraform -chdir=infra/envs/gcp/dev init
terraform -chdir=infra/envs/gcp/dev apply

gcloud container clusters get-credentials CLUSTER_NAME \
  --region REGION \
  --project PROJECT_ID

kubectl apply -k k8s/overlays/gcp
```

### AWS

```bash
terraform -chdir=infra/envs/aws/dev init
terraform -chdir=infra/envs/aws/dev apply

aws eks update-kubeconfig \
  --region REGION \
  --name CLUSTER_NAME

kubectl apply -k k8s/overlays/aws
```

### Azure

```bash
terraform -chdir=infra/envs/azure/dev init
terraform -chdir=infra/envs/azure/dev apply

az aks get-credentials \
  --resource-group RESOURCE_GROUP \
  --name CLUSTER_NAME

kubectl apply -k k8s/overlays/azure
```

## Rule Set

### Keep These in the Base

* Namespace
* Deployment
* Service
* ServiceAccount without cloud annotations
* Istio Gateway
* Istio VirtualService
* ConfigMap with generic defaults
* Probes
* Resource requests and limits
* Pod security context

### Keep These in Overlays

* Container registry path
* Image tag
* Cloud workload identity annotations
* Cloud-specific storage class
* Cloud-specific load balancer annotations
* Environment-specific replica count
* Environment-specific hostnames
* Cloud-specific secret provider configuration

### Do Not Put These in Application Code

* GCP service account keys
* AWS access keys
* Azure client secrets
* Cloud-specific config hardcoded into source
* Cloud-specific ingress logic
* Cloud-specific Kubernetes YAML in the base

## Resulting Model

* Same container image pattern
* Same Kubernetes base
* Same Istio traffic model
* Different Terraform module per cloud
* Different Kustomize overlay per cloud

This keeps the workload portable while accepting that infrastructure provisioning itself is necessarily cloud-specific.
