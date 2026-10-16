# Ejemplo 01 — DORA desde eventos CI/CD

Este ejemplo muestra el **patrón canónico** para calcular DORA desde un flujo de eventos tipo CI/CD, sin dependencias externas.

## Qué hay aquí

- `events.json` — un flujo sintético de ~45 eventos (commits mergeados a main, deploys a producción, incidents causados por deploys) para un servicio ficticio `checkout-api` durante **28 días**.
- `compute_dora.py` — script Python puro (sin dependencias) que lee `events.json` y calcula las 4 métricas DORA.

## Ejecutar

```bash
cd examples/01-dora-from-ci-cd-events
python3 compute_dora.py events.json
```

Salida esperada (resumen):

```
== DORA (service=checkout-api, window=28d) ==
  Deployment Frequency      : ~0.86 deploys/day  (24 successful deploys in 28 days)
  Lead Time for Changes     : 4.5 h (median)
  Change Failure Rate       : 12.50 %  (3 of 24 deploys caused incidents)
  Failed Deploy Recovery T. : 42 min (median)
  --> Bucket (reporte reciente): HIGH
```

## Lectura comentada

### 1. Formato del evento

Cada evento tiene una **llave discriminante** `type` y campos específicos:

```json
{"type": "commit_merged", "service": "checkout-api", "sha": "a1b2c3", "merged_at": "2026-09-15T09:03:00Z"}
{"type": "deploy",        "service": "checkout-api", "id": "d-001", "env": "prod",
 "commit_sha": "a1b2c3", "started_at": "...", "finished_at": "...", "status": "success"}
{"type": "incident",      "service": "checkout-api", "caused_by_deploy_id": "d-003",
 "started_at": "...", "resolved_at": "..."}
```

El campo clave es `caused_by_deploy_id` en los incidents: **sin ese join explícito, CFR y FDRT son inventados**.

### 2. Deployment Frequency

```python
successful = [e for e in deploys if e["status"] == "success"]
df = len(successful) / window_days
```

Trivial, pero **cuida la ventana**. Si solo cuentas los últimos 7 días, un servicio que lanza 1 vez/semana parece Elite en una semana y Low en la siguiente. Usa **ventana rolling de 90 días** en producción; aquí usamos 28 para que los ejemplos sean legibles.

### 3. Lead Time for Changes

```python
leads = []
for d in successful:
    merged = commit_times[d["commit_sha"]]
    leads.append(d["finished_at"] - merged)
lead_time = median(leads)
```

El sutil: ¿y los commits "ancillary" que viajaron en el mismo deploy? La métrica canónica DORA mide **lead time del commit → prod** para todos los commits incluidos. Aquí simplificamos a 1 commit = 1 deploy, pero en producción tendrías que mirar la cadena de commits entre dos deploys.

### 4. Change Failure Rate

```python
failed = {i["caused_by_deploy_id"] for i in incidents if i.get("caused_by_deploy_id")}
cfr = len(failed) / len(successful)
```

Interpretación: no es "deploys que fallaron el pipeline" (eso es *failed deploys*). Es "deploys exitosos **que luego causaron un incidente**". La diferencia es importante: un pipeline que detecta y bloquea un bug *no* cuenta como *change failure* — justo al revés, es una win.

### 5. Failed Deployment Recovery Time

```python
recoveries = [i["resolved_at"] - i["started_at"]
              for i in incidents if i.get("caused_by_deploy_id")]
fdrt = median(recoveries)
```

Mediana, no media. Un incidente de 8 h distorsiona la media; la mediana cuenta la **experiencia típica**.

## Qué NO hace este ejemplo

- No habla con GitHub, Argo CD ni PagerDuty. En un sistema real, un *collector* lo haría (ver `/examples` del reporte Four Keys).
- No persiste a Prometheus / BigQuery. Imprime a stdout.
- No considera multi-servicio. Fácil extensión: agrupar por `service` antes de computar.

## Siguiente

Ver `../02-space-survey-template/` para la encuesta SPACE trimestral que complementa estas 4 métricas.
