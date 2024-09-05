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
  name    = "jellyfin"
  chart   = "oci://tccr.io/truecharts/jellyfin"
  version = "20.1.20"

  namespace  = kubernetes_namespace.agnes-apps.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-apps, kubernetes_persistent_volume_claim.main-storage]
  values     = ["${file("./values/jellyfin/values.yaml")}"]

  set {
    name  = "persistence.media.existingClaim"
    value = kubernetes_persistent_volume_claim.main-storage.metadata[0].name
  }

  set {
    name  = "persistence.media.dataSource.name"
    value = kubernetes_persistent_volume_claim.main-storage.metadata[0].name
  }
}

resource "kubernetes_secret" "cloudflare-tunnel-creds" {
  metadata {
    name      = "cloudflare-tunnel-creds"
    namespace = kubernetes_namespace.agnes-apps.metadata[0].name
  }

  data = {
    "credentials.json" = "${file("secret-tunnel-credentials.json")}"
  }
}

# cloudflare tunnel
resource "helm_release" "cloudflare-tunnel" {
  name       = "cloudflare-tunnel"
  repository = local.cloudflare-repo
  chart      = "cloudflare-tunnel"
  namespace  = kubernetes_namespace.agnes-apps.metadata[0].name
  version    = "0.3.2"

  values = ["${file("./values/cloudflare-tunnel/values.yaml")}"]

  set {
    name  = "cloudflare.secretName"
    value = kubernetes_secret.cloudflare-tunnel-creds.metadata[0].name
  }

  set {
    name  = "cloudflare.tunnelName"
    value = "agnes-server-tunnel"
  }

  depends_on = [kubernetes_secret.cloudflare-tunnel-creds]
}

# qbit
resource "helm_release" "qbittorrent" {
  name    = "qbittorrent"
  chart   = "oci://tccr.io/truecharts/qbittorrent"
  version = "21.1.8"

  namespace  = kubernetes_namespace.agnes-apps.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-apps, kubernetes_persistent_volume_claim.main-storage]
  values     = ["${file("./values/qbittorrent/values.yaml")}"]

  set {
    name  = "persistence.media.existingClaim"
    value = kubernetes_persistent_volume_claim.main-storage.metadata[0].name
  }

  set {
    name  = "persistence.media.dataSource.name"
    value = kubernetes_persistent_volume_claim.main-storage.metadata[0].name
  }
}

resource "helm_release" "radarr" {
  name    = "radarr"
  chart   = "oci://tccr.io/truecharts/radarr"
  version = "23.4.4"

  namespace  = kubernetes_namespace.agnes-apps.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-apps, kubernetes_persistent_volume_claim.main-storage]
  values     = ["${file("./values/radarr/values.yaml")}"]

  set {
    name  = "persistence.media.existingClaim"
    value = kubernetes_persistent_volume_claim.main-storage.metadata[0].name
  }

  set {
    name  = "persistence.media.dataSource.name"
    value = kubernetes_persistent_volume_claim.main-storage.metadata[0].name
  }
}


resource "helm_release" "sonarr" {
  name    = "sonarr"
  chart   = "oci://tccr.io/truecharts/sonarr"
  version = "23.1.8"

  namespace  = kubernetes_namespace.agnes-apps.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-apps, kubernetes_persistent_volume_claim.main-storage]
  values     = ["${file("./values/sonarr/values.yaml")}"]

  set {
    name  = "persistence.media.existingClaim"
    value = kubernetes_persistent_volume_claim.main-storage.metadata[0].name
  }

  set {
    name  = "persistence.media.dataSource.name"
    value = kubernetes_persistent_volume_claim.main-storage.metadata[0].name
  }
}


resource "helm_release" "prowlarr" {
  name    = "prowlarr"
  chart   = "oci://tccr.io/truecharts/prowlarr"
  version = "18.4.0"

  namespace  = kubernetes_namespace.agnes-apps.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-apps, kubernetes_persistent_volume_claim.main-storage]
  values     = ["${file("./values/prowlarr/values.yaml")}"]

}


resource "helm_release" "recyclarr" {
  name    = "recyclarr"
  chart   = "oci://tccr.io/truecharts/recyclarr"
  version = "12.2.4"

  namespace  = kubernetes_namespace.agnes-apps.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-apps, kubernetes_persistent_volume_claim.main-storage]
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
    replicas = 0
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
