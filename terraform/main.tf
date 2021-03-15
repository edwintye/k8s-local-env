terraform {
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

provider "kubernetes" {
  config_context = var.kube_context
  config_path = var.kube_config
}

provider "helm" {
  kubernetes {
    config_context = var.kube_context
    config_path = var.kube_config
  }
}

provider "null" {}