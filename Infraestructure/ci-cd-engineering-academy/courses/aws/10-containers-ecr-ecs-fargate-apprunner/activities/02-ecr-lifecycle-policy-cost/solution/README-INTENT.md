# Intent de la lifecycle policy (referencia)

## Resumen

Esta policy aplica al repositorio ECR `capstone-api` (eu-west-1). Nuestro CI
construye una imagen por commit (~250 MB) y la publica con dos convenciones:

- **release** -> `v<MAJOR>.<MINOR>.<PATCH>` (p. ej. `v1.4.0`).
- **ephemeral** -> imagen taggeada con el SHA del commit y luego re-tagueada,
  dejando la original *untagged*.

El trade-off aceptado: **conservamos 10 releases historicos para rollback**
(hasta ~2.5 GB) y limpiamos agresivamente untagged (ruido de CI) y cualquier
cosa > 180 dias (red de seguridad). Esperamos reducir el tamano del repo de
los ~40 GB actuales a ~5 GB en estado estacionario.

## Regla 1: retener releases

- Que hace: expira imagenes `tagged` con prefijo `v` mas alla de las 10
  mas recientes.
- Por que: 10 releases cubren varios sprints de rollback historico.
- Riesgo que mitiga: perder la posibilidad de volver a una version reciente.
- Riesgo que introduce: si hacemos muchos releases el mismo dia, un release
  util podria caer fuera de la ventana de 10.

## Regla 2: limpiar untagged rapido

- Que hace: expira imagenes `untagged` con mas de 7 dias.
- Por que: una imagen untagged > 7 dias es casi seguro basura de un push
  re-tagueado o un `latest` sobreescrito. Nadie va a hacer `pull` por digest
  de hace >1 semana.
- Riesgo que mitiga: coste de almacenamiento acumulado y confusion.
- Riesgo que introduce: si un cliente estaba haciendo pin por digest a una
  imagen untagged, un deploy fallaria. Mitigacion: convencion de equipo de
  no referenciar imagenes untagged en manifests.

## Regla 3: backstop de 180 dias

- Que hace: expira cualquier imagen (tagged o no) con mas de 180 dias.
- Por que: ninguna version > 6 meses es un rollback realista; dependencias
  cambian, DB migra, config evoluciona.
- Riesgo que mitiga: olvidar tags viejos "colgados" indefinidamente.
- Riesgo que introduce: perder un historico de auditoria de imagenes
  antiguas. Si auditoria pide esto, movemos la copia a un bucket S3 con
  intelligent-tiering (fuera de ECR).

## Orden de evaluacion

ECR evalua las reglas por `rulePriority` ascendente y aplica la primera que
*match* para cada imagen. Por eso:

1. **Priority 1** (retener releases) va primero: queremos *proteger* las
   releases antes de que una regla general las barra.
2. **Priority 2** (limpiar untagged) va despues: solo mira untagged, no
   solapa con la anterior.
3. **Priority 3** (backstop 180 dias) va al final como *red de seguridad*
   general. Al evaluarse ultima, nunca "roba" imagenes a reglas mas
   especificas.

Monitorizacion: usaremos **CloudWatch Metrics** namespace `AWS/ECR` con
`RepositoryPushCount` + `RepositoryPullCount` y revisaremos semanalmente la
caida de `RepositorySizeInBytes` (ECR repository metrics) para confirmar que
la policy esta actuando. Si no cae, revisamos los eventos
`aws ecr describe-image-scan-findings` y los events de lifecycle.
