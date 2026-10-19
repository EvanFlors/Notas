# Ejemplo 03 — Lifecycle a Glacier con limpieza completa

> Lectura y analisis. JSON canonico que resuelve 3 problemas de costo: tiering, versiones viejas y multipart abortadas.

## 1. El problema real

Un bucket que crece sin lifecycle es un **goteo de costos silencioso**. Las tres fuentes mas comunes:

1. **Objetos "hot" eternos**: se escriben una vez y se leen rara vez, pero pagan Standard de por vida.
2. **Versiones viejas acumuladas**: `versioning = Enabled` sin politica de limpieza; cada overwrite deja la version anterior pagando storage.
3. **Multipart uploads abortadas**: un cliente empezo un multipart de 5 GB, subio 3 GB, se corto la conexion. Los 3 GB **se cobran** hasta que la subida se "completa" o se aborta explicitamente. Sin regla, nadie los limpia.

## 2. JSON de referencia

```json
{
  "Rules": [
    {
      "ID": "logs-tiering-and-cleanup",
      "Status": "Enabled",
      "Filter": { "Prefix": "logs/" },
      "Transitions": [
        { "Days": 30,  "StorageClass": "STANDARD_IA" },
        { "Days": 90,  "StorageClass": "GLACIER_IR" },
        { "Days": 180, "StorageClass": "DEEP_ARCHIVE" }
      ],
      "Expiration": { "Days": 2555 },
      "NoncurrentVersionTransitions": [
        { "NoncurrentDays": 7,  "StorageClass": "GLACIER_IR" }
      ],
      "NoncurrentVersionExpiration": { "NoncurrentDays": 30 },
      "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 }
    },
    {
      "ID": "incoming-ephemeral",
      "Status": "Enabled",
      "Filter": { "Prefix": "incoming/" },
      "Expiration": { "Days": 7 },
      "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 1 }
    }
  ]
}
```

## 3. Decisiones justificadas, campo por campo

### Regla 1 — `logs/`

- **`Prefix: "logs/"`**: aplica solo a logs. Siempre filtra; una regla "para todo" es dificil de razonar.
- **`Transitions`**:
  - **30 d → STANDARD_IA**: logs que ya no se consultan a diario pero podrian consultarse en un incidente.
  - **90 d → GLACIER_IR**: lectura inmediata todavia posible (ms), coste mitad.
  - **180 d → DEEP_ARCHIVE**: solo compliance / auditoria. Lectura en horas.
- **`Expiration: 2555`**: 7 años (ejemplo compliance financiero). Pasado ese tiempo, borrado automatico.
- **`NoncurrentVersionTransitions`**: versiones viejas van a Glacier Instant a los 7 dias (ya no son "ultima verdad", pero pueden hacer falta en incidente).
- **`NoncurrentVersionExpiration`**: 30 dias y se van. Es la limpieza que evita el goteo de versioning.
- **`AbortIncompleteMultipartUpload`**: 7 dias. Casi siempre basta; subidas legitimas se completan en minutos.

### Regla 2 — `incoming/`

Prefijo tipico de uploads sin promover. Objetivo distinto: **no acumular basura**.

- **`Expiration: 7`**: un upload que a los 7 dias no se "promovio" a `processed/` se asume abandonado y se borra.
- **`AbortIncompleteMultipartUpload: 1`**: subidas interrumpidas se limpian en 24h.

## 4. Trampas al diseñar lifecycle

- **No olvides `AbortIncompleteMultipartUpload`.** Es gratis, no afecta a nada util, y evita costos ocultos.
- **Las transiciones tienen minimo de permanencia**. Mover algo de Standard a IA y de IA a Standard de nuevo cobra ambas transiciones **mas** el minimo de storage de IA (30 dias). No oscilas gratis entre clases.
- **DEEP_ARCHIVE tiene minimo de 180 dias** y recuperacion caraisima + lenta. No lo uses para datos "por si acaso los consulto"; usalo para datos que **sabes** que no vas a leer salvo auditoria.
- **`Filter` sin `Prefix`** aplica al bucket entero. Explicito > implicito: pon siempre un prefix o un tag.
- **Reglas en conflicto**: si dos reglas afectan al mismo objeto, la mas **restrictiva** (menor fecha de expiration) gana. Nombra tus reglas con ID claros para auditar.

## 5. Como se valida esto en la actividad 01

En la actividad escribes un JSON de lifecycle, se valida **estructuralmente con Python** (campos obligatorios, tipos, enums de storage class) y se aplica contra LocalStack via `aws s3api put-bucket-lifecycle-configuration` para confirmar que la API lo acepta sintacticamente. LocalStack **no** ejecuta las transiciones en el tiempo, pero sirve para validar que el JSON es legal.

## 6. Micro-benchmark mental

Para un bucket con 1 TB de logs antiguos (180+ dias), moverlos a Deep Archive baja la factura de storage de aproximadamente $23/mes (Standard) a aproximadamente $1/mes (Deep Archive). Es una decision barata y de alto impacto, siempre que no necesites leerlos jamas en caliente.
