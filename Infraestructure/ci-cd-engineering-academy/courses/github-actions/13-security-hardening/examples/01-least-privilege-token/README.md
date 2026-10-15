# Ejemplo 01 — `GITHUB_TOKEN` con mínimo privilegio

## Concepto que demuestra

Patrón recomendado para el bloque `permissions:` de un workflow:
- **Top-level** restringido a lo mínimo que **todos** los jobs necesitan.
- **Por job**, escalada explícita a los scopes extra que ese job requiere.

Esto limita el radio de impacto de un step comprometido: si una action maliciosa roba el `GITHUB_TOKEN`, solo puede hacer lo que el job declaró.

## Contexto

Hasta febrero 2023 el default de GHA era `permissions: write-all` para el `GITHUB_TOKEN`. Un step comprometido podía escribir en issues, PRs, releases, packages, deployments, actions… Para orgs/repos creados antes de ese cambio, **el default sigue siendo permissive** salvo que lo cambies manualmente.

La guía oficial recomienda **declarar siempre** `permissions:` en el workflow para no depender del setting del repo.

## Objetivo

- `permissions: {}` top-level (deny by default).
- Un job `test` que **no** necesita escribir nada → sin `permissions:` extra (hereda `{}`).
- Un job `comment-on-pr` que escribe un comentario en el PR → `pull-requests: write`.
- Un job `release` que crea un release y pide OIDC → `contents: write` + `id-token: write`.

Ningún scope de más. Si mañana un job quiere más, hay que añadirlo explícitamente — fricción deseable que fuerza revisión.

## Archivos

- `workflow.yml` — a copiar a `.github/workflows/ci-release.yml` del repo real.

## Puntos finos

- `permissions: {}` **no es** lo mismo que omitir el bloque. Omitir hereda del setting del repo; `{}` niega todo explícitamente.
- Los permissions del **job** sobrescriben los del workflow — **no se suman**. Un job con `permissions: { issues: write }` no tiene `contents: read` a menos que lo declare.
- `id-token: write` **solo** es necesario para OIDC (y Sigstore). No lo pongas "por si acaso": sin este scope, GHA no emite el JWT, lo cual es un control extra.
- Para debug: `gh api -X GET /repos/OWNER/REPO/actions/permissions/workflow` muestra la config efectiva a nivel repo.

## Verificación

Tras commitear el workflow, en el log del run verás, al inicio de cada job, una línea:

```
Current runner permissions: ...
GITHUB_TOKEN permissions:
  Contents: read
  Metadata: read
```

Para el job `release` verás `Contents: write` y `IdToken: write`. Si ves más de lo esperado, el setting del repo está sobrescribiendo (ir a `Settings → Actions → General → Workflow permissions`).

## Interpretación

- "Escalada por job" no "escalada por step". GHA solo tiene granularidad a nivel job.
- La disciplina es más fácil que parece: la mayoría de los workflows CI (lint, test, build) **no necesita** ningún scope de escritura.

## Errores frecuentes

- Declarar `permissions:` solo top-level a `write-all` y pensar que es temporal. Nunca lo es.
- Olvidar `id-token: write` y recibir error `Error: Not authorized to request an OIDC token` → claro, lo denegaste.
- Confundir "los permissions del job se añaden" (no, sobrescriben).

## Referencia

- <https://docs.github.com/actions/security-guides/automatic-token-authentication>
- <https://docs.github.com/actions/using-jobs/assigning-permissions-to-jobs>
