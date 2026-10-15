# Starter — k8s-06-01

Copia `postgres.yaml` a tu carpeta de trabajo (`/tmp/k8s-06-01/`) y **complétalo** antes de aplicarlo.

Faltan **tres cosas**:

1. En el `Service pg`, falta hacerlo headless (`clusterIP: None`).
2. En el `StatefulSet`, falta la línea `serviceName: pg` dentro de `spec:` (debe referenciar el Service de arriba por nombre).
3. (ya está, pero verifica) `volumeClaimTemplates` con `name: data` y `storage: 1Gi`.

Aplicar sin estos arreglos levantará Postgres a medias y el validador fallará: no habrá DNS por Pod, y el STS no se asociará correctamente con el Service.
