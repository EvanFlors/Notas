# Ejemplo 01 — CloudWatch Logs Insights: queries útiles (y por qué son caras)

> Lectura y análisis. No se ejecuta en AWS real. Si quieres experimentar, LocalStack soporta parcialmente CloudWatch Logs (ver `../../resources/links.md`).

## 1. Modelo mental

Logs Insights escanea bytes **a demanda** sobre log groups ya ingresados. Cada query:

1. Define un **time range** (hora, día, semana, 90 días…).
2. Encadena **operadores pipe-syntax**: `fields`, `filter`, `stats`, `sort`, `limit`, `parse`, `dedup`.
3. Devuelve resultados y **te cobra por GB escaneados** (no por GB devueltos).

Regla de oro: **estrechar el time range y los campos antes de agregar** es la única palanca real de coste.

## 2. Query canónica: errores 5xx por minuto

```
fields @timestamp, @message
| filter @message like /HTTP 5\d{2}/
| stats count() as errors by bin(1m)
| sort @timestamp desc
| limit 60
```

Lectura:

- `filter` **antes** de `stats` para reducir el working set.
- `bin(1m)` crea el bucket temporal; cambia a `5m` si el log group es ancho.
- `limit 60` acota la respuesta (1 hora en buckets de 1 minuto).

## 3. Query de latencia p95 (requiere campos numéricos)

```
fields @timestamp, duration_ms
| filter ispresent(duration_ms)
| stats pct(duration_ms, 95) as p95, pct(duration_ms, 99) as p99 by bin(5m)
```

Si la app loguea `duration_ms` como entero (p. ej. estructurado en JSON) Logs Insights lo parsea automáticamente. Si viene embebido en un string, hay que `parse`:

```
parse @message /latency=(?<duration_ms>\d+)ms/
| filter ispresent(duration_ms)
| stats pct(duration_ms, 95) by bin(5m)
```

## 4. Query de auditoría cruzada (unirse con un trace_id)

```
fields @timestamp, @message, trace_id, span_id, level
| filter trace_id = "abcdef0123456789"
| sort @timestamp asc
```

Buscar todos los logs de una traza concreta. Útil cuando llegas desde X-Ray/Tempo con un `trace_id` y quieres ver el detalle textual.

## 5. Por qué esto NO sustituye a Loki/ELK

Tres razones económicas:

1. **GB escaneados vs GB indexados.** Loki/ELK indexan y la query lee solo lo relevante. Logs Insights escanea en bruto.
2. **Dashboards de alta frecuencia.** Una query de 30 s cada minuto × 10 paneles × 30 días escanea TB. En Loki, los chunks indexados hacen que la segunda query sea casi gratis.
3. **Compaction y caché.** CloudWatch no cachea resultados de query — cada ejecución paga. Grafana + Loki cachea resultados por panel/tiempo.

**Conclusión:** Logs Insights brilla para **investigación ad-hoc** y **compliance queries ocasionales**. Para dashboards permanentes de alto volumen, exporta a Loki/ELK (o paga el precio consciente).

## 6. Patrón recomendado

- **Hot** (< 7 días, logs de app) → CloudWatch Logs + Logs Insights para investigación.
- **Warm** (dashboards, SRE) → subscription filter → Kinesis Firehose → S3/Loki.
- **Cold** (compliance) → S3 con lifecycle a Glacier.

Logs Insights sigue siendo útil, pero deja de ser el único backend.
