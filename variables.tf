variable "cluster_type" {
  default = "docker"
}

variable "storage_class_name" {
  type = map(string)
  default = {
    kind   = "local-path"
    docker = "hostpath"
  }
}

variable "kube_config" {
  default = "~/.kube/config"
}

variable "kube_context" {
  default = "docker-desktop"
}
