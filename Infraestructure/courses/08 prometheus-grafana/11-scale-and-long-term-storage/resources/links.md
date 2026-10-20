# Recursos — obs-11

## Prometheus — escala y storage

- Storage internals (TSDB, WAL, blocks). <https://prometheus.io/docs/prometheus/latest/storage/>
- `remote_write` spec (v1 y v2). <https://prometheus.io/docs/concepts/remote_write_spec/>
- Federation (y por qué no es una solución a escala). <https://prometheus.io/docs/prometheus/latest/federation/>
- Operational best practices. <https://prometheus.io/docs/practices/>
- Métricas internas de `remote_write` (prefijo `prometheus_remote_storage_*`). <https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write>

## Thanos

- Documentación oficial. <https://thanos.io/>
- Componentes (sidecar, store, querier, compactor, ruler, receive). <https://thanos.io/tip/components/>
- Deduplication. <https://thanos.io/tip/components/query.md/#deduplication>
- Downsampling. <https://thanos.io/tip/components/compact.md/#downsampling>
- Repositorio y guías en K8s (`kube-thanos`). <https://github.com/thanos-io/thanos>

## Grafana Mimir

- Documentación oficial. <https://grafana.com/docs/mimir/latest/>
- Chart Helm `grafana/mimir-distributed`. <https://github.com/grafana/mimir/tree/main/operations/helm/charts/mimir-distributed>
- Multi-tenancy (`X-Scope-OrgID`). <https://grafana.com/docs/mimir/latest/configure/about-tenant-ids/>
- Mimir vs Cortex (anuncio y rationale). <https://grafana.com/blog/2022/03/30/announcing-grafana-mimir/>

## VictoriaMetrics

- Documentación oficial. <https://docs.victoriametrics.com/>
- Single-node vs cluster. <https://docs.victoriametrics.com/cluster-victoriametrics/>
- `vmagent`. <https://docs.victoriametrics.com/vmagent/>
- `vmalert`. <https://docs.victoriametrics.com/vmalert/>
- MetricsQL (extensiones sobre PromQL). <https://docs.victoriametrics.com/metricsql/>

## Cortex (contexto histórico)

- Documentación. <https://cortexmetrics.io/>
- CNCF project page. <https://www.cncf.io/projects/cortex/>

## Costos y dimensionado

- Grafana Labs — Active series como unidad de billing (concepto). <https://grafana.com/docs/grafana-cloud/cost-management-and-billing/understand-your-invoice/metrics-invoice/>
- AWS S3 pricing. <https://aws.amazon.com/s3/pricing/>
- Chronosphere / Datadog / Grafana Cloud — mental model de "cost of observability".

## Lecturas de arquitectura

- *Promcon* talks sobre escala (varios años). <https://promcon.io/>
- Thanos vs Cortex vs VictoriaMetrics — comparativas de la comunidad (buscar artículos del año en curso).
- Grafana Labs engineering blog — posts sobre Mimir internals.
