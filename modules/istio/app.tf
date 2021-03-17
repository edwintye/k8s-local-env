resource "kubernetes_namespace" "app" {
  metadata {
    name = "app"
    labels = {
      istio-injection = "enabled"
    }
  }
}
