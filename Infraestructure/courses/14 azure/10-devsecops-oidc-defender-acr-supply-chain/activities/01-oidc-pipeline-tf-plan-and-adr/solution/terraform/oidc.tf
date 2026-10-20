# App registrations + federated credentials for GitHub Actions OIDC.
# No client_secret anywhere.

locals {
  gha_issuer   = "https://token.actions.githubusercontent.com"
  gha_audience = "api://AzureADTokenExchange"
  repo_owner   = "acme"
  repo_name    = "checkout"
}

# ------- checkout: dev (pinned to main branch) -------
resource "azuread_application" "gha_checkout_dev" {
  display_name = "gha-deployer-checkout-dev"
}

resource "azuread_service_principal" "gha_checkout_dev" {
  client_id = azuread_application.gha_checkout_dev.client_id
}

resource "azuread_application_federated_identity_credential" "checkout_dev_main" {
  application_id = azuread_application.gha_checkout_dev.id
  display_name   = "gha-checkout-dev-main"
  description    = "GHA main branch of acme/checkout -> dev"
  audiences      = [local.gha_audience]
  issuer         = local.gha_issuer
  subject        = "repo:${local.repo_owner}/${local.repo_name}:ref:refs/heads/main"
}

# ------- checkout: prod (pinned to environment:prod with required reviewers) -------
resource "azuread_application" "gha_checkout_prod" {
  display_name = "gha-deployer-checkout-prod"
}

resource "azuread_service_principal" "gha_checkout_prod" {
  client_id = azuread_application.gha_checkout_prod.client_id
}

resource "azuread_application_federated_identity_credential" "checkout_prod_env" {
  application_id = azuread_application.gha_checkout_prod.id
  display_name   = "gha-checkout-prod-env"
  description    = "GHA environment=prod of acme/checkout"
  audiences      = [local.gha_audience]
  issuer         = local.gha_issuer
  subject        = "repo:${local.repo_owner}/${local.repo_name}:environment:prod"
}
