resource "kubernetes_namespace" "sdost" {
  metadata {
    name = "sdost"
  }
}

resource "helm_release" "littlelink" {
  name      = "littlelink"
  chart     = "oci://tccr.io/truecharts/littlelink"
  namespace = kubernetes_namespace.sdost.metadata[0].name
  version   = "15.1.15"
  values    = ["${file("./values/littlelink/values.yaml")}"]
}



resource "kubernetes_manifest" "parts-sdost-middleware" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "parts-sdost-middleware"
      namespace = kubernetes_namespace.sdost.metadata[0].name
    }
    spec = {
      redirectRegex = {
        regex       = "^https?://parts.sdost.org/(.*)"
        replacement = "https://drive.google.com/drive/u/0/folders/1v_kgz6pXpVgL174fQoMzARcpgW1zd8L5"
        permanent   = true
      }
    }
  }
  depends_on = [kubernetes_namespace.sdost, helm_release.traefik]
}


resource "kubernetes_ingress_v1" "parts-sdost-ingress" {
  metadata {
    name      = "parts-sdost-ingress"
    namespace = kubernetes_namespace.sdost.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"                   = "letsencrypt-issuer"
      "traefik.ingress.kubernetes.io/router.middlewares" = format("%s-parts-sdost-middleware@kubernetescrd", kubernetes_namespace.sdost.metadata[0].name)
    }
  }
  spec {
    ingress_class_name = "traefik"
    rule {
      host = "parts.sdost.org"
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = helm_release.littlelink.name
              port {
                number = 10040
              }
            }
          }
        }
      }
    }
    tls {
      hosts       = ["parts.sdost.org"]
      secret_name = "parts-sdost-tls"
    }
  }
  depends_on = [kubernetes_namespace.sdost]
}
