terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Namespaces
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/name" = "argocd"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/name" = "monitoring"
    }
  }
}

resource "kubernetes_namespace" "loki" {
  metadata {
    name = "loki"
    labels = {
      "app.kubernetes.io/name" = "loki"
    }
  }
}

resource "kubernetes_namespace" "velero" {
  metadata {
    name = "velero"
    labels = {
      "app.kubernetes.io/name" = "velero"
    }
  }
}

resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
    labels = {
      "app.kubernetes.io/name" = "ingress-nginx"
    }
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
    labels = {
      "app.kubernetes.io/name" = "cert-manager"
    }
  }
}

# Custom StorageClass for USB storage
resource "kubernetes_storage_class" "usb_storage" {
  metadata {
    name = "usb-storage"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }
  storage_provisioner    = "rancher.io/local-path"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    nodePath = "/mnt/usb-data"
  }
}

# Secret for DuckDNS (placeholder - update with actual token)
resource "kubernetes_secret" "duckdns_token" {
  metadata {
    name      = "duckdns-token"
    namespace = "cert-manager"
  }

  data = {
    token = "YOUR_DUCKDNS_TOKEN_HERE" # TODO: Replace with actual token
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.cert_manager]
}

# ClusterIssuer for Let's Encrypt
resource "kubernetes_manifest" "letsencrypt_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = "admin@example.com" # TODO: Replace with actual email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [kubernetes_namespace.cert_manager]
}

# PersistentVolumeClaims for applications
resource "kubernetes_persistent_volume_claim" "postgres_data" {
  metadata {
    name      = "postgres-data"
    namespace = "default"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.usb_storage.metadata[0].name

    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "prometheus_data" {
  metadata {
    name      = "prometheus-data"
    namespace = "monitoring"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.usb_storage.metadata[0].name

    resources {
      requests = {
        storage = "3Gi"
      }
    }
  }

  depends_on = [kubernetes_namespace.monitoring]
}

resource "kubernetes_persistent_volume_claim" "loki_data" {
  metadata {
    name      = "loki-data"
    namespace = "loki"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.usb_storage.metadata[0].name

    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }

  depends_on = [kubernetes_namespace.loki]
}

# ConfigMap for application configuration
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "app-config"
    namespace = "default"
  }

  data = {
    "DATABASE_HOST"     = "postgres-service"
    "DATABASE_PORT"     = "5432"
    "DATABASE_NAME"     = "appdb"
    "REDIS_HOST"        = "redis-service"
    "REDIS_PORT"        = "6379"
    "LOG_LEVEL"         = "info"
    "METRICS_ENABLED"   = "true"
    "HEALTH_CHECK_PATH" = "/health"
  }
}

# Outputs
output "storage_class_name" {
  description = "Name of the custom storage class"
  value       = kubernetes_storage_class.usb_storage.metadata[0].name
}

output "namespaces" {
  description = "Created namespaces"
  value = {
    argocd        = kubernetes_namespace.argocd.metadata[0].name
    monitoring    = kubernetes_namespace.monitoring.metadata[0].name
    loki          = kubernetes_namespace.loki.metadata[0].name
    velero        = kubernetes_namespace.velero.metadata[0].name
    ingress_nginx = kubernetes_namespace.ingress_nginx.metadata[0].name
    cert_manager  = kubernetes_namespace.cert_manager.metadata[0].name
  }
}
