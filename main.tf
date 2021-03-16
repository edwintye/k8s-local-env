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
  config_path    = var.kube_config
  version        = "2.0.2"
}

provider "helm" {
  kubernetes {
    config_context = var.kube_context
    config_path    = var.kube_config
  }
  version = "2.0.3"
}

provider "null" {
  version = "3.1.0"
}