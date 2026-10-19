# Actividad 01 — Pipeline con 5+ scanners nativos

## 1. Identificación

- **ID:** `gl-08-01-pipeline-with-scanners`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-08-security-scanners-registry-and-supply-chain`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** guided-lab (independiente — sin dependencia de la actividad 02)

## 2. Contexto

Security te pide habilitar la cadena completa de scanners nativos para un microservicio Python que vive en `gitlab.com/acme/payments-api`. El repo ya tiene `Dockerfile` y pipeline básico de tests. Debes añadir un `.gitlab-ci.yml` que:

- Incluya **al menos 5 templates oficiales** (`Jobs/SAST.gitlab-ci.yml`, `Jobs/Secret-Detection.gitlab-ci.yml`, `Jobs/Dependency-Scanning.gitlab-ci.yml`, `Jobs/Container-Scanning.gitlab-ci.yml`, `Jobs/SAST-IaC.gitlab-ci.yml`).
- Defina `stages:` con un stage `test` presente (los templates lo asumen).
- Evite pipelines duplicados en MR + branch con `workflow:rules`.
- Pase variables mínimas de ajuste.

**Importante**: no se corre nada en `gitlab.com`. El entregable es un `.gitlab-ci.yml` validado estructuralmente en local.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Nombrar los 5+ templates oficiales y qué cubre cada uno.
- Explicar por qué `include:template:` es preferible a copiar el YAML.
- Diseñar un `workflow:rules` que elimine pipelines duplicados.
- Pasar al validador estructural (sintaxis + presencia de keys mínimas).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§1 scanners, §2 Dashboard, §3 widget de MR).
- Haber recorrido `../../examples/01-enable-all-security-templates/`.
- Herramientas: `bash`, `python3` (para `yaml.safe_load`). Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar directorio de trabajo

```bash
mkdir -p /tmp/gl-08-scanners
cd /tmp/gl-08-scanners
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `.gitlab-ci.yml`

Nombre exacto. Debe contener:

- Top-level **`stages:`** con al menos `test` presente.
- Top-level **`workflow:`** con `rules:` que mencionen `$CI_PIPELINE_SOURCE` y/o `$CI_OPEN_MERGE_REQUESTS` para evitar duplicados.
- Top-level **`include:`** con **al menos 5** entradas `template: Jobs/*.gitlab-ci.yml`. Los nombres aceptados por el validador incluyen (combina 5):
  - `Jobs/SAST.gitlab-ci.yml`
  - `Jobs/Secret-Detection.gitlab-ci.yml`
  - `Jobs/Dependency-Scanning.gitlab-ci.yml`
  - `Jobs/Container-Scanning.gitlab-ci.yml`
  - `Jobs/SAST-IaC.gitlab-ci.yml`
  - `Jobs/License-Scanning.gitlab-ci.yml`
  - `Jobs/DAST.gitlab-ci.yml`
- Top-level **`variables:`** con al menos una de: `SAST_EXCLUDED_PATHS`, `DS_EXCLUDED_PATHS`, `CS_IMAGE`, `SECURE_LOG_LEVEL`.

### 5.3 Escribe `NOTES.md`

Un documento corto (10–20 líneas) justificando:

- Por qué `include:template:` y no copiar el YAML.
- Qué scanner elegirías *required* y cuál *advisory* para una API Python.
- Cómo bloquearías merges por severidad `High`/`Critical`.

Secciones obligatorias (el validador las busca):

- `## Por que include:template`
- `## Required vs advisory`
- `## Bloqueo por severidad`

> **No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa `NOTES.md`.

### 5.4 Entregables

```
/tmp/gl-08-scanners/
├── .gitlab-ci.yml
└── NOTES.md
```

## 6. Resultado esperado

- `.gitlab-ci.yml` parsea con `python3 -c 'import yaml; yaml.safe_load(open(".gitlab-ci.yml"))'`.
- El validador pasa en verde.
- `NOTES.md` existe con las 3 secciones.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Correctitud sintáctica**: YAML válido, nombres exactos de templates.
- **Mantenibilidad**: `variables:` consistente, `stages:` ordenado.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-08-scanners
```

El validador comprueba **estructura**, no que los scanners corran en SaaS runners. Esa validación es Fase 4.

## 9. Preguntas de reflexión

1. ¿Por qué `Container-Scanning` necesita un `build` previo? ¿Qué le pasa si no hay imagen en el registry?
2. ¿Qué pasa si eliminas el `workflow:rules` que evita duplicados? ¿Cuántos pipelines ves por push a una MR?
3. ¿En qué plan de GitLab empezaría a verse el Security Dashboard completo con todos los findings?
4. ¿Cómo pasarías `SAST_EXCLUDED_PATHS` solo en una branch concreta sin ensuciar el nivel global?
5. ¿Por qué `License-Scanning` es Ultimate y `Secret-Detection` es Free?

## 10. Extensiones

- Añade `DAST` con un stage `review` previo que publique a una URL stub (puedes dejar la URL mockeada; el validador no la verifica).
- Reemplaza el `build` placeholder por un `extends: .kaniko-build` definido en un hidden job.
- Añade un gating job que lee `gl-sast-report.json` (JSON mock) y falla si hay severidad >= `High`.

## 11. Limpieza

```bash
rm -rf /tmp/gl-08-scanners
```

No hay infraestructura que detener.
