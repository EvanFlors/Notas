# Lección: Scale and long-term storage

> **ID:** `obs-11-scale-and-long-term-storage` · **Nivel:** avanzado · **Duración:** 5 h
> **Prerrequisitos:** `obs-10-promql-advanced-recording-rules-cardinality`.

---

## 1. Introducción intuitiva

Tu stack arrancó con un Prometheus en un nodo. Scrapeaba 5 servicios, Grafana enseñaba cuatro paneles bonitos y nadie dormía mal. Un año después hay 400 servicios, Prometheus consume 60 GB de RAM, hace OOM los viernes a las 17:00 y cuando el VP de negocio pide "cómo quedó la latencia p99 el trimestre pasado" descubres que la retención sigue en los **15 días por default** y la respuesta correcta es *"no lo sé, se perdió"*.

Este módulo es sobre ese problema. Prometheus es excelente **detectando lo que pasa ahora**, pero fue diseñado explícitamente **sin resolver** el almacenamiento histórico ni la escala horizontal. Para esos dos problemas la comunidad construyó tres soluciones principales: **Thanos**, **Grafana Mimir** y **VictoriaMetrics** — y una zoología de patrones (federation, remote_write, sharding) que hay que conocer para elegir.

El objetivo del módulo es llegar a defender una elección: *"para esta org, con este volumen, este equipo y este presupuesto, elijo X — y aquí está el ADR"*.

---

## 2. Fundamentos — por qué Prometheus single-node tiene techo

Un Prometheus en un nodo guarda sus datos en una **TSDB local** basada en bloques inmutables de 2 h y un **WAL** (write-ahead log) que es lo único vivo en memoria. La fórmula operacional (muy aproximada) para dimensionar RAM es:

```
RAM ≈ series_activas × bytes_por_serie + overhead
```

Como regla de dedo de Prometheus upstream: **~3 KB por serie activa** en estado estable, más buffers de WAL y de queries. Diez millones de series activas ⇒ ~30 GB sólo en head block. Si una query sin agregar te devuelve 500k series y Grafana la refresca cada 10 s, el proceso se dispara.

Dos propiedades duras:

1. **Scrape y storage comparten memoria**: no puedes "scrapear mucho pero guardar poco" sin que la *head* siga llena mientras se compacta.
2. **La TSDB no es append-only distribuido**: no hay sharding nativo. Un nodo = una base de datos; dos nodos = dos bases independientes.

Retention: `--storage.tsdb.retention.time=15d` por default. Puedes subir a 1 año en un nodo con disco grande, pero el **coste** no es sólo disco: cada query a rangos largos abre miles de bloques y la latencia se dispara.

**Síntoma típico que te empuja a long-term**: `prometheus_tsdb_head_series` creciendo linealmente, OOMKills correlacionados con queries pesadas, y usuarios pidiendo "retention de 90 d o más".

---

## 3. Contexto histórico

- **2015-2017** — Prometheus 1.x. Sin remote_write. Si querías más, hacías **federation** jerárquica.
- **2017** — Nace **Cortex** (Weaveworks) como "Prometheus as a service" multi-tenant.
- **2018** — Thanos (Improbable), tomando otra apuesta: **object storage** + sidecar sin reinventar Prometheus.
- **2019** — VictoriaMetrics 1.x; énfasis en eficiencia por core.
- **2020** — `remote_write` v1 estable; se convierte en el camino canónico.
- **2022** — Grafana Labs **re-licencia Cortex** y crea **Mimir** (AGPLv3). La comunidad migra en masa.
- **2023+** — `remote_write` v2 con **native histograms**; VictoriaMetrics añade stream aggregation; Mimir presume 1 B+ series/día.

El patrón de la historia: *lo que empezó como "parcho sobre Prometheus" se convirtió en productos que lo reemplazan en la capa de almacenamiento, dejando a Prometheus como "colector" (scrape + rules).*

---

## 4. Sharding horizontal con `hashmod`

El patrón más simple para repartir carga de scrape entre N Prometheus "colectores" es `hashmod`:

```yaml
scrape_configs:
  - job_name: 'node'
    kubernetes_sd_configs: [...]
    relabel_configs:
      - source_labels: [__address__]
        modulus: 4                 # 4 shards
        target_label:  __tmp_hash
        action: hashmod
      - source_labels: [__tmp_hash]
        regex: ^0$                 # este Prometheus se queda con shard 0
        action: keep
```

Cada réplica se configura con un `regex` distinto (`^0$`, `^1$`, …). Cada Prometheus scrapea un subconjunto disjunto. Para query global necesitas un **querier federado** por encima (Thanos Querier, Mimir, VictoriaMetrics cluster).

También existen shards *por meta-label*: por `__meta_kubernetes_namespace`, `cluster`, `region`. Es más legible y evita re-hashing cuando crece N, pero menos uniforme.

---

## 5. Federation clásica vs `remote_write`

### 5.1 Federation (`/federate`)

Prometheus expone `/federate?match[]=...` para que **otro Prometheus "superior"** lo scrapee. Patrón jerárquico:

```
[shard-A] ──► /federate ──┐
                           ├──► [prometheus-global] ──► Grafana
[shard-B] ──► /federate ──┘
```

Dos problemas duros:

- **No es tiempo-real**: el "global" scrapea al "inferior" cada N segundos; añade latencia y pierde resolución.
- **Es frágil a volumen**: `/federate` es un endpoint HTTP sync; si matchea 500k series te explota el superior.

**Cuándo todavía sirve**: para **agregados pre-calculados** (recording rules del inferior) que se publican hacia arriba. P. ej. `job:http_requests:rate5m` por servicio, no las series raw.

### 5.2 `remote_write`

Prometheus envía cada muestra scrapeada **inmediatamente** a un endpoint HTTP (`POST`, cuerpo = `snappy(protobuf)`), en paralelo a persistirla local. El long-term store (VM, Mimir, Thanos Receive) acepta ese stream.

```yaml
remote_write:
  - url: http://victoriametrics:8428/api/v1/write
    queue_config:
      capacity: 10000
      max_shards: 30
      min_shards: 1
      max_samples_per_send: 2000
      batch_send_deadline: 5s
    write_relabel_configs:
      - source_labels: [__name__]
        regex: '(go_|process_).*'    # drop noisy defaults
        action: drop
```

Comportamiento clave:

- **Colas en memoria**: `capacity` y `max_shards` controlan backpressure. Si el remoto cae, se encola hasta ese techo; después se descartan muestras (visible como `prometheus_remote_storage_samples_dropped_total`).
- **No reemplaza al scrape**: Prometheus sigue siendo quien scrapea. El remoto sólo almacena.
- **Fire-and-forget**: si quieres leer del remoto, lo haces vía su propia API o vía Grafana datasource (no vía `/api/v1/query` del Prometheus local).
- **v2** (2024+) soporta **native histograms** y mejora el throughput.

Patrón canónico moderno:

```
[prometheus (short-term, 2d)] ──remote_write──► [LTS: VM/Mimir/Thanos] ──► Grafana (datasource)
```

---

## 6. Thanos — object storage + sidecar

Arquitectura de componentes (cada uno es un binario separado):

```
┌──────────────────┐
│  Prometheus      │
│   + thanos       │──► uploads 2h blocks ──► ┌──────────────┐
│     sidecar      │                          │ Object Store │
└───────┬──────────┘                          │ S3/GCS/MinIO │
        │ gRPC (StoreAPI)                     └──────┬───────┘
        │                                            │
┌───────▼──────────┐          gRPC          ┌────────▼──────┐
│ Thanos Querier   │◄───────────────────────┤ Store Gateway │
│  (PromQL federa- │                        │ (lee blocks)  │
│   do, dedup)     │                        └───────────────┘
└───────┬──────────┘                        ┌───────────────┐
        │                                   │ Compactor     │
        │                                   │ (dedup + down-│
        │                                   │  sampling)    │
┌───────▼─────────┐                         └───────────────┘
│    Grafana      │                         ┌───────────────┐
└─────────────────┘                         │ Ruler         │
                                            │ (recording +  │
                                            │  alerting)    │
                                            └───────────────┘
```

Componentes:

- **Sidecar** — vive junto a cada Prometheus. Dos funciones: (a) upload de bloques 2h al object store cuando se cierran; (b) exponer StoreAPI gRPC para queries en vivo contra la head.
- **Store Gateway** — expone StoreAPI gRPC leyendo los bloques del object store (con cache de index).
- **Querier** — endpoint PromQL. **Federa** sobre todas las StoreAPIs (sidecars + store gateways). Hace **deduplicación** sobre la label `replica` cuando se corren pares de Prometheus HA.
- **Compactor** — único singleton por bucket. Hace compaction, aplica **retention** y genera resoluciones **downsampled** (5m y 1h) para acelerar queries de rango largo.
- **Ruler** — evalúa recording y alerting rules "arriba" del querier (útil para rules que necesitan ver múltiples shards).
- **Receive** — alternativa al sidecar: acepta `remote_write` directo (push). Usado cuando el push es más conveniente que el pull de bloques.

Características del modelo:

- **Downsampling** no borra la raw: añade bloques 5m y 1h. Querier elige la resolución mínima que satisface la query (`step`).
- **Dedup por `replica` label**: corres 2 Prometheus idénticos con `external_labels: { replica: a | b }`; Querier presenta UNA serie.
- **Dependencia de object store**: S3/GCS/Azure Blob/MinIO. Baratísimo por GB; coste real = **requests/egress**.

Cuándo elegir Thanos: ya tienes muchos Prometheus y no quieres migrarlos; prefieres bajar coste con object storage y aceptar la operación de 5-6 componentes.

---

## 7. Grafana Mimir — horizontally-scalable, multi-tenant

Mimir viene de la línea Cortex. Componentes principales (microservicios):

- **Distributor** — recibe `remote_write`; valida, aplica límites, hashea y reparte a *ingesters*.
- **Ingester** — mantiene en RAM la "head" (12 h típico) y la flushea periódicamente a object storage como bloques TSDB.
- **Store Gateway** — sirve queries sobre bloques en object storage.
- **Compactor** — compaction + retention sobre bloques.
- **Querier** / **Query Frontend** — PromQL; el frontend parte la query en subqueries y las paraleliza.
- **Ruler**, **Alertmanager** incluido, **OverrideExporter** para límites por tenant.

Diferencias clave vs Thanos:

- **Push-only** por default: no hay sidecar; Prometheus envía con `remote_write`. (Thanos admite ambos; Mimir sólo push.)
- **Multi-tenant nativo**: header `X-Scope-OrgID` separa tenants dentro del mismo cluster.
- **Modo "monolithic"** (todos los componentes en un binario) para empezar, migrable a microservicios al crecer.
- Pensado para **miles de millones de series/día** y para operarse como SaaS.

Cuándo elegir Mimir: necesitas multi-tenancy (SaaS, varias BUs), equipos con experiencia operando microservicios en K8s, Helm chart es tu estándar, Grafana Cloud compatible (eventual migración).

---

## 8. VictoriaMetrics — eficiencia por core

VM apuesta por **menos componentes y menos RAM por serie**. Dos sabores:

- **vmsingle** (`victoria-metrics`): un único binario. Ingiere `remote_write` (y otros: InfluxDB line protocol, Graphite, OpenTSDB, OTLP). Expone PromQL compatible (`/api/v1/query`, `/api/v1/query_range`). Perfecto hasta ~millones de series activas en un nodo medio.
- **vmcluster**: tres componentes — `vmstorage` (stateful, shards), `vminsert` (sharding por hash), `vmselect` (query, scatter-gather). Escala horizontal pura.

Adicionales útiles:

- **vmagent** — reemplazo de Prometheus para scrape; **más eficiente en RAM**; soporta `remote_write` nativo a cualquier endpoint; buffering a disco si el remoto cae.
- **vmalert** — equivalente a Prometheus `rules` + Alertmanager-compatible.
- **vmauth** — reverse proxy con auth y rate limit.
- **MetricsQL** — PromQL compatible con extensiones (`histogram_over_time`, `rollup_rate`, etc.). Puedes ejecutar queries Prometheus-válidas sin cambio.

Características destacadas:

- RAM "por serie activa" ~1/3 a 1/10 de Prometheus upstream según el workload.
- Disk-first design (menos agresivo con RAM que ingesters de Mimir).
- Sin dependencia obligatoria de object storage (puede, pero no es necesario); corre con disco local.
- Licencia: Apache 2.0; existe VictoriaMetrics Enterprise con features de retención/replicación extra.

Cuándo elegir VM: operación simple y bajo coste; equipo pequeño; "quiero el 95% de las features con el 20% del gasto operacional". Es la opción **más ligera** del trío.

---

## 9. Cortex — el predecesor y por qué quedó relegado

Cortex fue el primer "Prometheus as a service" y durante 2017-2022 fue referencia. En 2022, Grafana Labs re-licenció y bifurcó para crear Mimir, llevándose la mayoría de los contribuidores. Cortex sigue vivo bajo CNCF pero su cadencia de releases es más lenta y la mayoría de guías nuevas apuntan a Mimir.

Aprendizaje práctico: si lees documentación "Cortex" de 2020-2022, la mayoría aplica a Mimir con nombres actualizados. En greenfield, elige Mimir.

---

## 10. Criterios de elección

| Criterio | Thanos | Mimir | VictoriaMetrics |
|----------|--------|-------|-----------------|
| Modelo de ingesta | pull (sidecar) o push (receive) | push (remote_write) | push (remote_write) |
| Dependencia object storage | obligatoria | obligatoria | opcional |
| Multi-tenancy | manual / per-cluster | nativa (`X-Scope-OrgID`) | vía vmauth |
| Componentes a operar | 5-6 | 7-10 (micro) o 1 (monolithic) | 1 (single) o 3 (cluster) |
| PromQL fidelity | 100% (es Prometheus abajo) | 100% + extensiones | compatible + MetricsQL |
| HA + dedup | `replica` label en sidecar | ingester replication factor | replication en vmstorage |
| Downsampling | sí (5m, 1h) | sí | no built-in (resolución nativa) |
| RAM por serie activa | ≈ Prometheus | medio (ingesters en RAM) | **bajo** |
| Comunidad / soporte | CNCF, muy activa | Grafana Labs + comm. | VM comm., VM Ent. comercial |
| Grafana Cloud ready | no directo | sí (misma stack) | parcial |

**Heurísticas**:

- *"Ya tengo 20 Prometheus"* → Thanos sidecar (migración trivial).
- *"Multi-tenant SaaS, equipos K8s/Helm"* → Mimir.
- *"Equipo pequeño, factura importa, opsless"* → VictoriaMetrics.
- *"Prototipo / proof of concept"* → VictoriaMetrics single (es lo que usamos aquí).

---

## 11. Costos — modelo mental

Las tres variables de coste de un LTS son:

1. **Active series** — unidad universal. Grafana Cloud, Chronosphere, Datadog cobran por aquí.
2. **Samples ingested / s** — determina compute (ingester CPU/RAM).
3. **Object storage** — GB-mes + requests + egress; muy barato en volumen pero **egress inter-region o inter-cloud mata**.

Rule-of-thumb de dimensionado:

- 1 M series × 15 s scrape ≈ 67 k samples/s ≈ 5.8 B samples/día.
- A ~1.5 bytes/sample comprimido en bloques TSDB ⇒ ~8 GB/día ⇒ ~2.9 TB/año.
- Object storage: ~0.023 USD/GB-mes (S3 Standard) ⇒ ~65 USD/mes por TB.

Mini-tabla orientativa para "cuánto cuesta aproximadamente":

| Escala | Series activas | Samples/día | Opción adecuada |
|--------|----------------|-------------|-----------------|
| Pequeña | 100 k | 500 M | VM single (1 nodo 8 GB RAM) |
| Media | 1 M | 5 B | VM cluster (3 nodos) o Mimir monolithic |
| Grande | 10 M | 50 B | Mimir microservicios o VM cluster grande o Thanos federado |
| Hyperscale | 100 M+ | 500 B+ | Mimir multi-tenant con sharding agresivo |

**Dónde se cuela el coste "oculto"**:

- Egress cross-AZ en K8s: cada muestra viaja de ingester a store gateway a querier.
- Compactor fallando y re-escribiendo bloques (ciclo infinito en IOPS).
- Dashboards con queries de 1 año sin `step` adecuado → scanea toda la raw.
- Métricas con cardinalidad explosiva que ya no se filtran en `write_relabel_configs`.

---

## 12. Checklist operacional y preguntas de evaluación

### Checklist antes de encender un LTS en producción

- [ ] `remote_write` con `write_relabel_configs` para drop del ruido (defaults de la librería, `_bucket` que nadie usa).
- [ ] Alerts sobre el propio pipeline: `prometheus_remote_storage_samples_dropped_total`, `prometheus_remote_storage_queue_highest_sent_timestamp_seconds` lag, "disco de ingester > 80 %".
- [ ] Retention policy explícita y testeada (ej. 15 d raw + 90 d 5m + 1 año 1h).
- [ ] Backups del object store (versioning + replica cross-region si justifica).
- [ ] Grafana data source apuntando al **querier del LTS**, no al Prometheus local, para dashboards históricos.
- [ ] Un dashboard "meta-observabilidad" del propio LTS (coste por tenant, cardinalidad top-10, ingest rate).

### Preguntas de evaluación

1. ¿Por qué `federation` escala mal cuando una `/federate` matchea 500 k series? Describe el fallo paso a paso.
2. Explica qué garantiza y qué **no** garantiza `remote_write` ante una caída transitoria del endpoint.
3. ¿Qué significa "deduplication por `replica` label" en Thanos y por qué sólo tiene sentido con pares de Prometheus HA?
4. En Mimir, ¿qué hace el ingester que no hace el store gateway y por qué eso explica el perfil de RAM del cluster?
5. Dado un workload de 100 M series activas y presupuesto limitado, ¿qué opción eliges y por qué? Lista 3 trade-offs explícitos.
6. ¿Cuándo preferirías `vmagent` sobre un Prometheus con `remote_write`? ¿Cuándo lo contrario?
7. ¿Por qué `/federate` sigue siendo útil para publicar recording rules agregadas hacia arriba?

---

## Lecturas de referencia

Ver `../resources/links.md`.
