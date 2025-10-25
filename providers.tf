terraform { 
  cloud { 
    
    organization = "agnes-js" 

    workspaces { 
      name = "k8s-agnes-terraform" 
    } 
  } 
}


provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}
