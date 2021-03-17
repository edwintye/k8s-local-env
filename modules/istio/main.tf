terraform {
  required_version = ">= 0.14"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">=3.1.0"
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

resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

resource "null_resource" "istio" {
  provisioner "local-exec" {
    command = "istioctl install -f ${path.module}/custom-istio.yaml --set profile=minimal --skip-confirmation"
  }
  depends_on = [
    kubernetes_namespace.istio_system
  ]
}

resource "kubectl_manifest" "istio-app-mtls" {
  yaml_body = templatefile("${path.module}/peer-auth.yaml", {
    applicationNamespace = kubernetes_namespace.app.metadata[0].name
  })
  depends_on = [
    null_resource.istio,
    kubernetes_namespace.app
  ]
}

resource "helm_release" "kiali" {
  name       = "kiali"
  repository = "https://kiali.org/helm-charts"
  chart      = "kiali-server"
  version    = "v1.29.0"

  values = [
    file("${path.module}/kiali-values.yaml")
  ]

  namespace = kubernetes_namespace.istio_system.metadata[0].name
  depends_on = [
    kubernetes_namespace.istio_system
  ]
  wait = true
}

output "kiali-ui" {
  value = "http://${helm_release.kiali.name}.${helm_release.kiali.namespace}:20001/kiali"
  depends_on = [
    helm_release.kiali
  ]
}

