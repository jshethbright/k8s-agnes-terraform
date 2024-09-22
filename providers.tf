# terraform {
#   backend "remote" {
#     organization = "jshethbright"
#     workspaces {
#       name = "k8s-agnes"
#     }
#   }
# }


provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}
