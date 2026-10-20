# Ejemplo 02 — `pull_request_target` seguro (y anti-patrón comentado)

## Concepto que demuestra

El patrón **seguro** de `pull_request_target`: el workflow usa secrets y `GITHUB_TOKEN` elevado para postear un comentario en el PR, **pero nunca ejecuta código del PR**. En el mismo archivo, el **anti-patrón** está incluido en un bloque comentado con la explicación de por qué es RCE.

## Contexto

`pull_request_target` existe por una razón legítima: permitir que workflows disparados por PRs de forks puedan **comentar, labelear, asignar reviewers** — operaciones que requieren `pull-requests: write` o `issues: write`, scopes que `pull_request` desde fork **no** concede (por diseño, para proteger los secrets).

El riesgo: `pull_request_target` corre **en el contexto del repo base** con sus secrets. Si además checkouteas el `head.sha` del PR y ejecutas scripts del PR (`npm install`, `pip install`, `make`), un atacante que abre un PR puede ejecutar código arbitrario con las credenciales del repo base. Este es el **"pwnrequest"** famoso.

## Objetivo

Mostrar los dos lados del cuchillo en el mismo archivo:
- Patrón seguro (activo): `pull_request_target` que SOLO comenta en el PR; no checkoutea el head; sin ejecutar nada del PR.
- Anti-patrón (comentado + anotado): el que da RCE.

## Archivos

- `workflow.yml`

## Puntos finos a notar

- El patrón seguro **no hace `actions/checkout`** del head del PR. Si necesita datos del PR (p. ej. título, autor, número), los lee del contexto `github.event.pull_request.*` **vía `env:`** (nunca interpolados en `run:`).
- Si de verdad necesitas **analizar el contenido del PR** (p. ej. calcular diff), parte el flujo en dos workflows:
  - `pull_request` (sin secrets) hace el análisis y sube un artefacto.
  - `workflow_run` (con secrets elevado) lee ese artefacto y comenta/postea.
  Esto se desarrolla en `activities/01-harden-an-existing-workflow/` como extensión.
- La defensa `if: github.event.pull_request.head.repo.fork == false` **no es segura** por sí misma: un maintainer malicioso puede empujar una rama en el propio repo y abrir PR desde ahí, cumpliendo el filtro.

## Verificación

Para probar el patrón **seguro** sin montar un fork:
1. Copiar el YAML en un repo scratch.
2. Abrir un PR normal (desde una rama del mismo repo o fork).
3. El job debe postear un comentario con número y autor del PR; **no debe correr** nada del código del PR.

Para el anti-patrón: **no reproducir en un repo con secrets reales**. Se incluye solo como texto comentado.

## Interpretación

- `pull_request_target` **sin checkout del head del PR** y **sin ejecución de código del PR** es seguro.
- `pull_request` desde fork **sin secrets y con `GITHUB_TOKEN: read-all`** es seguro aun ejecutando código del PR, porque no hay nada que exfiltrar más allá del repo público.
- La zona peligrosa es la intersección: elevated token + ejecución de código del PR.

## Errores frecuentes

- Pensar que leer `${{ github.event.pull_request.title }}` dentro de un `run:` es seguro porque "es solo un título". Es RCE (ver `activities/02-detect-script-injection/`).
- Usar `pull_request_target` cuando bastaba `pull_request` (más seguro por default).
- Confiar en filtros `fork == false`: no cubren el caso de maintainer comprometido.

## Referencia

- <https://securitylab.github.com/research/github-actions-preventing-pwn-requests/>
- <https://docs.github.com/actions/using-workflows/events-that-trigger-workflows#pull_request_target>
