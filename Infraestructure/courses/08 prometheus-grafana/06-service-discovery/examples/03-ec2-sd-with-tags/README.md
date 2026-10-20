# 03 — EC2 SD con filtro por tag (sin desplegar AWS)

Este ejemplo es **referencial**: muestra el `prometheus.yml` para EC2 SD con filtro por tag. **No** se levanta AWS real para no incurrir en costos.

## Configuración (`prometheus.yml`)

Ver `prometheus.yml` en este directorio.

Puntos clave:

- `ec2_sd_configs` requiere `region`. Las credenciales se toman del *default credentials chain* (IAM role del host, variables `AWS_*`, perfiles).
- `port` indica a qué puerto scrapear en cada instancia (el `__address__` queda `<private_ip>:<port>`).
- Los labels descubiertos tienen prefijo `__meta_ec2_*`:
  - `__meta_ec2_instance_id`
  - `__meta_ec2_tag_<KEY>`
  - `__meta_ec2_availability_zone`
  - `__meta_ec2_vpc_id`
  - `__meta_ec2_instance_state`
- El patrón es idéntico a Kubernetes SD: `keep` por tag, `replace` para construir labels útiles.

## Validar el YAML con `promtool`

Sin AWS real, se valida la *forma* con `promtool`:

```bash
docker run --rm -v "$PWD:/work" prom/prometheus:v2.54.1 \
  promtool check config /work/prometheus.yml
# → Checking /work/prometheus.yml ... SUCCESS
```

## Para probar en vivo (opcional, con AWS real)

1. Levantar 2 instancias t3.micro con `node_exporter` en 9100.
2. Taggear una con `monitoring=true`.
3. Dar al host de Prometheus un IAM role con `ec2:DescribeInstances`.
4. Lanzar Prometheus con este `prometheus.yml`.

**Coste**: ~$0.02/h de EC2 — recordar `terraform destroy` al terminar.
