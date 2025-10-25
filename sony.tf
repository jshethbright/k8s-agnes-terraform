resource "kubernetes_namespace" "sony" {
  metadata {
    name = "sony"
  }
}

resource "kubernetes_secret" "ghcr-docker-registry-secret" {
  metadata {
    name      = "ghcr-docker-registry-secret"
    namespace = kubernetes_namespace.sony.metadata[0].name
  }

  data = {
    ".dockerconfigjson" = base64decode(file("./secret-dockerconfig"))
  }

  type = "kubernetes.io/dockerconfigjson"
}

resource "helm_release" "country-api" {
  name       = "country-api"
  repository = local.agnes-repo
  chart      = "country-api"
  version    = "0.1.7"

  namespace  = kubernetes_namespace.sony.metadata[0].name
  depends_on = [kubernetes_namespace.sony, kubernetes_secret.ghcr-docker-registry-secret]
  values     = ["${file("./values/country-api/values.yaml")}"]
  set = [
    {
      name  = "imagePullSecrets[0].name"
      value = kubernetes_secret.ghcr-docker-registry-secret.metadata[0].name
    }
  ]
}