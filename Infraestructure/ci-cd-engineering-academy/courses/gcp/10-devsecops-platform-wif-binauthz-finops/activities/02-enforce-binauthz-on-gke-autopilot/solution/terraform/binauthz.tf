############################################################
# gcp-10-02 — Reference Binary Authorization Terraform.
#
# NOT APPLIED. Project IDs and cluster references are
# placeholders. In Fase 4, the policy YAML lives alongside
# this file and is loaded verbatim.
############################################################

variable "project_id" {
  type    = string
  default = "my-project-123"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

# ---------- Container Analysis note ----------
resource "google_container_analysis_note" "build_note" {
  project = var.project_id
  name    = "build-attestation-note"
  attestation_authority {
    hint {
      human_readable_name = "Build attestor (cosign + KMS)"
    }
  }
}

# ---------- Binauthz attestor ----------
resource "google_binary_authorization_attestor" "build" {
  project = var.project_id
  name    = "build-attestor"
  attestation_authority_note {
    note_reference = google_container_analysis_note.build_note.name
    public_keys {
      id = "projects/${var.project_id}/locations/${var.region}/keyRings/binauthz/cryptoKeys/build-signer/cryptoKeyVersions/1"
      pkix_public_key {
        public_key_pem      = file("${path.module}/../build-signer.pub.pem")
        signature_algorithm = "ECDSA_P256_SHA256"
      }
    }
  }
}

# ---------- Binauthz policy ----------
resource "google_binary_authorization_policy" "policy" {
  project = var.project_id

  default_admission_rule {
    evaluation_mode  = "ALWAYS_DENY"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
  }

  cluster_admission_rules {
    cluster                 = "${var.region}.prod-autopilot"
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [google_binary_authorization_attestor.build.name]
  }

  cluster_admission_rules {
    cluster                 = "${var.region}.dev-autopilot"
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "DRYRUN_AUDIT_LOG_ONLY"
    require_attestations_by = [google_binary_authorization_attestor.build.name]
  }

  admission_whitelist_patterns { name_pattern = "gcr.io/gke-release/*" }
  admission_whitelist_patterns { name_pattern = "registry.k8s.io/*" }
  admission_whitelist_patterns { name_pattern = "gke.gcr.io/*" }
  admission_whitelist_patterns { name_pattern = "europe-west1-docker.pkg.dev/${var.project_id}/system/*" }

  global_policy_evaluation_mode = "ENABLE"
}

# ---------- Autopilot cluster with Binauthz enabled ----------
# The actual cluster is managed in gcp-07; this is a reference that
# shows how to flip the toggle at cluster level.
resource "google_container_cluster" "prod_autopilot" {
  project          = var.project_id
  name             = "prod-autopilot"
  location         = var.region
  enable_autopilot = true

  # Toggle Binauthz enforcement on the cluster. The actual rule is in
  # google_binary_authorization_policy above.
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Minimal network/subnet refs — placeholders.
  network    = "default"
  subnetwork = "default"
}
