# Actividad 02 — Traducir un diseno DynamoDB a Firestore y detectar donde Bigtable gana

## 1. Identificacion

- **ID:** `gcp-05-02-dynamodb-to-firestore-translation`
- **Tecnologia:** `gcp`
- **Modulo:** `gcp-05-data-cloud-sql-firestore-bigtable-spanner`
- **Dificultad:** intermediate
- **Duracion:** 65–85 min
- **Tipo:** architecture (independiente de la actividad 01)

## 2. Contexto

Una app `events-tracker` corre hoy en AWS con DynamoDB. La organizacion migra a GCP y debe decidir el motor equivalente **por patron de acceso**, no "por servicio". Hay 2 clases de datos muy distintas en una sola tabla DynamoDB (single-table design):

### Spec DynamoDB actual

Tabla `events-tracker` con:

- **PK**: `pk` (string).
- **SK**: `sk` (string).
- **GSI1**: `gsi1pk` (string) / `gsi1sk` (string).

Items y patrones de acceso:

| Clase | pk | sk | Campos | Patrones |
|-------|----|----|--------|----------|
| USER | `USER#<uid>` | `#META` | name, email, country, created_at | 1) get user by uid; 2) list users by country (via GSI1 `gsi1pk=COUNTRY#<cc>`, `gsi1sk=USER#<uid>`) |
| USER_ORDER | `USER#<uid>` | `ORDER#<order_id>` | amount, status, created_at | 3) list orders of a user ordered by date desc; 4) list paid orders of a user |
| METRIC_POINT | `METRIC#<name>#<device>` | `TS#<reverse_ts>` | value (float), tags (map) | 5) list last N points of a (metric, device); 6) write 1–5 K points/s sostenido |

Tu encargo: **traducir** cada patron al motor GCP adecuado. No todos los patrones van al mismo lugar.

## 3. Objetivos

- Decidir **Firestore vs Bigtable** por patron, con criterios explicitos (volumen, forma de query, latencia).
- Modelar los patrones Firestore en terminos de **colecciones y subcolecciones**.
- Declarar los **indices compuestos** que Firestore necesita para las queries no triviales.
- Identificar donde Firestore es la eleccion incorrecta (hint: patron 5+6).
- Documentar los **limites del emulador** que afectan tu diseno (indices compuestos **no** se validan en emulador).

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` (secciones 4, 5, 8).
- Haber recorrido `examples/02-firestore-native-crud/` y `examples/03-bigtable-timeseries-starter/`.
- Herramientas: `bash`, un editor Markdown. Nada mas (actividad conceptual).

**Costos**: cero.

## 5. Instrucciones

### 5.1 Preparar

```bash
mkdir -p /tmp/gcp-05-02
cd /tmp/gcp-05-02
```

### 5.2 Escribe `TRANSLATION.md`

Secciones obligatorias (el validador las busca):

- `## Resumen`
- `## Mapeo por patron`
- `## Modelado Firestore`
- `## Donde Bigtable gana`
- `## Indices compuestos`
- `## Limites del emulador`

> **No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa `TRANSLATION.md`.

Contenido minimo (el validador lo exige):

- Una **tabla** (`| ... |`) mapeando los 6 patrones a motor (`Firestore` o `Bigtable`) con justificacion de una linea.
- Mencion explicita de **colecciones** y **subcolecciones** para el modelo Firestore.
- Mencion de **row key** para la justificacion Bigtable.
- Al menos **2 indices compuestos** declarados en forma `(campo1 ASC, campo2 DESC)` o similar; el validador acepta cualquier formato que incluya la palabra `compuesto` o `composite` y la lista de campos.
- Mencion de **GSI** / Global Secondary Index (para contrastar) y de **DynamoDB**.
- Mencion de **hotspot** o de **row key secuencial** como razon de un diseno (patron 6).

### 5.3 Entregable

```
/tmp/gcp-05-02/
└── TRANSLATION.md
```

## 6. Validacion

```bash
bash tests/validate.sh /tmp/gcp-05-02
```

El validador **no** evalua la correccion semantica de la traduccion. Compara con `solution/REFERENCE.md`.

## 7. Preguntas de reflexion

1. Si el GSI1 crece a 50 millones de entradas, ¿sigue siendo rentable mantenerlo "a mano" en Firestore con documentos de indice? ¿Que patron en Bigtable lo resuelve mejor?
2. ¿Por que **no** poner `METRIC_POINT` en Firestore aunque funcione a 10 escrituras/s?
3. ¿Que pasa si el patron 4 (ordenes `paid` de un user) crece a millones por usuario? ¿Firestore sigue siendo correcto?
4. ¿Como pruebas los indices compuestos sin levantar Firestore real?

## 8. Limpieza

```bash
rm -rf /tmp/gcp-05-02
```
