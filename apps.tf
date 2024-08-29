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


resource "helm_release" "jellyfin" {
  name  = "jellyfin"
  chart = "oci://tccr.io/truecharts/jellyfin"

  namespace  = kubernetes_namespace.agnes-apps.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-apps]
  values     = ["${file("./values/jellyfin/values.yaml")}"]
}