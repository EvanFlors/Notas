# obs-05-01 — Agregar `postgres_exporter` al stack

## 1. Identificación
- **ID:** `obs-05-01-add-postgres-exporter`
- **Tecnología:** prometheus-grafana
- **Módulo:** `05-exporters-and-relabeling`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

En el mundo real el 80% del valor de observabilidad de datos no viene de instrumentar la app, sino de scrapear los **sistemas gestionados** (bases de datos, caches, colas) con exporters. `postgres_exporter` es el exporter canónico para PostgreSQL: expone las vistas `pg_stat_*` como métricas Prometheus.

Esta actividad guía el proceso completo: levantar Postgres, levantar el exporter, configurar el scrape con relabel, verificar las métricas, y aplicar un `metric_relabel_configs` para quitar cardinalidad de bases del sistema (`template0`, `template1`, `postgres`).

## 3. Objetivos

- Agregar un servicio `postgres` y uno `postgres-exporter` al `docker-compose.yml`.
- Añadir un `scrape_config` llamado `postgres` que haga target al exporter.
- Aplicar `relabel_configs` que:
  - Fije `instance=pg-main`.
  - Añada `env=lab` y `team=data`.
- Aplicar `metric_relabel_configs` que:
  - Dropee métricas `pg_stat_database_*` cuyo label `datname` sea `template0`, `template1` o `postgres`.
- Validar con `bash tests/validate.sh` que `pg_up == 1` y que al menos 3 series `pg_stat_database_*` sobreviven.

## 4. Prerrequisitos

- Docker y Docker Compose v2 (`docker compose version` ≥ 2.20).
- `curl`, `jq` opcional.
- Puertos libres: 5432, 9090, 9187.
- **Costos**: cero (todo local).

## 5. Instrucciones

### Paso 1 — Revisar el starter

```bash
cd activities/01-add-postgres-exporter/starter
cat docker-compose.yml    # tiene prometheus y postgres; falta postgres-exporter
cat prometheus.yml        # tiene job prometheus; falta job postgres
```

### Paso 2 — Agregar el servicio `postgres-exporter`

Edita `starter/docker-compose.yml` añadiendo un servicio que use la imagen `quay.io/prometheuscommunity/postgres-exporter:v0.15.0`, lea `DATA_SOURCE_NAME` apuntando a la DB `demo`, y exponga `9187`. La password es dummy: `demo_pw_change_me`.

> **Secrets**: nunca mergees passwords reales. Aquí es un entorno aislado y la DB solo acepta conexiones del compose network, así que una password hardcoded de demostración es aceptable y queda marcada como tal.

### Paso 3 — Agregar el job `postgres` a `prometheus.yml`

```yaml
- job_name: postgres
  static_configs:
    - targets: ["postgres-exporter:9187"]
  relabel_configs:
    # TODO: fijar instance=pg-main
    # TODO: añadir env=lab, team=data
  metric_relabel_configs:
    # TODO: drop pg_stat_database_* para datname in (template0, template1, postgres)
```

### Paso 4 — Levantar y verificar

```bash
docker compose up -d
sleep 20
curl -s 'http://localhost:9090/api/v1/query?query=pg_up' | jq .
# Expect: result[].value[1] == "1"
```

### Paso 5 — Correr el validador

```bash
cd ..   # back to activity root
bash tests/validate.sh
```

## 6. Resultado esperado

- `docker compose ps` muestra 3 servicios healthy (prometheus, postgres, postgres-exporter).
- `pg_up == 1`.
- Al menos 3 series `pg_stat_database_*` presentes.
- `count(pg_stat_database_xact_commit{datname=~"template0|template1|postgres"}) == 0`.

## 7. Criterios de aceptación

- `tests/validate.sh` exit 0.
- `prometheus.yml` incluye comentarios explicando cada regla.
- `instance` label aparece como `pg-main` (no `postgres-exporter:9187`).

## 8. Validación

```bash
bash tests/validate.sh
```

Si el stack no está arriba, el validador reporta "SKIP: stack no detectado" (exit 0) para no romper runs offline.

## 9. Preguntas de reflexión

- ¿Por qué dropear `datname="postgres"` también? ¿Es una decisión universal?
- Si mañana aparece una métrica `pg_stat_statements_*` por query (alta cardinalidad), ¿la dropeas con `metric_relabel_configs` o parcheas el exporter?
- ¿Qué pasaría si `instance=pg-main` fuera igual al label de otro Prometheus (misma región, otro cluster)? ¿Cómo lo distinguirías en una vista federada?

## 10. Extensiones

1. Añadir métricas custom con la opción `--extend.query-path` del exporter (p. ej. slow queries).
2. Agregar `scrape_timeout: 3s` y ver qué pasa con queries lentas al exporter.
3. Añadir Grafana al compose con un dashboard provisionado que muestre `pg_stat_database_xact_commit` por `datname`.

## 11. Limpieza

```bash
docker compose down -v
rm -rf /tmp/obs-05-01-* 2>/dev/null || true
```
