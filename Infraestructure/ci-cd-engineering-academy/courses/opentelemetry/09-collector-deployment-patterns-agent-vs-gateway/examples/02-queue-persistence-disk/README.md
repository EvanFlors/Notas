# Example 02 — Queue persistence en disco (`file_storage`)

Demuestra que la `sending_queue` de un Collector sobrevive un **reinicio** cuando el backend no está disponible, usando la extension `file_storage`.

```
telemetrygen ──► Collector(agent) ──X── Backend (apagado)
                     │                      ▲
                     │                      │
                     └──► cola en disco ────┘  (al volver, reenvía)
                          /tmp/otel-09-ex02/storage
```

## Qué demuestra

- `extensions.file_storage` + `exporters.otlp.sending_queue.storage: file_storage`.
- Al matar el Collector mientras el backend está caído y volver a levantarlo, la cola se **recupera** del disco.
- Diferencia con `sending_queue` sin storage (pérdida silenciosa).

## Modo local (docker, sin K8s)

Para mantenerlo simple se usa `docker` directo con dos contenedores: `otelcol` (con el `file_storage`) y `backend` (otro otelcol que hace de "backend" OTLP y vuelca a `file`).

## Archivos

- `collector-config.yaml` — Collector con `file_storage`, pipeline traces, exporter OTLP al backend.
- `backend-config.yaml` — Collector "backend" que recibe OTLP y escribe a `/data/out.json`.
- `run.sh` — demo end-to-end con el ciclo apagar/encender.
- `cleanup.sh` — baja contenedores y borra `/tmp/otel-09-ex02`.

## Ejecutar

```bash
bash run.sh
# ... se verá:
#  1) backend arriba, se emiten 50 spans → OK
#  2) backend abajo; se emiten 50 más → cola crece en disco
#  3) collector se reinicia (la cola in-memory se perdería; la de disco no)
#  4) backend arriba otra vez; los spans encolados en disco se envían
```

## Verificar manualmente

```bash
ls -lh /tmp/otel-09-ex02/storage
# archivo *.db > 0 bytes mientras el backend está caído

wc -l /tmp/otel-09-ex02/data/out.json
# aumenta cuando el backend vuelve y se vacía la cola
```

## Limpieza

```bash
bash cleanup.sh
```
