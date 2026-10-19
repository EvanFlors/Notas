# gcp-05 — Datos gestionados: Cloud SQL, Firestore, Bigtable y Spanner

## Identificacion

- **ID:** `gcp-05-data-cloud-sql-firestore-bigtable-spanner`
- **Curso:** `gcp`
- **Nivel:** intermedio
- **Duracion estimada:** 4 h
- **Prerrequisitos:** `gcp-01-model-projects-billing-and-cli`, `gcp-02-iam-bindings-deny-policies-and-service-accounts`, `gcp-03-vpc-global-and-networking`, curso AWS `aws-08`.

## Objetivo

Mapear el catalogo de datos de GCP (**Cloud SQL**, **AlloyDB**, **Firestore**, **Bigtable**, **Spanner**) a los casos de uso AWS equivalentes y aprender a elegir el motor correcto por workload. Al terminar deberias poder:

- Justificar por que `checkout` usa Cloud SQL/Postgres y `events` usa Bigtable, o por que un sistema globalmente consistente justifica el salto a Spanner.
- Levantar los **emuladores oficiales** de Firestore, Bigtable y Spanner en tu laptop para hacer CRUD y SQL sin tocar GCP real.
- Correr Postgres como stand-in local de Cloud SQL en Docker y conectar una app FastAPI contra el, demostrando el patron de **Cloud SQL Auth Proxy** sin desplegar nada en la nube.
- Producir Terraform de provisioning y ADRs que un equipo pueda ejecutar en Fase 4.

## Alcance

Este modulo cubre:

- **Cloud SQL** (Postgres/MySQL/SQL Server, HA regional, read replicas, backups, Point-in-Time Recovery) y el patron **Cloud SQL Auth Proxy** que habilita TLS + IAM sin exponer la DB a internet.
- **AlloyDB** como alternativa Postgres-compatible de mayor rendimiento OLTP (introductorio: cuando merece la pena saltar).
- **Firestore** (modos Native vs Datastore), su modelo documental con transacciones ACID por documento/por tx cross-document, y los limites de query (indices compuestos).
- **Bigtable** (wide-column), diseno de row key para series temporales (prefijo invertido para evitar hotspots), familias de columnas, perfil operacional y por que es la pieza preferida para telemetria operacional de alto volumen.
- **Spanner** como SQL globalmente consistente (TrueTime + Paxos a escala global); por que es materialmente distinto a Aurora Global.
- **Mapeo desde AWS:** RDS -> Cloud SQL/AlloyDB; DynamoDB -> Firestore (parcial) + Bigtable (parcial); Aurora Global -> Spanner (sin equivalente real en AWS).
- **Emuladores oficiales** para desarrollo local sin coste:
  - Firestore: `gcloud emulators firestore start` o la imagen oficial de Google.
  - Bigtable: `gcloud beta emulators bigtable start` o `google/cloud-sdk`.
  - Spanner: imagen `gcr.io/cloud-spanner-emulator/emulator` (oficial).
  - Cloud SQL: no existe emulador oficial, se usa **Postgres en Docker** como stand-in del motor y se documenta el delta operacional.

Lo que **no** cubre (se vera despues):

- Observabilidad de bases de datos (metricas, SLOs) -> `gcp-08`.
- Keys CMEK y rotation sobre Cloud SQL/BigQuery -> `gcp-06`.
- Workload Identity Federation para que el CI acceda a estas DBs -> `gcp-10`.
- BigQuery (plano analitico separado, cubierto en pistas de datos avanzadas; no es foco de este modulo).

Este modulo es **artefactos locales + emuladores + Terraform plan**. **No** se provisiona nada en un proyecto GCP real, **no** se usan Project IDs reales (todos los TF usan `project = "example-project-id"` o similar); **el coste es cero**. El unico tooling necesario: `bash`, `jq`, `python3` (>= 3.10), `docker`, `terraform` (>= 1.3) y opcionalmente `gcloud` para los emuladores (pero cada emulador tiene imagen Docker alternativa).

## Materiales

- **`theory/lesson.md`** — leccion profunda con 10 secciones (criterio de eleccion, Cloud SQL + Auth Proxy, Firestore, Bigtable, Spanner, mapeo AWS, cuando NO usar X).
- **`examples/`** — ejemplos ejecutables localmente:
  - `01-cloud-sql-postgres-with-auth-proxy/` — Postgres en Docker como stand-in de Cloud SQL, cliente Python que conecta via DSN y Terraform `google_sql_database_instance` con la bandera `ipConfiguration.ipv4Enabled = false` (Auth Proxy only).
  - `02-firestore-native-crud/` — emulador Firestore + script Python de CRUD con transaccion y batched write.
  - `03-bigtable-timeseries-starter/` — emulador Bigtable + script Python que escribe metricas con row key `metric#device#<reverse_ts>` y recupera el ultimo minuto.
  - `04-spanner-emulator-sql/` — emulador Spanner (imagen oficial) + script Python que crea esquema con interleaved tables y corre una tx de lectura/escritura.
- **`activities/`** — dos actividades **independientes**:
  - `01-connect-fastapi-to-cloud-sql/` (**guided-lab**) — una API FastAPI con endpoints `/items` que persiste en Postgres (stand-in de Cloud SQL) + Terraform real de Cloud SQL + ADR corto.
  - `02-dynamodb-to-firestore-translation/` (**architecture**) — leer una especificacion DynamoDB (tabla + GSI + patrones de acceso) y traducirla a Firestore (colecciones + subcolecciones + indices compuestos) justificando donde el mapeo NO es 1:1 y donde conviene Bigtable en vez de Firestore.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimension | Al terminar deberias |
|-----------|----------------------|
| Conceptual | Explicar que es TrueTime y por que habilita external consistency en Spanner; por que el Auth Proxy no expone IP publica; por que un hot shard de Bigtable viene casi siempre de un row key mal elegido. |
| Operativa (local) | Levantar los 3 emuladores (Firestore, Bigtable, Spanner), correr Postgres en Docker, hacer CRUD contra los 4 motores y entender el delta de cada emulador respecto al servicio real. |
| Arquitectonica | Elegir el motor correcto para 3 workloads concretos; defender Spanner vs Cloud SQL con 2 ejemplos reales; traducir un diseno DynamoDB a Firestore identificando donde Bigtable encaja mejor. |

## Criterios de evaluacion

- Dado un workload (p. ej. "catalogo de productos con 100 lecturas/s y 1 escritura/s por SKU"), elige motor y justifica.
- Lee un snippet de codigo y detecta un **antipattern** (p. ej. row key secuencial en Bigtable, usar Firestore para analytics agregados).
- Entrega las dos actividades con sus validadores en verde.
- Produce un ADR Spanner vs Cloud SQL para 2 casos.

## Entregables

- **Codigo** (`activity 01`): `main.py` FastAPI conectada a Postgres local via `DATABASE_URL`, con `GET/POST /items` y healthcheck que valida la conexion; `main.tf` que declara `google_sql_database_instance` (Postgres 15, region europea, `ipv4Enabled = false`), `google_sql_user`, `google_sql_database` y una `google_service_account` + binding `roles/cloudsql.client`; `ADR-DB-CHOICE.md` corto justificando Postgres vs AlloyDB.
- **Analisis** (`activity 02`): `TRANSLATION.md` con tabla DynamoDB -> Firestore + un apartado "cuando Bigtable gana" + justificacion de indices compuestos.

## Costos

**Ninguno.** Todo el modulo corre en tu laptop:

- Postgres en Docker (`postgres:15-alpine`): gratis.
- Firestore emulator (imagen `google/cloud-sdk` o `gcloud emulators`): gratis.
- Bigtable emulator (igual): gratis.
- Spanner emulator (imagen `gcr.io/cloud-spanner-emulator/emulator`): gratis.
- Terraform **solo** se usa en modo `init -backend=false` + `validate` + `plan` contra placeholders (no `apply`); los proveedores se descargan en local, no se autentica contra GCP.

Si en Fase 4 provisionas lo disenado:

- Cloud SQL Postgres `db-f1-micro` 1 vCPU en region europea: ~7–15 USD/mes.
- Firestore Native: free tier (50 K lecturas/dia, 20 K escrituras/dia, 1 GiB).
- Bigtable: minimo 1 node (~500 USD/mes) — **nunca** encenderlo sin plan de uso real; para dev usar siempre emulador.
- Spanner: minimo 100 processing units (~65 USD/mes) — mismo criterio.

## Siguiente modulo

-> `gcp-06-kms-and-secret-manager` — proteger los secretos de conexion (DSN, service account) y aplicar CMEK sobre Cloud SQL/GCS cuando lo exija la politica.
