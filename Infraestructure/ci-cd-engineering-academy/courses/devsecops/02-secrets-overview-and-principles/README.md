# sec-02 — Secretos: panorama y principios

## Identificación

- **ID:** `sec-02-secrets-overview-and-principles`
- **Curso:** `devsecops`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `sec-01-principles-threat-modeling-and-supply-chain-overview`.

## Objetivo

Entender **dónde pueden vivir los secretos**, **qué principios aplican** antes de elegir una herramienta y **cómo medir el blast radius** de cada decisión. Al terminar deberías poder auditar un proyecto real, decir dónde está cada secreto, qué tan expuesto está y qué cambio de principio reduce más riesgo por euro de esfuerzo.

Este módulo es **100 % conceptual + inventario**. No se instala Vault, ni OIDC, ni ESO. Esas piezas aterrizan en `sec-04` (secret scanning) y `sec-13` (secretos a escala).

## Alcance

Este módulo cubre:

- Definición operativa de **secreto** (y la frontera con "config sensible pero no secreto").
- **Taxonomía** por propósito: API keys, DB creds, OAuth tokens, cert privkeys, SSH keys, JWT signing keys, encryption keys.
- **Anti-patrones** clásicos (secreto en código, env vars de larga vida, ticket systems, Slack/Drive).
- Los **principios irrenunciables**: rotación, mínimo privilegio, auditoría, detección de uso anómalo, **short-lived > long-lived**, separation of duties.
- **Dónde pueden vivir** los secretos: git, env, config files, secret manager, KMS, HSM, vault.
- La métrica central: **blast radius × ventana de exposición**. Un secreto es "una contraseña que se vuelve exponencialmente más valiosa cuanto más tiempo existe".
- Introducción conceptual a **short-lived credentials**: OIDC federation, Workload Identity, STS AssumeRole.

Lo que **no** cubre (se verá después):

- Instalar y usar `gitleaks` / `trufflehog` → `sec-04`.
- Vault + ESO + Workload Identity en profundidad → `sec-13`.
- Firma de artefactos → `sec-09`.

## Materiales

- **`theory/lesson.md`** — 12 secciones profundas.
- **`examples/`** — ejemplos de lectura:
  - `01-where-secrets-live/` — tabla y diagramas de los 7 "hogares" posibles de un secreto, con blast radius de cada uno.
  - `02-long-lived-vs-short-lived/` — comparativa cuantitativa (ventana × impacto) entre una API key estática y un token OIDC de 15 min.
- **`activities/`** — dos actividades **independientes** (sin dependencia entre sí):
  - `01-audit-your-secrets/` — producir el **inventario de secretos** de un proyecto (modelo del capstone) con columnas obligatorias.
  - `02-rotation-policy-adr/` — escribir un **ADR de política de rotación** que elige TTL por tipo de secreto y justifica cada decisión.
- **`resources/links.md`** — referencias oficiales (OWASP, NIST, CSA, docs de Vault, AWS STS, GitHub OIDC).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Definir "secreto" en una frase operativa. Enumerar los 7 hogares posibles y el blast radius de cada uno. Distinguir rotación de revocación. |
| Operativa | Auditar un proyecto real y producir un inventario con `tipo × hogar × TTL × owner × rotación × último uso`. |
| Arquitectónica | Dado un secreto `long-lived`, proponer migración razonable a `short-lived` (OIDC, Workload Identity, dynamic creds). Justificar la **ventana de blast radius** aceptable. |

## Criterios de evaluación

- Explica, con sus palabras, por qué un secreto long-lived es exponencialmente peor que uno short-lived.
- Clasifica cualquier credencial (API key, DB password, SSH key, OAuth token) en la taxonomía del módulo.
- Audita un proyecto y produce un inventario con `>=5` secretos y los campos requeridos.
- Entrega un ADR de rotación con TTL por tipo + proceso de break-glass.
- Los dos validadores estructurales en verde.

## Entregables

- **Inventario de secretos** (`INVENTORY.md`) del capstone (modelo) — sale de la actividad `01-audit-your-secrets`.
- **ADR de rotación** (`ADR-rotation.md`) — sale de la actividad `02-rotation-policy-adr`.

## Siguiente módulo

→ `sec-03-scanning-landscape-sast-dast-sca-iac-container-secret` (panorama de scanning) y, en paralelo cuando toque, `sec-04-secret-scanning-gitleaks-trufflehog-github` (herramientas para encontrar secretos filtrados).
