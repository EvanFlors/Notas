# Intent — Canary 95/5 en Cloud Run para `capstone-api`

## Canary

Estrategia: enviamos **95%** del trafico a la revision `capstone-api-v1`
(estable, en produccion) y **5%** a `capstone-api-v2` (nueva). La asignacion
va en dos bloques `traffic{}` del recurso `google_cloud_run_v2_service`.

Nombramos las revisiones de forma explicita (`template.revision = "capstone-api-v2"`)
para que el rollback sea una operacion de **routing**, no de rebuild/redeploy.

Promocion si el canary se porta bien (p99 estable, error rate < umbral) tras
15 minutos:

- Dejar un unico bloque `traffic{}` con `revision = "capstone-api-v2"` y
  `percent = 100`, y `terraform apply`.

## Rollback

Si el canary muestra regresion:

1. Editar `cloud-run.tf`: `capstone-api-v1 -> percent = 100`, `capstone-api-v2 -> percent = 0`.
2. `terraform apply`.
3. Tiempo de rollback medido: segundos (Cloud Run solo re-enruta; no construye nada).
4. Investigar la revision `capstone-api-v2` offline antes de reintentar.

## Por que esto es seguro

- Las revisiones son **inmutables**: no desaparecen al promover; siempre podemos
  volver a `capstone-api-v1`.
- No hay rebuild ni pull de imagen; es un cambio de configuracion del service.
- La service account dedicada no cambia entre revisiones, asi que no hay
  movimiento de IAM.
