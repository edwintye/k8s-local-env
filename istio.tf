resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

resource "null_resource" "istio" {
  provisioner "local-exec" {
    command = "istioctl install -f istio/custom-istio.yaml --set profile=minimal"
  }
  depends_on = [kubernetes_namespace.istio_system]
}

resource "kubectl_manifest" "istio-app-mtls" {
  yaml_body = templatefile("istio/peer-auth.yaml", {
    applicationNamespace = kubernetes_namespace.app.metadata[0].name
  })
  depends_on = [null_resource.istio, kubernetes_namespace.app]
}

resource "helm_release" "kiali" {
  name       = "kiali"
  repository = "https://kiali.org/helm-charts"
  chart      = "kiali-server"
  version    = "v1.29.0"

  values = [
    file("istio/kiali-values.yaml")
  ]

  namespace = kubernetes_namespace.istio_system.metadata[0].name
  depends_on = [kubernetes_namespace.istio_system]
  wait = true
}
