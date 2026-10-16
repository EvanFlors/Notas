# Ejemplo 01 — Añadir Postgres como dependencia

## Qué muestra

Cómo declarar un chart maduro (`bitnami/postgresql`) como dependencia de un chart propio, resolverlo con `helm dependency update`, inspeccionar `Chart.lock` y renderizar la composición.

## Requisitos

- Helm ≥ 3.14 (probado con 4.3.1).
- **Internet** para alcanzar `charts.bitnami.com`.
- `jq` opcional, no imprescindible.

> Si trabajas offline, salta a `examples/03-chart-lock-reproducibility/`, que usa un subchart local.

## Ejecutar

```bash
bash run.sh
```

El script:

1. Crea `/tmp/helm-ex-01` con un chart mínimo (`myapp`).
2. Añade `bitnami/postgresql` como dep en `Chart.yaml` (versión pinneada).
3. Ejecuta `helm dependency update`.
4. Imprime `Chart.lock` y lista `charts/`.
5. Renderiza con `helm template` y cuenta kinds generados.

## Qué observar

- `Chart.lock` registra la versión *exacta* (18.12.4), repo y un digest de todo el conjunto.
- `charts/postgresql-18.12.4.tgz` aparece — es el `.tgz` descargado, no una copia expandida.
- El render incluye recursos del padre (Deployment, Service) **y** del subchart (StatefulSet, Services, Secret, PDB, NetworkPolicy, ServiceAccount).
- El Secret contiene credenciales dummy que inyectamos vía values; nunca pongas secretos reales en `values.yaml` commiteado.

## Limpieza

```bash
bash cleanup.sh
```
