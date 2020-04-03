locals {
  iis_sample_hostname = "iis.${local.dns_subdomain}.${local.parent_dns_zone}"
}

resource "kubernetes_namespace" "iis" {
  metadata {
    name = "iis-sample"
  }
}

resource "kubernetes_deployment" "iis" {
  count = var.windows_workers_count > 0 ? 1 : 0

  metadata {
    name      = "windows-iis"
    namespace = kubernetes_namespace.iis.metadata.0.name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "windows-iis"
      }
    }

    template {
      metadata {
        labels = {
          app = "windows-iis"
        }
      }

      spec {
        container {
          image = "mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2019"
          name  = "iis"

          port {
            name           = "http"
            container_port = 80
          }
        }

        node_selector = {
          "beta.kubernetes.io/os" = "windows"
        }
      }
    }
  }
}

resource "kubernetes_service" "iis" {
  count = var.windows_workers_count > 0 ? 1 : 0

  metadata {
    name      = "windows-iis"
    namespace = kubernetes_namespace.iis.metadata.0.name
  }

  spec {
    selector = {
      app = kubernetes_deployment.iis.0.spec.0.template.0.metadata.0.labels.app
    }

    port {
      port        = 8080
      target_port = kubernetes_deployment.iis.0.spec.0.template.0.spec.0.container.0.port.0.container_port
    }
  }
}

resource "kubernetes_ingress" "iis" {
  count = var.windows_workers_count > 0 ? 1 : 0

  metadata {
    name      = "windows-iis"
    namespace = kubernetes_namespace.iis.metadata.0.name

    annotations = {
      # Ensures this Ingress object is picked up by our Nginx Ingress Controller
      "kubernetes.io/ingress.class" = "nginx"

      # Ensures cert-manager generates a cert for us to use.
      #
      # Note: Using the staging issuer to avoid hitting any limits on
      # Let's Encrypt's production issuer.
      "cert-manager.io/cluster-issuer" = "letsencrypt-staging"
    }
  }

  spec {
    rule {
      host = local.iis_sample_hostname

      http {
        path {
          backend {
            service_name = kubernetes_service.iis.0.metadata.0.name
            service_port = kubernetes_service.iis.0.spec.0.port.0.port
          }
        }
      }
    }

    tls {
      hosts = [
        local.iis_sample_hostname
      ]

      # Name of the 'Secret' which will hold the cert's private key
      secret_name = "windows-iis-tls"
    }
  }

  depends_on = [
    helm_release.cert_manager,
    helm_release.external_dns,
  ]
}

output "iis_sample_url" {
  value = "https://${local.iis_sample_hostname}"
}
