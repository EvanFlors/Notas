# Ejemplo 02 — Montar un Secret en Cloud Run (lectura y análisis)

> **No se ejecuta contra GCP.** Es un ejemplo *comentado* para interiorizar el patrón.

## Objetivo

Mostrar las dos formas canónicas de montar un `Secret Manager Secret` en un servicio Cloud Run y por qué **nunca** se debe pasar un secreto por `--set-env-vars`.

## Ciclo de vida del secret

```hcl
# 1) Secret contenedor. Replicacion automatica = GCP decide donde replicar.
resource "google_secret_manager_secret" "db_password" {
  secret_id = "db-password"
  project   = var.project_id

  replication {
    auto {}
  }
}

# 2) Primera version. En un flujo real, el VALOR no se pasa aqui:
#    se crea con `gcloud secrets versions add` fuera de Terraform.
#    Para el ejemplo, usamos un placeholder ficticio.
resource "google_secret_manager_secret_version" "db_password_v1" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = "fake-sk-REPLACE_ME_IN_GCLOUD"   # ficticio
}

# 3) La service account del servicio Cloud Run tiene acceso de LECTURA
#    sobre el secret concreto (no sobre el project).
resource "google_secret_manager_secret_iam_member" "run_accessor" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:sa-run-app@${var.project_id}.iam.gserviceaccount.com"
}
```

## Montaje A — como variable de entorno

```bash
gcloud run deploy app \
  --image=europe-west1-docker.pkg.dev/${PROJECT_ID}/apps/app:v1 \
  --service-account=sa-run-app@${PROJECT_ID}.iam.gserviceaccount.com \
  --set-secrets=DB_PASSWORD=db-password:latest \
  --region=europe-west1
```

El runtime inyecta la variable `DB_PASSWORD` en el proceso. La resolución ocurre al **arrancar la revisión**, así que un redeploy refresca el valor.

## Montaje B — como fichero en un volumen

```bash
gcloud run deploy app \
  --image=europe-west1-docker.pkg.dev/${PROJECT_ID}/apps/app:v1 \
  --service-account=sa-run-app@${PROJECT_ID}.iam.gserviceaccount.com \
  --set-secrets=/etc/secrets/db_password=db-password:latest \
  --region=europe-west1
```

El runtime monta un **tmpfs** en `/etc/secrets/db_password` con el valor. Preferido cuando:

- El valor es grande (PEMs, JSONs de service account, etc.).
- El framework ya sabe leer de disco (`--credentials-file=/etc/secrets/sa.json`).
- Quieres evitar que un `/proc/<pid>/environ` filtre el valor.

## Por qué NUNCA `--set-env-vars` para datos sensibles

```bash
# MALO. El valor aparece en:
#  - gcloud run services describe app
#  - La Console en claro
#  - Logs de deploy del shell y del CI
#  - El historial de bash y la auditoria del CI
gcloud run deploy app --set-env-vars DB_PASSWORD=super-secret-123
```

`--set-secrets` resuelve el valor dentro de la plataforma; `describe` muestra solo la referencia `db-password:latest`.

## Versioning y rollback

- `--set-secrets=DB_PASSWORD=db-password:latest` — refresca al redeployar.
- `--set-secrets=DB_PASSWORD=db-password:3` — pinned a version 3; rollback atómico cambiando a `:2`.

En el patrón de **rotación con solape**:

1. El rotator crea `version 4` con el valor nuevo.
2. La `version 3` sigue `ENABLED` durante la ventana de solape.
3. El servicio con `:latest` se refresca en el próximo redeploy.
4. Pasada la ventana, `version 3` se marca `DISABLED` y luego `DESTROYED`.

## IAM mínima

El principal del servicio Cloud Run necesita exactamente:

```json
{
  "role": "roles/secretmanager.secretAccessor",
  "members": [
    "serviceAccount:sa-run-app@PROJECT_ID.iam.gserviceaccount.com"
  ]
}
```

Aplicado **al secret concreto**, no al project. Dar `secretAccessor` sobre el project daría acceso a *todos* los secretos del project — violación de menor privilegio clara.

## Comparación con AWS

| GCP | AWS equivalente |
|---|---|
| `--set-secrets=K=secret:ver` en Cloud Run | ECS task definition con `secrets` referenciando Secrets Manager | 
| Volumen `/etc/secrets/...` | ECS valueFrom + mountPoints a shared volume |
| `roles/secretmanager.secretAccessor` por secret | `secretsmanager:GetSecretValue` con `Resource: arn:...:secret:name-??????` |
| Resolución al arrancar la revisión | Resolución al arrancar la task |
