# Actividad 02 — DynamoDB single-table: diseño de PK/SK y GSI

## 1. Identificación

- **ID:** `aws-08-02-dynamodb-partition-key-design`
- **Tecnología:** `aws`
- **Módulo:** `aws-08-managed-data-rds-aurora-dynamodb`
- **Dificultad:** intermediate
- **Duración estimada:** 60–90 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Tienes que modelar en **DynamoDB** una porción pequeña de un dominio e-commerce (usuarios, órdenes, items de orden, productos) usando el **patrón single-table**: una sola tabla con PK/SK compuestas y, si hace falta, un GSI.

El ejercicio es **data-plane puro**: no se crea nada en AWS real. Se usa **LocalStack** para la tabla DynamoDB. Si LocalStack no está instalado o no responde, el script hace **SKIP controlado** y aun así tienes que entregar el documento `ACCESS_PATTERNS.md`.

## 3. Objetivos

Al terminar deberías poder:

- Diseñar PK y SK para resolver 3 patrones de acceso en **1 query** cada uno.
- Justificar cuándo necesitas un **GSI** y qué `projection_type` elegir.
- Implementar la tabla + ítems de prueba en LocalStack con `boto3`.
- Explicar un caso donde esa PK generaría **hot partition** y proponer **write sharding**.

## 4. Prerrequisitos

- `aws-03` (VPC) y `aws-06` (IAM) — contextuales, no bloquean la práctica.
- `python3` ≥ 3.10 con `boto3` instalado:
  ```bash
  python3 -m pip install --user boto3
  ```
- **LocalStack** (opcional, se puede saltar):
  ```bash
  docker run -d --name aws08-localstack -p 4566:4566 \
    -e SERVICES=dynamodb localstack/localstack:latest
  ```
- `awscli` (opcional, para inspeccionar). No es obligatorio.

**Costos**: cero. Todo local.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/aws-08-dynamodb
cd /tmp/aws-08-dynamodb
```

### 5.2 Copiar el starter

```bash
cp <ruta-repo>/courses/aws/08-managed-data-rds-aurora-dynamodb/activities/02-dynamodb-partition-key-design/starter/model.py \
   /tmp/aws-08-dynamodb/model.py
```

El `model.py` contiene:

- Comprobación si LocalStack responde en `http://localhost:4566` (configurable con `AWS_ENDPOINT_URL`).
- Si **no** responde → imprime `SKIP: LocalStack not available` y sale con exit 0.
- Si **sí** responde → crea la tabla `ecom-single` con un GSI, inserta ítems de prueba, ejecuta las 3 queries y imprime el resultado.

### 5.3 (Si tienes LocalStack) ejecutar el modelo

```bash
cd /tmp/aws-08-dynamodb
export AWS_ACCESS_KEY_ID=dummy
export AWS_SECRET_ACCESS_KEY=dummy
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

python3 model.py | tee run.log
```

El output debe mostrar:

- `Creating table ecom-single...`
- 3 bloques `Query N:` con los ítems devueltos.
- `OK: 3/3 access patterns verified`.

Si no tienes LocalStack:

```bash
unset AWS_ENDPOINT_URL
python3 model.py | tee run.log
```

Verás `SKIP: LocalStack not available at http://localhost:4566`. El script sale 0 — no es un fallo, es una señal clara de que estás en modo SKIP.

### 5.4 Escribir `ACCESS_PATTERNS.md`

Crea `/tmp/aws-08-dynamodb/ACCESS_PATTERNS.md` con **cuatro secciones**:

#### A — Patrones de acceso

Enumera **al menos 3** patrones de acceso del dominio y para cada uno:

- Patrón en lenguaje natural (p. ej. "Dado un user_id, listar sus órdenes del último mes ordenadas por fecha descendente").
- Operación DynamoDB: `GetItem`, `Query` sobre la tabla, o `Query` sobre un GSI.
- Expresión concreta: valor de `PK`, condición de `SK`, nombre del índice si aplica.

#### B — Modelo single-table

Dibuja la tabla con una muestra de ítems para **al menos 2 entidades distintas** (p. ej. user y order). Columnas: `PK`, `SK`, `GSI1PK`, `GSI1SK`, `type`, y 1–2 atributos específicos.

Explica:

- Por qué los dos patrones conviven en la misma tabla (prefijos distintos en PK).
- Qué `projection_type` elegiste para el GSI y por qué (ALL / KEYS_ONLY / INCLUDE).

#### C — Hot partition y write sharding

Describe un **escenario** en el que tu PK generaría hot partition (p. ej. si un tenant concentra el 80 % del tráfico). Propón:

- Nueva forma de PK con sharding: `PK = USER#<id>#<bucket>` con `bucket ∈ [0..N-1]`.
- Cómo cambiarían las queries de lectura (N queries paralelas, agregación en cliente).
- Trade-off: más coste de lectura, menos riesgo de throttling.

#### D — Resultado de la ejecución

Pega el contenido relevante de `run.log` o describe el modo SKIP. Esto demuestra que ejecutaste (o intentaste ejecutar) el modelo.

### 5.5 Limpieza

```bash
docker rm -f aws08-localstack 2>/dev/null || true
rm -rf /tmp/aws-08-dynamodb
```

El validador comprueba el entregable **antes** de limpiar.

## 6. Resultado esperado

- `/tmp/aws-08-dynamodb/ACCESS_PATTERNS.md` con las 4 secciones.
- `/tmp/aws-08-dynamodb/model.py` (copia del starter).
- `/tmp/aws-08-dynamodb/run.log` con el output (o línea SKIP).
- `bash tests/validate.sh /tmp/aws-08-dynamodb` en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa; `model.py` ejecuta sin excepciones (o salta limpio si no hay LocalStack).
- **Calidad**: los patrones citan **operación DynamoDB exacta** (`Query`, `GetItem`) y la **expresión de clave**, no vaguedades.
- **Reproducibilidad**: alguien con tu modelo lo podría implementar sin ambigüedad.
- **Mantenibilidad**: Markdown y Python válidos.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-08-dynamodb
```

Comprueba estructura. La corrección semántica se compara con `solution/REFERENCE.md`.

## 9. Preguntas de reflexión

1. ¿Por qué `scan` es la operación que delata un modelo mal diseñado?
2. ¿Qué pasa con el costo WCU cuando añades un GSI con `projection_type = ALL`?
3. Si un patrón nuevo llega 6 meses después, ¿qué opciones tienes y cuál es la más barata?
4. ¿Por qué `on-demand` es la elección correcta para empezar, aunque sea 5× más caro por request?
5. En Postgres harías un `JOIN users ⋈ orders`. En DynamoDB, ¿cómo lo resuelves y qué pierdes?

## 10. Extensiones

- Añade un **4º patrón** y decide si cabe en el GSI1 o requiere un GSI2.
- Simula write sharding con `N = 10` en el `model.py` y mide (con `time`) la diferencia de latencia agregada.
- Habilita **Streams** en la definición de la tabla (sólo cambia una línea en LocalStack) y describe qué triggerías.

## 11. Limpieza

```bash
docker rm -f aws08-localstack 2>/dev/null || true
rm -rf /tmp/aws-08-dynamodb
```

Sin recursos AWS reales — nada que facturar.
