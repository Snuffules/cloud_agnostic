# cloud_agnostic
gcp, aws, azure, k8s, istio, helm, kustomize

##Contents:

Terraform = cloud infrastructure, Kubernetes cluster, IAM, registry, Istio install.

Kustomize = portable Kubernetes workload manifests plus per-cloud overlays.

Application code = cloud-neutral container.

##Istio Gateway:
describes ingress traffic entering the mesh, while VirtualService routes that traffic to services. This is portable across GKE, EKS, and AKS because it targets Istio and Kubernetes APIs, not cloud-specific ingress resources.

##Repository layout

<img width="409" height="678" alt="{FB3B6475-A522-40CE-A21C-FE16AEA53051}" src="https://github.com/user-attachments/assets/d3a80f21-d96a-4268-a3d2-4af014c5a484" />

