# Didactic only: do NOT use random_password to manage real secrets.
# Real secrets belong in a secret manager; here we only demonstrate that
# `sensitive` is CLI-side signaling, not state-side encryption.

resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!@#%&*-_"
}

output "db_password" {
  description = "Password generated for the fake DB. CLI will mask it; state will NOT."
  value       = random_password.db.result
  sensitive   = true
}

# Writing the same value to disk to make it visible: the point is that any
# consumer of this value sees it in cleartext — Terraform cannot magically
# protect what it hands over.
resource "local_file" "passwords" {
  filename        = "${path.module}/passwords.txt"
  content         = "db_password=${random_password.db.result}\n"
  file_permission = "0600"
}
