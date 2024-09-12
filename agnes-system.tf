resource "kubernetes_namespace" "agnes-system" {
  metadata {
    name = "agnes-system"
    labels = {
      "pod-security.kubernetes.io/enforce" : "privileged"
      "pod-security.kubernetes.io/audit" : "privileged"
      "pod-security.kubernetes.io/warn" : "privileged"
    }
  }
}

# traefik
resource "helm_release" "traefik" {
  name = "traefik"

  repository = "https://traefik.github.io/charts"
  chart      = "traefik"

  namespace  = kubernetes_namespace.agnes-system.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-system]
  values     = ["${file("./values/traefik/values.yaml")}"]

}

resource "kubernetes_manifest" "traefik_default_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "traefik-default-cert"
      namespace = kubernetes_namespace.agnes-system.metadata[0].name
    }
    spec = {
      secretName = "traefik-default-cert"
      issuerRef = {
        name = local.main-cert-issuer
        kind = "ClusterIssuer"
      }
      dnsNames = ["*.jitarth.com"]
    }
  }
}

# cert manager
resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"

  namespace  = kubernetes_namespace.agnes-system.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-system]
  set {
    name  = "crds.enabled"
    value = true
  }

}

# metallb
resource "helm_release" "metallb" {
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"

  namespace  = kubernetes_namespace.agnes-system.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-system]
}


resource "kubernetes_manifest" "metallb-address-pool" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "metallb-address-pool"
      namespace = kubernetes_namespace.agnes-system.metadata[0].name
    }
    spec = {
      addresses = ["10.0.0.129/32"]
    }
  }
  depends_on = [helm_release.metallb]
}


resource "kubernetes_manifest" "metallb-advertisement" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "metallb-advertisement"
      namespace = kubernetes_namespace.agnes-system.metadata[0].name
    }
    spec = {
      ipAddressPools = ["metallb-address-pool"]
      interfaces     = ["eno2"]
    }
  }
  depends_on = [helm_release.metallb]
}

# letsencrypt
resource "kubernetes_secret" "cloudflare-acme-token" {
  metadata {
    name      = "cloudflare-acme-token"
    namespace = kubernetes_namespace.agnes-system.metadata[0].name
  }
  data = {
    "cloudflare-token" = file("./secret-cloudflare-acme-token")
  }

}

resource "kubernetes_manifest" "letsencrypt-issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = local.main-cert-issuer
    }
    spec = {
      acme = {
        email  = chomp(file("./secret-email"))
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "cluster-issuer-account-key"
        }
        solvers = [{
          dns01 = {
            cloudflare = {
              email = chomp(file("./secret-email"))
              apiTokenSecretRef = {
                name = kubernetes_secret.cloudflare-acme-token.metadata[0].name
                key  = "cloudflare-token"
              }
            }
          }
        }]
      }
    }
  }
}

# intel gpu plugin
resource "helm_release" "nfd" {
  name       = "nfd"
  repository = "https://kubernetes-sigs.github.io/node-feature-discovery/charts"
  chart      = "node-feature-discovery"

  namespace  = kubernetes_namespace.agnes-system.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-system]
}


resource "helm_release" "intel-device-plugins-operator" {
  name       = "intel-device-plugins-operator"
  repository = "https://intel.github.io/helm-charts/"
  chart      = "intel-device-plugins-operator"

  namespace  = kubernetes_namespace.agnes-system.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-system, helm_release.nfd]
}


resource "helm_release" "intel-gpu-plugin" {
  name       = "intel-gpu-plugin"
  repository = "https://intel.github.io/helm-charts/"
  chart      = "intel-device-plugins-gpu"

  namespace  = kubernetes_namespace.agnes-system.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-system, helm_release.nfd, helm_release.intel-device-plugins-operator]
}

resource "helm_release" "kube-prometheus-stack" {
  name       = "kube-prometheus-stack"
  repository = local.prometheus-community-repo
  chart      = "kube-prometheus-stack"

  namespace  = kubernetes_namespace.agnes-system.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-system]
  values     = ["${file("./values/kube-prometheus-stack/values.yaml")}"]
}


#rook-ceph
# resource "helm_release" "rook-ceph-operator" {
#   name       = "rook-ceph"
#   repository = local.rook-repo
#   chart      = "rook-ceph"

#   set {
#     name  = "enableDiscoveryDaemon"
#     value = true
#   }

#   namespace  = kubernetes_namespace.agnes-system.metadata[0].name
#   depends_on = [kubernetes_namespace.agnes-system]

# }

# resource "helm_release" "rook-ceph-cluster" {
#   name       = "rook-ceph-cluster"
#   repository = local.rook-repo
#   chart      = "rook-ceph-cluster"

#   namespace  = kubernetes_namespace.agnes-system.metadata[0].name
#   depends_on = [kubernetes_namespace.agnes-system, helm_release.rook-ceph-operator]
#   values     = ["${file("./values/rook-ceph-cluster/values.yaml")}"]
# }

# longhorn
# resource "helm_release" "longhorn" {
#   name       = "longhorn"
#   repository = local.longhorn-repo
#   chart      = "longhorn"

#   values = ["${file("./values/longhorn/values.yaml")}"]


#   namespace  = kubernetes_namespace.agnes-system.metadata[0].name
#   depends_on = [kubernetes_namespace.agnes-system]

# }

#openebs
resource "helm_release" "openebs" {
  name       = "openebs"
  repository = local.openebs-repo
  chart      = "openebs"

  values = ["${file("./values/openebs/values.yaml")}"]


  namespace  = kubernetes_namespace.agnes-system.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-system]

}

resource "kubernetes_storage_class" "openebs-lvm-storageclass" {
  metadata {
    name = "openebs-lvmpv"
  }
  storage_provisioner = "local.csi.openebs.io"
  parameters = {
    storage  = "lvm"
    volgroup = "lvmvg"
    fsType   = "xfs"
    shared   = "yes"
  }
  allow_volume_expansion = true
}

