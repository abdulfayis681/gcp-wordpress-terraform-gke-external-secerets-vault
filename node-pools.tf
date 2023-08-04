# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "kubernetes" {
  account_id = "your-account-id"
  project    = var.projectid
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
resource "google_container_node_pool" "general" {
  name       = "${var.clustername}-general"
  cluster    = google_container_cluster.primary.id
  node_count = var.nodecount

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = false
    machine_type = var.machinetype
    image_type   = var.imagetype
    disk_size_gb = var.disksize
    disk_type    = var.disktype
    workload_metadata_config {
      mode = "GKE_METADATA"
    }


    labels = {
      role = "general"
    }

    service_account = google_service_account.kubernetes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}