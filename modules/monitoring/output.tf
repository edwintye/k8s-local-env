output "prometheus-url" {
  value = "http://${helm_release.prometheus.metadata[0].name}-server.${helm_release.prometheus.metadata[0].namespace}.svc:9090"
  depends_on = [
    helm_release.prometheus
  ]
}