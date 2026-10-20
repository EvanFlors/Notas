# Actividad 01 — Escribir el skeleton de un Compliance Framework

## 1. Identificación

- **ID:** `gl-09-01-apply-compliance-framework`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-09-compliance-approvals-and-governance`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** guided-lab (independent — sin dependencia de la actividad 02)

## 2. Contexto

El equipo de **plataforma + compliance** quiere lanzar un framework interno (`Internal-Baseline`) que se aplicará a todos los projects del grupo `workloads/*`. Tu encargo es escribir el **skeleton** de los 3 artefactos que lo componen:

1. **`compliance-pipeline.yml`** — el pipeline inyectado que vivirá en `platform/compliance-pipelines`. Debe ejecutar SAST y Secret Detection obligatorios y luego dejar correr el pipeline del project consumidor.
2. **`CODEOWNERS`** — plantilla que cada project del grupo clonará como punto de partida. Owners por grupo (nunca por usuario individual).
3. **`approval-rules.yml`** — descripción declarativa (YAML, pensada para que un script de Fase 4 la aplique con la API) de las reglas: 2 approvers por default, Code Owners obligatorios, security approval por findings high/critical.

Además, un **`README-INTENT.md`** justifica cada archivo y explica qué puede y qué no puede sobreescribir el project consumidor.

**Importante**: no hay instancia GitLab. No se aplica nada. El entregable son 4 archivos de texto.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Explicar por qué el compliance pipeline hace `include:` al project consumidor y no al revés.
- Redactar un `CODEOWNERS` sintácticamente correcto con secciones y owners por grupo.
- Nombrar las claves mínimas de una approval rule (`approvals_required`, `prevent_author_approval`, `code_owner_approval_required`, `report_type`, `severity_levels`).
- Documentar en lenguaje humano qué garantías aporta el framework y qué puede extender el project.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §3, §4, §5, §6, §10).
- Haber recorrido los tres `examples/` del módulo.
- Haber completado `gl-07` (environments) y `gl-08` (scanners).
- Herramientas: `bash`, `yq` (parser YAML), `jq` (opcional), un editor Markdown.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gl-09-framework
cd /tmp/gl-09-framework
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `compliance-pipeline.yml`

Requisitos (el validador los comprueba):

- YAML parseable por `yq`.
- Debe tener una clave top-level `include:` que referencie `$CI_PROJECT_PATH` y `$CI_CONFIG_PATH`.
- Debe declarar una lista `stages:` que incluya al menos `compliance`, y los stages estándar que el project puede extender (`build`, `test`, `deploy`).
- Debe definir al menos **dos** jobs cuyo nombre empiece por `compliance:` (p. ej. `compliance:sast` y `compliance:secret-detection`).
- Cada job `compliance:*` debe tener `allow_failure: false`.
- Cada job `compliance:*` debe estar en el stage `compliance`.

### 5.3 Escribe `CODEOWNERS`

Requisitos:

- Al menos una regla *default* para `*`.
- Al menos **tres secciones** nombradas con `[Nombre]` (p. ej. `[Infra]`, `[Compliance]`, `[Payments]`).
- Al menos **3 owners únicos** del tipo `@group/<nombre>` (owners por grupo, no por usuario individual).
- Al menos una regla sobre `/.gitlab/` o `.gitlab-ci.yml` (compliance de la propia config).

### 5.4 Escribe `approval-rules.yml`

Requisitos (YAML parseable por `yq`):

- Clave top-level `project:`.
- Clave `rules:` con una lista de al menos **3 reglas**.
- Al menos una regla con `approvals_required: 2`, `prevent_author_approval: true`, `prevent_committers_approval: true`.
- Al menos una regla con `code_owner_approval_required: true`.
- Al menos una regla con `report_type: vulnerability` y `severity_levels:` listando `high` y/o `critical`.

### 5.5 Escribe `README-INTENT.md`

Secciones obligatorias (el validador las busca):

- `## compliance-pipeline`
- `## CODEOWNERS`
- `## approval-rules`
- `## Lo que el project puede y no puede sobrescribir`

Contenido mínimo que el validador exige por grep:

- Mencionar explícitamente **SAST** y **Secret Detection**.
- Mencionar **Code Owners** y **approval rules**.
- Mencionar **Compliance Framework** (el concepto del módulo).
- Mencionar que el project **puede extender** pero **no puede omitir** jobs del framework.

### 5.6 Entregables

```
/tmp/gl-09-framework/
├── compliance-pipeline.yml
├── CODEOWNERS
├── approval-rules.yml
└── README-INTENT.md
```

## 6. Resultado esperado

- Los dos YAML parsean con `yq`.
- El `CODEOWNERS` cumple los mínimos de secciones y owners.
- El `README-INTENT.md` tiene las 4 secciones y menciona los conceptos.
- Validador en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Correctitud sintáctica**: YAML válido, keys bien ordenadas, strings bien cerradas.
- **Correctitud conceptual** (autoevaluación): comparar con `solution/REFERENCE.md`.
- **Mantenibilidad**: nombres de jobs legibles, `Sid` humanos, comentarios donde ayuden.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-09-framework
```

El validador comprueba **estructura y presencia de claves/secciones mínimas**. **No** comprueba que al aplicarse en una instancia GitLab real todo funcione como esperas. Esa validación se hace en Fase 4 contra un group de pruebas.

## 9. Preguntas de reflexión

1. ¿Por qué el `include:` del compliance pipeline referencia `$CI_PROJECT_PATH` y no un path fijo?
2. Si un project consumidor define un job llamado `compliance:sast` en su `.gitlab-ci.yml`, ¿qué pasa? ¿puede evadir el del framework?
3. ¿Cómo encajarías los nuevos **Pipeline Execution Policies** de Ultimate con este skeleton?
4. ¿Qué pasa si el project consumidor no define el stage `build` que anuncia el framework? ¿se rompe?
5. ¿Pondrías Code Owners por **usuario** individual alguna vez? ¿cuándo?

## 10. Extensiones

- Añade un job `compliance:dependency` que corra Dependency Scanning y bloquee en findings `critical`.
- Añade una regla `release-branch-extra` en `approval-rules.yml` que pida 1 release manager en `release/*`.
- Añade un `CODEOWNERS` section `[Documentation]` que no bloquee merge (documenta el *trick* de `optional`).
- Escribe un `verify.sh` que corra `yq eval` + grep y replique parte del validador.

## 11. Limpieza

```bash
rm -rf /tmp/gl-09-framework
```

No hay infraestructura que detener.
