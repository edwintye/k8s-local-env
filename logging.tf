resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
  }
}

resource "helm_release" "es" {
  name = "es"
  repository = "https://helm.elastic.co"
  chart = "elasticsearch"
  version = "7.9.0"

  values = [
    file("logging/elasticsearch-values.yaml")
  ]

  set {
    name = "fullnameOverride"
    value = "elasticsearch"
  }

  set {
    name = "volumeClaimTemplate.accessModes"
    value = "ReadWriteOnce"
  }

  set {
    name = "volumeClaimTemplate.storageClassName"
    value = var.storage_class_name[var.cluster_type]
  }

  set {
    name = "volumeClaimTemplate.resources.requests.storage"
    value = "100M"
  }

  namespace = kubernetes_namespace.logging.metadata[0].name
  wait = true
  depends_on = [kubernetes_namespace.logging]
}

resource "helm_release" "fluent-bit" {
  name = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart = "fluent-bit"
  version = "0.12.3"

  namespace = kubernetes_namespace.logging.metadata[0].name
  wait = true
  depends_on = [
    helm_release.es
  ]
}

resource "helm_release" "kibana" {
  name = "kibana"
  repository = "https://helm.elastic.co"
  chart = "kibana"
  version = "7.9.0"

  values = [
    file("logging/kibana-values.yaml")
  ]

  set {
    name = "elasticsearchHosts"
    value = "http://elasticsearch:9200"
  }

  set {
    name = "service.type"
    value = var.cluster_type == "kind" ? "ClusterIP" : "NodePort"
  }

  set {
    name = "service.nodePort"
    value = var.cluster_type == "kind" ? "" : "31000"
  }

  namespace = kubernetes_namespace.logging.metadata[0].name
  depends_on = [
    helm_release.es,
    helm_release.fluent-bit
  ]
}
