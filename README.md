# cloud_agnostic
gcp, aws, azure, k8s, istio, helm, kustomize

##Contents:

Terraform = cloud infrastructure, Kubernetes cluster, IAM, registry, Istio install.
Kustomize = portable Kubernetes workload manifests plus per-cloud overlays.
Application code = cloud-neutral container.

##Repository layout

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
