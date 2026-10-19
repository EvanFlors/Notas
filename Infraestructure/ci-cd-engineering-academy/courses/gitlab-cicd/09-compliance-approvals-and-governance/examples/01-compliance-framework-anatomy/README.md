# Ejemplo 01 — Anatomía de un Compliance Framework

> Lectura y análisis. Sin ejecución. Objetivo: ver **de qué partes** está hecho un Compliance Framework y cómo se **inyecta** al project.

## 1. El framework (lado del grupo)

En `Group → Settings → General → Compliance frameworks` el equipo de compliance define:

```
Name:           Internal-Baseline
Description:    SAST + Secret Detection + Dependency obligatorios
Color:          #1f75cb
Pipeline cfg:   compliance/pipeline.yml@platform/compliance-pipelines:main
```

Esto crea una etiqueta `Internal-Baseline` que un Owner del grupo puede aplicar a cualquier project.

## 2. El project consumidor (lado del equipo de desarrollo)

El project `workloads/checkout` queda etiquetado con `Internal-Baseline`. El equipo de checkout sigue manteniendo su propio `.gitlab-ci.yml`:

```yaml
# .gitlab-ci.yml  (lo mantiene el equipo de checkout)
stages:
  - build
  - test
  - deploy

build:
  stage: build
  script: ["make build"]

unit:
  stage: test
  script: ["make test-unit"]

deploy:dev:
  stage: deploy
  script: ["./deploy.sh dev"]
  environment: dev
```

El equipo de checkout **no** menciona el framework en ningún sitio. Es el group quien lo inyecta.

## 3. El pipeline realmente ejecutado

Cuando llega un commit a `workloads/checkout`, GitLab compone un pipeline así (orden lógico):

```
compliance  →  compliance:sast
            →  compliance:secret-detection
            →  compliance:dependency

build       →  build

test        →  unit

deploy      →  deploy:dev

compliance-post  →  compliance:license-report
```

Observaciones clave:

- Los jobs `compliance:*` **no estaban** en `.gitlab-ci.yml`; vienen del framework.
- Los stages `compliance` y `compliance-post` son añadidos por el framework **antes** y **después** de los stages del project.
- Si `compliance:sast` falla con `allow_failure: false`, los stages posteriores **no corren**. El pipeline del checkout queda abortado.
- El equipo de checkout **no puede** borrar los jobs `compliance:*` desde su `.gitlab-ci.yml` — intentar sobreescribirlos con el mismo nombre falla porque `include:` del framework los re-define.

## 4. Qué puede hacer el project (extensión) vs qué no puede (omisión)

Puede:

- Añadir stages adicionales (`qa`, `smoke`...).
- Añadir jobs propios en los stages ya definidos.
- Extender un hidden job del framework si éste lo expone (`extends: .compliance-template`).
- Pasar inputs/variables al framework vía `variables:` del project.

No puede:

- Borrar o renombrar un job `compliance:*`.
- Cambiar `allow_failure` del framework.
- Modificar `rules:` del framework para desactivar un job en su branch.
- Despegar la etiqueta `Internal-Baseline` desde su propia UI de settings (solo Owner del group puede hacerlo).

> **Idea para debate:** si el equipo de checkout quiere SAST con reglas custom, ¿cómo lo pide? Respuesta: no sobreescribe el job del framework; propone un **cambio al framework** (PR al repo `platform/compliance-pipelines`), que compliance aprueba o rechaza. Es gobernanza como código.
