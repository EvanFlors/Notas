# Autoevaluación — gcp-06-02

## Puntos semánticos clave

1. **`rotation_period`** en segundos (`"2592000s"` = 30 d). GCP no acepta `"30d"`.
2. **`next_rotation_time`** debe ser RFC3339 en el futuro al momento del `apply`. Si lo pones en el pasado, el apply falla.
3. **Topic de Pub/Sub** debe existir antes y el **service agent de Secret Manager** necesita `roles/pubsub.publisher` sobre él. Si falta, la rotación programada no publica eventos.
4. **El `secret_data`** nunca debe ser real. En producción se maneja fuera de Terraform (el rotator crea las versiones).
5. **Dos service accounts separadas**: la del consumidor (`secretAccessor`) y la del rotator (`secretVersionManager`). No las fusiones.
6. **Ventana de solape** es un concepto operativo, no un campo de Terraform. Se materializa en el rotator y en la política de refresco de los consumidores.

## Variantes aceptables

- `rotation_period` entre 7d y 90d: todos válidos; justifica.
- Dos consumidores: añade más `google_secret_manager_secret_iam_member`.
- Mover `secret_data` a `terraform-import` (ignorando el `secret_data` desde TF): preferible en prod real.

## Variantes NO aceptables

- `member = "serviceAccount:service-...@gs-project-accounts.iam.gserviceaccount.com"` (ese es el service agent de GCS, no el consumidor del secret).
- Secret real o parcial. Si por accidente pegas un valor real, **revócalo inmediatamente en el proveedor externo** antes de reemplazarlo en el repo.
- Dar `roles/owner` a la service account consumidora.
