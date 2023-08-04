terraform {
  

  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.0"
    }

    google-beta = {
      source = "hashicorp/google-beta"
      version = "4.0"
    }
  }

  # Store Terraform state and the history of all revisions remotely, and protect that state with locks to prevent corruption.
  backend "gcs" {
    bucket      = "f4yieebackend2"
    prefix      = "terraform/state"
    credentials = "./GCPKEY.json"
  }
}

provider "google" {
  credentials = file("./GCPKEY.json")
  project     = var.projectid
  region      = var.region
  # version = "~> 2.18"
}