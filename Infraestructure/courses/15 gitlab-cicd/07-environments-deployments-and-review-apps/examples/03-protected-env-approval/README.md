# Ejemplo 03 — Protected environment con approval rule

## Objetivo

Ver como se configura un `production` protegido que requiere aprobacion humana antes de que el job de deploy arranque, y como se comporta la UI cuando el pipeline llega al gate.

## Pieza 1 — El job en `.gitlab-ci.yml`

```yaml
deploy_production:
  stage: deploy
  script:
    - ./deploy.sh --env production --sha "$CI_COMMIT_SHA"
  environment:
    name: production
    url: https://app.example.com
    deployment_tier: production
  rules:
    - if: $CI_COMMIT_TAG =~ /^v[0-9]+\.[0-9]+\.[0-9]+$/
      when: manual
```

El job declara que apunta al environment `production`. La `rule` lo filtra a tags SemVer y lo marca `manual` (alguien tiene que apretar el "Play" en la UI del pipeline).

## Pieza 2 — Protected environment (configuracion)

Esto se hace en **Settings > CI/CD > Protected environments** (o via API `POST /projects/:id/protected_environments`). Representacion YAML conceptual del estado deseado:

```yaml
# Representacion del estado del protected environment (no es un archivo
# que GitLab lea; es la vista declarativa del Settings)
protected_environments:
  - name: production
    deploy_access_levels:
      - group: platform-admins
    approval_rules:
      - group: sre
        required_approvals: 1
      - group: security
        required_approvals: 1
```

Lo que esto significa:

- **`deploy_access_levels`** — solo miembros del grupo `platform-admins` pueden lanzar un job que apunte a `production`. Un developer que ejecute el pipeline y aprete "Play" en `deploy_production` recibira un error de permisos.
- **`approval_rules`** — el deployment queda `blocked / waiting for approval` hasta recibir:
  - 1 aprobador del grupo `sre`, **y**
  - 1 aprobador del grupo `security`.
  Dos reglas = **ambas** se deben satisfacer (AND). Si quisieras "cualquiera de dos", seria una sola regla con `required_approvals: 1` y los dos grupos listados como approvers posibles (requiere Ultimate en algunas versiones).

## Flujo UI cuando el pipeline llega al gate

1. Un maintainer aprieta "Play" en `deploy_production` (porque es `when: manual`).
2. GitLab valida `deploy_access_levels`: ¿el que lo lanzo esta en `platform-admins`? Si no → error.
3. Si pasa, el job queda en estado **`waiting for approval`**. El pipeline no avanza.
4. En el MR / pipeline view aparece el widget **"Deployment waiting for approval — 0 of 1 from @sre, 0 of 1 from @security"**.
5. Un miembro de `@sre` entra, revisa, aprueba. Un miembro de `@security` hace lo mismo.
6. Al llegar al minimo (1 + 1), el job arranca y ejecuta `./deploy.sh`.
7. Si en vez de aprobar alguien **rechaza**, el deployment queda `rejected` y el job no arranca.

## Approval rule vs `rules:`

Confusion comun. **No son lo mismo**:

| Pregunta                                             | `rules:`      | approval rule         |
|------------------------------------------------------|---------------|-----------------------|
| ¿El job se incluye en el pipeline?                   | si            | no                    |
| ¿El job se ejecuta?                                  | si (`when:`)  | si (gate antes de run)|
| ¿Lo evalua el runner?                                | no, GitLab    | no, GitLab            |
| ¿Depende de aprobacion humana?                       | no            | si                    |
| ¿Vive en `.gitlab-ci.yml`?                           | si            | no (vive en Settings) |

`rules:` filtra la **shape del pipeline** (que jobs existen y cuando). Approval rule es un **gate de deployment** que corre antes de que el job declarado como `environment:` arranque. Son planos ortogonales.

## Trampas comunes

- **Olvidar `deploy_access_levels`**: cualquier developer puede lanzar el job, aunque haya approval. El approval es necesario pero no suficiente.
- **Approval rule sin usuarios asignados al grupo**: el pipeline queda bloqueado para siempre.
- **El mismo usuario como aprobador y como lanzador**: por defecto GitLab no permite auto-aprobacion (correcto); verificar en la version actual.
- **Approval rule en SaaS Free**: no esta disponible. Requiere Premium/Ultimate.

## Lectura recomendada

- `../../theory/lesson.md` §6 (protected environments y approval rules).
