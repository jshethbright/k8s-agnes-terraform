locals {
  bitnami-repo    = "oci://registry-1.docker.io/bitnamicharts"
  agnes-repo      = "https://jshethbright.github.io/agnes-charts/"
  rook-repo       = "https://charts.rook.io/release"
  longhorn-repo   = "https://charts.longhorn.io"
  openebs-repo    = "https://openebs.github.io/openebs"
  cloudflare-repo = "https://cloudflare.github.io/helm-charts"
  littlelink-repo = "https://k8s-at-home.com/charts/"
}

locals {
  main-cert-issuer = "letsencrypt-issuer"
}
