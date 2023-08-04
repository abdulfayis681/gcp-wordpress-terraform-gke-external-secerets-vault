variable "projectid" {
  description = "The ID of the project"
  type        = string
}

variable "clustername" {
  description = "The name of the GKE cluster"
  type        = string
}

variable "region" {
  description = "The region for the GKE cluster"
  type        = string
}

variable "nodecount" {
  description = "The number of nodes in the GKE cluster"
  type        = number
}

variable "machinetype" {
  description = "The machine type for the GKE nodes"
  type        = string
}

variable "imagetype" {
  description = "The image type for the GKE nodes"
  type        = string
}

variable "disksize" {
  description = "The disk size in GB for the GKE nodes"
  type        = number
}

variable "disktype" {
  description = "The disk type for the GKE nodes"
  type        = string
}