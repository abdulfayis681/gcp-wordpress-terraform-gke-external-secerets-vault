output "project_id" {
  value       = var.projectid
  description = "The ID of the project"
}

output "cluster_name" {
  value       = var.clustername
  description = "The name of the GKE cluster"
}

output "region" {
  value       = var.region
  description = "The region for the GKE cluster"
}

output "node_count" {
  value       = var.nodecount
  description = "The number of nodes in the GKE cluster"
}

output "machine_type" {
  value       = var.machinetype
  description = "The machine type for the GKE nodes"
}

output "image_type" {
  value       = var.imagetype
  description = "The image type for the GKE nodes"
}

output "disk_size" {
  value       = var.disksize
  description = "The disk size in GB for the GKE nodes"
}

output "disk_type" {
  value       = var.disktype
  description = "The disk type for the GKE nodes"
}

output "command_line_access" {
  value       = "gcloud container clusters get-credentials ${var.clustername} --zone ${var.region}-a --project ${var.projectid}"
  description = "Configure kubectl command line access by running the following command"
}