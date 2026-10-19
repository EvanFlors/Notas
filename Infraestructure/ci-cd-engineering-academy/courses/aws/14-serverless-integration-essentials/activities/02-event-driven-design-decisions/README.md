# Actividad 02 — Decisiones de diseño event-driven

## 1. Identificación

- **ID:** `aws-14-02-event-driven-design-decisions`
- **Tecnología:** `aws`
- **Módulo:** `aws-14-serverless-integration-essentials`
- **Dificultad:** advanced
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Un equipo pide ayuda para diseñar la **integración event-driven** de un nuevo flujo:

> **Escenario.** Una app web permite a usuarios subir fotos a S3. Por cada subida, el equipo quiere:
> 1. Generar un **thumbnail** y guardarlo en otro prefijo S3.
> 2. **Notificar** a un canal interno (webhook HTTP a Slack).
> 3. **Indexar** la foto en una tabla DynamoDB.
> Además, una **segunda ruta**: diariamente a las 03:00 UTC, procesar en batch todas las fotos del día anterior y generar un **informe PDF** (duración media del batch: 20 min, picos de 45 min).

El entregable es un documento Markdown + un archivo JSON de ASL. **No se despliega nada**; es un ejercicio de diseño con justificación técnica.

**Costo**: cero.

## 3. Objetivos

Al terminar deberías poder:

- Para cada subcaso del escenario, elegir **Lambda / ECS-Fargate / EKS** y defender la elección.
- Diseñar la **topología event-driven** (quién dispara, quién transforma, quién notifica, qué cola intermedia, qué DLQ) con **valores concretos** de `VisibilityTimeout` y `maxReceiveCount`.
- Decidir **FIFO vs standard** por cola, con justificación.
- Escribir una **ASL** JSON mínima para el flujo del informe PDF.
- Nombrar **3 costos ocultos** del diseño y qué knob los controla.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo.
- Haber recorrido los dos `examples/` del módulo.
- Herramientas: `bash`, `python3` (para validar JSON) y un editor Markdown.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-14-design
cd /tmp/aws-14-design
```

Puedes usar otro directorio; entonces pásalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `DECISIONS.md` con 5 secciones

#### Sección A — Elección de compute (Lambda vs ECS vs EKS)

Rellena esta tabla para los 3 subcasos. Justifica cada decisión en 2–3 líneas citando **duración**, **patrón de carga**, **cold starts aceptables** y/o **costo estimado**.

```
## Compute

| Subcaso                       | Elección (Lambda / ECS-Fargate / EKS) | Justificación |
|-------------------------------|---------------------------------------|---------------|
| 1. Thumbnailer (por subida)   | ...                                   | ...           |
| 2. Notifier (webhook Slack)   | ...                                   | ...           |
| 3. Indexer (DDB upsert)       | ...                                   | ...           |
| 4. Batch PDF diario (20-45m)  | ...                                   | ...           |
```

#### Sección B — Topología event-driven

Dibuja la topología (ASCII) de la ruta "subida → 3 consumers" y pon valores concretos de `VisibilityTimeout` y `maxReceiveCount` por cola. Al menos:

- Identifica el **source** del evento (S3 directo o Lambda router).
- Marca si usas **SNS** o **EventBridge** como fanout, y por qué.
- Dibuja las **colas SQS** por consumer, con DLQ.
- Añade **al menos un comentario** sobre qué consumer necesita **idempotencia explícita** y cómo.

Ejemplo de encabezado:

```
## Topologia

### Diagrama

   S3 ──► ...

### Parametros por cola

| Cola        | FIFO/Std | VisTO | maxReceiveCount | DLQ         | Justificacion               |
|-------------|----------|-------|-----------------|-------------|-----------------------------|
| thumbs      | ...      | ...   | ...             | thumbs-dlq  | ...                         |
| notify      | ...      | ...   | ...             | notify-dlq  | ...                         |
| index       | ...      | ...   | ...             | index-dlq   | ...                         |
```

#### Sección C — FIFO vs Standard

Para cada una de las 3 colas de la sección B, responde: **FIFO** o **Standard** y por qué, en 1–2 líneas. Al menos **una** debería ser Standard y **una** debería tener un argumento serio para FIFO (aunque la elijas Standard al final; el ejercicio es que **razones** la decisión).

#### Sección D — Costos ocultos

Enumera **al menos 3** costos ocultos de este diseño y nombra la palanca concreta que los controla. Por ejemplo:

```
## Costos ocultos

1. CloudWatch Logs: ... — palanca: ...
2. ...
3. ...
```

#### Sección E — ASL JSON para el batch PDF

Escribe `pdf-report.asl.json` en el mismo directorio (`/tmp/aws-14-design/pdf-report.asl.json`) con una Step Function **sintácticamente válida** que:

- Tenga `StartAt` apuntando a un estado existente.
- Contenga al menos un `Task`, un `Choice` y un `Pass` o `Succeed`.
- Todos los `Next` apunten a estados definidos.
- Al menos un estado tenga un bloque `Retry` o `Catch`.

Puedes usar ARNs placeholder (`arn:aws:lambda:us-east-1:123456789012:function:GenerarReporte`). No se ejecuta contra AWS; se valida solo la estructura.

### 5.3 Entregable

Dos archivos en `/tmp/aws-14-design/`:

- `DECISIONS.md` con las secciones A..E completas.
- `pdf-report.asl.json` sintácticamente válido.

## 6. Validación

```bash
bash tests/validate.sh /tmp/aws-14-design
```

El validador comprueba:

- `DECISIONS.md` existe, con las 5 secciones.
- Tabla de compute con al menos 4 filas de decisión.
- Topología menciona SQS, SNS/EventBridge, DLQ y VisTO.
- Al menos 3 costos ocultos listados.
- `pdf-report.asl.json` existe, es JSON válido, tiene `StartAt` + `States` y al menos un `Task`, un `Choice` y un `Retry` o `Catch`.

No comprueba corrección semántica — eso lo haces tú contra `solution/REFERENCE.md`.

## 7. Preguntas de reflexión

1. Si quisieras preservar el **orden** de actualizaciones del mismo `object_key` (p. ej., si una foto se re-sube), ¿qué cambia en tu diseño? ¿Es viable con SNS standard + SQS standard?
2. Si el notifier a Slack falla por rate limiting, ¿cuántos retries y en qué ventana haría tu diseño antes de mandar a DLQ? ¿Y cómo sabe un humano que hay mensajes en la DLQ?
3. Para el batch PDF, ¿por qué (o por qué no) usas Lambda? Si lo haces, ¿cómo manejas los picos de 45 min?
4. ¿Cuánto cambiaría tu diseño si en lugar de 100 fotos/día fuesen **1 millón** de fotos/día? Nombra 2 cosas que romperían.

## 8. Limpieza

```bash
rm -rf /tmp/aws-14-design
```
