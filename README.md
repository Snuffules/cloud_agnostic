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

## Portability Model

This keeps the workload portable while accepting that infrastructure provisioning itself is necessarily cloud-specific.

## About Containers

Container images should be built separately from Terraform and Kustomize, then pushed to a container registry.

## Where the Images Go

Use one of the following patterns.

### Option 1: Separate Registry per Cloud

| Cloud | Registry                   |
| ----- | -------------------------- |
| GCP   | Artifact Registry          |
| AWS   | Elastic Container Registry |
| Azure | Azure Container Registry   |

Example image paths:

```text
GCP:
us-docker.pkg.dev/PROJECT_ID/myapp/myapp:v1.0.0

AWS:
ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/myapp:v1.0.0

Azure:
ACR_NAME.azurecr.io/myapp:v1.0.0
```

This is the cleanest enterprise model.

### Option 2: One Shared Registry

Use one registry for all clusters:

```text
ghcr.io/YOUR_ORG/myapp:v1.0.0
docker.io/YOUR_ORG/myapp:v1.0.0
```

This is simpler and more cloud-agnostic.

## How Kubernetes Connects to the Container

The base `Deployment` should use a placeholder image:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: myapp
  template:
    metadata:
      labels:
        app.kubernetes.io/name: myapp
    spec:
      containers:
        - name: myapp
          image: app-image
          ports:
            - containerPort: 8080
```

Each Kustomize overlay replaces `app-image`.

### GCP

```yaml
images:
  - name: app-image
    newName: us-docker.pkg.dev/PROJECT_ID/myapp/myapp
    newTag: v1.0.0
```

### AWS

```yaml
images:
  - name: app-image
    newName: ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/myapp
    newTag: v1.0.0
```

### Azure

```yaml
images:
  - name: app-image
    newName: ACR_NAME.azurecr.io/myapp
    newTag: v1.0.0
```

## How Istio Connects to the Container

Istio does not connect directly to the container image.

Istio routes traffic to the Kubernetes `Service`.

```text
User
 ↓
Cloud Load Balancer
 ↓
Istio Ingress Gateway
 ↓
Istio Gateway
 ↓
Istio VirtualService
 ↓
Kubernetes Service
 ↓
Pod
 ↓
Container
```

The Kubernetes `Service` targets the app pods:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: myapp
spec:
  selector:
    app.kubernetes.io/name: myapp
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

The Istio `VirtualService` routes traffic to that service:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: myapp
  namespace: myapp
spec:
  hosts:
    - "*"
  gateways:
    - myapp-gateway
  http:
    - route:
        - destination:
            host: myapp.myapp.svc.cluster.local
            port:
              number: 80
```

## Build and Push Examples

### GCP

```bash
docker build -t us-docker.pkg.dev/PROJECT_ID/myapp/myapp:v1.0.0 ./apps/myapp
docker push us-docker.pkg.dev/PROJECT_ID/myapp/myapp:v1.0.0
kubectl apply -k k8s/overlays/gcp
```

### AWS

```bash
docker build -t ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/myapp:v1.0.0 ./apps/myapp
docker push ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/myapp:v1.0.0
kubectl apply -k k8s/overlays/aws
```

### Azure

```bash
docker build -t ACR_NAME.azurecr.io/myapp:v1.0.0 ./apps/myapp
docker push ACR_NAME.azurecr.io/myapp:v1.0.0
kubectl apply -k k8s/overlays/azure
```

## Final Structure

### Terraform

* Creates GKE, EKS, or AKS
* Creates the container registry
* Configures cluster identity
* Installs Istio

### Docker

* Builds the application into an OCI image

### Registry

* Stores the built image

### Kustomize

* Points Kubernetes to the correct image per cloud

### Kubernetes

* Runs the container as a Pod

### Istio

* Exposes and routes traffic to the Kubernetes `Service`

## TODO: Executable Deployment Approach

Use this section if the repository should become executable instead of descriptive.

Required changes for executable deployment:

### Add Application Source and Dockerfile

```text
apps/myapp/
├── Dockerfile
└── src/
```

### Use a Placeholder Image in the Base Deployment

```yaml
image: app-image
```

### Replace the Image in Each Kustomize Overlay

```yaml
images:
  - name: app-image
    newName: us-docker.pkg.dev/PROJECT_ID/myapp/myapp
    newTag: v1.0.0
```

### Make Sure the Container Exposes the Expected Port

```yaml
containerPort: 8080
```

The application must listen on the same port, for example `8080`.

### Build and Push the Image Before Applying Kustomize

```bash
docker build -t REGISTRY/myapp:v1.0.0 ./apps/myapp
docker push REGISTRY/myapp:v1.0.0
kubectl apply -k k8s/overlays/gcp
```

