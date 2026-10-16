# sec-04 — Secret scanning: gitleaks, trufflehog y GitHub secret scanning

## Identificación

- **ID:** `sec-04-secret-scanning-gitleaks-trufflehog-github`
- **Curso:** `devsecops`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `sec-02` (principios de secretos), `sec-03` (panorama de scanning).

## Objetivo

Detectar secretos filtrados en código y **prevenir que entren a Git**. Al terminar deberías poder: (a) instalar un `pre-commit` que ejecute `gitleaks` o `trufflehog` antes de cada commit; (b) correr en CI un escaneo de **toda la historia** del repo; (c) responder a un hallazgo real siguiendo la secuencia correcta — **rotar primero, limpiar la historia después**.

## Alcance

Este módulo cubre:

- Diferencia entre **pre-commit** (local, barato, previene) y **CI full-history scan** (red de seguridad, cubre historia).
- Herramientas: **gitleaks** (regex + entropy, config TOML), **trufflehog** (verificación en vivo contra el proveedor), **GitHub secret scanning** + **push protection** (gratis en public; GHAS en private).
- Limpieza de historia con **BFG Repo-Cleaner** o `git filter-repo` — y por qué eso **no sustituye** la rotación.
- Falsos positivos típicos y gestión disciplinada de excepciones con `.gitleaks.toml`.
- Proceso de respuesta a incidente: **rotar → notificar → limpiar historia → post-mortem**.

Lo que **no** cubre (se verá después):

- Gestión de secretos en producción con **SOPS**, **External Secrets Operator** o **Vault** → `sec-13`.
- SAST, SCA, IaC scan → `sec-05` a `sec-07`.
- Firma y attestations → `sec-09`.

## Materiales

- **`theory/lesson.md`** — lección con la mecánica de cada herramienta, cuándo usar cuál, y el runbook canónico de respuesta.
- **`examples/`** (lectura):
  - `01-pre-commit-gitleaks/` — hook pre-commit mínimo con gitleaks.
  - `02-ci-full-history-scan/` — workflow de GitHub Actions con `fetch-depth: 0` que escanea toda la historia.
  - `03-rotate-then-rewrite-history/` — guión paso a paso de respuesta a un secreto filtrado.
- **`activities/`** (independientes):
  - `01-full-pipeline-secret-scan/` — construir un repo con pre-commit + CI scan + runbook.
  - `02-incident-response-exercise/` — redactar la respuesta a un leak dado un escenario.
- **`resources/links.md`** — docs oficiales.

## Nota sobre secretos

Todos los "secretos" usados en este módulo son **obviamente falsos** (`sk_fake_...`, `ghp_FAKEabc...`). Nunca copies ni commits credenciales reales mientras practicas: aunque los borres de inmediato, Git los conserva en la reflog y los backups.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué pre-commit **y** CI full-history son complementarios, no redundantes. Nombrar la diferencia entre detección por regex, por entropía y por verificación en vivo. |
| Operativa | Instalar un pre-commit con gitleaks en < 5 min. Escribir un workflow CI que falle en hallazgos de severidad alta. |
| Incidente | Ejecutar la secuencia **rotar → notificar → limpiar** sin confundir el orden. Justificar por qué `git rm` + commit no resuelve nada. |
