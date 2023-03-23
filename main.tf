terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  # Your Google Cloud Platform credentials file.
  credentials = file("<YOUR-GCP-JSON-KEY-FILE>")
  project     = "<YOUR-GCP-PROJECT-ID>"
  region      = "us-central1"
}

resource "google_compute_network" "vpc_network" {
  name                    = "my-vpc-network"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "private_subnet" {
  name          = "my-private-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

resource "google_compute_global_address" "private_ip_range" {
  name          = "private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.self_link
}

resource "google_sql_database_instance" "postgres_instance" {
  name             = "test-instance"
  database_version = "POSTGRES_13"
  region           = "us-central1"

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc_network.self_link
    }
  }
}

resource "google_sql_database" "test_db" {
  name       = "test"
  instance   = google_sql_database_instance.postgres_instance.name
}

resource "google_sql_user" "test_user" {
  name     = "test"
  instance = google_sql_database_instance.postgres_instance.name
  password = "test"
}

resource "google_project_service" "cloud_run_api" {
  service = "run.googleapis.com"

  disable_dependent_services = true
}

resource "google_cloud_run_service" "my_test_app" {
  name     = "my-test-app"
  location = "us-central1"

  template {
    spec {
      containers {
        image = "nginx"
        env {
          name  = "DATABASE_HOST"
          value = google_sql_database_instance.postgres_instance.private_ip_address
        }
        env {
          name  = "DATABASE_NAME"
          value = google_sql_database.test_db.name
        }
        env {
          name  = "DATABASE_USER"
          value = google_sql_user.test_user.name
        }
        env {
          name  = "DATABASE_PASSWORD"
          value = google_sql_user.test_user.password
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [google_project_service.cloud_run_api]
}

resource "google_cloud_run_service_iam_member" "allow_unauthenticated" {
  service  = google_cloud_run_service.my_test_app.name
  location = google_cloud_run_service.my_test_app.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "cloud_run_service_url" {
  value = google_cloud_run_service.my_test_app.status[0].url
}

output "database_instance_connection_name" {
  value = google_sql_database_instance.postgres_instance.connection_name
}

output "database_instance_private_ip" {
  value = google_sql_database_instance.postgres_instance.private_ip_address
}

