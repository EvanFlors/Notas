# Post-mortem: lock colgado en `tf-11-02`

## Resumen

A las 03:40 UTC un `terraform apply` quedó bloqueado al intentar aplicar cambios al
state `tf-11-02/terraform.tfstate`. La causa: la laptop de Alice (que inició el apply a
las 03:12) se durmió a mitad de ejecución, dejando la fila de lock en DynamoDB sin
liberar. Lo liberé con `terraform force-unlock` tras confirmar que no había proceso
vivo ni escrituras pendientes al bucket.

## Datos del lock

- **LockID**: `tf-state-tf11/tf-11-02/terraform.tfstate-md5`
- **Who**: `alice@laptop`
- **Operación**: `OperationTypeApply`
- **Creado**: `2026-10-15T03:12:00Z`

## Verificaciones ANTES de desbloquear

- Confirmé por Slack que la laptop de Alice estaba fuera de red (apagada por tapa cerrada).
- Verifiqué con `aws s3api list-object-versions --bucket tf-state-tf11 --prefix tf-11-02/`
  que la última escritura al state fue a las 03:11:47Z (anterior al lock) — no hubo apply
  parcial que escribiera un state nuevo.
- `terraform plan` tras `force-unlock` muestra 0 cambios respecto al state actual, indicando
  que la infra real coincide con el state → ningún recurso quedó a medio crear.

## Acción

```
terraform force-unlock f3a1c9e2-aaaa-bbbb-cccc-ddddeeeeffff
Do you really want to force-unlock? yes
Terraform state has been successfully unlocked!
```

## Verificación posterior

- [x] `terraform plan` corre sin error
- [x] La fila ya no está en DynamoDB (`dynamodb scan` lo confirma)
- [x] `terraform state list` refleja la realidad

## Causa raíz y acción preventiva

- Causa raíz: aplicar desde laptop personal sin controles de "no dormir mientras hay un proceso TF corriendo".
- Preventivas:
  - Mover `apply` a CI con runners efímeros (timeout corto, cleanup garantizado).
  - Prohibir policy-side `apply` desde laptops en PROD (solo lectura; apply vía pipeline con approval).
  - Alertar automáticamente si un lock lleva > 60 min activo (job cron contra `dynamodb scan` + mensaje a #ops).
