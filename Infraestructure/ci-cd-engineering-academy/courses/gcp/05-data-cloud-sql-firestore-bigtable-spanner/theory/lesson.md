# gcp-05 — Leccion: datos gestionados en GCP (Cloud SQL, AlloyDB, Firestore, Bigtable, Spanner)

> 10 secciones. Mayoritariamente conceptual + criterios de eleccion. Prerrequisitos: `gcp-01`, `gcp-02`, `gcp-03`, AWS `aws-08`.

---

## 1. El mapa del catalogo de datos de GCP

A diferencia de AWS, donde hay media docena de bases de datos relacionales (RDS en sus 7 motores + Aurora + Aurora Serverless + Aurora Global) y un salto duro al mundo NoSQL (DynamoDB, DocumentDB, Keyspaces), **GCP agrupa su oferta en 5 planos** mas limpios:

| Plano | Servicio GCP | Motor interno | Equivalente AWS | Cuando |
|-------|--------------|---------------|-----------------|--------|
| OLTP relacional "clasico" | **Cloud SQL** | Postgres / MySQL / SQL Server managed | RDS | OLTP tipico; equipos que ya saben SQL; <= decenas de TB. |
| OLTP relacional de alto rendimiento | **AlloyDB** | Postgres-compatible (motor propio) | Aurora Postgres | OLTP exigente que satura Cloud SQL pero no justifica Spanner. |
| Documental escalable | **Firestore** (Native) | Documental con transacciones | DynamoDB (parcial), DocumentDB | App moderna con documentos jerarquicos, acceso por key o por consultas acotadas. |
| Wide-column alto throughput | **Bigtable** | HBase-compatible | DynamoDB (parcial, para patrones time-series) | Telemetria, series temporales, feature store, >= 10 K ops/s sostenidas. |
| SQL globalmente consistente | **Spanner** | Spanner (TrueTime + Paxos) | *sin equivalente real*; Aurora Global es *eventual* para lectores | Multi-region con **external consistency**; dinero, inventario global, reservas. |

Tambien existen **Memorystore** (Redis/Memcached managed) y **BigQuery** (OLAP serverless columnar), pero quedan fuera del alcance de este modulo.

> **Idea clave:** en GCP la pregunta no es "RDS o DynamoDB" sino "**que patron de acceso** tengo". Si el patron es "SQL en un pais, decenas de TB", Cloud SQL. Si es "SQL en varios continentes con tx global", Spanner. Si es "escribir 50 K puntos/segundo", Bigtable. Si es "documentos de usuario con subcolecciones", Firestore. Elegir mal cuesta rediseno completo, no solo una migracion.

---

## 2. Cloud SQL y el patron Auth Proxy

**Cloud SQL** es Postgres/MySQL/SQL Server managed. Lo opera Google: parches, backups, HA failover regional, read replicas. Lo que diferencia a Cloud SQL de "simplemente poner Postgres en una VM" es:

1. **No expongas IP publica.** `ipConfiguration.ipv4Enabled = false`. Se accede via **Cloud SQL Auth Proxy** (binario Go publicado por Google) o via **Private Service Connect**. El Auth Proxy abre un socket local y establece un canal TLS mutuo autenticado con IAM: el cliente nunca ve credenciales de red.
2. **IAM database authentication.** El usuario Postgres se mapea a un principal IAM (user, service account); no hay password local, el token lo emite IAM. Rota automaticamente.
3. **Automated backups + Point-in-Time Recovery.** Habilitados por default. PITR permite recuperar a cualquier segundo dentro de la ventana de retencion (max 35 dias).
4. **HA regional** (opcional): instancia primaria + secundaria en otra zona, failover automatico <= 60 s.

> **Antipattern frecuente:** levantar Cloud SQL con `ipv4Enabled = true` + password Postgres pegado en un `.env`. Tira el 80% del valor del servicio: pierdes auth centralizada, logging IAM de accesos y aislamiento de red.

### Patron Auth Proxy en la practica

```
┌─────────────────────┐     TCP localhost:5432     ┌────────────────────┐
│  Cliente (FastAPI)  │ ─────────────────────────> │ cloud-sql-proxy    │
│  psycopg2 / asyncpg │                            │ (sidecar o local)  │
└─────────────────────┘                            └─────────┬──────────┘
                                                             │ TLS mutuo + IAM
                                                             ▼
                                                   ┌────────────────────┐
                                                   │ Cloud SQL instance │
                                                   │ (sin IP publica)   │
                                                   └────────────────────┘
```

En Cloud Run / GKE el proxy puede correr como *sidecar container*. En local, se corre como proceso aparte (`cloud-sql-proxy --port 5432 example-project:europe-west1:myinst`) y el cliente conecta a `localhost:5432`. **Para este modulo**, en lugar del proxy real contra Cloud SQL (coste), se usa Postgres en Docker en `localhost:5432`: la *forma* del DSN y del codigo cliente es identica, solo cambia que el otro lado del socket es Postgres local, no Cloud SQL + Auth Proxy. Esto es lo que hace reproducible el laboratorio sin facturar.

---

## 3. AlloyDB: cuando Cloud SQL no da mas

**AlloyDB** es un fork de Postgres rediseñado por Google: separa compute de storage, cachea paginas en memoria tier intermedio (Ultra Fast Cache), tiene columnar engine opcional para HTAP. Benchmarks de Google: ~4x Cloud SQL en OLTP transaccional, ~100x en analytics sobre el mismo dato.

Pero:

- **Coste**: minimo ~1.3 vCPU / 8 GiB, varias veces el precio de Cloud SQL `db-f1-micro`.
- **No es un drop-in** para cualquier Postgres: hay extensiones no soportadas; algunos tipos custom se comportan distinto.
- **Lock-in**: no es Postgres puro, migrar fuera requiere exportar.

Criterio: empieza en **Cloud SQL Postgres**. Si satura (p95 de query > SLA, write TPS cerca del maximo de la instancia, replicas de lectura ya sumadas), evalua AlloyDB como paso intermedio **antes** de considerar Spanner.

---

## 4. Firestore: modos Native vs Datastore, modelo documental

**Firestore** es la DB documental serverless de GCP. Dos modos **mutuamente excluyentes por project**:

- **Native mode** (el default moderno): modelo colecciones -> documentos -> subcolecciones; snapshots en tiempo real; transacciones ACID cross-document (hasta 500 writes/tx); SDKs para web/mobile con sincronizacion offline.
- **Datastore mode** (compat heredada): API Datastore clasica; sin realtime; strong consistency en ancestros. Solo tiene sentido si migras una app Datastore legacy.

En este modulo asumimos **Firestore Native**.

### Forma de los datos

```
db
└── collection: users
    └── document: user_abc123
        ├── field: name = "Ana"
        ├── field: created_at = <timestamp>
        └── subcollection: orders
            └── document: order_42
                ├── field: amount = 199
                └── field: status = "paid"
```

### Reglas de modelado que importan

1. **Query cuesta por documento leido**, no por tamano. Mantener documentos "razonables" (< 1 MiB cada uno, cientos de campos como maximo).
2. **Indices compuestos explicitos.** Firestore mantiene un indice simple por campo. Para `where("status","==","paid").orderBy("created_at")` necesitas declarar el indice compuesto `(status ASC, created_at DESC)` o la query falla con `FAILED_PRECONDITION`. En Terraform: `google_firestore_index`.
3. **No hay joins.** Si quieres joinear, duplicas. Modelado "para la query", no para la normalizacion.
4. **Transacciones ACID** multi-documento, pero con **limite de 500 writes** por tx; para batches mas grandes, usa `WriteBatch` (que es atomico tambien pero sin lectura).
5. **Reads de subcoleccion no bajan automaticamente.** `users/{uid}/orders` no se trae con el documento padre; es query aparte. Si necesitas "ultimas 3 ordenes del user" cada vez, duplica un campo `latest_orders` denormalizado.

### Antipattern

> "Guardar un documento gigante que crece sin tope (ej: una lista `comments` embebida que llega a 50 K entradas)". Cada read trae todo el documento. Hay que modelar comments como subcoleccion.

---

## 5. Bigtable: wide-column, series temporales y el pecado del hotspot

**Bigtable** es la DB wide-column managed de Google (la que corre Gmail, Search, Maps internamente). Modelo HBase-compatible: tabla -> row key (bytes) -> column families -> column qualifier -> timestamped cell. Escala horizontal a **millones de ops/s** con latencia p99 < 10 ms si el diseno es correcto.

### Row key disena todo

Bigtable ordena fisicamente las filas por row key en los tablets. Un prefijo muy popular crea un **hotspot** (un tablet servidor atendiendo todo). Reglas:

- Evita timestamps **monotono creciente** como prefijo (`20261019T...`). Todas las escrituras caen en el ultimo tablet.
- Patrones utiles:
  - **Prefijo por entidad + reverse timestamp**: `device#abc#` + `(MAX_LONG - ts)` -> escrituras distribuidas, lectura de "ultimos N puntos del device" es un scan corto.
  - **Hash corto de salting** (`sha1(entity)[:2] + entity + ts`): distribuye entre tablets pero cuesta leer "todos los puntos de una entidad" (hay que leer todos los sales).

### Para que si (y para que NO)

- **Si**: telemetria, metricas, feature stores, logs operacionales de alto volumen, dedup/stream state de pipelines.
- **No**: datos relacionales con joins, OLTP tipico, aplicaciones de bajo volumen (minimo 1 node ~500 USD/mes; para dev usa siempre emulador).

### Diferencia con DynamoDB

| Dimension | DynamoDB | Bigtable |
|-----------|----------|----------|
| Modelo | Key-value + document (JSON) | Wide-column (cells con timestamp) |
| Secondary indexes | GSI/LSI managed | *No* existen; hay que mantener tabla paralela |
| Transacciones | Multi-item (hasta 100) | Single-row atomica; no multi-row |
| Billing | Por request + storage | Por node + storage; nodos encendidos 24/7 |

DynamoDB cubre un rango mas amplio ("de 1 req/dia a 1 M req/s"); Bigtable esta diseñado para **el extremo alto sostenido**.

---

## 6. Spanner: SQL globalmente consistente

**Spanner** es la unica DB SQL comercial del mercado que ofrece **external consistency** (linearizability) distribuida globalmente. Lo que lo hace posible es **TrueTime**, el API de reloj de Google que expone **un intervalo** `[earliest, latest]` en el que *se garantiza* esta el "ahora". Un servidor espera `latest - earliest` antes de responder un commit, de modo que ninguna tx posterior pueda tener timestamp menor. Con antenas GPS + relojes atomicos en cada DC, ese intervalo es tipicamente < 7 ms.

Resultado: puedes correr una transaccion que lea y escriba en Berlin, Londres y Virginia y obtener semantica serializable **como si fuese una sola base en una sola maquina**. No hay otro producto comercial que haga esto.

Trade-off:

- Minimo 100 Processing Units (~65 USD/mes para empezar); escala en pasos finos pero el piso no es cero.
- Esquema relacional con **tablas interleaved** (hija fisicamente colocada con padre) para evitar joins caros.
- SQL ANSI-ish con limites: no toda feature de Postgres. Dialecto PostgreSQL opcional desde hace años.

### Cuando Spanner vs Cloud SQL

Elige Spanner si **cualquiera** de estos aplica:

1. Latencia de lectura consistente < 100 ms **desde multiples regiones** (no "replica eventual").
2. Necesitas transacciones ACID cross-region (p. ej. reserva de inventario global).
3. Tamaño activo esperado > 10 TB con QPS > 10 K sostenido.

Si **ninguno** aplica, Cloud SQL es dramaticamente mas barato y mas simple. No sobre-ingenieres.

---

## 7. Emuladores oficiales: por que son el core del dev local

Google publica emuladores **oficiales** de Firestore, Bigtable, Spanner y Pub/Sub. Son binarios/imagenes de Docker que corren en tu laptop y hablan **el mismo protocolo gRPC** que el servicio real. El SDK se re-dirige con una variable de entorno:

```bash
export FIRESTORE_EMULATOR_HOST=localhost:8080
export BIGTABLE_EMULATOR_HOST=localhost:8086
export SPANNER_EMULATOR_HOST=localhost:9010
```

Con esas vars, `google.cloud.firestore.Client()` ya no habla con GCP; habla con tu contenedor. Delta importante:

| Feature | Soportada en emulador |
|---------|-----------------------|
| CRUD / transacciones basicas | si |
| Indices compuestos (Firestore) | **no automatico**: no fallan en emulador aunque falten; en prod si |
| Reglas de seguridad (Firestore) | si |
| Replicacion multi-region (Spanner) | **no**: single-region solo |
| Backups / PITR | **no** |
| IAM real | **no** (todos los calls pasan) |

Reglas: **no uses el emulador para probar permissions ni replicacion**. Usalos para contratos de API, modelado de datos y tests de integracion.

Cloud SQL **no** tiene emulador oficial (es Postgres managed; se usa Postgres en Docker como stand-in del motor). El delta es: no obtienes el **Auth Proxy** ni **IAM auth** reales — se documentan.

---

## 8. Mapeo desde AWS

| AWS | GCP primario | GCP alternativo | Nota |
|-----|--------------|------------------|------|
| RDS Postgres/MySQL | Cloud SQL | AlloyDB (si rendimiento) | 1:1 funcional en lo basico. |
| Aurora Postgres | Cloud SQL o AlloyDB | — | Aurora **storage-decoupled** se parece mas a AlloyDB. |
| Aurora Global (lectores) | Spanner **o** Cloud SQL + read replica cross-region | — | Aurora Global es *eventual* para read-only; Spanner da strong. |
| DynamoDB (KV/document) | Firestore | Bigtable si throughput muy alto | DynamoDB cubre un rango que GCP divide en 2. |
| DynamoDB (streams + GSI) | Firestore + Firestore triggers | Bigtable + Dataflow | No hay GSI "managed" en Bigtable. |
| DocumentDB | Firestore | — | Firestore es mas moderno; MongoDB-compat no es nativo. |
| Keyspaces (Cassandra) | Bigtable | — | Modelo wide-column cercano. |
| Timestream | Bigtable | — | Series temporales: Bigtable con row key correcto. |
| Redshift | **BigQuery** | — | Fuera de este modulo. |
| ElastiCache Redis | Memorystore Redis | — | Fuera de este modulo. |

Patron de traduccion importante: **DynamoDB -> Firestore no siempre es 1:1**. Un diseno DynamoDB "single-table" con 20 patrones de acceso y PK compuestas termina mas limpio en Firestore si cada tipo de item se vuelve una coleccion; pero si el acceso predominante es "serie de eventos por entidad", muda a Bigtable, no a Firestore. La actividad 02 es exactamente ese ejercicio.

---

## 9. Consistency y transacciones comparados

| DB | Consistencia default | Transacciones | Scope de tx |
|----|----------------------|---------------|-------------|
| Cloud SQL | Postgres: strict serializable dentro de la instancia | ACID clasico | Dentro de la instancia |
| AlloyDB | Igual que Postgres | ACID clasico | Dentro de la instancia |
| Firestore Native | Strong (dentro de region) | ACID; cross-document | Hasta 500 writes/tx |
| Bigtable | Strong por row | Atomica single-row | 1 fila |
| Spanner | External consistency (linearizable global) | ACID distribuida | Global |

Elegir mal aqui es doloroso: p. ej. asumir "atomico multi-row en Bigtable" cuando no existe lleva a race conditions sutiles en produccion.

---

## 10. Checklist de decision rapida

Preguntas a hacer **antes** de elegir motor:

1. ¿SQL relacional o modelo distinto? -> si SQL, Cloud SQL/AlloyDB/Spanner; si no, Firestore/Bigtable.
2. ¿Multi-region con tx fuertes? -> Spanner, no hay alternativa.
3. ¿Throughput sostenido > 10 K ops/s? -> probablemente Bigtable.
4. ¿Documentos jerarquicos, acceso por key o filtros acotados? -> Firestore.
5. ¿Puedo defender la eleccion a Finance en una linea? -> si no, no esta clara.

Y la pregunta meta: **¿puedo validar este diseno con emuladores + Docker en mi laptop esta semana?**. Si la respuesta es no, el diseno es demasiado ambicioso para esta fase.
