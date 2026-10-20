# Actividad 01 — Añadir Loki al stack del capstone

## 1. Identificación

- **ID:** `obs-13-01-add-loki-to-stack`
- **Tecnología:** `prometheus-grafana`
- **Módulo:** `13-loki-and-logs-in-the-stack`
- **Dificultad:** advanced
- **Duración estimada:** 60–75 min
- **Tipo:** guided-lab

## 2. Contexto

Hasta ahora el stack del capstone tiene **métricas** (Prometheus) y **UI** (Grafana). Toca cerrar el ciclo con **logs**. Vas a añadir **Grafana Loki** como data source y **Grafana Alloy** como agente, con una app de ejemplo que loguea JSON. El objetivo es ver los logs en Explore filtrados por `{app="demo-app"}` y correlacionar con los paneles de métricas existentes.

El starter trae un `docker-compose.yaml` base **sin Loki ni Alloy**. Lo editas (o aceptas el que viene en `solution/`) y validas.

## 3. Objetivos

- Añadir Loki y Alloy a un `docker-compose.yaml` existente.
- Configurar Alloy para descubrir contenedores Docker y promover el label `app` al stream.
- Provisionar Loki como data source en Grafana.
- Verificar que `{app="demo-app"}` devuelve líneas en Explore.
- Ejecutar una **log-based metric query** (`sum(rate({app="demo-app"} |= "ERROR" [1m]))`) y ver una serie no vacía.

## 4. Prerrequisitos

- `obs-08-grafana-deep` completada.
- Docker + Docker Compose plugin disponibles y daemon corriendo.
- Puertos libres: `3000` (Grafana), `3100` (Loki), `12345` (Alloy).
- **Costos**: ninguno (todo local).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/setup.sh /tmp/obs13-lab01
cd /tmp/obs13-lab01
```

Esto copia un stack base **sin logs** a `/tmp/obs13-lab01/`.

### 5.2 Añadir Loki + Alloy

Edita `docker-compose.yaml` y añade dos servicios:

- `loki` (imagen `grafana/loki:3.2.0`), montando `./loki-config.yaml`.
- `alloy` (imagen `grafana/alloy:v1.4.2`), montando `./alloy-config.alloy` y el socket Docker.

Crea `loki-config.yaml` con la config monolithic + filesystem (ver `solution/` como referencia **después** de intentarlo).

Crea `alloy-config.alloy` que:

- Descubra contenedores con `discovery.docker`.
- Promueva el label Docker `app` al stream Loki.
- Mantenga solo los contenedores con label `app` presente.
- Mande a `http://loki:3100/loki/api/v1/push`.

### 5.3 Provisionar Loki en Grafana

Edita `grafana/provisioning/datasources/datasources.yaml` y añade a Loki como data source (URL `http://loki:3100`).

### 5.4 Levantar y validar

```bash
docker compose up -d
bash /ruta/al/repo/.../tests/validate.sh /tmp/obs13-lab01
```

### 5.5 Explorar en Grafana

Abre `http://localhost:3000` (admin/admin) → Explore → Loki → prueba:

```logql
{app="demo-app"}
{app="demo-app"} |= "ERROR"
sum(rate({app="demo-app"} |= "ERROR" [1m]))
```

## 6. Resultado esperado

- `docker compose ps` muestra `loki`, `alloy`, `grafana`, `demo-app` en `running`.
- `curl -fsS http://localhost:3100/ready` responde `ready`.
- `curl -fsS -G --data-urlencode 'query={app="demo-app"}' http://localhost:3100/loki/api/v1/query_range` devuelve `values`.
- Grafana Explore con la query `{app="demo-app"}` muestra líneas.

## 7. Criterios de aceptación

- [ ] Loki responde a `/ready` en < 60 s.
- [ ] Alloy está `running` y conectado al socket Docker.
- [ ] Al menos **1 línea** de `{app="demo-app"}` llega a Loki en los primeros 90 s.
- [ ] Grafana tiene a Loki provisionado (`/api/datasources/name/Loki` responde 200).
- [ ] No hay secretos ni credenciales reales en los configs.

## 8. Validación

```bash
bash tests/validate.sh /tmp/obs13-lab01
```

Reporta OK/FAIL por check (Loki ready, Alloy up, logs flowing, Grafana datasource).

Si Docker no está disponible, el validador imprime `SKIP` y sale `0` (gracefully skip).

## 9. Preguntas de reflexión

1. ¿Por qué Alloy necesita montar el socket Docker en modo lectura? ¿Qué problema de seguridad abre y cómo lo mitigarías en producción?
2. Si cambias el label del contenedor de `app` a `service_name`, ¿qué partes del Alloy config hay que tocar y por qué?
3. En este lab Loki guarda chunks en `filesystem`. Para producción, ¿qué cambios mínimos haces para pasar a S3?
4. ¿Qué pasa si un contenedor loguea 10 MB/s de debug? ¿Dónde cortarías ese tráfico y por qué ahí?
5. ¿Por qué el label `request_id` no debe promoverse al stream aunque sería "útil" en Explore?

## 10. Extensiones

- **E1** — Añade un segundo contenedor `demo-worker` con label `app=demo-worker` y verifica que aparece como stream independiente.
- **E2** — Configura `grafana-datasources.yaml` para que el data source de Loki tenga `derivedFields` que extraigan `request_id` como link.
- **E3** — Define una **recording rule** de Loki (`loki_rules.yaml`) que pre-calcule `demo:log_error_rate:sum`.

## 11. Limpieza

```bash
cd /tmp/obs13-lab01 && docker compose down -v
rm -rf /tmp/obs13-lab01
```
