// Reference solution — GCE instance template + regional MIG.

variable "runtime_sa_email_gce" {
  type    = string
  default = "runtime-sa-gce@placeholder-project-id.iam.gserviceaccount.com"
}

resource "google_compute_instance_template" "api" {
  name_prefix  = "capstone-api-"
  machine_type = "e2-small"
  region       = "europe-west1"

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "default"
  }

  service_account {
    email  = var.runtime_sa_email_gce
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    # Would docker-run the capstone-api image here.
    # This Terraform is NEVER applied; the script is illustrative.
    echo "would run: docker run -p 8080:8080 europe-west1-docker.pkg.dev/.../capstone-api:v1"
  EOT

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "api" {
  name               = "capstone-api-mig"
  region             = "europe-west1"
  base_instance_name = "capstone-api"
  target_size        = 2

  version {
    instance_template = google_compute_instance_template.api.self_link
  }
}
