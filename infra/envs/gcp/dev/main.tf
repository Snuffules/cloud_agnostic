terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source = "hashicorp/google"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    helm = {
      source = "hashicorp/helm"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

resource "google_container_cluster" "main" {
  name     = var.cluster_name
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {}

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false
}

resource "google_container_node_pool" "primary" {
  name       = "primary"
  cluster    = google_container_cluster.main.name
  location   = var.region
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

provider "kubernetes" {
  host  = "https://${google_container_cluster.main.endpoint}"
  token = data.google_client_config.default.access_token

  cluster_ca_certificate = base64decode(
    google_container_cluster.main.master_auth[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes = {
    host  = "https://${google_container_cluster.main.endpoint}"
    token = data.google_client_config.default.access_token

    cluster_ca_certificate = base64decode(
      google_container_cluster.main.master_auth[0].cluster_ca_certificate
    )
  }
}

module "istio" {
  source = "../../modules/istio"

  istio_version = var.istio_version

  gateway_service_annotations = {
    # GCP-specific annotations can go here if needed.
  }
}
