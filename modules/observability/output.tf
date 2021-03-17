output "jaeger-ui" {
  value      = "http://${kubernetes_service.jaeger.metadata[0].name}.${kubernetes_service.jaeger.metadata[0].namespace}.svc:${kubernetes_service.jaeger.spec[0].port[3].port}"
  depends_on = [kubernetes_deployment.jaeger, kubernetes_service.jaeger]
}
