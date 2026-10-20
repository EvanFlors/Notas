# Actividad 02 — ADR de migración y pipeline en dual-run

## 1. Identificación

- **ID:** `jk-08-02-migration-adr-and-dual-run`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-08-operate-at-scale-and-migration-to-modern`
- **Dificultad:** advanced
- **Duración estimada:** 110–140 min
- **Tipo:** mini-project (independent — no depende de la actividad 01)

## 2. Contexto

La misma fintech del contexto operacional (`jk-08-01`) decide **planificar la migración** del Jenkins a **GitHub Actions** porque:

- Todos los repos ya viven en una GitHub Enterprise corporativa.
- El equipo platform tiene experiencia en GHA en otros proyectos.
- Compliance pide **retirar credentials de larga duración**; OIDC federation es el camino.
- Los 40 pipelines freestyle sin dueño son deuda insoportable.

Inventario resumido:

| Pipeline | Tipo | Estado | Owner | Notas |
|----------|------|--------|-------|-------|
| `orders-api-ci` | pipeline | activo | backend | Build + test + push imagen a ECR. Pipeline simple, crítico. |
| `payments-nightly` | pipeline | activo | payments | Jobs nocturnos de reconciliación. Complejo. |
| `legacy-report-weekly` | freestyle | sin runs 180d | ninguno | Candidato a retirar. |
| `docs-site` | pipeline | activo | docs | Build + deploy a Netlify. Simple, no crítico. |
| `app-release-{a,b,c,d}` | freestyle | activo | releng | 4 jobs idénticos con parámetros. Consolidar antes de migrar. |
| ... (120 total) | | | | |

Tu encargo:

1. **ADR de migración** completo (`ADR-MIGRATION.md`) con inventario resumido, clasificación, elección de target, plan por fases, dual-run framework, OIDC design y criterios de apagado.
2. Un **pipeline de ejemplo en dual-run**: `Jenkinsfile` + `.github/workflows/dual-run.yml` equivalentes, mostrando el reemplazo de `withCredentials` por OIDC.

**Importante**: no hay GitHub real ni AWS real. No se despliega nada. Entregables son documentos y archivos de pipeline estáticos validados estructuralmente.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Clasificar pipelines en migrar / consolidar / retirar y justificar.
- Elegir un target de migración con criterio contra alternativas.
- Diseñar un dual-run con criterios de corte y rollback.
- Escribir un workflow GHA que use OIDC en lugar de credenciales de larga duración.
- Defender el plan contra "si funciona no lo toques" y contra "migra todo ya".

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§6–§10).
- Haber recorrido `../../examples/02-dual-run-jenkins-and-gha/` y `../../examples/03-migration-plan-template/`.
- Haber completado `jk-04`, `jk-06`, `jk-07`.
- Haber visto en algún momento un workflow GHA (del curso `github-actions` o similar).
- Herramientas: `bash` y un editor de texto. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/jk-08-02/.github/workflows
cd /tmp/jk-08-02
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-MIGRATION.md`

Formato ADR estándar con secciones obligatorias (el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio en el ADR (el validador lo exige):

- Al menos un **diagrama ASCII** del flujo dual-run (con fences de código).
- Mención explícita del **target elegido** (`GitHub Actions`, `GHA`, `GitLab CI` o `Argo Workflows`).
- Las tres clases del inventario: **`migrar`**, **`consolidar`**, **`retirar`**.
- Mención de **`dual-run`** o `dual run`.
- Mención de **`OIDC`** y de la eliminación/retirada de **`withCredentials`** o `access key` de larga duración.
- Mención de **`Shared Librar`** y su reemplazo (`reusable workflow`, `CI/CD Component`, `WorkflowTemplate`).
- Mención de **`archiv`** (archivado histórico) y **`compliance`** o **retención**.
- Mención explícita de **criterios de corte** o **rollback**.
- Mención de **fase** o **fases** del plan.
- Mención explícita de los dos pipelines canary de ejemplo: **`orders-api`** y **`docs-site`** (o justificación si eliges otros del inventario).

### 5.3 Escribe `Jenkinsfile`

Un `Jenkinsfile` **declarative** para el pipeline `orders-api-ci`:

- Debe empezar con `pipeline {`.
- Debe tener bloque `agent` (puede ser `kubernetes`, `docker` o `any`).
- Debe tener `stages {` con al menos 3 stages: `Install` (o `Build`), `Test`, y `Publish` (o `Deploy`).
- Debe usar `withCredentials` en el stage de publish (es el patrón **viejo** que la migración elimina).
- Debe mencionar `s3://` o `ecr` en el publish (destino del artefacto).

### 5.4 Escribe `.github/workflows/dual-run.yml`

El workflow equivalente en GHA:

- Debe empezar con `name:` y tener `on:` con eventos.
- Debe declarar `permissions:` con `id-token: write` (OIDC obligatorio).
- Debe tener `jobs:` con al menos un job que use `actions/checkout@`.
- Debe usar `aws-actions/configure-aws-credentials@` **sin** `aws-access-key-id` ni `aws-secret-access-key` como inputs (es decir, OIDC federation con `role-to-assume`).
- Debe mencionar `role-to-assume:` con un ARN que contenga `role/`.
- Debe cubrir las mismas tres fases lógicas del Jenkinsfile (build/install, test, publish).

### 5.5 Entregables

```
/tmp/jk-08-02/
├── ADR-MIGRATION.md
├── Jenkinsfile
└── .github/
    └── workflows/
        └── dual-run.yml
```

## 6. Resultado esperado

- Los tres archivos existen y pasan el validador estructural.
- El ADR es coherente y defendible.
- El par `Jenkinsfile` + `dual-run.yml` ejecuta la **misma lógica** desde dos herramientas distintas, mostrando el reemplazo `withCredentials` → OIDC.

## 7. Criterios de aceptación

- **Funcionalidad**: validador en verde.
- **Equivalencia**: Jenkinsfile y workflow hacen el mismo trabajo lógico (install → test → publish del mismo artefacto).
- **Seguridad**: el workflow GHA **no** declara secretos de larga duración; usa OIDC.
- **Mantenibilidad**: Markdown y YAML válidos; pipelines sin pasos vacíos.

## 8. Validación

```bash
bash tests/validate.sh /tmp/jk-08-02
```

El validador comprueba **estructura** (secciones, patrones mínimos de Jenkinsfile y workflow, OIDC). **No** comprueba que el pipeline funcione en una infra real (eso vive en los cursos destino).

## 9. Preguntas de reflexión

1. Si el inventario tuviera **120 pipelines**, ¿cuántos de los 40 freestyle estimas acabarán en `retirar`? ¿Qué criterio aplicas?
2. ¿Por qué eliges `orders-api-ci` y `docs-site` como canarios en lugar de `payments-nightly`?
3. ¿Qué pasa si tras 4 semanas de dual-run, el workflow GHA es más lento 1.5× que Jenkins? ¿Declaras ganador o investigas?
4. En el workflow GHA, el `role-to-assume` apunta a un rol con `sub` claim muy abierto. ¿Qué riesgo hay y cómo lo cierras?
5. Un auditor pregunta en 3 años "¿cómo garantizas que no se perdió un log de 2026 al apagar Jenkins?". ¿Qué le enseñas?

## 10. Extensiones

- Añade un segundo workflow `release.yml` que use `environments:` con approval gate (equivalente a `input` en Jenkins).
- Diseña el reemplazo de la Shared Library `std-build@v3` como **reusable workflow** llamado desde `dual-run.yml`.
- Añade un `compare-runs.sh` conceptual que extraiga ambos resultados y compare hash de artefacto.

## 11. Limpieza

```bash
rm -rf /tmp/jk-08-02
```

No hay procesos ni infraestructura que detener.
