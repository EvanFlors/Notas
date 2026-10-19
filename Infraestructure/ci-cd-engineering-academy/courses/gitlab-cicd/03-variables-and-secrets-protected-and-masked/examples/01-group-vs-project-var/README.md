# Ejemplo 01 — Group variable vs Project variable: precedencia

> Lectura y análisis. No ejecuta nada. Ilustra qué pasa cuando el mismo nombre de variable existe en dos scopes.

## Escenario

- Grupo top-level: `acme/platform`.
- Proyecto: `acme/platform/checkout`.
- Variable: `DEPLOY_ENV`.

### Configuración en la UI (equivalente)

**Group `acme/platform` → Settings → CI/CD → Variables:**

```
Key:               DEPLOY_ENV
Value:             staging
Protected:         false
Masked:            false
Expanded:          true
Environment scope: *            (todas)
```

**Project `acme/platform/checkout` → Settings → CI/CD → Variables:**

```
Key:               DEPLOY_ENV
Value:             production
Protected:         true
Masked:            false
Expanded:          true
Environment scope: production
```

## `.gitlab-ci.yml` del proyecto

```yaml
stages: [show]

show-env:
  stage: show
  image: alpine:3.20
  script:
    - echo "DEPLOY_ENV = $DEPLOY_ENV"
    - echo "CI_COMMIT_REF_NAME = $CI_COMMIT_REF_NAME"
    - echo "CI_COMMIT_REF_PROTECTED = $CI_COMMIT_REF_PROTECTED"
```

## Qué imprime en cada caso

| Pipeline corre en… | Branch protegido? | `DEPLOY_ENV` vale |
|---|---|---|
| `main` (protected) con `environment: production` | sí | `production` (Project > Group; además `protected: true` sí aplica) |
| `main` (protected) **sin** `environment:` | sí | `staging` (el Project var tiene `environment_scope: production` → no matchea; cae al Group var) |
| `feature/x` (no protegida) | no | `staging` (el Project var es `protected: true` → no legible desde feature; cae al Group var) |

## Lecturas clave

1. **Precedencia por especificidad**: Project > Group. Pero el matching de `environment_scope` es un filtro: si no matchea, la variable **no existe** y la resolución sigue hacia arriba (en este caso al Group).
2. **`protected: true` en el Project var** actúa como un segundo filtro: la variable es invisible desde refs no protegidas.
3. En `feature/x`, el pipeline *sí corre* y *sí tiene* `DEPLOY_ENV` definida — pero con el valor del Group (`staging`), no el del Project. Esto es, probablemente, lo que quieres: dev/stg "abierto" para experimentar, prod bloqueado.

## Qué estaría mal en este diseño

- Si quisiéramos que `feature/x` **no** tenga valor para `DEPLOY_ENV`, habría que **eliminar el Group var** y dejar solo el Project var `protected`. Entonces desde una feature branch el `echo "$DEPLOY_ENV"` imprime cadena vacía.
- Si quisiéramos que **cualquier** environment resuelva al Project var, cambiar `environment_scope: production` por `*`.

## Mapping mental GHA ↔ GitLab

| GHA | GitLab |
|---|---|
| `secrets.DEPLOY_ENV` en el repo | Project variable |
| `secrets.DEPLOY_ENV` en el org | Group variable (del top-level group) |
| `environments: production` + env secret | Project variable con `environment_scope: production` + `protected: true` |

## Siguiente

Ejemplo `02-protected-and-masked`: la matriz de combinaciones de ambos flags.
