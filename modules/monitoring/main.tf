terraform {
  required_version = ">= 0.14"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.0.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.0.3"
    }
  }
}

provider "kubernetes" {
  config_context = var.kube_context
  config_path    = var.kube_config
}

provider "helm" {
  kubernetes {
    config_context = var.kube_context
    config_path    = var.kube_config
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "metrics-server" {
  // although we are installing this from a monitoring module, we are only doing this
  // because we don't have a kube-system module atm
  name       = "metrics-server"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "metrics-server"
  version    = "5.4.0"

  values = [
    file("${path.module}/metrics-server-values.yaml")
  ]

  namespace = "kube-system"
  wait      = true
}

resource "kubernetes_secret" "grafana-secret" {
  metadata {
    name      = "grafana-secret"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  type = "Opaque"
  data = {
    "admin-user"     = "admin"
    "admin-password" = "grafana"
  }

  depends_on = [
    kubernetes_namespace.monitoring
  ]
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "11.12.0"

  values = [
    file("${path.module}/prometheus-values.yaml")
  ]

  namespace = kubernetes_namespace.monitoring.metadata[0].name
  wait      = false
  depends_on = [
    kubernetes_namespace.monitoring
  ]
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "6.2.1"

  values = [
    file("${path.module}/grafana-values.yaml")
  ]

  namespace = kubernetes_namespace.monitoring.metadata[0].name
  wait      = false
  depends_on = [
    kubernetes_secret.grafana-secret,
    helm_release.prometheus
  ]
}
