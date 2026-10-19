# Actividad 01 — Jerarquía de variables con mínimo privilegio

## 1. Identificación

- **ID:** `gl-03-01-least-privilege-variables`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-03-variables-and-secrets-protected-and-masked`
- **Dificultad:** beginner
- **Duración estimada:** 70–80 min
- **Tipo:** guided-lab

## 2. Contexto

Tu equipo ha creado un proyecto `acme/platform/checkout` con tres entornos (dev, stg, prod). Hasta ahora las variables viven como variables inline dentro del `.gitlab-ci.yml` (`variables:` top-level sin ningún flag). Security te pide refactorizar:

- Mover credenciales a la configuración de CI/CD (fuera del repo).
- Aplicar `protected: true` a lo que solo deba leerse desde `main` (branch protegido).
- Aplicar `masked: true` a cualquier token/password.
- Usar `type: file` para credenciales multilinea (ej. JSON de GCP service account).
- Documentar la decisión en un `variables.yml` versionado (no es un archivo que GitLab lea; es documentación estructurada que vive junto al `.gitlab-ci.yml`).

**Importante**: no hay instancia de GitLab. No se aplica nada. El entregable son 2 archivos (`variables.yml` + `.gitlab-ci.yml`) que un validador comprueba estructuralmente.

**Nunca** uses tokens reales. Para los valores sensibles usa placeholders como `dummy-stg-token-xxxx` o `REPLACE_IN_GITLAB_UI`.

## 3. Objetivos

Al terminar deberías poder:

- Decidir el **scope** correcto (Group, Project, Environment-scoped) para una variable dada.
- Aplicar correctamente `protected` y `masked` según la sensibilidad.
- Reconocer cuándo una credencial debe ser `file` en vez de `variable`.
- Escribir un `.gitlab-ci.yml` con tres jobs (`deploy-dev`, `deploy-stg`, `deploy-prod`) que consuma las variables documentadas.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (secciones 2 a 6).
- Haber recorrido `../../examples/01-group-vs-project-var/` y `../../examples/02-protected-and-masked/`.
- Herramientas: `bash`, `python3` (parser YAML). Un editor.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/gl-03-01
cd /tmp/gl-03-01
```

Puedes usar otro directorio: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `variables.yml`

Un documento estructurado (YAML) que lista cada variable con: `name`, `scope` (`group`, `project`, `environment`), `environment_scope` (si aplica), `type` (`variable` | `file`), `protected`, `masked`, `example_value` (dummy), y `justification`.

Variables mínimas requeridas (el validador las busca por `name`):

| name | scope | environment_scope | type | protected | masked | notas |
|------|-------|-------------------|------|-----------|--------|-------|
| `INTERNAL_REGISTRY_URL` | group | `*` | variable | false | false | URL, no secreto |
| `DOCKER_HUB_READER_TOKEN` | group | `*` | variable | false | true | token de lectura compartido |
| `STG_API_KEY` | project | `staging` | variable | false | true | solo para stg |
| `PROD_DEPLOY_ROLE_ARN` | project | `production` | variable | true | false | ARN, sensible pero no secreto |
| `PROD_API_KEY` | project | `production` | variable | true | true | secreto de prod |
| `GCP_SA_JSON` | project | `production` | file | true | false | JSON multilinea, no enmascarable |

Estructura esperada por el validador:

```yaml
# variables.yml — jerarquia documentada de variables de CI/CD
# No es un archivo que GitLab lea; es documentacion versionada.

variables:
  - name: INTERNAL_REGISTRY_URL
    scope: group
    environment_scope: "*"
    type: variable
    protected: false
    masked: false
    example_value: "registry.internal.acme.com"
    justification: "URL del registry interno. Compartida por todo el grupo acme/platform."

  - name: DOCKER_HUB_READER_TOKEN
    scope: group
    environment_scope: "*"
    type: variable
    protected: false
    masked: true
    example_value: "dummy-dockerhub-reader-xxxxxxx"
    justification: "Token read-only de Docker Hub para evitar rate limit. Enmascarado por si aparece en logs."

  # ... repite para el resto
```

### 5.3 Escribe `.gitlab-ci.yml`

Un pipeline con **al menos** estos jobs:

- `deploy-dev` — corre en cualquier branch; usa `INTERNAL_REGISTRY_URL`.
- `deploy-stg` — corre en branch `staging`; usa `INTERNAL_REGISTRY_URL`, `DOCKER_HUB_READER_TOKEN`, `STG_API_KEY`.
- `deploy-prod` — corre solo en `main`; usa `PROD_DEPLOY_ROLE_ARN`, `PROD_API_KEY`, `GCP_SA_JSON` (como path a archivo).

Debe ser YAML válido (parseable por `python3 -c "import yaml; yaml.safe_load(...)"`).

Debe declarar `stages:` con al menos `deploy`.

Cada job debe declarar `environment:` apuntando a `development`, `staging` o `production` respectivamente.

Ejemplo esqueleto:

```yaml
stages:
  - deploy

.base-deploy:
  image: alpine:3.20
  before_script:
    - echo "Deploying from $CI_COMMIT_REF_NAME to $CI_ENVIRONMENT_NAME"

deploy-dev:
  extends: .base-deploy
  stage: deploy
  environment:
    name: development
  rules:
    - if: $CI_COMMIT_BRANCH
  script:
    - echo "Registry: $INTERNAL_REGISTRY_URL"

deploy-stg:
  # ...

deploy-prod:
  # ...
```

### 5.4 Entregables

```
/tmp/gl-03-01/
├── variables.yml
└── .gitlab-ci.yml
```

## 6. Resultado esperado

- `variables.yml` existe, es YAML válido, contiene las 6 variables mínimas con los flags correctos.
- `.gitlab-ci.yml` existe, es YAML válido, contiene los 3 jobs mínimos con `environment:` y referencia a las variables correspondientes.
- El validador pasa en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Correctitud**: cada variable con sus flags correctos según la tabla.
- **Reproducibilidad**: alguien externo puede leer `variables.yml` y aplicarlo tal cual en la UI de GitLab.
- **Seguridad**: ningún valor real como ejemplo (solo `dummy-*`, `REPLACE_IN_*`, placeholders).

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-03-01
```

El validador comprueba **estructura**, no comportamiento en una instancia real. Compara con `solution/` después para autoevaluarte.

## 9. Preguntas de reflexión

1. Si mañana aparece un proyecto nuevo `acme/platform/billing`, ¿qué variables heredaría automáticamente y cuáles tendrías que redefinir? ¿Por qué?
2. ¿Qué pasa si un developer abre una MR desde una feature branch y lanza manualmente el job `deploy-prod` desde la UI (asumiendo que `rules:` lo permita)? ¿Qué variables ve y cuáles no?
3. Si `GCP_SA_JSON` fuera definido como `variable` en vez de `file`, ¿qué problema concreto aparecería al intentar `masked: true`?
4. ¿Qué cambia si eliminas `environment_scope: production` de `PROD_API_KEY`?

## 10. Extensiones

- Añade una variable `FEATURE_FLAG_*` definida solo a nivel Pipeline (manual trigger) y documenta por qué.
- Añade un segundo entorno `canary` entre `staging` y `production` con sus propias variables.
- Añade a `variables.yml` una columna `rotation_strategy` (por ejemplo `manual-90d`, `vault-dynamic`, `n/a`) y aplícala a cada variable.

## 11. Limpieza

```bash
rm -rf /tmp/gl-03-01
```

No hay infraestructura que detener.
