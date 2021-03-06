locals {
  # Latest as of time of writing.
  # Found using 'helm search hub metrics-sever'
  #
  # Chart 2.11.0 points to AppVersion 0.3.6 of metrics-server
  metrics_server_chart_version = "2.11.0"
}

resource "kubernetes_namespace" "metrics_server" {
  metadata {
    name = "metrics-server"
  }
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  chart      = "metrics-server"
  version    = local.metrics_server_chart_version
  repository = data.helm_repository.stable.metadata.0.name
  namespace  = kubernetes_namespace.metrics_server.metadata.0.name

  set_string {
    name  = "nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
}
