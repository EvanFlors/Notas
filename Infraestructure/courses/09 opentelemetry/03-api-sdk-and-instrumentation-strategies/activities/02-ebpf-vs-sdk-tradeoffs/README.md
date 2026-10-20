# otel-03-02 — Análisis: eBPF vs SDK (independiente)

## 1. Identificación
- **ID:** `otel-03-02-ebpf-vs-sdk-tradeoffs`
- **Tecnología:** opentelemetry
- **Módulo:** 03-api-sdk-and-instrumentation-strategies
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** independent (análisis escrito)

## 2. Contexto
Vas a entrar a una organización con 4 servicios heterogéneos. Alguien ya decidió "usemos OTel", pero *cómo* instrumentar cada uno sigue abierto. Tu tarea: proponer, por servicio, la estrategia (**manual / library / auto / eBPF / ninguna**) y defenderla por escrito.

El output es un **documento**, no código.

## 3. Objetivos
- Elegir y justificar una estrategia por servicio.
- Nombrar al menos una herramienta eBPF concreta (Pixie, Beyla, Hubble).
- Identificar al menos un caso donde eBPF sea *la única* opción razonable.
- Sintetizar 5 criterios reutilizables.

## 4. Prerrequisitos
- Haber leído `theory/lesson.md` del módulo.
- Un editor de texto. No se requiere red, SDK, Docker ni cluster.
- Sin costos.

## 5. Instrucciones

### Paso 1 — Scratch
```bash
rm -rf /tmp/otel-03-02
mkdir -p /tmp/otel-03-02
cp starter/template.md /tmp/otel-03-02/ANALYSIS.md
```

### Paso 2 — Para cada uno de los 4 escenarios, decide y justifica

Rellena `ANALYSIS.md` manteniendo las secciones `## Escenario N`. Cada sección debe contener:

- Breve descripción del servicio.
- Línea `Decisión: <manual|library|auto|ebpf|ninguna> + opcionalmente combinadas`.
- Justificación de 3–6 líneas que mencione al menos uno de: *acceso al código fuente*, *madurez del SDK*, *lenguaje*, *criticidad de la lógica de dominio*, *permisos del nodo* (CAP_BPF, hostPID).

Los 4 escenarios (ya listados en el starter):

1. **checkout-api** — Python 3.12 FastAPI greenfield, con PostgreSQL y Redis. Tiene lógica de cupones y reserva de inventario.
2. **legacy-pricing** — binario Go 1.17 cerrado (no hay fuente disponible), expone HTTP interno en el cluster. Debes dar visibilidad "ya".
3. **payments-worker** — worker Python 3.11 celery. Procesa cobros con una pasarela externa. La trazabilidad del cobro end-to-end es un requisito de auditoría.
4. **cron-sync-bash** — script Bash que corre cada 15 min, hace `rsync` y `curl`. ~30 s de ejecución.

### Paso 3 — Síntesis
Al final de `ANALYSIS.md`, incluye una sección `## Síntesis` con exactamente 5 criterios numerados (`1.` … `5.`) que resuman cómo elegirías en el futuro. Al menos uno debe referirse a eBPF.

### Paso 4 — Validar
```bash
bash courses/opentelemetry/03-api-sdk-and-instrumentation-strategies/activities/02-ebpf-vs-sdk-tradeoffs/tests/validate.sh /tmp/otel-03-02
```

## 6. Resultado esperado
`/tmp/otel-03-02/ANALYSIS.md` con 4 secciones de escenario + síntesis con 5 criterios, mencionando al menos una herramienta eBPF concreta.

## 7. Criterios de aceptación
- Estructura: 4 escenarios + síntesis con 5 criterios numerados.
- Cada escenario incluye marca `Decisión:` seguida de la estrategia elegida.
- Se nombra al menos una herramienta eBPF (Pixie, Beyla, Hubble).
- Al menos un escenario incluye un *trade-off* explícito (no todo es blanco/negro).
- No se filtran credenciales ni nombres propios de empresa.

## 8. Validación
`bash tests/validate.sh /tmp/otel-03-02` imprime reporte y exit 0 si la estructura cumple. **La corrección semántica** se evalúa manualmente contra `solution/REFERENCE.md`.

## 9. Preguntas de reflexión
- ¿Qué servicio *no* ganaría nada con eBPF, aunque técnicamente se pueda?
- ¿Dónde es más fuerte el argumento "eBPF nos ahorra tocar el binario"?
- ¿Qué pierdes si eliges solo eBPF para el checkout-api?
- ¿Un worker Celery se cubre mejor con auto o con manual? ¿Por qué?

## 10. Extensiones
- Añade un 5º escenario inventado por ti (p. ej. FaaS, mobile backend).
- Convierte la decisión en una tabla "signal × servicio × estrategia".
- Dibuja un árbol de decisión que resuma los 5 criterios.

## 11. Limpieza
```bash
rm -rf /tmp/otel-03-02
```
