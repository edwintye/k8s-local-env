terraform {
  required_version = ">= 0.14"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.0.0"
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

resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
  }
}

resource "helm_release" "es" {
  name       = "es"
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  version    = "7.9.0"

  values = [
    file("${path.module}/elasticsearch-values.yaml")
  ]

  set {
    name  = "fullnameOverride"
    value = "elasticsearch"
  }

  set {
    name  = "volumeClaimTemplate.accessModes"
    value = "ReadWriteOnce"
  }

  set {
    name  = "volumeClaimTemplate.storageClassName"
    value = var.storage_class_name[var.cluster_type]
  }

  set {
    name  = "volumeClaimTemplate.resources.requests.storage"
    value = "100M"
  }

  namespace  = kubernetes_namespace.logging.metadata[0].name
  wait       = true
  depends_on = [kubernetes_namespace.logging]
}

resource "helm_release" "fluent-bit" {
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  version    = "0.12.3"

  values = [
    file("${path.module}/fluentbit-values.yaml")
  ]

  namespace = kubernetes_namespace.logging.metadata[0].name
  wait      = true
  depends_on = [
    helm_release.es
  ]
}

resource "helm_release" "kibana" {
  name       = "kibana"
  repository = "https://helm.elastic.co"
  chart      = "kibana"
  version    = "7.9.0"

  values = [
    file("${path.module}/kibana-values.yaml")
  ]

  set {
    name  = "elasticsearchHosts"
    value = "http://elasticsearch:9200"
  }

  set {
    name  = "service.type"
    value = var.cluster_type == "kind" ? "ClusterIP" : "NodePort"
  }

  set {
    name  = "service.nodePort"
    value = var.cluster_type == "kind" ? "" : "31000"
  }

  namespace = kubernetes_namespace.logging.metadata[0].name
  depends_on = [
    helm_release.es,
    helm_release.fluent-bit
  ]
}
