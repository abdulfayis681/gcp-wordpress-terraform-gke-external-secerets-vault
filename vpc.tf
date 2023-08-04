# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "compute" {
  project            = var.projectid
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  project            = var.projectid
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "main" {
  name                            = "${var.clustername}-main"
  routing_mode                    = "REGIONAL"
  auto_create_subnetworks         = false
  mtu                             = 1460
  delete_default_routes_on_create = false
  project                         = var.projectid

  depends_on = [
    google_project_service.compute,
    google_project_service.container
  ]
}