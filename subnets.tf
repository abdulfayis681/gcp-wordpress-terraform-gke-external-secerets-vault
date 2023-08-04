resource "google_compute_subnetwork" "private" {
  name                     = "${var.clustername}-private"
  ip_cidr_range            = "10.0.0.0/18"
  region                   = var.region
  network                  = google_compute_network.main.self_link
  private_ip_google_access = true
  project                  = var.projectid

  secondary_ip_range {
    range_name    = "k8s-pod-range"
    ip_cidr_range = "10.48.0.0/14"
  }
  secondary_ip_range {
    range_name    = "k8s-service-range"
    ip_cidr_range = "10.52.0.0/20"
  }
}