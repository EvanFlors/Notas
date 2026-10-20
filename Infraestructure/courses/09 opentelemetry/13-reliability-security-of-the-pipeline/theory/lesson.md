# Lección — Confiabilidad y seguridad del pipeline OTel

> Nivel producción. Da por hecho `otel-09` (agent + gateway) y `otel-10` (sampling). Esta lección es densa; léela entera antes de abrir los ejemplos.

## 1. El pipeline como sistema crítico

Un pipeline de telemetría *es* un sistema distribuido productivo. Falla por las mismas razones que cualquier otro: picos de carga, memoria insuficiente, red flaky, backend lento, certificados vencidos, upgrades mal planeados. La diferencia operacional es cruel: cuando el pipeline falla **nadie se entera** — porque el pipeline es *el* mecanismo por el cual te enterarías. "No veo spans desde hace tres horas" puede significar que la app está muerta, que el agent está OOMKilled, que el gateway rechaza por mTLS vencido o que el backend está rate-limiting. Diagnosticar sin segunda vía de observación es el peor error.

Las dos invariantes de diseño son:

1. **Observa el pipeline con otro pipeline** (o al menos, con otra vía): las métricas internas `otelcol_*` deben ir a Prometheus directo con `remote_write` o scrape, no por el OTLP del propio Collector. Si cae el OTLP, aún ves `otelcol_exporter_queue_size`.
2. **Falla ruidosamente, no silenciosamente**: cada drop debe quedar en una métrica contada y una alerta deseada. "Perdí 2% de spans y no lo supe" es inaceptable; "estoy perdiendo 2% de spans y hay una alerta activa" es operación normal.

El resto de la lección aplica estos dos principios a cada hop del pipeline: SDK → agent → gateway → backend. Cada flecha es una red, cada caja un proceso. Las dos cosas pueden morirse.

## 2. TLS entre SDK, agent, gateway y backend

El default de muchos ejemplos de OTel es `tls: insecure: true` por simplicidad. En producción eso es inadmisible: el OTLP transporta nombres de servicio, PII, headers HTTP capturados, nombres de usuarios en atributos. Capturar OTLP en claro con `tcpdump` es equivalente a leer los logs de aplicación.

**TLS server-side** (lo mínimo): el receptor (gateway) expone certificado; cliente (agent) verifica CA.

```yaml
# gateway: receivers block
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        tls:
          cert_file: /etc/otel/certs/server.crt
          key_file:  /etc/otel/certs/server.key
          # client_ca_file ausente -> no exige client cert (TLS server-side)
```

```yaml
# agent: exporters block
exporters:
  otlp:
    endpoint: gateway.observability.svc.cluster.local:4317
    tls:
      insecure: false
      ca_file: /etc/otel/certs/ca.crt
      # server_name_override solo si el CN del cert no coincide con el DNS
```

**Puntos no obvios**:

- `insecure` en **receiver** significa "no uses TLS en absoluto" (plaintext). En **exporter** significa lo mismo. No confundir con `insecure_skip_verify` (que *sí* usa TLS pero no valida el server cert) — es útil en dev con self-signed, inaceptable en prod.
- El agent corriendo en el nodo *puede* hablar `insecure: true` con la app en el mismo pod si confías el loopback — es un compromiso aceptable (nadie puede sniffar `127.0.0.1` sin root en el host). Pero del nodo al gateway, siempre TLS.
- Para OTLP/HTTP, el endpoint es `https://...:4318` y el bloque `tls` se aplica igual. Para OTLP/gRPC es `endpoint: host:4317` + bloque `tls`.
- Certificado del backend (Mimir/Loki/Tempo/vendor SaaS) casi siempre lo verifica el pool CA del sistema; no toques `ca_file` a menos que uses una CA interna.

## 3. Autenticación entre hops

TLS cifra; no autentica al cliente (salvo mTLS). Para que el gateway rechace spans de agents desconocidos — o para que el backend rechace tráfico de gateways no autorizados — necesitas una de tres opciones:

**(a) Bearer header estático**. Simple, suficiente para muchos entornos:

```yaml
# agent exporter
exporters:
  otlphttp:
    endpoint: https://gateway:4318
    headers:
      Authorization: "Bearer ${env:AGENT_TOKEN}"
```

```yaml
# gateway receiver
extensions:
  bearertokenauth:
    scheme: "Bearer"
    tokens: ["${env:AGENT_TOKEN_HASH_1}", "${env:AGENT_TOKEN_HASH_2}"]
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318
        auth:
          authenticator: bearertokenauth
service:
  extensions: [bearertokenauth]
```

Problema: rotación. Si tienes 10k nodos, cambiar el token requiere rolling restart de todos los agents. Mitigación: dos tokens válidos simultáneamente durante la ventana de rotación.

**(b) mTLS**. El cliente presenta certificado firmado por una CA que el server reconoce:

```yaml
# gateway: exige client cert
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        tls:
          cert_file: /etc/otel/certs/server.crt
          key_file:  /etc/otel/certs/server.key
          client_ca_file: /etc/otel/certs/client-ca.crt   # <- aquí
```

```yaml
# agent: presenta cert
exporters:
  otlp:
    endpoint: gateway:4317
    tls:
      ca_file:   /etc/otel/certs/ca.crt
      cert_file: /etc/otel/certs/client.crt
      key_file:  /etc/otel/certs/client.key
```

Pro: rotación por cert, no por token global; CA puede emitir N certs. Contra: operación de PKI no trivial. En K8s, `cert-manager` lo automatiza (CSR → secret → mount).

**(c) OIDC**. El agent obtiene un JWT de un IdP (Keycloak, Dex, vendor); el gateway valida la firma contra las JWKs del issuer:

```yaml
extensions:
  oauth2client:
    client_id:     "${env:CLIENT_ID}"
    client_secret: "${env:CLIENT_SECRET}"
    token_url:     "https://idp.example.com/oauth/token"
    scopes: ["otel.ingest"]
exporters:
  otlp:
    endpoint: gateway:4317
    auth:
      authenticator: oauth2client
```

El Collector refresca el token automáticamente antes de expirar. Es el patrón más limpio para flotas multi-tenant con muchos equipos, pero añade dependencia dura al IdP.

Regla práctica: **Bearer para ≤1k agents**, **mTLS para flotas administradas**, **OIDC cuando ya existe un IdP corporativo**.

## 4. Multi-tenancy: `X-Scope-OrgID` y el `routing` processor

Mimir, Loki y Tempo (en modo multi-tenant) exigen el header `X-Scope-OrgID` para separar inquilinos. El Collector lo envía como `headers:` en el exporter:

```yaml
exporters:
  otlphttp/tenant_a:
    endpoint: https://mimir:9009/otlp
    headers:
      X-Scope-OrgID: tenant-a
  otlphttp/tenant_b:
    endpoint: https://mimir:9009/otlp
    headers:
      X-Scope-OrgID: tenant-b
```

Si el **tenant** se decide **en runtime** a partir de un atributo del span (p. ej. `deployment.environment`), usa el `routing` processor para derivar la pipeline:

```yaml
processors:
  routing:
    from_attribute: deployment.environment
    default_exporters: [otlphttp/tenant_shared]
    table:
      - value: production
        exporters: [otlphttp/tenant_prod]
      - value: staging
        exporters: [otlphttp/tenant_staging]
```

Trampas:

- El atributo debe estar como **resource attribute**, no span attribute, para que `routing` lo lea con la configuración por default (`from_attribute` lee de contexto HTTP o resource según versión; verifica docs vigentes).
- Si el agente *puede* mentir sobre el tenant (nada lo impide del lado del SDK), el gateway debe reescribir el header antes del exporter, no confiar en el input. Usa `attributes/upsert` sobre `deployment.environment` en el gateway si el agent está dentro del perímetro de confianza; sino, enfórzalo por auth (un cert = un tenant).

## 5. `memory_limiter` y `batch` bien dimensionados

El error #1 en producción: Collector OOMKilled bajo spike porque el `memory_limiter` no estaba o estaba mal. El error #2: `batch` demasiado grande que entrega lotes de 10 MB al backend, timeout, retry, loop.

**`memory_limiter`** tiene dos umbrales:

```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512          # hard limit: a este punto empieza a rechazar
    spike_limit_mib: 128    # soft limit: límite - spike = 384; a este punto empieza a GC agresivo
```

- Debe ir **primero** en la pipeline (`processors: [memory_limiter, ...]`). Si va después, los datos ya entraron en memoria y el limiter solo los puede tirar más tarde — peor.
- `limit_mib` ≈ 75–80% del límite del contenedor. Si el pod tiene `resources.limits.memory: 1Gi`, pon `limit_mib: 750`.
- Cuando el limiter activa, **rechaza spans/metrics/logs al receiver**, lo que propaga backpressure al cliente (agent). El agent entonces retry con backoff o encola — ambos buenos. Sin memory_limiter, el Collector muere y el agent pierde conexión bruscamente.

**`batch`** debe ir **después** de memory_limiter y **antes** del exporter:

```yaml
processors:
  batch:
    send_batch_size: 8192       # spans/metrics/logs por lote
    send_batch_max_size: 10000  # tope duro
    timeout: 200ms              # máximo tiempo esperando llenar el lote
```

- `send_batch_size` grande → menos requests, mejor compresión, latencia end-to-end mayor.
- `timeout` pequeño → latencia baja, lotes a veces pequeños.
- Para traces, 8192 spans/lote con `timeout: 200ms` es un buen default. Para métricas, 1024 datapoints/lote suele bastar. Para logs, depende del tamaño medio.

Orden canónico (muy opinionado): `memory_limiter → k8sattributes → attributes/scrub → tail_sampling → batch → exporter`.

## 6. `sending_queue` persistente en disco y retries

Por default, el `sending_queue` del exporter vive en memoria. Si el Collector reinicia, se pierde. Para producción:

```yaml
extensions:
  file_storage:
    directory: /var/lib/otelcol/queue
    timeout: 1s
    compaction:
      directory: /var/lib/otelcol/queue
      on_start: true
exporters:
  otlp:
    endpoint: backend:4317
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 10000
      storage: file_storage        # <- clave
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s
service:
  extensions: [file_storage]
```

- La cola persistente requiere un **volumen** (hostPath, PVC o volumen local). Si el pod se recrea en otro nodo sin volumen compartido, la cola se pierde — por eso en gateway se suele usar PVC, en agent hostPath (cada nodo tiene el suyo).
- `queue_size` cuenta lotes, no spans. Con `send_batch_size: 8192`, 10000 lotes = ~80M spans. Dimensionar según la peor caída esperada del backend.
- **Qué errores se retryean**: `RESOURCE_EXHAUSTED`, `UNAVAILABLE`, `ABORTED` (gRPC) y 5xx (HTTP). Un 4xx (p. ej. 401 por token vencido) **no** se reintenta y los datos se pierden — por eso rotación de tokens debe hacerse antes de que venzan.
- `max_elapsed_time: 300s` = tras 5 minutos de fallos, el ítem se tira. En gateway crítico, suele ponerse `0` (reintentar indefinidamente); el riesgo es que la cola crezca sin fondo si el backend está muerto permanentemente.

## 7. Alertas sobre el Collector mismo

El Collector expone sus propias métricas Prometheus en `localhost:8888/metrics` (configurable con `service.telemetry.metrics.address`). Las que debes alertar:

| Métrica | Significado | Alerta sugerida |
|---------|-------------|-----------------|
| `otelcol_exporter_queue_size` | Longitud actual de la cola de salida | > 80% de `queue_size` durante 5 min |
| `otelcol_exporter_queue_capacity` | Tope de cola | (constante) |
| `otelcol_exporter_send_failed_spans` | Spans que fallaron tras retries | tasa > 0 durante 5 min |
| `otelcol_processor_refused_spans` | Spans rechazados por memory_limiter u otros | tasa > 0 durante 2 min |
| `otelcol_processor_dropped_spans` | Spans dropeados silenciosamente (p. ej. por filter) | tasa > N (depende de policy) |
| `otelcol_receiver_refused_spans` | Spans rechazados en entrada | tasa > 0 durante 2 min |
| `otelcol_exporter_sent_spans` | Spans entregados OK | **ausencia** durante 5 min = pipeline muerto |
| `process_resident_memory_bytes` | RSS del proceso | > 90% del limit del container |

Las mismas métricas existen para `_metric_points` y `_log_records`. **Scrape** estas métricas con un Prometheus **independiente** del pipeline que estás monitoreando (si usas el propio OTLP para enviárselas a Mimir y Mimir cae, pierdes también las métricas de que Mimir cae).

Ejemplo de regla:

```yaml
- alert: OTelCollectorQueueBackingUp
  expr: otelcol_exporter_queue_size / otelcol_exporter_queue_capacity > 0.8
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Collector {{ $labels.instance }} exporter queue >80%"
    description: "El backend está lento o caído. Verifica otelcol_exporter_send_failed_spans."
```

## 8. Chaos testing del pipeline

Lo único peor que un pipeline sin tests es un pipeline con tests que nunca ejercitan los paths de error. Tres ataques baratos:

1. **Backend lento**: `toxiproxy` entre gateway y backend añade latencia (`toxic add -t latency -a latency=2000`) y comprueba que el `sending_queue` crece sin perder datos.
2. **Backend caído**: `docker stop backend`; mide cuánto tarda la cola en llenarse (depende de `queue_size`, de tasa de ingestión y de `max_elapsed_time`).
3. **Red flaky**: `tc qdisc add dev eth0 root netem loss 10%` dentro del container del gateway; verifica que los retries recuperan.

**Criterio de éxito**: ninguno de los tres debe producir pérdida silenciosa. Debe haber:

- Alertas disparadas (queue size, send failures).
- Datos entregados tras recuperación (nada se tira si la cola no está llena).
- Logs del Collector describiendo lo que pasa.

Si el chaos test revela drop silencioso, falta instrumentación interna o la cola es muy pequeña.

## 9. Versioning del Collector y upgrade seguro

El Collector mueve rápido. Nuevas versiones mensuales, con breaking changes documentados en CHANGELOG. Estrategia:

- **Fija versión exacta** en imagen (`otel/opentelemetry-collector-contrib:0.110.0`), no `latest`.
- **Lee el CHANGELOG antes de upgrade** — hay deprecations trimestrales. Procesadores pueden cambiar nombre (p. ej. `logging` exporter → `debug` exporter en 0.86).
- **Valida la config con la nueva versión** antes de desplegar: `otelcol-contrib validate --config=config.yaml`. Esto no corre la pipeline, solo parsea.
- **Blue/green del gateway**: despliega una segunda réplica del gateway con la nueva versión, haz split de tráfico 10/90 por servicio o por tenant, observa métricas de drop, promueve si limpio.
- **El agent es menos crítico upgradearlo** (reinicio por nodo). El gateway tiene estado (queues en memoria/disco); hazlo con drain:
  1. Marca el pod como "no accept new" (quitar del Service).
  2. Espera a que la queue baje a 0 (`otelcol_exporter_queue_size == 0`).
  3. SIGTERM → el Collector flushea batch pendiente.
  4. Nuevo pod con nueva versión entra.
- **Rolling con cola persistente**: si el PVC es RWO (único nodo), el nuevo pod debe esperar al terminación del viejo. Si es RWX, pueden coexistir drenando la cola.

Deprecation nunca es "mañana"; suele ser 2–3 releases. Pero si no las vas migrando, se acumulan.

## 10. PII scrubbing con `attributes` processor y OTTL

**Nunca** confíes en que el emisor no incluya PII. En algún momento alguien va a `span.set_attribute("user.email", email)` y vas a tener correos en tu backend. El Collector es el *único* lugar donde puedes garantizar scrubbing a escala.

**`attributes` processor** (declarativo, simple):

```yaml
processors:
  attributes/pii:
    actions:
      - key: user.email
        action: hash           # SHA-256; mantiene cardinalidad para debugging
      - key: user.password
        action: delete         # desaparece totalmente
      - key: credit_card
        action: delete
      - key: http.request.header.authorization
        action: delete
```

- `hash` conserva el atributo con el hash en vez del valor — útil para contar "cuántos requests por usuario único" sin saber qué usuario.
- `delete` lo elimina del todo.
- `update` cambia el valor por uno fijo (p. ej. `"REDACTED"`).
- `insert` solo añade si no existía; `upsert` siempre reescribe.

**OTTL** (`transform` processor, expresivo, para reglas por regex o condición):

```yaml
processors:
  transform/pii_regex:
    error_mode: ignore
    trace_statements:
      - context: span
        statements:
          # Email en cualquier atributo string
          - replace_pattern(attributes["http.url"], "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+", "***@***")
          # Credit card detectado por regex Luhn-like (simplificado)
          - replace_pattern(attributes["db.statement"], "\\b(?:\\d[ -]*?){13,16}\\b", "[CARD]")
          # Eliminar cualquier atributo que coincida con nombre
          - delete_key(attributes, "ssn") where attributes["ssn"] != nil
```

OTTL soporta `where` clauses, `IsMatch`, `set`, `delete_key`, manipulación de resource/span/attributes. Lento vs `attributes` processor pero mucho más potente.

**Patrón recomendado**: `attributes/pii` para campos conocidos, `transform/pii_regex` como red de seguridad.

## 11. `redaction` processor para headers y queries

HTTP captura headers y URLs. Ambos filtran PII fácilmente. El `redaction` processor va más allá del `attributes`:

```yaml
processors:
  redaction:
    allow_all_keys: true                 # no borra atributos; solo redacta valores
    blocked_values:                      # regex de valores a redactar en cualquier atributo
      - "4[0-9]{12}(?:[0-9]{3})?"        # Visa
      - "(5[1-5][0-9]{14})"              # MasterCard
    summary: debug                       # añade métricas de redacciones
```

Para headers y query params específicamente, lo usual es combinar con OTTL:

```yaml
transform/redact_headers:
  trace_statements:
    - context: span
      statements:
        - set(attributes["http.request.header.authorization"], "[REDACTED]") where attributes["http.request.header.authorization"] != nil
        - set(attributes["http.request.header.cookie"], "[REDACTED]") where attributes["http.request.header.cookie"] != nil
        - replace_pattern(attributes["url.query"], "(token|key|secret|password)=[^&]*", "$$1=[REDACTED]")
```

## 12. Baggage, cardinalidad y costos del transporte

**Baggage** es poderoso (propaga atributos de negocio across servicios) y peligroso: cada hop recibe y propaga esos valores. Si tu baggage incluye `user_id`, cada span de cada servicio va a tener `user_id` como atributo — explotación de cardinalidad en el backend.

Reglas:

- **Nunca** propagues PII en baggage.
- Limita el tamaño: el SDK permite `baggage.max_items` y `baggage.max_bytes`. Default suele bastar, pero verifica.
- En el Collector, considera `attributes/clear_baggage` para dropear baggage antes de salir al backend (si no lo necesitas allí, no lo pagues).

**Cardinalidad** en métricas y labels es el otro killer de costo:

- Un label `http.target` con la URL completa (incluyendo IDs) genera millones de series. Reemplázalo por `http.route` (la plantilla).
- Un atributo `trace.span.name` dinámico (p. ej. `"GET /users/42"`) hace lo mismo. Normaliza en instrumentación o con OTTL.
- Reglas de oro: < 100 valores únicos por label en métricas; < 10 labels por métrica.

**Compresión OTLP**: default es `gzip`. Para flotas grandes:

```yaml
exporters:
  otlp:
    endpoint: backend:4317
    compression: zstd         # typically 20–30% smaller, 2x faster than gzip
```

`zstd` es ampliable; verifica soporte del backend. Costo: ~5% más CPU en el Collector; beneficio: ancho de banda y egress (en cloud, esto es dinero real).

**No comprimir** solo tiene sentido en LAN sin cuello de botella y con CPU limitada en el Collector.

---

## Resumen operativo (checklist)

- [ ] TLS end-to-end (server-side mínimo; mTLS en gateway↔backend si CA interna).
- [ ] Auth entre hops (Bearer / mTLS / OIDC).
- [ ] `X-Scope-OrgID` correcto si backend multi-tenant.
- [ ] `memory_limiter` primero, dimensionado al 75–80% del límite del container.
- [ ] `batch` después, dimensionado por tasa y latencia aceptable.
- [ ] `sending_queue` persistente en disco con `file_storage`.
- [ ] `retry_on_failure` con backoff y `max_elapsed_time` razonable.
- [ ] Métricas `otelcol_*` scraped por Prometheus independiente.
- [ ] Alertas para queue size, send_failed, refused, dropped, sent_spans=0.
- [ ] Versión del Collector fijada; proceso documentado de upgrade.
- [ ] `attributes/pii` + `transform/pii_regex` + `redaction` como defensa en profundidad.
- [ ] Baggage controlada en tamaño y no contiene PII.
- [ ] Compresión `zstd` o `gzip` en OTLP; cardinalidad verificada en labels.

Si todo lo de arriba está marcado, has endurecido el pipeline a nivel producción. La Actividad 01 te hace recorrerlo; la 02 te obliga a definir cuándo "está bien" (SLOs) y cómo lo mides.
