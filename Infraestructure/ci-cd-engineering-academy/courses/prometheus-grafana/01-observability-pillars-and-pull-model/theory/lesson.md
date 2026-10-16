# Lección: Pilares de observabilidad y modelo pull

> **ID:** `obs-01-observability-pillars-and-pull-model` · **Nivel:** fundamentos · **Duración:** 2 h
> **Prerrequisitos:** HTTP y nociones básicas de sistemas.

---

## 1. Introducción intuitiva

Imagina que operas un servicio web pequeño. El equipo pone un *check* cada 60 segundos que hace `GET /health` y, si no responde `200`, suena un *buzzer*. Es cómodo: cuando el *buzzer* calla, el servicio "está bien".

Un día llega un reporte: "entre las 10:12 y las 10:17 el checkout fallaba intermitentemente". Vas al check: todo `200`. Vas a los logs: hay millones de líneas, sin filtros útiles. Vas al código: nadie midió nada. Terminas respondiendo *"no sé"*, lo cual en producción es una respuesta cara.

Ese check de salud es **monitoring**: *"mido lo que ya sé que importa"*. Funciona para fallos binarios conocidos. Falla para preguntas nuevas.

**Observabilidad** es la propiedad opuesta: un sistema es observable si **puedes responder preguntas nuevas sobre él sin desplegar código nuevo**. Para lograrlo no basta con alarmas: necesitas datos ricos, correlacionables, con contexto suficiente para preguntar lo que no previste.

En este módulo construyes ese cambio de modelo mental y entiendes, antes de instalar nada, **por qué Prometheus adopta un modelo *pull*** y qué implicaciones tiene.

---

## 2. Fundamentos

Antes de hablar de Prometheus, cuatro ideas que necesitas tener claras.

### 2.1 Monitoring vs observabilidad

- **Monitoring** = alarmar sobre señales conocidas de antemano. Lo preguntas una vez, lo mides para siempre. Ejemplo: "si CPU > 80 % durante 5 min, avisa".
- **Observabilidad** = tener suficiente telemetría de alta calidad para formular preguntas **que no previste**. Ejemplo: "¿qué tienen en común los requests que fallaron entre 10:12 y 10:17 — usuario, región, versión, cliente HTTP, endpoint?". No es una alarma: es una exploración.

Monitoring es un subconjunto de la observabilidad. No son opuestos — son niveles distintos de ambición. Toda organización necesita *monitoring* (alertas que despierten gente). Las que operan sistemas complejos necesitan además *observabilidad* (para no quedarse sin respuestas).

### 2.2 Los tres pilares

Un sistema observable produce tres clases de señales:

- **Metrics** (métricas) — números numéricos agregados en el tiempo: `requests_total`, `cpu_seconds`, `queue_depth`. Baratos de almacenar, caros de "zoom-in": dicen *cuánto*, raramente *por qué*.
- **Logs** — eventos discretos con texto: `2026-10-13T10:14:03 ERROR user=42 payment failed: card declined`. Rico contexto, caro de almacenar y buscar sin disciplina.
- **Traces** — grafos causales de un request a través de N servicios: `frontend → api → payments → bank`. Responden *dónde* se perdió el tiempo o falló algo en un sistema distribuido.

Pilares emergentes (reconocidos por la industria desde ~2022):

- **Events** — hechos de negocio discretos y de alto cardinal (deploys, feature flag toggles, incidentes). Útiles como anotaciones para correlacionar.
- **Continuous profiling** — perfilado continuo (CPU, memory, allocations) correlacionable con el resto. Herramientas: Pyroscope, Parca.

El modelo mental es: **cada pregunta tiene un pilar que la responde mejor**. Querer resolver todo con uno solo (p. ej. "logs para todo") es un anti-patrón clásico y caro.

### 2.3 Pull vs push

Las métricas pueden recolectarse de dos formas:

- **Push**: el proceso instrumentado *envía* sus métricas al colector (StatsD, InfluxDB push, OpenTelemetry OTLP export).
- **Pull**: el colector *consulta* al proceso instrumentado (Prometheus, SNMP). El proceso solo expone un endpoint (`/metrics`).

Prometheus eligió **pull** deliberadamente. No es un detalle de implementación: es una decisión arquitectónica con consecuencias que verás en §4.

### 2.4 Exporters

Un **exporter** es un proceso que traduce las métricas de "algo que no habla Prometheus" a un endpoint `/metrics` en formato Prometheus. Ejemplos: `node_exporter` (sistema operativo), `blackbox_exporter` (probes de red), `postgres_exporter`. Los exporters son el *driver* común: convierten el ecosistema heterogéneo (bases de datos, hardware, cloud APIs) en targets uniformes.

Memoriza estas cuatro ideas: **monitoring vs observabilidad**, **tres pilares**, **pull vs push**, **exporters**.

---

## 3. Contexto histórico

- **2003** — Google publica el paper interno **Borgmon**: un sistema de monitoreo basado en pull sobre endpoints HTTP, con un lenguaje propio para alerting. Era interno; se vuelve legendario por boca de SREs.
- **2012** — SoundCloud escribe **Prometheus**, abiertamente inspirado en Borgmon, por ingenieros ex-Google que querían el mismo modelo en open source.
- **2015** — Prometheus 0.x público, con PromQL y modelo de datos de series temporales etiquetadas.
- **2016** — Prometheus se incorpora a la CNCF como el **segundo proyecto graduado**, después de Kubernetes. No es coincidencia: K8s y Prometheus comparten diseño (controllers que reconcilian estado, APIs declarativas, service discovery nativo).
- **2017** — Dapper (Google, 2010) inspira **Jaeger** y **Zipkin**: *traces* como pilar de primera clase.
- **2019** — Nace **OpenTelemetry** (fusión de OpenTracing + OpenCensus): un estándar vendor-neutral para instrumentar métricas, logs y traces.
- **2021** — Honeycomb y otros popularizan el término **"observability"** como diferente de *monitoring*; aparece el libro *Observability Engineering* (Majors, Fong-Jones, Miranda).
- **2024+** — OTLP ingest nativo en Prometheus; **native histograms** sparse estabilizándose; perfilado continuo entra como "cuarto pilar" en la práctica.

Un dato cultural: Borgmon y Prometheus adoptaron pull **a pesar de que StatsD (push) ya era popular** en 2012. Fue una decisión contrarian, no la ruta de menor resistencia.

---

## 4. Funcionamiento interno

### 4.1 El loop fundamental de Prometheus

Simplificado al máximo:

```
cada scrape_interval (default 15s):
  for target in service_discovery.resolve():
    try:
      metrics = HTTP GET http://target/metrics  (timeout = scrape_timeout)
      tsdb.append(metrics, timestamp=now)
      up{target} = 1
    except (connection_refused | timeout | 5xx | parse_error):
      up{target} = 0        # ← este dato vale oro
```

Fíjate en lo que pasa cuando el target está caído: Prometheus **no se calla** — anota explícitamente `up{instance="…"} = 0`. Esa métrica existe sin que el target la emita; la *produce el scraper*. Es el fundamento de alertas tipo "este target lleva 2 min caído".

En push esa información se pierde o es ambigua: si no llegan datos, ¿es porque el proceso cayó, o porque la red cayó, o porque el colector está saturado, o porque simplemente ese proceso no tenía nada que decir? Pull convierte esa pregunta en una respuesta booleana.

### 4.2 Por qué pull es *simétrico y auditable*

- **Simétrico**: cualquiera con acceso de red al endpoint `/metrics` puede ver qué expone un proceso. Lo mismo que ve Prometheus lo ve un humano con `curl`. No hay "formato interno" opaco. Esto hace **testable** la instrumentación: puedes `curl` tu propio servicio y verificar que mide lo que dices.
- **Auditable**: el inventario de qué se scrapea vive en el config de Prometheus (o en el servicio de discovery). Sabes qué consulta a quién. En push, cualquier proceso puede enviar lo que quiera: la lista de emisores se descubre leyendo lo que llegó, no por diseño.
- **Service discovery → scrape**: Prometheus delega "qué existe" al descubrimiento (K8s API, Consul, EC2, file-based). Al correr sobre K8s, un `ServiceMonitor` nuevo activa scrapes nuevos sin reiniciar nada. Es declarativo y revisable.

### 4.3 Formato `/metrics`

Formato de texto deliberadamente simple (grep-able, `curl`-able):

```
# HELP http_requests_total Total HTTP requests served.
# TYPE http_requests_total counter
http_requests_total{method="GET",status="200"} 1027
http_requests_total{method="POST",status="500"} 3

# HELP process_cpu_seconds_total Total user and system CPU time.
# TYPE process_cpu_seconds_total counter
process_cpu_seconds_total 42.17
```

Características:

- Texto plano, UTF-8, línea por muestra. No binario, no protobuf (el binario existe pero se desaconseja). *(Nota: en 2024+ se añadió OTLP ingest nativo, pero el default sigue siendo text.)*
- Labels como `method="GET"` — crean *series* distintas.
- `# TYPE` y `# HELP` son metadatos: Prometheus parsea `# TYPE` para saber si tratar una métrica como `counter`, `gauge`, `histogram`, `summary`.

### 4.4 Modelo de datos

Cada muestra es:

```
(metric_name, {label1=value1, label2=value2, ...}, timestamp, float64_value)
```

El par `(metric_name, labelset)` define una **serie**. La TSDB de Prometheus está optimizada para write-heavy sobre muchas series pequeñas. Una serie "pesa" en RAM: por eso la **cardinalidad** (número de combinaciones únicas de labels) es la métrica a vigilar — se cubre en `obs-10`.

### 4.5 Límites estructurales del pull

Hay casos donde pull falla por diseño:

- **Jobs batch cortos**: un cron que dura 10 s y publica una métrica "cuántos registros procesó". Si tu `scrape_interval` es 15 s, Prometheus nunca lo verá vivo. Solución: `Pushgateway` — un intermediario push-friendly que *persiste* la última muestra para que Prometheus la scrapee cuando quiera. El job *empuja* al Pushgateway al terminar; el Pushgateway *es scrapeado* por Prometheus. Es la **excepción documentada**, no la regla, y añade estado operativo (hay que limpiar métricas obsoletas con `DELETE`).
- **IoT masivo** con muchísimos pequeños emisores detrás de NAT: Prometheus no puede alcanzar millones de dispositivos. Patrones de telemetría push (MQTT + ingesta en VictoriaMetrics, por ejemplo) encajan mejor.
- **Serverless efímero** (Lambda, Cloud Functions): instancias que viven segundos, sin dirección estable, sin ventana para scrape. Alternativas: emitir métricas a CloudWatch/Stackdriver y traerlas con un *exporter*, o usar `remote_write` push desde el stack serverless hacia un backend.

Regla operativa: si tu proceso vive **menos que tu `scrape_interval` o no es alcanzable por red**, pull no aplica. Para todo lo demás, pull es el default.

---

## 5. Ejemplo mínimo

Esto es solo **lectura**: no corre nada. Son dos endpoints `/metrics` ficticios para fijar el modelo mental.

**Servicio A — `api-gateway`**, expuesto en `http://10.0.0.11:9100/metrics`:

```
# HELP http_requests_total Requests served.
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/users",status="200"} 1830
http_requests_total{method="GET",path="/users",status="500"} 12
http_requests_total{method="POST",path="/orders",status="201"} 405
```

**Servicio B — `payments`**, expuesto en `http://10.0.0.12:9100/metrics`:

```
# HELP http_requests_total Requests served.
# TYPE http_requests_total counter
http_requests_total{method="POST",path="/charge",status="200"} 400
http_requests_total{method="POST",path="/charge",status="402"} 5
```

Prometheus los descubre vía SD (p. ej. K8s pods con label `scrape=true`), hace `GET /metrics` cada 15 s a cada uno, y **anota ambas series con la label `instance` que añade él**:

```
http_requests_total{instance="10.0.0.11:9100", job="apps", method="GET", path="/users", status="200"} = 1830
http_requests_total{instance="10.0.0.12:9100", job="apps", method="POST", path="/charge", status="402"} = 5
```

Si `payments` se cae, el próximo scrape falla, Prometheus escribe `up{instance="10.0.0.12:9100"} = 0`, y una alerta `up == 0 for 2m` dispara. **El dato "está caído" lo produce el scraper, no el servicio** — porque el servicio no puede reportarlo si está muerto. Esta es la ventaja estructural del pull.

Compara con el escenario push: `payments` se cae y simplemente **deja de enviar**. ¿Cómo distingue el colector "silencio por salud" de "silencio por muerte"? Con un *heartbeat* explícito que `payments` tendría que emitir — y que también deja de llegar cuando el proceso muere. Terminas construyendo medio modelo pull sobre el push.

---

## 6. Implementación progresiva

Este módulo es conceptual, pero el camino de aprendizaje operativo (que verás a partir de `obs-02`) tiene este orden:

1. **Nivel 0 — mental**: entender que pull existe y por qué (este módulo).
2. **Nivel 1 — manual**: `prometheus.yml` con `static_configs`, un target `node_exporter` local, un `GET /targets` en la UI (`obs-02`).
3. **Nivel 2 — tipado**: elegir `counter` vs `gauge` vs `histogram` para cada métrica (`obs-03`).
4. **Nivel 3 — PromQL**: calcular `rate()`, `sum by()`, cuantiles (`obs-04`).
5. **Nivel 4 — ecosistema**: exporters + relabeling (`obs-05`).
6. **Nivel 5 — dinámico**: service discovery real (K8s, EC2) sustituye a `static_configs` (`obs-06`).
7. **Nivel 6 — propio**: instrumentar una app Python (`obs-07`).

Cada nivel asume que el anterior está interiorizado. Saltarse `obs-01` lleva a usar push "porque es más fácil" sin entender qué se pierde.

---

## 7. Aplicación profesional

En el mundo real, estas preguntas aparecen en semanas 1-2 de cualquier proyecto de observabilidad:

- **"¿Datadog o Prometheus?"** Es una pregunta mal planteada. La respuesta sensata es: *push SaaS* (Datadog, New Relic) vs *pull OSS* (Prometheus/Grafana). El criterio es TCO + lock-in + capacidades del equipo, no "cuál es mejor".
- **"¿Y si usamos CloudWatch?"** CloudWatch es *push-centric* y nativo de AWS. Funciona bien si todo tu stack es AWS y nunca saldrás. Si tienes multi-cloud, workloads on-prem o quieres portabilidad, pierde.
- **"¿OpenTelemetry no reemplaza esto?"** OTel es *la capa de instrumentación* (SDK + Collector). Las métricas que recoge terminan en un backend: puede ser Prometheus (vía OTLP → Prometheus ingest), Datadog, Honeycomb, lo que sea. OTel no te libera de elegir backend; te libera de reescribir instrumentación cuando cambias de backend.
- **"¿Por qué no todo en logs?"** Porque los logs son caros (texto) y la agregación cardinal es lenta en el peor caso (full scan sobre strings). Las métricas son *agregados pre-computados* en origen: contar 1 M de requests cuesta ~16 bytes, no 1 M de líneas.
- **"Equipos pequeños, ¿vale la pena?"** Para 1-2 servicios y un VPS, un `/metrics` + Prometheus local + Grafana son 30 min de setup y rinden por años. El overhead real empieza al escalar long-term storage y gobernanza.

El patrón que verás en empresas serias:

- Instrumentación con **OpenTelemetry SDK** (vendor-neutral).
- **Prometheus/Mimir** para métricas (pull, con `remote_write` a long-term store).
- **Loki** para logs.
- **Tempo** / Jaeger para traces.
- **Grafana** como UI única.
- **Alertmanager** para alerting.

Y una regla: **nunca medir con una sola herramienta lo que resuelven varias juntas**. Métricas te dicen *qué está pasando*; logs te dicen *qué dijo el proceso en ese instante*; traces te dicen *dónde se perdió el tiempo*. Correlacionar las tres (gracias a labels y exemplars compartidos) es lo que hace observable un sistema.

---

## 8. Trade-offs

### 8.1 Ventajas del modelo pull

- **Simplicidad del cliente**: el proceso solo expone `/metrics`. No gestiona conexiones ni retries.
- **Audibilidad**: la lista de targets es explícita y revisable.
- **Detección de caídas gratuita**: `up == 0` es la alerta más barata y confiable que existe.
- **Service discovery nativo**: K8s/Consul/EC2 enchufan directo.
- **Testing trivial**: `curl` tu propio `/metrics` reproduce exactamente lo que ve Prometheus.
- **Debug asimétrico controlado**: puedes apuntar un segundo Prometheus al mismo target sin coordinar con nadie.

### 8.2 Limitaciones del modelo pull

- **Jobs batch cortos** → requieren Pushgateway (excepción, con sus costos).
- **NAT / firewalls** → el scraper necesita alcanzar el target. En redes muy segmentadas, hay fricción.
- **Cardinalidad** del lado del cliente — si tu `/metrics` tiene 100 k series, el scrape se vuelve lento y pesado. Problema de instrumentación, no del modelo.
- **Granularidad limitada por `scrape_interval`** — 15 s es un buen default; para medir latencias muy variables puedes necesitar 5 s, con costo en storage.
- **No apto para altas tasas de eventos sincrónicos**: métricas agregan, no transportan eventos individuales. Para esto, usa logs o traces.

### 8.3 Prometheus **no es**

Debes decirlo en voz alta para interiorizarlo:

- **No es una base de datos general** — no hagas JOIN sobre PromQL ni esperes transacciones.
- **No es almacenamiento de largo plazo** (default 15 días de retención local). Para eso: Thanos, Mimir, VictoriaMetrics (`obs-11`).
- **No es un sistema de eventos** — para audit trails, usa logs o un event store.
- **No es un sistema de logs** — para logs, Loki/Elastic.
- **No es un APM completo** — no te traza automáticamente un request end-to-end; para eso añades traces.

---

## 9. Errores frecuentes

1. **Usar push "porque es más intuitivo"** — y luego construir heartbeats y detección de caídas a mano, reinventando pull sin service discovery.
2. **Confundir "tengo un dashboard" con "soy observable"** — un dashboard es monitoring. Observabilidad empieza cuando puedes responder preguntas no previstas.
3. **Pedir todo con la misma herramienta** — intentar debug de un trace con PromQL, o calcular SLIs sobre logs. Cada pilar tiene su cometido.
4. **Alertar sobre causas en vez de síntomas** — "CPU al 95%" no es un síntoma del usuario; "latencia p99 > 2 s" sí lo es. Alertar sobre causas genera ruido.
5. **Instrumentar con labels de alta cardinalidad** (`user_id`, `request_id`, `email`) — explota la TSDB. Para esos atributos usa logs/traces/exemplars, no labels de métrica.
6. **Olvidar `up`** — `up == 0` es el primer dashboard y la primera alerta de todo stack Prometheus. Ignorarlo deja targets caídos silenciosamente.
7. **Pushgateway como regla, no excepción** — convertir todo en push mata las ventajas de pull. Pushgateway es para jobs batch cortos y punto.
8. **Creer que OpenTelemetry excluye Prometheus** — OTel es la capa de recolección; Prometheus es (uno de los) backends. Son complementarios.

---

## 10. Buenas prácticas

- **Pull por default**. Push solo para batch cortos vía Pushgateway, y documéntalo como excepción.
- **Service discovery siempre** que sea posible (K8s, Consul, file-based). `static_configs` solo para labs locales.
- **`up` dashboard y alerta** en el día 1 del stack.
- **Instrumenta en el borde** del servicio (middleware HTTP) con RED metrics: `rate`, `errors`, `duration`. Verás por qué en `obs-03`.
- **Labels con disciplina**: nunca pongas como label algo con cardinalidad potencialmente ilimitada.
- **Separa pilares conscientemente**: métricas para "cuánto", logs para "qué dijo", traces para "dónde se perdió el tiempo".
- **Instrumenta con OpenTelemetry** si tienes margen — te desacopla del backend.
- **Prefiere exporters existentes** antes que custom (hay para casi todo).

---

## 11. Ejercicios recomendados

Antes de ir a las actividades formales:

1. Describe en 3 frases, sin usar la palabra "pilares", qué diferencia hay entre monitoring y observabilidad.
2. Dibuja en papel el diagrama de scrape: Prometheus, service discovery, 3 targets, 1 caído. Marca dónde aparece `up == 0`.
3. Lista 2 escenarios donde Prometheus *no* sería tu primera elección y por qué.
4. Dado el log `2026-10-13 10:14:03 ERROR user=42 payment failed: card declined`, propón una métrica equivalente que capturaría la tendencia agregada sin perder la cardinalidad (`user=42` ¿va de label? ¿va en otro pilar?).

---

## 12. Evaluación

Responde (idealmente por escrito, forma parte del entregable del módulo):

1. En una frase: ¿qué permite responder la observabilidad que el monitoring no permite?
2. ¿Por qué `up` es un dato que *solo* el modelo pull puede producir gratis?
3. Un cron corre cada 5 min y dura 20 s procesando una cola. ¿Lo scrapea Prometheus directo? Si no, ¿qué patrón usas y por qué?
4. Enumera los tres pilares y asigna cada una de estas preguntas al pilar correcto:
   - "¿cuántos 5xx en la última hora?"
   - "¿qué dijo el servicio exactamente a las 10:14:03?"
   - "¿en qué servicio se perdieron 400 ms del request `abc123`?"
5. ¿Por qué Pushgateway es "excepción documentada" y no "la forma más fácil de hacer todo push"?
6. Un ingeniero propone "medir latencia con label `user_id` para ver por usuario". ¿Qué le respondes y qué alternativa le ofreces en otro pilar?
7. Define *exporter* en una frase. Da un ejemplo real.
8. ¿Prometheus es un sistema de retención larga? Si no, ¿qué se usa y cuándo?

Si puedes responder las 8 sin consultar la lección, estás listo para `obs-02`.

---

## Referencias

Ver `../resources/links.md`.
