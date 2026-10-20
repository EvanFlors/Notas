# Actividad 02 — ADR final: GitLab como plataforma CI/CD

## 1. Identificación

- **ID:** `gl-10-02-platform-adr-final`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-10-migration-and-platform-patterns`
- **Dificultad:** advanced
- **Duración estimada:** 100–140 min
- **Tipo:** architecture (independent — no depende de la actividad 01)

## 2. Contexto

Eres parte del equipo de **Platform** de una empresa de 300 ingenieros con 120 repos en GitLab (Premium, SaaS). Acabáis de terminar la migración piloto (actividad `01`) y la dirección pide un **ADR final** que defina **cómo se opera GitLab como plataforma** para el resto de 2026:

- **CI/CD Catalog interno**: qué componentes, cómo se contribuye, cómo se versiona, cómo se mide adopción.
- **Cost control**: SaaS runners vs runners propios (K8s + Fleeting). Decidir y justificar con números orientativos.
- **Observabilidad**: 4 métricas mínimas, fuentes, alertas.
- **Frontera CI/CD con Argo CD**: qué construye GitLab y qué despliega Argo. Por qué.
- **Elección GHA vs GitLab**: para 3 organizaciones ejemplo (startup 20 personas, scaleup 300 personas, enterprise 5000 personas) defender la elección con criterios.

El entregable es un único archivo `PLATFORM-ADR.md` que un equipo de Platform de 4 personas pueda ejecutar.

**Importante**: no hay cuenta GitLab real. El entregable es un **documento**.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Diseñar la gobernanza del catálogo CI/CD de una org real.
- Decidir SaaS vs runners propios con datos cuantitativos.
- Instrumentar 4 métricas y defender por qué esas 4.
- Trazar la frontera CI/CD con Argo CD sin solaparlos.
- Defender la elección GHA vs GitLab por tipo de organización.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo.
- Haber recorrido los tres `examples/` (sobre todo `02-cicd-catalog-governance` y `03-ci-metrics-dashboard`).
- Haber completado `gl-08` y `gl-09`.
- Herramientas: `bash`, editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/gl-10-platform
cd /tmp/gl-10-platform
```

### 5.2 Escribe `PLATFORM-ADR.md`

Formato ADR estándar. Secciones obligatorias (el validador las busca):

1. `# ADR` (encabezado con la palabra "ADR").
2. `## Estado` (o `Status`).
3. `## Contexto` (o `Context`).
4. `## Decisión` (o `Decision`).
5. `## Consecuencias` (o `Consequences`).
6. `## Alternativas` (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio:

- Sección **Catálogo** con mención de **inner-source**, **Code Owners**, **SemVer** y **deprecation** (o `@deprecated`).
- Sección **Runners / Cost** comparando **SaaS** y **K8s** (o **Fleeting**).
- Sección **Observabilidad** nombrando al menos **4 métricas** (de: `duration`, `queue`, `success rate`, `minutos`/`consumidos`, `queue time`).
- Sección **Argo CD** o **GitOps** describiendo la frontera (CI construye / CD aplica).
- Sección o tabla **GHA vs GitLab** cubriendo **3 organizaciones** (startup, scaleup, enterprise u equivalentes nombradas).
- Mención explícita de **Compliance** / **Compliance Framework** (gobernanza heredada).
- Al menos **1 fenced code block** (ejemplo de PromQL, de YAML del catálogo, de rule, lo que elijas).
- **2 alternativas descartadas** (`#` sub-headings o `1.`/`2.` numerados).

### 5.3 Entregable

```
/tmp/gl-10-platform/PLATFORM-ADR.md
```

## 6. Resultado esperado

- Documento coherente, defendible ante dirección y ante Platform.
- El validador pasa en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decisión justificada con criterio (no solo opinión).
- **Reproducibilidad**: un nuevo miembro de Platform puede leerlo y ejecutar.
- **Mantenibilidad**: Markdown válido.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-10-platform
```

Compara con `solution/REFERENCE.md` para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Qué componente del catálogo introducirías **antes** que los demás y por qué?
2. ¿Cuál es el umbral de minutos/mes a partir del cual los runners propios ganan?
3. Si solo pudieras instrumentar 1 métrica, ¿cuál y por qué?
4. ¿Qué pasa el día que GitLab tiene una caída de 2 h en SaaS?
5. En la decisión GHA vs GitLab, ¿cuál es el *tie-breaker* más honesto para una scaleup de 300 personas?

## 10. Extensiones

- Añade una **sección de riesgos** con 5 riesgos de operar GitLab como plataforma y mitigaciones.
- Añade un **roadmap** a 12 meses (Q1 lanzar catálogo con 3 componentes, Q2 runners propios piloto, etc.).
- Añade un **modelo de SLOs** de la plataforma CI/CD (p95 duration, success rate target, queue time target).

## 11. Limpieza

```bash
rm -rf /tmp/gl-10-platform
```
