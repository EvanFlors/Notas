# Actividad 02 — Análisis: cuándo NO adoptar OTel (todavía)

## 1. Identificación

- **ID:** `otel-01-02-when-not-otel`
- **Tecnología:** `opentelemetry`
- **Módulo:** `otel-01-what-and-why-signals-and-maturity`
- **Dificultad:** beginner
- **Duración estimada:** 40–50 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

OTel es el estándar; eso **no** quiere decir que adoptarlo hoy, en cualquier equipo, bajo cualquier circunstancia, sea la decisión correcta. El entusiasmo por adoptarlo puede llevar a invertir horas de ingeniería en algo que **todavía** no está maduro para el stack dado, o cuyo valor es marginal porque el equipo ya tiene algo que funciona.

Esta actividad entrena el músculo contrario al "adoptar por default": para **4 escenarios distintos**, decidir si OTel es la respuesta correcta **hoy**, y defender la decisión con criterios técnicos.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Articular **cuándo** adoptar OTel y cuándo no, con criterios **medibles** (madurez del SDK del lenguaje, madurez de las instrumentation libraries, madurez del signal relevante, horizonte de cambio de backend, tamaño del equipo, costo de instrumentación).
- Nombrar **al menos una alternativa concreta o estrategia parcial** cuando OTel no encaja hoy (SDK propietario del vendor, auto-instrumentation eBPF, esperar 6 meses, adoptar solo tracing…).
- Explicar el impacto de **profiling en incubación** sobre la decisión.
- Escribir un análisis corto, defendible y revisable por un peer.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §5, §6, §10).
- Haber recorrido `examples/02-status-page-walkthrough/`.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/otel-01-when-not
cd /tmp/otel-01-when-not
```

Puedes usar otro directorio, pero entonces debes pasárselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Los 4 escenarios

Para cada uno, escribe una sección en `DECISIONS.md` con el formato que ves más abajo.

#### Escenario 1 — Greenfield: 3 microservicios Python en EKS

> Startup arranca de cero. Stack previsto: 3 microservicios Python/FastAPI en EKS, equipo plataforma de 2 personas, aún no hay backend de observabilidad elegido. Quieren empezar con "lo correcto" desde el día uno.

#### Escenario 2 — Vendor APM contratado y pagado: Datadog en producción

> Empresa mediana lleva 3 años con Datadog (APM + logs + métricas), contrato firmado por 2 años más, el equipo tiene dashboards y runbooks maduros. Un ingeniero propone "migrar todo a OTel ya para evitar lock-in".

#### Escenario 3 — Stack poliglota con un lenguaje de SDK inmaduro

> App crítica en **Erlang/Elixir** (procesamiento de eventos) + servicios auxiliares en Node.js y Python. El SDK OTel en Erlang/Elixir tiene algunos signals aún en Alpha/Beta. El equipo quiere unificar observabilidad.

#### Escenario 4 — Equipo pequeño pide profiling continuo "con OTel"

> Equipo de 4 ingenieros en Go, servicio con quejas de alto consumo de CPU en producción. El tech lead oye hablar de "profiling en OTel" y plantea esperar a adoptar OTel para resolver el problema de CPU con el signal de profiling.

### 5.3 Formato de cada sección

Repite para los 4 escenarios:

```
## Escenario N — <nombre>

**Decisión:** OTel SÍ ya | OTel parcial | OTel NO (todavía) | Esperar

**Justificación (3–6 bullets):**
- criterio 1 (madurez SDK/signal, tamaño equipo, horizonte de cambio de backend, costo…)
- criterio 2
- …

**Alternativa / estrategia parcial:**
- herramienta/patrón concreto y por qué encaja (SDK del vendor, auto-instrumentation eBPF,
  adoptar solo traces, esperar GA del signal, dual-emit transitorio…)

**Riesgo si lo haces mal:**
- un impacto concreto (ej.: "SDK Alpha rompe en una minor y la app queda sin trazas",
  "6 meses de ingeniería para re-instrumentar sin ganancia operativa visible", …)
```

### 5.4 Síntesis final

Añade al final de `DECISIONS.md` una sección:

```
## Síntesis

**Regla de adopción OTel que me llevo:** <una frase>

**Rol del status page en mi decisión:** <2–3 frases>

**Impacto de profiling en incubación:** <2–3 frases>

**7 preguntas-criterio para decidir OTel sí / parcial / no / esperar:**
1. ...
2. ...
3. ...
4. ...
5. ...
6. ...
7. ...
```

Las 7 preguntas deben ser **tuyas**, cortas, operables (que un lead pueda contestar en una reunión). Ejemplos de forma (no las copies literalmente):

- "¿Están GA todos los signals que necesito para mi lenguaje?"
- "¿Tengo riesgo real de cambiar de backend en los próximos 24 meses?"

### 5.5 Entregable

Un archivo:

```
/tmp/otel-01-when-not/DECISIONS.md
```

con las 4 secciones + la síntesis.

## 6. Resultado esperado

- `DECISIONS.md` existe y es coherente.
- Cada escenario tiene decisión, justificación, alternativa y riesgo.
- La síntesis incluye regla de adopción, rol del status page, impacto de profiling, y las 7 preguntas numeradas.
- `bash tests/validate.sh /tmp/otel-01-when-not` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decisión está defendida con criterios técnicos (madurez, horizonte, costo), no con slogans.
- **Reproducibilidad**: cualquiera que lea tu análisis sabe por qué decidiste eso.
- **Mantenibilidad**: Markdown válido.

## 8. Validación

```bash
bash tests/validate.sh /tmp/otel-01-when-not
```

El validador comprueba **estructura**, no semántica. Compara tu análisis con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. En el escenario 1, ¿cambiaría tu decisión si el stack fuera **Rust** en lugar de Python? ¿Por qué?
2. En el escenario 2, el ingeniero insiste: "pero nos atamos a Datadog". ¿Cómo le respondes **sin** rechazar OTel ni rechazar Datadog?
3. En el escenario 3, ¿qué significa "adopción parcial" concretamente? Nombra qué sí y qué no.
4. En el escenario 4, ¿por qué el signal de profiling en incubación **no es** la respuesta hoy a un problema de CPU en producción?
5. ¿Cuál de los 4 escenarios es el más "obvio" y cuál el más "trampa"? Argumenta.

## 10. Extensiones

- Añade un **5.º** escenario propio (de tu trabajo real si puedes). Analízalo con el mismo formato.
- Para el escenario 2, diseña un **plan de 12 meses** para introducir OTel sin romper la relación con Datadog (pista: *dual-emit*, Collector + exporter Datadog).
- Para el escenario 3, propón un **experimento** de 2 semanas que decidiría si adoptar OTel en Erlang/Elixir ahora o esperar.

## 11. Limpieza

Como es puramente conceptual:

```bash
rm -rf /tmp/otel-01-when-not
```

No hay procesos ni contenedores que detener.
