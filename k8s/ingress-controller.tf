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
  repository = data.helm_repository.stable.metadata.0.name
  chart      = "nginx-ingress"
  namespace  = kubernetes_namespace.nginx_ingress.metadata.0.name

  values = [
    file("ingress-values.yaml"),
  ]

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

  depends_on = [
    module.eks,
    module.lb,
  ]
}

