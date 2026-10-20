locals {
  project_prod    = var.project_prod
  project_shared  = var.project_shared
  project_number  = var.project_number
  region          = var.region
  github_org      = var.github_org
  github_repo     = var.github_repo
  github_fqrepo   = "${var.github_org}/${var.github_repo}"
  deploy_sa_email = var.deploy_sa_email
  cluster         = var.cluster_resource_name
  attestor_name   = var.attestor_name
  bq_dataset      = var.bq_dataset

  # Principal set for the WIF binding — scoped by repository attribute.
  wif_principal_set = "principalSet://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/github/attribute.repository/${var.github_org}/${var.github_repo}"
}
