# Actividad 02 — ADR: `component` vs `include` vs `extends` para 3 escenarios

## 1. Identificación

- **ID:** `gl-05-02-adr-components-vs-includes`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-05-reuse-include-extends-and-cicd-components`
- **Dificultad:** intermediate
- **Duración estimada:** 60–80 min
- **Tipo:** architecture (independiente de la actividad 01)

## 2. Contexto

Tu grupo `payments/` tiene 12 proyectos y 2 workloads activos. En la última retro de plataforma se discutieron tres situaciones de reutilización reales:

- **Escenario A — "El job de smoke test duplicado 4 veces en el mismo pipeline"**. Dentro del `.gitlab-ci.yml` de `payments/checkout-api`, hay 4 jobs (`smoke:dev`, `smoke:stg`, `smoke:prod`, `smoke:canary`) que son prácticamente idénticos salvo variables de entorno. Son 60 líneas de duplicación en un solo archivo.
- **Escenario B — "El pipeline Node compartido entre 3 proyectos del mismo grupo"**. `payments/checkout-api`, `payments/webhooks-api` y `payments/refunds-worker` tienen el mismo bloque de lint+test. Solo tres consumidores, mismo grupo, mismo stack.
- **Escenario C — "El pipeline de build+sign de imágenes para toda la org"**. 11 proyectos de 4 grupos distintos quieren un mismo flujo de `docker build + cosign sign + push`. Compliance exige poder decir qué versión del flujo se usó en cada deploy.

Tu encargo: **escribir un ADR** justificando qué mecanismo (`extends:`, `include:`, o CI/CD Component) usar para cada escenario, con trade-offs y alternativas descartadas.

**Importante**: no se escribe YAML aquí; se escribe **prosa de decisión**. El entregable es un documento.

## 3. Objetivos

Al terminar deberías poder, sin consultar la lección:

- Nombrar el mecanismo correcto para cada escenario y por qué.
- Enunciar al menos 2 trade-offs por mecanismo (contrato tipado, versionado, blast radius, costo de mantenimiento).
- Reconocer anti-patrones típicos (`include: remote:` con `main`, `extends:` de 5 niveles, componente sin `spec:inputs:`).
- Escribir un ADR legible por otro equipo.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§2, §3, §4, §7 son los más relevantes).
- Haber recorrido los tres `examples/` del módulo.
- Herramientas: `bash` y un editor Markdown.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gl-05-02
cd /tmp/gl-05-02
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-REUSE-STRATEGY.md`

Formato ADR estándar:

```
# ADR 002 — Estrategia de reutilización en GitLab CI/CD

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2-4 párrafos: los 3 escenarios, el grupo, los constraints)

## Decisión
(Un mecanismo por escenario, con justificación corta y concreta.
Idealmente una tabla resumen al principio y un apartado por escenario.)

## Consecuencias
(Qué ganas, qué pierdes por decisión. Debe cubrir positivas y negativas.)

## Alternativas descartadas
(Al menos 2 alternativas por escenario — o 2 globales — y por qué no.)
```

Secciones obligatorias (el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives`).

Contenido mínimo (el validador lo exige):

- Mención explícita de los tres mecanismos: **`extends`**, **`include`**, **CI/CD Component** (o Components).
- Mención de los tres escenarios por nombre: **"Escenario A"**, **"Escenario B"**, **"Escenario C"** (puedes añadir subtítulos propios).
- Mención de **`spec:inputs:`** o del concepto *contrato tipado* para el componente.
- Mención de **SemVer** o *tag* como estrategia de versionado para el componente.
- Al menos **2 alternativas** descartadas (p. ej. "`include: remote:` con `main`", "composite action adaptada", "mantener duplicado").
- Mención de al menos un **anti-patrón** (`include: remote:` con `main`, `extends:` muy profundo, componente sin `spec:inputs:`, consumer apuntando a `main` del componente, etc.).

### 5.3 Entregables

```
/tmp/gl-05-02/
└── ADR-REUSE-STRATEGY.md
```

### 5.4 Ejecuta el validador

```bash
bash tests/validate.sh /tmp/gl-05-02
```

Debe terminar con `OK: estructura valida.` y exit code 0.

## 6. Criterios de aceptación

- `ADR-REUSE-STRATEGY.md` existe y tiene las 5 secciones ADR estándar.
- Menciona los 3 mecanismos (`extends`, `include`, component) y los 3 escenarios (A, B, C).
- Menciona `spec:inputs:` y SemVer.
- Lista al menos 2 alternativas descartadas y al menos 1 anti-patrón.
- `bash tests/validate.sh` retorna 0.

## 7. Autoevaluación

Compara con `solution/REFERENCE.md`:

- ¿Elegiste `extends:` para A, `include: project:` o component para B, y **component** para C? Si no, ¿tu justificación es defendible?
- ¿Tu ADR cubre el **blast radius** (quién se rompe si cambia el YAML compartido)?
- ¿Mencionas la **asimetría de responsabilidad**: el componente puede fallar al parse en los 11 consumers si quien lo mantiene publica mal una versión?

## 8. Qué sigue

→ Si no la has hecho, `../01-extract-component-from-pipeline/` te hace vivir en código lo que acabas de escribir.
→ `gl-06` cambia de tema: ejecutores de runner y OIDC a cloud.
