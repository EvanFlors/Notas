# Lección: Secretos, variables y environments (básicos) en GitHub Actions

> **ID:** `gha-05-secrets-variables-and-environments-basics` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** `gha-02` (contextos y expresiones).

---

## 1. Introducción intuitiva

Un pipeline necesita dos tipos de datos externos al código:

1. **Configuración**: cosas que varían entre entornos pero no son sensibles. "La URL de la API es `https://api.staging.example.com`." "La región es `us-east-1`." "La versión de Python es `3.12`."
2. **Secretos**: cosas que, si se filtran, comprometen un sistema. "El token para publicar paquetes." "El password del S3." "La private key para firmar releases."

Mezclar los dos es un error común y caro. Lo primero porque hace imposible rotar el secreto sin editar código; lo segundo porque pone datos no sensibles bajo controles ceremoniales que molestan al equipo (y acaban todos duplicados en texto plano "para desbloquear").

GitHub Actions ofrece esta separación con dos primitivas distintas:

- **`secrets.X`** — valor cifrado, enmascarado en logs, nunca legible una vez guardado.
- **`vars.Y`** — valor plano, legible en la UI, visible en logs, pensado para configuración.

A esto se suma un tercer actor que ya existe sin que lo configures: el **`GITHUB_TOKEN`**, un token que GitHub inyecta en cada run para que tu workflow pueda hablar con la API del propio repo (comentar PRs, publicar releases, subir a GHCR, etc.). Por defecto puede ser *demasiado* permisivo: la práctica correcta es declarar `permissions:` explícitas y aplicar mínimo privilegio.

Finalmente, los **environments** son el namespace donde "el mismo secreto" tiene *valores distintos* según dónde se despliega: `DATABASE_URL` del environment `staging` apunta a staging; `DATABASE_URL` del environment `prod` apunta a prod; el workflow no cambia, cambia de qué environment pide los valores.

Este módulo construye esos cuatro conceptos: `secrets`, `vars`, `GITHUB_TOKEN` con sus `permissions:`, y `environments`.

---

## 2. Fundamentos

### 2.1 `secrets` y `vars` son dos stores distintos

Ambos viven en GitHub (no en el repo), ambos se declaran en Settings → Secrets and variables → Actions, pero:

| Propiedad | `secrets` | `vars` |
|---|---|---|
| Visibilidad del valor | Solo write; nunca legible | Legible en UI y logs |
| Enmascarado automático en logs | Sí (vía filter) | No |
| Scope posible | repo, environment, org | repo, environment, org |
| Uso típico | Credenciales, tokens, keys | Configuración (URLs, flags, versiones) |
| Sintaxis en workflow | `${{ secrets.X }}` | `${{ vars.Y }}` |

Regla: **si saber el valor da acceso a algo, es `secret`; si no, es `var`**.

### 2.2 Scopes y precedencia

Un mismo nombre (digamos `API_URL`) puede existir a tres niveles. Cuando el workflow lee `${{ vars.API_URL }}`, GitHub resuelve con esta precedencia (más específico gana):

```
environment  >  repository  >  organization
```

El scope de **environment** solo aplica si el job declara `environment: <nombre>`. Si no, environment no participa de la resolución y gana repo (o org si repo no lo define).

Consecuencia práctica útil: podés tener `DATABASE_URL` en `vars` a nivel org con el valor por defecto, override en repo para proyectos excepcionales, y override por environment para `prod`. El workflow no sabe de dónde salió.

### 2.3 El `GITHUB_TOKEN` no es un secreto que vos configuraste

Es un token efímero que GitHub crea *para cada run* y expone en el contexto como `${{ secrets.GITHUB_TOKEN }}` (y como variable de entorno `GITHUB_TOKEN` dentro de ciertos steps). Bajo el capó es un **installation token** emitido por la GitHub App llamada "GitHub Actions" que está instalada automáticamente en el repo. Dos propiedades:

- **Corta vida**: expira al terminar el job (típicamente ~1 h máximo).
- **Scopeado**: sus permisos son los que vos declares con `permissions:` en el workflow o el job, acotados a los del propio repo (nunca puede tocar otros repos).

Por eso, el modelo correcto no es "pedir un PAT" para que el workflow haga cosas — es declarar los `permissions:` que el `GITHUB_TOKEN` necesita y usarlo.

### 2.4 Environments son recursos de GitHub, no solo texto

Cuando escribís `environment: production` en un job, no estás creando una etiqueta libre: estás referenciando un **recurso llamado `production`** en el repo. Si no existe, GitHub lo crea con configuración vacía. Y a ese recurso le podés atar:

- Variables y secretos específicos de ese environment.
- Required reviewers (approval manual).
- Wait timers.
- Deployment branch rules (qué refs pueden deployar).
- Custom deployment protection rules (GitHub Apps).

Los gates se evalúan **antes** de que el job arranque (si hay approval pendiente, el job queda en "Waiting"). Y queda **registro auditable** en la pestaña Deployments.

En este módulo solo usamos la parte de namespace de secretos; el resto es `gha-09`.

---

## 3. Contexto histórico

- **2019** — GitHub Actions GA: solo había secretos a nivel repo; el `GITHUB_TOKEN` existía desde el principio pero sus permisos por defecto eran amplios (equivalentes a `write-all`).
- **2020–2021** — Se introduce `permissions:` como key del workflow/job, permitiendo recortar al token.
- **2022** — GitHub cambia el default para orgs/repos nuevos a `permissions: contents: read` (restricted). Repos viejos conservan el default permisivo por compatibilidad — por eso hoy convive la asimetría: dos repos del mismo tipo pueden tener defaults diferentes según cuándo nacieron. **Verificá siempre en Settings → Actions → General → Workflow permissions.**
- **2022** — Se introducen **variables de repo/org/environment** (`vars`), separando configuración de secretos (antes todo convivía como `secrets`, lo cual mezclaba datos no sensibles con datos ceremoniosos).
- **2022+** — Environments con required reviewers, wait timers, deployment branch rules.
- **2023+** — OIDC estable como alternativa a secretos de larga vida para federar a cloud providers (ver `gha-11`).

---

## 4. Funcionamiento interno

### 4.1 Cómo se expone un secreto a un step

```
┌─────────────────────────────────────────────────────────┐
│ GitHub (plano de control)                               │
│   Secret store (AES-GCM, keys per repo/env/org)         │
└───────────────────┬─────────────────────────────────────┘
                    │ al preparar el run, GitHub:
                    │   1) resuelve los ${{ secrets.X }} referenciados
                    │   2) descifra el valor
                    │   3) lo marca como "valor a enmascarar"
                    ▼
┌─────────────────────────────────────────────────────────┐
│ Runner                                                  │
│   - Recibe el workflow con el valor ya resuelto         │
│   - Instala filtro de output: toda línea impresa que    │
│     contenga el valor se reemplaza por "***"            │
│   - Expone al step como env var (si vos lo mapeás)      │
└─────────────────────────────────────────────────────────┘
```

Dos consecuencias importantes:

1. **El filtro trabaja sobre coincidencias de string**. Si transformás el valor (base64, split, uppercase) el filtro ya **no lo reconoce**. Por eso filtrar un secreto es, en la práctica, trivial para cualquiera con permiso de editar el workflow. El modelo asume que el autor del workflow es de confianza.
2. **El secreto NO se expone al step si no lo pedís**. Un `run: ./script.sh` sin `env:` no tiene acceso al `MY_SECRET`. Es opt-in explícito.

### 4.2 Cómo se emite el `GITHUB_TOKEN`

```
┌─────────────────────────────────────────────────────────┐
│ GitHub App "GitHub Actions" (instalada en el repo)      │
└───────────────────┬─────────────────────────────────────┘
                    │ al iniciar el run:
                    │   genera installation token con:
                    │     - scope = este repo
                    │     - permisos = los del workflow/job
                    │     - ttl = duración del job (~1h máx)
                    ▼
┌─────────────────────────────────────────────────────────┐
│ Runner                                                  │
│   secrets.GITHUB_TOKEN = <el token recién emitido>      │
└─────────────────────────────────────────────────────────┘
```

Al terminar el job, el token se revoca. Si lográs filtrarlo y usarlo cinco minutos después, puede que ya no sirva — pero no cuentes con eso como control.

### 4.3 Precedencia completa (secrets y vars)

```
Lectura de ${{ secrets.X }} o ${{ vars.X }} desde un job:

      ┌─────────────────────────────────────┐
      │ Does the job declare `environment`? │
      └───────────────┬─────────────────────┘
                      │
             ┌────────┴────────┐
             │                 │
            yes               no
             │                 │
             ▼                 │
   environment-level?          │
             │                 │
      ┌──────┴──────┐          │
      │             │          │
     yes            no         │
      │             ▼          ▼
      │       repository-level?
      │             │
      │      ┌──────┴──────┐
      │      │             │
      │     yes            no
      │      │             ▼
      │      │       organization-level?
      │      │             │
      │      │      ┌──────┴──────┐
      │      │      │             │
      │      │     yes            no
      ▼      ▼      ▼             ▼
     usa    usa    usa      no definido
    env    repo    org     (expression devuelve '')
```

Nota: para `secrets` a nivel org, el admin elige a qué repos aplican (allow list). Para `vars` org, igual.

### 4.4 Reusable workflows: los secretos **no se heredan solos**

Un reusable workflow (`workflow_call`) corre con *otro* contexto: sus `secrets` tienen que serle pasados explícitamente. Dos formas:

```yaml
# Opción 1: pasar explícito (seguro, auditable)
jobs:
  deploy:
    uses: owner/repo/.github/workflows/deploy.yml@v1
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
      API_TOKEN:    ${{ secrets.API_TOKEN }}

# Opción 2: inherit (cómodo pero amplio: pasa TODO el bag de secrets del caller)
jobs:
  deploy:
    uses: owner/repo/.github/workflows/deploy.yml@v1
    secrets: inherit
```

Regla: **usá `secrets: inherit` solo cuando el reusable workflow es tuyo y auditado**. Para workflows ajenos, pasá secretos explícitos. (Se profundiza en `gha-08`.)

---

## 5. Ejemplo mínimo

Workflow que lee un secreto, una variable, y muestra qué pasa en el log:

```yaml
# .github/workflows/demo-secrets-and-vars.yml
name: demo-secrets-and-vars
on:
  workflow_dispatch:

permissions:
  contents: read   # mínimo

jobs:
  demo:
    runs-on: ubuntu-latest
    env:
      # Opt-in: expongo el secreto a los steps vía env.
      # El valor nunca aparecerá literal en logs porque GitHub lo enmascara.
      API_TOKEN: ${{ secrets.EXAMPLE_SECRET }}
      API_URL:   ${{ vars.EXAMPLE_VAR }}
    steps:
      - name: Show the variable (plain)
        run: echo "API_URL=$API_URL"

      - name: Try to show the secret
        run: |
          # Aparecerá como *** en el log; el valor nunca es visible.
          echo "API_TOKEN=$API_TOKEN"

      - name: Use the secret (correct way)
        run: curl -fsSL -H "Authorization: Bearer $API_TOKEN" "$API_URL/health" || true
```

Si `EXAMPLE_SECRET=hunter2` y `EXAMPLE_VAR=https://api.example.com`, el log mostrará:

```
API_URL=https://api.example.com
API_TOKEN=***
```

El `***` es el enmascaramiento automático. Si transformás el valor (p. ej. `echo "${API_TOKEN^^}"`), el filtro **no** lo captura y verás el valor en mayúsculas.

---

## 6. Implementación progresiva

### Paso 1 — Declará siempre `permissions:` explícitas

Nuevo workflow: top-level mínimo.

```yaml
permissions:
  contents: read
```

### Paso 2 — Escalá solo el job que lo necesita

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    # hereda contents: read del top-level
    steps: [...]

  comment-on-pr:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write   # justificación: dejar un comentario con el resumen
    steps: [...]
```

### Paso 3 — Separá secret de var

Antes:

```yaml
env:
  API_URL:   ${{ secrets.API_URL }}      # mal: no es sensible
  API_TOKEN: ${{ secrets.API_TOKEN }}
```

Después:

```yaml
env:
  API_URL:   ${{ vars.API_URL }}         # bien: config, visible en logs
  API_TOKEN: ${{ secrets.API_TOKEN }}
```

### Paso 4 — Introducí environment cuando el valor difiere por entorno

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: staging        # ahora resuelve vars/secrets de env=staging primero
    env:
      API_URL:   ${{ vars.API_URL }}
      API_TOKEN: ${{ secrets.API_TOKEN }}
    steps: [...]
```

Y repetís con `environment: production` en otro job. Mismo nombre de clave, distinto valor.

### Paso 5 — Pasá secretos explícitos a reusables

Nunca `secrets: inherit` para workflows de terceros.

---

## 7. Aplicación profesional

Patrón de referencia para un repo que despliega a dos entornos:

```yaml
name: ci-cd
on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read   # DEFAULT: read-only para todo lo que no escale explícito

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4   # (en prod: pin a SHA — gha-13)
      - run: ./scripts/test.sh

  publish-coverage:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write   # para dejar comentario con cobertura
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/comment-coverage.sh
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  deploy-staging:
    if: github.ref == 'refs/heads/main'
    needs: test
    runs-on: ubuntu-latest
    environment: staging       # resuelve vars/secrets del env staging
    env:
      API_URL:   ${{ vars.API_URL }}
      API_TOKEN: ${{ secrets.API_TOKEN }}
    steps:
      - run: ./scripts/deploy.sh

  deploy-prod:
    if: github.ref == 'refs/heads/main'
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production    # mismo YAML, otro env ⇒ otros valores
    env:
      API_URL:   ${{ vars.API_URL }}
      API_TOKEN: ${{ secrets.API_TOKEN }}
    steps:
      - run: ./scripts/deploy.sh
```

Observá:

- `permissions:` top-level es `contents: read`.
- Solo `publish-coverage` escala a `pull-requests: write`.
- `deploy-staging` y `deploy-prod` son **idénticos** salvo por `environment:`. Toda la config distinta vive en GitHub, no en YAML.

---

## 8. Trade-offs

| Decisión | A favor | En contra |
|---|---|---|
| `secret` para datos no sensibles | "por si acaso" | No se puede leer, no se puede diffear, no se auditan cambios de valor; difícil de operar |
| `var` para datos sensibles | Legible en UI | Catástrofe: cualquiera con lectura al repo lo ve |
| `permissions: write-all` en top-level | Un step nuevo "simplemente funciona" | Cualquier action comprometida roba todo el repo |
| `permissions: contents: read` default | Mínimo privilegio real | Cada escalada es un cambio deliberado (fricción positiva) |
| `secrets: inherit` a reusable workflow | Menos YAML | Pasás todo el bag sin saber qué usa el callee |
| Environments para config "igual" | Sin beneficio real | Añade ceremonia innecesaria |
| Environments para config que *difiere* por etapa | Mismo workflow, distintos valores; namespaces claros; gate natural para approvals (`gha-09`) | Más clicks de configuración inicial |
| OIDC en vez de secrets de larga vida (`gha-11`) | Nada que rotar, nada que filtrar | Más complejidad inicial; depende del cloud provider |

---

## 9. Errores frecuentes

1. **Guardar la URL o el ID de proyecto como `secret`.** No es sensible: va en `vars`. Si lo guardaste como secret, no vas a poder debuggear por qué el pipeline falla porque ni siquiera verás el valor en el log.

2. **Confiar en el filtro de enmascaramiento como control.** El filtro no sobrevive a transformaciones del valor (`base64`, `tr`, split). Alguien con acceso a editar el workflow puede filtrar cualquier secreto en minutos. El control real es: controlar *quién puede escribir workflows* (CODEOWNERS, protected branches, required reviewers).

3. **Dejar `permissions: write-all` o no declarar `permissions:` en orgs con default permisivo.** El workflow queda con permisos de admin del repo. Una action comprometida (`uses: random/evil@main`) puede borrar branches, hacer push a main, publicar releases falsos.

4. **Suponer que un secreto se "hereda" a un reusable workflow.** No: hay que pasarlo explícito o usar `secrets: inherit`. Si no pasás nada, el callee ve `secrets.X == ''`.

5. **Usar `${{ secrets.GITHUB_TOKEN }}` para operar en *otro* repo.** No puede: el token está scopeado a *este* repo. Para cross-repo necesitás un PAT (con los riesgos que implica) o una GitHub App dedicada.

6. **Imprimir `toJSON(secrets)` para "ver qué hay".** El filtro enmascarará cada valor individualmente, pero vas a ver los *nombres* y la *estructura*; además de ser mala higiene, en reusable workflows revela qué pasa el caller.

7. **Crear environment solo para "tener environment".** Si todos tus environments usan los mismos valores, es ceremonia sin propósito. Introducilo cuando el valor difiere, o cuando necesites approval/branch rules (`gha-09`).

8. **No chequear el default de `permissions:` de la org.** Dos repos del mismo tipo pueden tener defaults distintos según cuándo se crearon. Siempre declará `permissions:` explícitas en el workflow — no dependas del default.

---

## 10. Buenas prácticas

- **Explícito > implícito** en todo este módulo: declará `permissions:`, pasá secretos a reusables, mapeá secretos a env vars solo en los steps que los usan.
- **Default read-only + escalada por job con comentario de justificación.** El comentario es el audit trail más barato: "¿por qué este job tiene `pull-requests: write`?" → ver el comentario.
- **Un secreto, una razón.** Si `AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY` solo se usan en un workflow de deploy, no son secretos de org — son de repo o de environment.
- **Nombrá consistentemente.** `UPPER_SNAKE_CASE`. Prefijo opcional por servicio (`AWS_`, `GHCR_`, `STRIPE_`). Lo que *es* un secret, debe gritarlo (ni `token`, ni `t1`).
- **Rotá antes de que alguien tenga que preguntar cómo.** Documentá el procedimiento de rotación junto al secreto; sin eso, los secretos "viven para siempre".
- **No pongas `GITHUB_TOKEN` como env var top-level si no todos los jobs lo usan.** Mapéalo donde haga falta.
- **Pensá OIDC apenas haya cloud involucrado** (`gha-11`): elimina la clase entera de "qué pasa si el secret se filtra".
- **Auditá periódicamente** quién tiene permiso para ver y editar secrets (admin del repo/org).

---

## 11. Ejercicios recomendados

1. En un repo tuyo, listá todo lo que tenés en `Settings → Secrets and variables → Actions`. Clasificá cada entrada: `¿es secret o var?`, `¿scope correcto?`, `¿se usa en más de un workflow?`.
2. En un workflow existente, agregá `permissions: contents: read` en top-level y ejecutá. ¿Qué se rompe? Cada ruptura te dice un permiso que estaba escalado implícitamente.
3. Reescribí un workflow que usa `secrets: inherit` para pasar explícitos. Documentá qué secrets necesita realmente el callee.
4. Imprimí `${{ toJSON(vars) }}` desde un run manual (`workflow_dispatch`): ¿qué variables ves definidas al nivel que estás ejecutando?
5. Convertí un workflow con un único job `deploy` en dos jobs `deploy-staging` / `deploy-prod` usando environments.

---

## 12. Evaluación

Responder sin consultar el material:

1. ¿Cuál es la diferencia operativa entre `secrets.X` y `vars.X`? Da un ejemplo de dato que debería ser *var* y otro que debería ser *secret*.
2. Explicá qué es el `GITHUB_TOKEN`: quién lo emite, cuánto dura, en qué scope.
3. Dado un workflow con `permissions: write-all` que corre contra un repo con 200 colaboradores, ¿qué riesgo introduce que no se note hasta que algo falla?
4. ¿Qué pasa si un reusable workflow referencia `${{ secrets.API_TOKEN }}` y el caller lo invoca sin `secrets:` ni `secrets: inherit`?
5. ¿Por qué los environments existen como recurso de GitHub y no como simple etiqueta en YAML? Da dos capacidades que habilita.
6. Un compañero propone guardar `GCP_PROJECT_ID` como `secret` "por consistencia con el resto de valores de GCP". ¿Qué le respondés y por qué?
7. Mostrás `echo "$MY_SECRET" | base64` en un run y ves el output claramente en el log. ¿Por qué el filtro de enmascaramiento no lo capturó?
8. Dado el orden de precedencia (environment > repo > org), ¿qué pasa si `API_URL` está definida como `var` tanto en org como en el environment `staging`, y el job declara `environment: staging`?

Si alguna respuesta no fluye en 30 segundos, repasá la sección correspondiente antes de hacer las actividades.
