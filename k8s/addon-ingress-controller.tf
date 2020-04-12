locals {
  # Latest as of time of writing.
  # Found using 'helm search repo nginx-ingress'
  nginx_ingress_chart_version = "1.36.2" # maps to AppVersion 0.30.0
}

resource "kubernetes_namespace" "nginx_ingress" {
  metadata {
    name = "nginx-ingress"
  }
}

data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  chart      = "nginx-ingress"
  version    = local.nginx_ingress_chart_version
  repository = data.helm_repository.stable.metadata.0.name
  namespace  = kubernetes_namespace.nginx_ingress.metadata.0.name

  set {
    name  = "controller.metrics.enabled"
    value = true
  }

  set_string {
    name  = "controller.metrics.service.annotations.prometheus\\.io/scrape"
    value = "true"
  }

  set {
    name  = "controller.service.type"
    value = "NodePort"
  }

  set {
    name  = "controller.service.nodePorts.http"
    value = local.ingress_controller_node_ports.http
  }

  set {
    name  = "controller.service.nodePorts.https"
    value = local.ingress_controller_node_ports.https
  }

  # Preserve the source IP for incoming requests
  # https://kubernetes.io/docs/tutorials/services/source-ip/#source-ip-for-services-with-typenodeport
  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "controller.extraArgs.publish-status-address"
    value = module.lb.this_lb_dns_name
  }

  # Ensure pods are scheduled on Linux nodes only
  set_string {
    name  = "controller.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  set_string {
    name  = "defaultBackend.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  depends_on = [
    module.eks,
    module.lb,
  ]
}

