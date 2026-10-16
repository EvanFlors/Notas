# Actividad 01 — Canvas del primer golden path: "nuevo microservicio Python"

## 1. Identificación

- **ID:** `plat-02-01-define-first-golden-path`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-02-golden-paths-paved-roads-and-developer-experience`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 02)

## 2. Contexto

Estás arrancando una plataforma interna para una organización de **~50 ingenieros** repartidos en **8 equipos stream-aligned**. En el último trimestre se han creado **12 microservicios Python nuevos** y en todos han discutido lo mismo: framework, logging, CI, Dockerfile, Helm chart, despliegue. Cada uno ha resuelto distinto.

El platform team tiene **3 personas** y presupuesto para construir **un** primer golden path este trimestre.

Tu tarea: rellenar el **canvas** del golden path candidato "nuevo microservicio Python" y defenderlo con criterios explícitos. **No** vas a construir el path — solo a diseñarlo lo suficiente para que un comité decida si vale la pena invertir.

El entregable es un documento Markdown. **No hay** cluster, ni `kubectl`, ni código.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Rellenar las **8 secciones** del canvas (ver `examples/02-first-golden-path-canvas/`).
- Justificar la elección contra los **4–5 criterios** (volumen, variabilidad, dolor, impacto, riesgo).
- Definir una **constelación de 3–5 métricas DX** con *valores objetivo numéricos*, no "rápido".
- Nombrar el **long tail** explícitamente y la postura ante él.
- Identificar al menos **3 antipatterns** de la lección y cómo los evitarás.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (especialmente §5, §6, §7, §10).
- Haber recorrido `examples/02-first-golden-path-canvas/` y `examples/03-dx-metrics-samples/`.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-02-golden-path
cd /tmp/plat-02-golden-path
```

Puedes usar otro directorio, pero entonces pásalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `CANVAS.md` con las 8 secciones

Usa la plantilla de `examples/02-first-golden-path-canvas/README.md` como esqueleto. Cada sección es un `##` encabezado.

Secciones **obligatorias** (el validador las comprueba por título):

1. `## 1. Caso de uso`
2. `## 2. Usuarios objetivo`
3. `## 3. Alcance`
4. `## 4. Criterios`
5. `## 5. Métricas`
6. `## 6. Long tail`
7. `## 7. Owner`
8. `## 8. Riesgos`

Reglas de contenido:

- **Sección 3 (Alcance)** debe listar como mínimo: scaffolding, CI, chart/manifest, observabilidad (logs/metrics/traces), registro en catálogo.
- **Sección 4 (Criterios)** debe dar un argumento (1–3 líneas) para **cada uno** de los 4 criterios base (volumen, variabilidad baja, dolor compartido, impacto medible). Opcionalmente el quinto (bajo riesgo de regresión).
- **Sección 5 (Métricas)** debe listar **al menos 3** métricas DX con valor numérico objetivo (p. ej. `TTP p50 < 24h`, `adopción > 50 %`, `NPS ≥ 30`).
- **Sección 6 (Long tail)** debe nombrar al menos **2 casos excluidos** y qué postura adoptas (opción B soportada / opción B no soportada / mandato selectivo).
- **Sección 7 (Owner)** debe nombrar un **owner concreto** (persona + rol, p. ej. "Ana López — Platform Lead"), política de versionado (SemVer) y de deprecations.
- **Sección 8 (Riesgos)** debe listar al menos **3 antipatterns** (ver §10 del lesson) y cómo los evitas.

### 5.3 Entregable

```
/tmp/plat-02-golden-path/CANVAS.md
```

## 6. Resultado esperado

- `CANVAS.md` existe y es coherente.
- Las 8 secciones están presentes.
- Las métricas incluyen valores numéricos objetivo.
- El long tail está nombrado explícitamente.
- `bash tests/validate.sh /tmp/plat-02-golden-path` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada sección es específica, no genérica.
- **Reproducibilidad**: un lector puede imaginar el path a partir del canvas.
- **Mantenibilidad**: Markdown válido.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-02-golden-path
```

El validador comprueba **estructura**, no semántica. Compara tu análisis con `solution/REFERENCE.md` después para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué "nuevo microservicio Python" probablemente es un buen primer path y "entrenar un modelo ML" probablemente no lo es?
2. Si solo pudieras medir **una** métrica DX, ¿cuál elegirías y qué perderías?
3. ¿En qué momento convertirías este golden path en un **mandato**? ¿Qué señales lo justifican?
4. ¿Cómo evitas que el canvas sea "optimista" (todo cubierto, ningún long tail, ninguna métrica puede empeorar)?
5. ¿Qué pasaría si el owner del path se va de la empresa el próximo trimestre?

## 10. Extensiones

- Añade una sección **9. Plan de release** (fases: alpha, beta, GA, deprecated).
- Añade una sección **10. Feedback loops** describiendo cadencia de entrevistas, survey y telemetría.
- Dibuja un diagrama ASCII del flujo "developer click → repo en prod" indicando dónde el platform team opera y dónde solo documenta.

## 11. Limpieza

```bash
rm -rf /tmp/plat-02-golden-path
```

No hay procesos ni contenedores que detener.
