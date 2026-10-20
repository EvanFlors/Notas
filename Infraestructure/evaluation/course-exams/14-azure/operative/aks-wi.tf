############################################
# AKS Workload Identity + GitHub Actions OIDC federation
############################################
#
# OP-task-3 — Debes completar los dos `azurerm_federated_identity_credential`
# (uno para el ServiceAccount del cluster AKS, otro para GitHub Actions).
#
# BUG intencional: el bloque de GitHub Actions tiene `subject = "repo:${var.github_repo}:*"`.
# Eso acepta cualquier branch, PR o environment — un contributor con permiso de abrir
# un PR puede obtener un token con permisos de prod. Debes pinnear a
# `repo:example-org/example-repo:environment:prod`.

# TODO (OP-task-3 #1): federated credential para el ServiceAccount `workload-sa`
# del namespace `app` del cluster AKS cuyo issuer es `var.aks_oidc_issuer_url`.
#
# resource "azurerm_federated_identity_credential" "aks_workload" {
#   name                = "fed-aks-workload"
#   resource_group_name = azurerm_resource_group.exam.name
#   parent_id           = azurerm_user_assigned_identity.uami_workload.id
#   audience            = ["api://AzureADTokenExchange"]
#   issuer              = var.aks_oidc_issuer_url
#   subject             = "system:serviceaccount:app:workload-sa"
# }

# BUG intencional (OP-task-3 #2): subject sin pinning.
resource "azurerm_federated_identity_credential" "github_actions" {
  name                = "fed-github-actions"
  resource_group_name = azurerm_resource_group.exam.name
  parent_id           = azurerm_user_assigned_identity.uami_workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"

  # <-- RED FLAG: acepta cualquier ref/PR del repo.
  subject = "repo:${var.github_repo}:*"
}

# OP-task-3 #3 — Dejar como `local` un YAML de ejemplo del ServiceAccount con la
# anotación `azure.workload.identity/client-id`. Debe referenciar el client_id de la MI.
#
# locals {
#   service_account_manifest = <<-YAML
#     apiVersion: v1
#     kind: ServiceAccount
#     metadata:
#       name: workload-sa
#       namespace: app
#       annotations:
#         azure.workload.identity/client-id: ${azurerm_user_assigned_identity.uami_workload.client_id}
#       labels:
#         azure.workload.identity/use: "true"
#   YAML
# }

# NOTAS
# -----
# Reemplaza al terminar con:
# - Qué garantiza y qué NO garantiza el subject pinneado a `environment:prod`
#   (ejemplo: no previene que un `self-approver` de environments apruebe su propio PR).
# - Por qué user-assigned > system-assigned aquí (identidad reutilizable, sobrevive al recrear
#   el cluster, se puede compartir entre dos SAs).
# - Qué cambia en Container Apps: el subject sigue siendo del cluster lógico (Container Apps
#   environment), no un ServiceAccount K8s. La MI se adjunta directamente al Container App.
