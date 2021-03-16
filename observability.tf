resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
  }
}

resource "kubernetes_deployment" "jaeger" {
  metadata {
    name      = "jaeger"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels = {
      app = "jaeger"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "jaeger"
      }
    }
    template {
      metadata {
        labels = {
          app = "jaeger"
        }
        annotations = {
          "sidecar.istio.io/inject" = "false"
          "prometheus.io/scrape"    = "true"
          "prometheus.io/port"      = "14269"
        }
      }
      spec {
        container {
          name  = "jaeger"
          image = "docker.io/jaegertracing/all-in-one:1.22"
          port {
            container_port = 5775
            name           = "zk-compact-trft"
            protocol       = "UDP"
          }
          port {
            container_port = 5778
            name           = "config-rest"
            protocol       = "TCP"
          }
          port {
            container_port = 6831
            name           = "jg-compact-trft"
            protocol       = "UDP"
          }
          port {
            container_port = 6832
            name           = "jg-binary-trft"
            protocol       = "UDP"
          }
          port {
            container_port = 9411
            name           = "zipkin"
            protocol       = "TCP"
          }
          port {
            container_port = 14250
            name           = "grpc"
            protocol       = "TCP"
          }
          port {
            container_port = 14267
            name           = "c-tchan-trft"
            protocol       = "TCP"
          }
          port {
            container_port = 14268
            name           = "c-binary-trft"
            protocol       = "TCP"
          }
          port {
            container_port = 14269
            name           = "admin-http"
            protocol       = "TCP"
          }
          port {
            container_port = 16686
            name           = "query"
            protocol       = "TCP"
          }
          liveness_probe {
            http_get {
              path = "/"
              port = "14269"
            }
          }
          readiness_probe {
            http_get {
              path = "/"
              port = "14269"
            }
          }
          volume_mount {
            name       = "data"
            mount_path = "/badger"
          }
          resources {
            requests {
              cpu = "10m"
            }
          }
        }
        volume {
          name = "data"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "jaeger" {
  metadata {
    name      = "jaeger"
    namespace = kubernetes_namespace.observability.metadata[0].name
  }
  spec {
    selector = {
      app = "jaeger"
    }
    port {
      port        = 9411
      target_port = "9411"
      name        = "http-query"
      protocol    = "TCP"
    }
    port {
      port        = 14268
      target_port = "14268"
      name        = "jaeger-collector-http"
      protocol    = "TCP"
    }
    port {
      port        = 14250
      target_port = "14250"
      name        = "jaeger-collector-grpc"
      protocol    = "TCP"
    }
    port {
      port        = 16686
      target_port = "16686"
      name        = "ui"
      protocol    = "TCP"
    }
  }
}

output "jaeger-ui" {
  value      = "http://${kubernetes_service.jaeger.metadata[0].name}.${kubernetes_service.jaeger.metadata[0].namespace}.svc:${kubernetes_service.jaeger.spec[0].port[3].port}"
  depends_on = [kubernetes_deployment.jaeger, kubernetes_service.jaeger]
}

