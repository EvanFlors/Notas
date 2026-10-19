// Starter — GCE instance template + regional MIG for the same app.
// Fill in TODOs. Do NOT apply.

variable "runtime_sa_email_gce" {
  type    = string
  default = "runtime-sa-gce@placeholder-project-id.iam.gserviceaccount.com"
}

// TODO 2: google_compute_instance_template "api"
//   - machine_type = "e2-small"
//   - disk { source_image = "debian-cloud/debian-12", auto_delete, boot }
//   - network_interface { network = "default" }
//   - service_account { email = var.runtime_sa_email_gce, scopes = ["cloud-platform"] }
//   - metadata_startup_script = <<-EOT
//       #!/bin/bash
//       # would docker-run the capstone-api image here
//     EOT

// TODO 3: google_compute_region_instance_group_manager "api"
//   - region = "europe-west1"
//   - base_instance_name = "capstone-api"
//   - target_size = 2
//   - version { instance_template = google_compute_instance_template.api.self_link }
