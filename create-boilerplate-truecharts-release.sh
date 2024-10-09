#!/usr/bin/env bash

cat >> agnes-apps.tf << EOF
resource "helm_release" "$1" {
  name       = "$1"
  chart      = "oci://tccr.io/truecharts/$1"
  version    = "$2"

  values     = ["\${file("./values/$1/values.yaml")}"]
  namespace  = kubernetes_namespace.agnes-apps.metadata[0].name
  depends_on = [kubernetes_namespace.agnes-apps, kubernetes_persistent_volume_claim.main-storage]
}
EOF