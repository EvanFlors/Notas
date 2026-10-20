# otel-13-01 — Endurecer un Collector gateway (siete controles)

## 1. Identificación

- **ID:** `otel-13-01-harden-collector`
- **Tecnología:** opentelemetry
- **Módulo:** `13-reliability-security-of-the-pipeline`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

Te entregan un gateway Collector que "funciona" pero no sobreviviría auditoría: `insecure: true` en todos los TLS, sin auth, sin memory_limiter, sin cola persistente, sin scrubbing de PII. Tu trabajo: endurecerlo hasta cumplir siete controles concretos. Es exactamente el escenario que ves cuando heredas un pipeline de otro equipo.

## 3. Objetivos

Al terminar debes poder:

- Explicar por qué `memory_limiter` va primero y `batch` después.
- Configurar `file_storage` extension y persistir la cola.
- Diferenciar entre `insecure: true`, `insecure_skip_verify: true` y mTLS.
- Aplicar scrubbing de PII con `attributes` processor.
- Verificar los siete controles con `yq`/`grep` y con el comportamiento real del Collector.

## 4. Prerrequisitos

- `docker` + `docker compose`.
- `openssl` (para los certs; si falta, `bootstrap.sh` imprime `SKIP`).
- `yq` **no es requerido**: el validador usa `grep` sobre YAML.
- Haber leído `theory/lesson.md` entero.
- `/tmp` escribible.

## 5. Instrucciones

### Paso 1 — Preparar

```bash
cd starter
bash bootstrap.sh
# Esto crea /tmp/otel13-act01/ con certs + copia starter/collector.yaml a /tmp/otel13-act01/collector.yaml
```

### Paso 2 — Lee el starter

`starter/collector.yaml` es el pipeline "inseguro". Léelo entero y mentalmente lista las 7 cosas que faltan.

### Paso 3 — Edita

Edita **`/tmp/otel13-act01/collector.yaml`** (no el del repo) hasta cumplir **los siete controles**:

1. **TLS server-side**: el receiver OTLP (gRPC y HTTP) debe tener `cert_file` y `key_file` apuntando a `/etc/otel/certs/server.crt` y `.../server.key`. Ya no debe haber `insecure: true` en el receiver.
2. **Bearer auth**: declara `extensions: bearertokenauth` con `scheme: "Bearer"` y `tokens: ["dev-bearer-token-not-a-secret"]`. Enganchalo con `auth.authenticator: bearertokenauth` en el receiver OTLP.
3. **memory_limiter**: declara `processors.memory_limiter` con `limit_mib: 400`, `spike_limit_mib: 100`, `check_interval: 1s`.
4. **batch**: declara `processors.batch` con `send_batch_size: 1024`, `timeout: 500ms`.
5. **sending_queue persistente**: declara `extensions.file_storage` con `directory: /var/lib/otelcol/queue`. En el exporter `otlp/backend`, configura `sending_queue.enabled: true`, `sending_queue.storage: file_storage`, `sending_queue.queue_size: 5000`.
6. **retry_on_failure**: en el mismo exporter, `retry_on_failure.enabled: true`, `initial_interval: 2s`, `max_interval: 10s`, `max_elapsed_time: 60s`.
7. **PII scrubbing**: declara `processors.attributes/pii` con dos acciones:
   - `user.email` → `action: hash`
   - `http.request.header.authorization` → `action: delete`

**Orden en la pipeline** (obligatorio): `receivers → [memory_limiter, attributes/pii, batch] → exporters`. Recuerda que `memory_limiter` va primero.

El `service.extensions` debe listar tanto `bearertokenauth` como `file_storage`.

### Paso 4 — Levantar y validar

```bash
# Desde starter/
docker compose up -d --force-recreate
sleep 6

docker logs otel13-act01-gateway | tail -40
# Debe decir "Everything is ready. Begin running and processing data."

# Probar auth: SIN token -> rechazado; CON token -> OK
curl -sS -o /dev/null -w "sin token: %{http_code}\n" \
  -k --cacert /tmp/otel13-act01/certs/ca.crt \
  https://localhost:4318/v1/traces -X POST -H "Content-Type: application/json" -d '{}'
# Esperado: 401

curl -sS -o /dev/null -w "con token: %{http_code}\n" \
  -k --cacert /tmp/otel13-act01/certs/ca.crt \
  -H "Authorization: Bearer dev-bearer-token-not-a-secret" \
  https://localhost:4318/v1/traces -X POST -H "Content-Type: application/json" -d '{}'
# Esperado: 400 (payload invalido, pero autenticado) o 200

bash ../tests/validate.sh
```

Pasa cuando los siete controles aparecen correctamente configurados **y** el gateway arranca sin errores.

## 6. Resultado esperado

- `/tmp/otel13-act01/collector.yaml` editado con los 7 controles.
- Contenedor `otel13-act01-gateway` running.
- `validate.sh` reporta `7/7 controles OK`.

## 7. Criterios de aceptación

- Receptor OTLP con TLS (sin `insecure: true` activo en receiver).
- Receptor OTLP con `auth.authenticator: bearertokenauth`.
- `memory_limiter` presente, con `limit_mib` ≥ 100.
- `batch` presente, con `send_batch_size` ≥ 100.
- `file_storage` extension declarada **y** listada en `service.extensions`.
- Exporter con `sending_queue.storage: file_storage` **y** `retry_on_failure.enabled: true`.
- `attributes/pii` processor con al menos una acción `hash` o `delete` sobre un atributo PII.

## 8. Validación

```bash
bash tests/validate.sh
```

Debe reportar `== OK: 7/7 controles verificados ==`.

## 9. Preguntas de reflexión

1. ¿Qué pasaría si pusieras `batch` antes de `memory_limiter`?
2. ¿Por qué `insecure_skip_verify` *no* equivale a desactivar TLS?
3. ¿Qué errores HTTP/gRPC se reintentan automáticamente y cuáles no? ¿Qué pasa con un 401?
4. Si cambias el token Bearer, ¿cómo evitas downtime en una flota de 100 agents?
5. `hash` vs `delete` sobre `user.email`: ¿cuándo preferirías cada uno?

## 10. Extensiones

- **mTLS**: añade `client_ca_file` al receiver y configura un segundo Collector (como agent) que presente client cert.
- **Routing multi-tenant**: añade `routing` processor que mande `deployment.environment=production` a `otlp/prod-tenant` y lo demás a `otlp/dev-tenant`.
- **Chaos**: usa `toxiproxy` entre gateway y backend para añadir 2s de latencia; observa `otelcol_exporter_queue_size`.

## 11. Limpieza

```bash
bash starter/clean.sh
```

Baja el compose y borra `/tmp/otel13-act01/`.
