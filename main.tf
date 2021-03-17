terraform {
  required_version = ">= 0.14"
}

module "istio" {
  source = "./modules/istio"
  kube_config = var.kube_config
  kube_context = var.kube_context
}

module "logging" {
  source = "./modules/logging"
  kube_config = var.kube_config
  kube_context = var.kube_context
}

module "monitoring" {
  source = "./modules/monitoring"
  kube_config = var.kube_config
  kube_context = var.kube_context
}

module "observability" {
  source = "./modules/observability"
  kube_config = var.kube_config
  kube_context = var.kube_context
}
