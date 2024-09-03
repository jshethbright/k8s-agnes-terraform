resource "kubernetes_namespace" "agnes-apps" {
  metadata {
    name = "agnes-apps"
    labels = {
      "pod-security.kubernetes.io/enforce" : "privileged"
      "pod-security.kubernetes.io/audit" : "privileged"
      "pod-security.kubernetes.io/warn" : "privileged"
    }
  }
}


resource "kubernetes_persistent_volume_claim" "main-storage" {
  metadata {
    name      = "main-storage"
    namespace = kubernetes_namespace.agnes-apps.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        "storage" : "1300Gi"
      }
    }
    storage_class_name = kubernetes_storage_class.openebs-lvm-storageclass.metadata[0].name
  }
}

resource "helm_release" "jellyfin" {
  name  = "jellyfin"
  chart = "oci://tccr.io/truecharts/jellyfin"

  namespace  = kubernetes_namespace.agnes-apps.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-apps, kubernetes_persistent_volume_claim.main-storage]
  values     = ["${file("./values/jellyfin/values.yaml")}"]

  set {
    name  = "persistance.media.existingClaim"
    value = kubernetes_persistent_volume_claim.main-storage.metadata[0].name
  }

  set {
    name  = "persistance.media.dataSource.name"
    value = kubernetes_persistent_volume_claim.main-storage.metadata[0].name
  }
}

# resource "kubernetes_secret" "samba-creds" {
#   metadata {
#     name      = "samba-creds"
#     namespace = kubernetes_namespace.agnes-apps.metadata[0].name
#   }

#   data = {
#     username = "admin"
#     password = file("./secret-samba-password")
#   }
# }

# #ubuntu deployment
resource "kubernetes_deployment" "ubuntu-debug" {
  metadata {
    name      = "ubuntu-debug"
    namespace = kubernetes_namespace.agnes-apps.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "ubuntu"
      }
    }
    template {
      metadata {
        labels = {
          app = "ubuntu"
        }
      }
      spec {
        container {
          name    = "ubuntu"
          image   = "ubuntu:latest"
          command = ["/bin/bash", "-c", "--"]
          args    = ["while true; do sleep 30; done;"]
          security_context {
            privileged = true
          }
          volume_mount {
            name       = "main-storage"
            mount_path = "/mnt/main-storage"
          }
          volume_mount {
            name       = "host-storage"
            mount_path = "/mnt/host-storage"
          }

        }
        volume {
          name = "main-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.main-storage.metadata[0].name
          }
        }
        volume {
          name = "host-storage"
          host_path {
            path = "/var"
            type = "Directory"
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.agnes-system, helm_release.nfd, helm_release.intel-device-plugins-operator]


}


# resource "helm_release" "samba" {
#   name       = "samba"
#   repository = local.agnes-repo
#   chart      = "samba"
#   version    = "0.5.0"

#   namespace  = kubernetes_namespace.agnes-apps.metadata[0].name
#   depends_on = [kubernetes_namespace.agnes-apps, kubernetes_secret.samba-creds, kubernetes_persistent_volume_claim.main-storage]
#   values     = ["${file("./values/samba/values.yaml")}"]

#   set {
#     name  = "secretRefs.sambaCreds.name"
#     value = kubernetes_secret.samba-creds.metadata[0].name
#   }
# }
