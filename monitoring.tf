resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "metrics-server" {
  name       = "metrics-server"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "metrics-server"
  version    = "5.4.0"

  values = [
    file("../monitoring/metrics-server-values.yaml")
  ]

  namespace = "kube-system"
  wait = true
}

resource "kubernetes_secret" "grafana-secret" {
  metadata {
    name = "grafana-secret"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  type = "Opaque"
  data = {
    "admin-user" = "admin"
    "admin-password" = "grafana"
  }

  depends_on = [kubernetes_namespace.monitoring]
}

resource "helm_release" "prometheus" {
  name = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart = "prometheus"
  version = "11.12.0"

  values = [
    file("../monitoring/prometheus-values.yaml")
  ]

  namespace = kubernetes_namespace.monitoring.metadata[0].name
  wait = false
  depends_on = [kubernetes_namespace.monitoring]
}

resource "helm_release" "grafana" {
  name = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart = "grafana"
  version = "6.2.1"

  values = [
    file("../monitoring/grafana-values.yaml")
  ]

  namespace = kubernetes_namespace.monitoring.metadata[0].name
  wait = false
  depends_on = [kubernetes_secret.grafana-secret, helm_release.prometheus]
}

output "prometheus-url" {
  value = "http://${helm_release.prometheus.metadata[0].name}-server.${helm_release.prometheus.metadata[0].namespace}.svc.cluster.local:9090"
  depends_on = [helm_release.prometheus]
}
