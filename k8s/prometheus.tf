locals {
  # Latest as of time of writing.
  # Found on: https://github.com/kubernetes-sigs/metrics-server/releases
  prometheus_server_version = "2.17.1"
}

resource "kubernetes_namespace" "prometheus" {
  metadata {
    name = "prometheus"
  }
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  chart      = "prometheus"
  repository = data.helm_repository.stable.metadata.0.name
  namespace  = kubernetes_namespace.prometheus.metadata.0.name

  set_string {
    name  = "alertmanager.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  set_string {
    name  = "nodeExporter.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  set_string {
    name  = "pushgateway.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  set_string {
    name  = "server.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
}

