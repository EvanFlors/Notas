# Ejemplo 02 — Recorrido guiado por el OTel Status Page

> Lectura y análisis. Sin ejecución. Objetivo: aprender a **leer** la matriz oficial de madurez y a **no asumir** que "Python está GA" significa que todo en Python está GA.

## 1. Dónde vive el status

OTel publica el estado de **cada lenguaje × cada signal × cada componente** en:

- `https://opentelemetry.io/status/` — vista principal.
- `https://opentelemetry.io/docs/languages/<lang>/` — detalle por lenguaje.
- Repos individuales por lenguaje (p. ej. `github.com/open-telemetry/opentelemetry-python`) con sus propios `CHANGELOG` y matrices.

Nota: el status page **cambia**. Lo que aquí se describe es el *patrón* para leerlo; los valores concretos pueden evolucionar.

## 2. Los 5 estados que debes reconocer

| Estado | Qué significa en la práctica | Cuándo adoptar |
|--------|------------------------------|----------------|
| **Stable (GA)** | API/SDK 1.x. Breaking changes solo en 2.0. | Producción. |
| **Beta** | Funcional, interfaz probable que estabilice. Pueden haber cambios menores. | Pre-prod y adopción temprana. |
| **Alpha** | Funciona en happy path. La interfaz **puede romper** sin aviso extenso. | Prototipos, dev interno. **No** prod crítica. |
| **Experimental** | En diseño activo. Puede desaparecer o reorganizarse. | Solo para experimentar. |
| **Not implemented** | No existe aún para esa combinación. | Esperar o contribuir. |

## 3. Matriz tipo (ilustrativa — verificar valores reales)

```
                 │ Traces │ Metrics │  Logs  │ Profiling │
─────────────────┼────────┼─────────┼────────┼───────────┤
 Java            │ Stable │ Stable  │ Stable │   Alpha   │
 .NET            │ Stable │ Stable  │ Stable │   Alpha   │
 Python          │ Stable │ Stable  │ Stable │   Alpha   │
 Node.js         │ Stable │ Stable  │ Stable │   Alpha   │
 Go              │ Stable │ Stable  │ Stable │   Alpha   │
 Ruby            │ Stable │ Stable  │  Beta  │   Alpha   │
 PHP             │ Stable │ Stable  │ Stable │   Alpha   │
 C++             │ Stable │ Stable  │ Stable │  Not impl │
 Rust            │  Beta  │  Alpha  │ Alpha  │  Not impl │
 Erlang/Elixir   │ Stable │  Beta   │ Alpha  │  Not impl │
 Swift           │  Beta  │  Alpha  │  Alpha │  Not impl │
```

> **Advertencia:** los valores anteriores son **ilustrativos** para el ejercicio de lectura. Antes de tomar una decisión real, **ir al status page oficial** y confirmar. Lo que **no cambia** es el **patrón**: traces es el signal más maduro, metrics después, logs después, profiling todavía experimental.

## 4. Lo que la matriz grande NO te dice (y que importa)

El status de un lenguaje es solo la **superficie**. Debajo hay 3 capas más donde la madurez puede ser otra:

### 4.1 Instrumentation libraries

Cada *framework* (FastAPI, Django, Rails, Spring, Express…) y cada *driver* (psycopg, redis, boto3…) tiene su propio package `opentelemetry-instrumentation-<X>`. Cada uno con su propio estado.

Ejemplo (ilustrativo, Python):

```
 opentelemetry-instrumentation-fastapi    → Stable
 opentelemetry-instrumentation-django     → Stable
 opentelemetry-instrumentation-requests   → Stable
 opentelemetry-instrumentation-psycopg2   → Stable
 opentelemetry-instrumentation-redis      → Stable
 opentelemetry-instrumentation-httpx      → Beta
 opentelemetry-instrumentation-<nuevo>    → Alpha
```

**El SDK Python puede estar GA mientras la instrumentation library del framework que usas está en Alpha.** Cuidado.

### 4.2 Semantic Conventions

Un segundo tipo de madurez: las **semconv** por dominio (HTTP, DB, messaging, RPC, k8s, cloud, faas, gen-ai…) tienen cada una su propio estado:

```
 http        → Stable (v1.0 publicado)
 db          → Stable para SQL, Beta para NoSQL
 messaging   → Beta
 rpc         → Stable
 k8s         → Stable
 cloud       → Beta
 faas        → Beta
 gen-ai      → Experimental
```

Esto afecta a tus **dashboards y alertas**: si usas atributos de un dominio Experimental, puede que mañana se renombren.

### 4.3 Collector components

El Collector tiene **Core** (componentes oficiales, GA-bias) y **Contrib** (todos los exporters/receivers/processors de la comunidad). Dentro de contrib, cada componente tiene su propio estado:

```
 receiver/otlpreceiver             → Stable
 receiver/prometheusreceiver       → Beta
 receiver/kafkareceiver            → Beta
 processor/batch                   → Stable
 processor/memorylimiter           → Stable
 processor/tail_sampling           → Beta
 processor/transform (OTTL)        → Alpha → Beta en algunas funciones
 exporter/otlpexporter             → Stable
 exporter/datadogexporter          → Beta
 exporter/lokiexporter             → Beta
```

Un pipeline puede usar un receiver Stable, un processor Beta y un exporter Alpha. **El estado global del pipeline es el del eslabón más débil.**

## 5. Cómo tomar una decisión informada

Antes de adoptar OTel para un servicio concreto, verifica — en este orden:

1. **Lenguaje** del servicio: ¿está GA el SDK para los signals que te interesan?
2. **Instrumentation libraries** que vas a usar: ¿están GA/Beta las de tu framework + drivers?
3. **Signals** que necesitas: ¿están todos GA en tu lenguaje? (Especialmente profiling: hoy casi siempre no.)
4. **Semconv** de tu dominio: ¿los atributos que vas a usar están en una semconv Stable?
5. **Collector components** del pipeline previsto: ¿todos Beta o mejor?

Si todo da verde: adelante. Si alguno está Alpha/Experimental y es **crítico**, considera **esperar**, **pin exact version** y evaluar en 3–6 meses, o **adoptar con bandera de riesgo** documentada.

## 6. Trampas habituales al leer el status

- Confundir **"GA del lenguaje"** con **"GA de todo el stack"**. Ya cubierto; es el error #1.
- Confundir **"la spec está estable"** con **"mi SDK la implementa al 100 %"**. La spec puede estabilizar antes que una implementación.
- Confundir **"está en Contrib"** con **"es inestable"**. Contrib no es sinónimo de alpha; hay componentes Contrib Stable.
- Usar un atributo **deprecated** (p. ej. `http.method` cuando ya existe `http.request.method` Stable). Los dashboards se rompen silenciosamente — se cubre en `otel-02`.
- Asumir que **profiling** va a estar GA "pronto". Puede o no. Diseña como si fueras a vivir sin él por 1–2 años más.

## 7. Preguntas de autocomprobación

1. Si tu servicio usa `fastapi` + `httpx` + `psycopg3` y el status de `opentelemetry-instrumentation-httpx` está en **Beta**, ¿qué haces?
2. ¿Qué significa que **profiling** aparezca como **Alpha** en Python para una decisión de adoptar OTel **hoy** en tu organización?
3. Si `exporter/datadogexporter` está en Beta y necesitas enviar a Datadog, ¿cuál es el plan B (pensando en vendor-neutral)?
4. ¿Por qué el `opentelemetry-instrumentation-<X>` de un paquete muy nuevo probablemente esté en Alpha aunque el SDK Python esté GA?

Las respuestas se discuten en las actividades, especialmente en `02-when-not-otel/`.
