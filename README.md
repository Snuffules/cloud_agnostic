# cloud_agnostic
gcp, aws, azure, k8s, istio, helm, kustomize

##Contents:

Terraform = cloud infrastructure, Kubernetes cluster, IAM, registry, Istio install.

Kustomize = portable Kubernetes workload manifests plus per-cloud overlays.

Application code = cloud-neutral container.

##Istio Gateway:

describes ingress traffic entering the mesh, while VirtualService routes that traffic to services. This is portable across GKE, EKS, and AKS because it targets Istio and Kubernetes APIs, not cloud-specific ingress resources.

##Decisions per cloud:

GC{: GKE Workload Identity Federation lets Kubernetes workloads authenticate to Google Cloud APIs without static service account keys; the cloud-specific part belongs in the GCP overlay, not the base.
AWS: On EKS, IAM Roles for Service Accounts use a Kubernetes service account annotation pointing to the IAM role ARN
Azure: AKS Workload Identity uses OIDC plus Microsoft Entra Workload ID, and Azure documents service account labels and annotations such as azure.workload.identity/client-id

##Repository layout

<img width="409" height="678" alt="{FB3B6475-A522-40CE-A21C-FE16AEA53051}" src="https://github.com/user-attachments/assets/d3a80f21-d96a-4268-a3d2-4af014c5a484" />

##Installation

Deployment commands

GCP:

terraform -chdir=infra/envs/gcp/dev init
terraform -chdir=infra/envs/gcp/dev apply

gcloud container clusters get-credentials CLUSTER_NAME \
  --region REGION \
  --project PROJECT_ID

kubectl apply -k k8s/overlays/gcp

AWS:

terraform -chdir=infra/envs/aws/dev init
terraform -chdir=infra/envs/aws/dev apply

aws eks update-kubeconfig \
  --region REGION \
  --name CLUSTER_NAME

kubectl apply -k k8s/overlays/aws

Azure:

terraform -chdir=infra/envs/azure/dev init
terraform -chdir=infra/envs/azure/dev apply

az aks get-credentials \
  --resource-group RESOURCE_GROUP \
  --name CLUSTER_NAME

kubectl apply -k k8s/overlays/azure
Rule set

Keep these in the base:

Namespace
Deployment
Service
ServiceAccount without cloud annotations
Istio Gateway
Istio VirtualService
ConfigMap with generic defaults
Probes
Resource requests and limits
Pod security context

Keep these in overlays:

Container registry path
Image tag
Cloud workload identity annotations
Cloud-specific storage class
Cloud-specific load balancer annotations
Environment-specific replica count
Environment-specific hostnames
Cloud-specific secret provider configuration

Do not put these in the app code:

GCP service account keys
AWS access keys
Azure client secrets
Cloud-specific config hardcoded into source
Cloud-specific ingress logic
Cloud-specific Kubernetes YAML in the base

The resulting model is:

Same container image pattern
Same Kubernetes base
Same Istio traffic model
Different Terraform module per cloud
Different Kustomize overlay per cloud

This keeps the workload portable while accepting that infrastructure provisioning itself is necessarily cloud-specific.
