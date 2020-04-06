locals {
  # Latest as of time of writing.
  # Found on: https://github.com/kubernetes-sigs/metrics-server/releases
  metrics_server_version = "0.3.6"
}

resource "kubernetes_namespace" "metrics_server" {
  metadata {
    name = "metrics-server"
  }
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  chart      = "metrics-server"
  repository = data.helm_repository.stable.metadata.0.name
  namespace  = kubernetes_namespace.metrics_server.metadata.0.name

  set {
    name  = "image.tag"
    value = "v${local.metrics_server_version}"
  }

  set_string {
    name  = "nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
}
