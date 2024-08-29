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
      name = "letsencrypt-issuer"
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
