# Lección: GitHub security and supply chain

> **ID:** `gh-13-github-security-and-supply-chain` · **Nivel:** producción · **Duración:** 5–6 h
> **Prerrequisitos:** `gh-12-github-governance-and-automation`.

---

## 1. Introducción intuitiva

Hasta este módulo hemos tratado al repo como "mío": yo escribo, yo configuro, yo despliego. En producción esa visión es ingenua. Un repo moderno es parte de una **cadena de suministro** que empieza en el autor del commit y termina en un binario ejecutándose en producción. Cualquier eslabón que no puedas **verificar** es un eslabón que un atacante puede sustituir.

Casos reales recientes han vuelto esto urgente:

- **SolarWinds (2020)** — el atacante no comprometió el código fuente; comprometió el *build*. Nadie podía demostrar "este artefacto proviene de ese commit en ese pipeline".
- **xz-utils backdoor (2024)** — un mantenedor con identidad verificable mantuvo acceso durante años. La identidad no era el problema; la **revisión del contenido** sí.
- **Fugas de tokens** en commits (año tras año) — el `AWS_ACCESS_KEY_ID` olvidado en un `.env` sigue siendo la vía número uno de incidentes serios en pequeños equipos.

Este módulo pone **cinco controles** sobre la mesa y te enseña por qué cada uno vive donde vive:

1. **Firma** del commit → prueba quién lo hizo.
2. **Escaneo** del contenido → detecta vulnerabilidades y secretos.
3. **Dependabot** → mantiene dependencias al día automáticamente.
4. **Attestations SLSA** → prueba de dónde salió un artefacto.
5. **OIDC federation** → mata las credenciales de larga vida en CI.

Juntos forman una **defensa en profundidad**: ningún control es suficiente solo; todos juntos te sacan del 99% de los incidentes comunes.

---

## 2. Fundamentos

### 2.1 El modelo de amenazas de un repo

Pregunta siempre: *¿quién, con qué capacidad, contra qué eslabón?*

```
          autor           repo             CI/CD           artefacto         deploy
            │               │                │                  │                │
            ▼               ▼                ▼                  ▼                ▼
    ┌───────────┐   ┌─────────────┐   ┌───────────┐    ┌──────────────┐   ┌──────────┐
    │  identity │   │  contenido  │   │  build    │    │  binario /   │   │  entorno │
    │  (clave,  │──>│  (código,   │──>│  (runner, │───>│  imagen /    │──>│  (cloud, │
    │  2FA)     │   │  deps,      │   │  acciones)│    │  SBOM)       │   │  k8s)    │
    └───────────┘   │  secretos)  │   └───────────┘    └──────────────┘   └──────────┘
                    └─────────────┘
```

Controles por eslabón:
- **Identidad** → MFA obligatorio, SSO/SAML, SSH keys hardware (si posible), **firma de commits**.
- **Contenido** → code scanning (CodeQL), secret scanning, push protection, Dependabot, revisión obligatoria con CODEOWNERS.
- **Build** → runners efímeros, `permissions: read-all` por default, OIDC en vez de secretos, pinning de actions por SHA.
- **Artefacto** → SBOM, attestation SLSA, firma del artefacto (cosign para contenedores).
- **Deploy** → environments protegidos con approval, OIDC a cloud, rotación automática de credenciales que sigan existiendo.

### 2.2 ¿Qué es una firma de commit y qué garantiza?

Un commit firmado añade **tres cosas** al objeto commit en el repo:

```
tree 7ab2…
parent 9c1e…
author  Evan <evan@example.com> 1697000000 +0000
committer Evan <evan@example.com> 1697000000 +0000
gpgsig -----BEGIN SSH SIGNATURE-----       ← la firma
U1NIU0lHAAAAAQAAADMAAAALc3NoLWVkMjU1MTkAAAAg…
-----END SSH SIGNATURE-----

<mensaje del commit>
```

La firma cubre **el resto del commit** (tree + padres + autor/committer + mensaje). Cualquier alteración rompe la firma.

Garantiza (fuerte): *quien firmó tenía la clave privada en el momento de firmar*.
No garantiza (débil): que el contenido sea correcto, que la clave no haya sido comprometida después, que el autor sea un humano, que no sea un bot con una clave robada.

Por eso la firma es **necesaria pero no suficiente**. Se combina con: 2FA, políticas de revisión (CODEOWNERS, PR approval), rulesets ("required signatures"), rotación de claves.

### 2.3 El badge "Verified" de GitHub

GitHub considera un commit **Verified** si:

1. El commit tiene una firma SSH, GPG o X.509 (S/MIME, gitsign/Sigstore).
2. La clave pública está **registrada en el perfil del usuario** (en la sección *SSH and GPG keys* → *Signing keys*).
3. La identidad en la clave (email para GPG, llave para SSH) **corresponde a** un email verificado del autor del commit.
4. La firma **valida criptográficamente**.

Si uno de 1–4 falla: badge "Unverified" (o directamente ningún badge). El commit no se bloquea por sí mismo; el *bloqueo* requiere una regla "Required signatures" en el ruleset (ver `gh-12`).

### 2.4 ¿Qué es una attestation SLSA y qué garantiza?

**SLSA** (Supply-chain Levels for Software Artifacts) es un marco con niveles de madurez (L1–L4). GitHub Actions, desde 2024, puede generar automáticamente una **build provenance attestation** nivel SLSA v1.0 L2+ cuando el workflow usa la acción `actions/attest-build-provenance`.

La attestation es un documento firmado (vía **Sigstore**, keyless) con el formato `in-toto Statement` + predicate `slsa-provenance/v1`, que afirma:

- **Subject**: el artefacto (hash digest).
- **Builder**: `https://github.com/actions/runner` + versión.
- **BuildType**: `https://actions.github.io/buildtypes/workflow/v1`.
- **Invocation**: el workflow (`.github/workflows/x.yml`), ref (`refs/heads/main`), SHA del commit, el repositorio.
- **Materials**: el repo y commit SHA de entrada.

Garantiza (fuerte): *este artefacto fue producido por ese workflow en ese commit en ese runner de GitHub*. Terceros pueden verificar con `gh attestation verify` sin confianza previa en el repositorio: la firma Sigstore se ancla en el log público **Rekor**.

No garantiza: que el código sea bueno, que el workflow sea correcto, que no hubiera un atacante *dentro* del workflow. La attestation **ata** artefacto a build, no decide si el build era seguro.

### 2.5 ¿Por qué OIDC-to-cloud elimina credenciales largas?

El patrón clásico de CI:

```
GitHub Actions secret: AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY  (vida: meses/años)
   │
   ▼
Workflow usa esas credenciales para hablar con AWS
```

Problema: la credencial es *persistente*. Si se filtra, el atacante tiene acceso hasta que alguien la rota. Nadie rota.

El patrón OIDC:

```
Workflow run (GitHub Actions)
   │
   │  1) GitHub firma un JWT (OIDC token) con claims:
   │     iss  = https://token.actions.githubusercontent.com
   │     sub  = repo:org/repo:ref:refs/heads/main    (o environment:prod, pull_request, etc.)
   │     aud  = sts.amazonaws.com                     (configurable)
   │     + jti, iat, exp (~5-15 min), run_id, run_attempt, actor…
   │
   ▼
AWS STS AssumeRoleWithWebIdentity
   │  2) STS verifica la firma contra el JWKS público de GitHub,
   │     comprueba el trust policy del rol (ver abajo),
   │     y emite credenciales temporales (STS: 1h máx típico).
   │
   ▼
Workflow usa esas credenciales temporales. Al terminar: desaparecen.
```

Lo que **requiere el trust policy del rol** en AWS:

- **Identity Provider** `token.actions.githubusercontent.com` registrado como `OpenIDConnectProvider` en IAM (una vez por cuenta).
- Un `Role` con `AssumeRolePolicyDocument` que:
  - Permite `sts:AssumeRoleWithWebIdentity`.
  - Condiciona por `token.actions.githubusercontent.com:aud` = `sts.amazonaws.com`.
  - **Pin del sujeto** por `token.actions.githubusercontent.com:sub`: `repo:MyOrg/MyRepo:ref:refs/heads/main` (o `:environment:prod`, `:pull_request`, etc.). **Sin este pin, cualquier workflow de cualquier repo podría asumir el rol.**

Ejemplo (ver `examples/03-oidc-to-aws/trust-policy.json`):

```json
{
  "Effect": "Allow",
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Principal": { "Federated": "arn:aws:iam::AWS-ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com" },
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:ref:refs/heads/main"
    }
  }
}
```

Equivalentes conceptuales existen para **GCP** (Workload Identity Federation con Pool/Provider) y **Azure** (Entra ID federated credentials). El patrón es idéntico: *el proveedor cloud confía en el token del IdP de GitHub, no en una credencial estática.*

### 2.6 SBOM, dependency graph y Dependabot

**SBOM** (Software Bill of Materials) = inventario firmado de las dependencias de un artefacto.

GitHub genera un SBOM nativo basado en el **dependency graph** (que a su vez se nutre de los manifests detectados: `package.json`, `requirements.txt`, `go.mod`, etc.). Se puede exportar:

```bash
gh api /repos/OWNER/REPO/dependency-graph/sbom > sbom.spdx.json
```

El SBOM alimenta tres servicios:

- **Dependabot alerts** — comparación continua con la **GitHub Advisory Database** (GHSA). Cuando una dependencia tiene vulnerabilidad conocida, abre alerta.
- **Dependabot security updates** — PR automático a la versión mínima que resuelve la vulnerabilidad.
- **Dependabot version updates** — PR automático a nuevas versiones aunque no haya vulnerabilidad (controlado por `.github/dependabot.yml`).

---

## 3. Contexto histórico

| Año | Hito |
|-----|------|
| 2008 | GitHub lanza. Firma de commits = GPG, nicho. |
| 2013 | GitHub muestra badge "verified" para firmas GPG. |
| 2017 | Dependabot (empresa) lanza; GitHub lo adquiere en **2019**. |
| 2018 | GitHub lanza security advisories y la GHSA. |
| 2019 | GitHub Actions GA; secrets como mecanismo principal. |
| 2021 | GitHub soporta **SSH signing** y **S/MIME** además de GPG. OIDC provider para GitHub Actions lanza. |
| 2022 | **Sigstore** (y `gitsign`) empuja la firma keyless basada en identidad OIDC. SLSA v1.0 draft. |
| 2023 | Secret scanning + **push protection** disponible gratis para repos públicos. |
| 2024 | `actions/attest-build-provenance` GA. Dependency graph + SBOM export vía API. SLSA v1.0 estable. |
| 2024+ | SSH signing recomendado como *default* por GitHub (menor fricción que GPG). |

El patrón: **cada eslabón que podía ser falsificado o filtrado ganó un mecanismo criptográfico verificable**. La historia es la de las credenciales de larga vida muriendo lentamente.

---

## 4. Funcionamiento interno

### 4.1 Cómo verifica Git una firma SSH

El comando `git log --show-signature` o `git verify-commit <hash>` dispara:

1. Git lee el campo `gpgsig` del objeto commit.
2. Detecta el formato por el prefijo (`-----BEGIN SSH SIGNATURE-----`, `-----BEGIN PGP SIGNATURE-----`, …).
3. Para **SSH**: invoca `ssh-keygen -Y verify`, pasándole:
   - El contenido firmado (todo el commit menos la propia firma).
   - La firma (`-----BEGIN SSH SIGNATURE-----` …).
   - El archivo `allowed_signers` (configurado con `gpg.ssh.allowedSignersFile`), que mapea identidad → clave pública aceptada.
4. `ssh-keygen` valida criptográficamente y responde `Good "evan@example.com" signature from …`.

**Si no hay `allowedSignersFile` configurado**, Git puede verificar que la firma es criptográficamente válida pero no sabe *de quién* es (no tiene un mapeo identidad→clave). Resultado típico: `No principal matched`.

GitHub hace exactamente lo mismo pero el `allowedSignersFile` es implícito: usa las claves de firma registradas en los perfiles de los miembros.

### 4.2 Cómo construye GitHub Actions una attestation

Cuando usas `actions/attest-build-provenance@v2` con `subject-path: path/to/artifact`:

1. La acción calcula `sha256` del artefacto.
2. Construye un `in-toto Statement`:
   ```json
   {
     "_type": "https://in-toto.io/Statement/v1",
     "subject": [{ "name": "artifact", "digest": {"sha256": "…"} }],
     "predicateType": "https://slsa.dev/provenance/v1",
     "predicate": {
       "buildDefinition": {
         "buildType": "https://actions.github.io/buildtypes/workflow/v1",
         "externalParameters": { "workflow": {...} },
         "internalParameters": {...},
         "resolvedDependencies": [{"uri": "git+https://github.com/MyOrg/MyRepo@refs/heads/main", "digest": {"sha1": "<commit-sha>"}}]
       },
       "runDetails": {
         "builder": {"id": "https://github.com/actions/runner/github-hosted"},
         "metadata": {"invocationId": "https://github.com/MyOrg/MyRepo/actions/runs/<id>/attempts/<n>"}
       }
     }
   }
   ```
3. Pide un token OIDC a GitHub con `audience=sigstore`.
4. Lo intercambia en **Fulcio** (CA de Sigstore) por un **certificado X.509 de corta vida** (10 min) que incluye extensiones con los claims OIDC: `Build Signer URI`, `Source Repository URI`, `Build Config URI`, etc.
5. Firma el `in-toto Statement` con la clave efímera correspondiente al certificado.
6. Sube la firma + certificado al log de transparencia **Rekor**.
7. Sube el bundle (statement + firma + certificado + prueba de inclusión) a GitHub como **attestation asociada al repo**.

Verificación (por cualquier persona):

```bash
gh attestation verify path/to/artifact --repo MyOrg/MyRepo
```

Internamente: resuelve el bundle, verifica cadena contra la raíz de Fulcio, verifica inclusión en Rekor, y comprueba que los claims (repo, workflow) coinciden con lo esperado.

### 4.3 Push protection del lado del servidor

Cuando habilitas **secret scanning** + **push protection**:

1. Para cada push, antes de aceptar los objetos, GitHub ejecuta detectores de patrones (regex + validadores para ~300 proveedores: AWS, GCP, Stripe, Slack, GitHub tokens, etc.).
2. Si detecta un secreto *con alta confianza* (algunos detectores incluyen validador vivo contra el emisor):
   - **Bloquea el push** con `remote: Push rejected: contains secret`.
   - El autor puede **bypass** si está autorizado y justifica (telemetría al audit log).
3. En paralelo, para repos con secret scanning sin push protection: se abre una alerta tras el push.

Es un control del *lado del servidor*. Localmente, para una defensa en profundidad, se añade un hook pre-commit (gitleaks, trufflehog) que atrapa la fuga antes de que salga de la máquina.

### 4.4 Modelos de secrets de Actions

| Scope | Visibilidad | Uso típico |
|-------|-------------|------------|
| **Repository** secrets | solo workflows de ese repo | credenciales específicas del proyecto |
| **Environment** secrets | solo workflows que corren contra ese environment, respetan **approval** y **branch policies** del environment | credenciales de producción con reviewer requerido |
| **Organization** secrets | repos elegidos (allowlist o todos los repos privados/internos/públicos) | credenciales compartidas (p. ej. `NPM_TOKEN` para toda la org) |

Reglas:

- Los secrets no se imprimen en logs (mask automático), pero cuidado con *derivados*: si imprimes `base64 $SECRET`, el mask no lo cubre.
- Los secrets **no son accesibles** desde workflows disparados por `pull_request` de un fork (política de seguridad). Para esos casos usa `pull_request_target` con cuidado (ver sec. 9.3).
- **Preferible**: no usar secrets. Usar OIDC. Si inevitable (webhooks externos, APIs legacy sin OIDC), usar environment secrets + approval.

### 4.5 Audit log

A nivel de **organization** y **enterprise**, GitHub registra eventos: cambios en rulesets, modificaciones de secrets, uso de bypass en push protection, aprobaciones de environments, cambios de permisos, etc.

Formato: JSON por evento. Export por API (`/orgs/{org}/audit-log`), streaming a S3/Azure/Splunk, retención ampliable con GitHub Enterprise.

Es la **única fuente de verdad** para post-mortem de incidentes. Encender el streaming desde el día 1.

---

## 5. Ejemplo mínimo

Configurar **SSH signing local** y hacer un commit firmado — sin GitHub, 100% local, verificable con `ssh-keygen -Y verify`.

```bash
# 1) Generar una clave SSH SOLO para firmar (separada de la de auth, buena práctica)
mkdir -p ~/.config/git-signing
ssh-keygen -t ed25519 -C "git-signing" \
  -f ~/.config/git-signing/signing_ed25519 -N ""

# 2) Configurar Git para firmar con esa clave
git config --global gpg.format ssh
git config --global user.signingkey ~/.config/git-signing/signing_ed25519.pub
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# 3) Crear el archivo allowed_signers (quién tiene permiso para firmar como quién)
mkdir -p ~/.config/git
printf '%s %s\n' "$(git config user.email)" "$(cat ~/.config/git-signing/signing_ed25519.pub)" \
  > ~/.config/git/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers

# 4) Repo de prueba
rm -rf /tmp/sign-demo && mkdir /tmp/sign-demo && cd /tmp/sign-demo
git init -q -b main
echo hello > README.md
git add README.md
git commit -q -m "chore: signed init"

# 5) Verificar
git log --show-signature -1
# Debe mostrar: "Good "<tu-email>" signature with ED25519 key ..."
```

Si GitHub (sección *Settings → SSH and GPG keys → New SSH key* con tipo **Signing Key**) tiene tu `signing_ed25519.pub`, un `git push` a ese repo mostrará el badge **Verified** en la UI de GitHub.

---

## 6. Implementación progresiva

### 6.1 Dependabot — `.github/dependabot.yml`

Mínimo útil para un repo mixto:

```yaml
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/"
    schedule: { interval: "weekly", day: "monday", time: "08:00", timezone: "Europe/Madrid" }
    open-pull-requests-limit: 5
    labels: [ "dependencies", "python" ]
    groups:
      dev-dependencies:
        dependency-type: "development"
      prod-minor-and-patch:
        dependency-type: "production"
        update-types: [ "minor", "patch" ]

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule: { interval: "weekly" }
    labels: [ "dependencies", "ci" ]

  - package-ecosystem: "docker"
    directory: "/"
    schedule: { interval: "weekly" }
```

Puntos finos:
- **Groups** evitan 50 PRs: agrupan menores y parches en uno.
- `github-actions` ecosystem actualiza las `uses: foo/bar@vX` (versión y, si usas `# vX.Y.Z` como comentario, SHA pinning).
- Para repos **privados** con registros privados, hay que configurar `registries:` + repo secrets.

### 6.2 CodeQL / code scanning

Snippet mínimo de `.github/workflows/codeql.yml`:

```yaml
name: CodeQL
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }
  schedule: [{ cron: "17 3 * * 1" }]

permissions:
  contents: read
  security-events: write    # necesario para publicar hallazgos
  actions: read

jobs:
  analyze:
    runs-on: ubuntu-latest
    strategy:
      matrix: { language: [python, javascript] }
    steps:
      - uses: actions/checkout@v4
      - uses: github/codeql-action/init@v3
        with: { languages: ${{ matrix.language }} }
      - uses: github/codeql-action/analyze@v3
```

Resultados aparecen en **Security → Code scanning alerts** y pueden ser requisito en el ruleset ("required status checks").

### 6.3 Secret scanning + push protection

Vía UI: `Settings → Code security and analysis` → activar *Secret scanning* y *Push protection*.
Vía API:

```bash
gh api -X PATCH /repos/OWNER/REPO \
  -f security_and_analysis.secret_scanning.status=enabled \
  -f security_and_analysis.secret_scanning_push_protection.status=enabled
```

Para repos públicos: gratis. Para privados: requiere **GitHub Advanced Security** (en plan Enterprise, o add-on).

Como defensa en profundidad local, pre-commit con gitleaks:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
```

### 6.4 Private vulnerability reporting (PVR)

Activar en `Settings → Code security → Private vulnerability reporting`. Expone `/security/advisories/new` para que investigadores reporten sin filtrar. Crea un canal responsable (vs. abrir un issue público que es, de facto, 0-day).

### 6.5 OIDC a AWS — mínimo funcional

Trust policy del rol:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::AWS-ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:ref:refs/heads/main"
      }
    }
  }]
}
```

Workflow:

```yaml
name: deploy
on: { push: { branches: [main] } }

permissions:
  contents: read
  id-token: write     # imprescindible para pedir el JWT OIDC

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::AWS-ACCOUNT-ID:role/github-deploy
          aws-region: eu-west-1
      - run: aws sts get-caller-identity
```

Ni un solo secreto. Las credenciales viven ~1h, atadas a este workflow en esta rama.

### 6.6 Attestation de build provenance

```yaml
name: release
on: { push: { tags: ["v*"] } }
permissions:
  contents: write
  id-token: write       # para firma Sigstore
  attestations: write   # para subir attestation al repo

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          mkdir -p dist
          echo "fake-binary" > dist/myapp-${{ github.ref_name }}
      - uses: actions/attest-build-provenance@v2
        with: { subject-path: dist/myapp-${{ github.ref_name }} }
      - uses: softprops/action-gh-release@v2
        with: { files: dist/myapp-${{ github.ref_name }} }
```

Verificación por consumidor:

```bash
gh attestation verify ./myapp-v1.0.0 --repo MyOrg/MyRepo
```

---

## 7. Aplicación profesional

### 7.1 Baseline mínimo de un repo productivo

Checklist (no negociable):

- [ ] 2FA/MFA obligatorio a nivel organización.
- [ ] SSO/SAML activo si tu plan lo permite.
- [ ] **Ruleset** sobre `main` con: required PR, required reviewers (≥1), required status checks (CodeQL, build, tests), **required signatures**, no force-push, no deletions.
- [ ] CODEOWNERS cubriendo paths críticos.
- [ ] **Secret scanning + push protection** habilitados.
- [ ] **Dependabot alerts** + **security updates** + **version updates** (`.github/dependabot.yml`).
- [ ] **CodeQL** o equivalente (semgrep, etc.) en PR y schedule.
- [ ] **PVR** habilitado + `SECURITY.md` con proceso de reporte.
- [ ] **OIDC** para toda interacción con cloud desde Actions. Cero `AWS_ACCESS_KEY_ID` largos.
- [ ] Releases con **attestation** `actions/attest-build-provenance`.
- [ ] Workflows con `permissions:` **mínimas** por job (default: `read`, upgrade por job).
- [ ] Actions pinneadas por **SHA** (no por tag flotante) para dependencias críticas.
- [ ] Audit log streaming activo (si plan Enterprise).

### 7.2 Firmar commits en equipo

Opciones por equipo:

- **Equipo pequeño** (≤10): **SSH signing** personal. Cada dev configura su clave, la publica en GitHub, PR template recuerda verificar "Verified". `required signatures` en el ruleset.
- **Equipo mediano** (~50): mismo, pero **centraliza el `allowed_signers`** en un repo compartido para `git verify-commit` offline.
- **Equipo grande** / regulado: **gitsign** (Sigstore) con OIDC corporativo (Okta, Entra ID). Los devs no gestionan claves — firman con su identidad corporativa, el certificado vive 10 min y está en Rekor. Verificación con `gitsign verify`.
- **Bots y automatizaciones**: no uses PAT firmando con GPG a mano. **GitHub Apps** emiten commits firmados por el servidor cuando hacen commits vía API — llegan como "Verified" automáticamente.

### 7.3 OIDC + environment approvals

Patrón productivo:

```yaml
jobs:
  deploy-prod:
    environment: production      # requiere approval configurado en Settings → Environments
    permissions: { id-token: write, contents: read }
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/deploy-prod
          aws-region: eu-west-1
```

En el trust policy del rol `deploy-prod`, pinnea con `environment`:

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:environment:production"
}
```

Doble barrera: aprobación humana + token OIDC ligado al environment.

### 7.4 SBOM y SLSA en releases

Flujo típico release-de-binario:

1. Workflow `release.yml` dispara en `push: tags: ["v*"]`.
2. Build reproducible → `dist/binary`.
3. `actions/attest-build-provenance@v2` genera attestation.
4. (Opcional) `anchore/sbom-action` genera SBOM SPDX.
5. `softprops/action-gh-release` publica el release con los artefactos y, por detrás, GitHub asocia la attestation al release.
6. Documentación de consumo: `gh attestation verify` + checksum.

### 7.5 Auditoría de un repo ajeno

Checklist para auditar un repo (ejercicio final del módulo):

1. **Permisos y acceso**: ¿público/privado? ¿quién tiene admin? ¿collaborators externos?
2. **Branch protection / Rulesets** sobre `main`: ¿PR requerido? ¿approvals? ¿signatures?
3. **Firma**: ¿commits recientes marcados Verified? ¿cuántos autores?
4. **Dependabot**: ¿`.github/dependabot.yml`? ¿alerts habilitado? ¿cuántas alertas abiertas sin tratar?
5. **Code scanning**: ¿CodeQL u otro? ¿alertas abiertas?
6. **Secret scanning + push protection**: ¿activo? ¿alertas pasadas?
7. **Workflows**: ¿`permissions:` mínimas? ¿actions pinneadas por SHA? ¿`pull_request_target` seguro?
8. **OIDC vs long-lived secrets**: ¿aparece `AWS_ACCESS_KEY_ID` en secrets? ¿workflows usan `id-token: write` + `configure-aws-credentials`?
9. **Attestation / provenance**: ¿releases tienen attestations?
10. **SECURITY.md + PVR**: ¿proceso documentado?
11. **Audit log** (si eres owner): ¿bypasses recientes de push protection? ¿cambios en rulesets?

Entrega: un documento con **gap** + **riesgo** + **recomendación priorizada (P0/P1/P2)**.

---

## 8. Trade-offs

### 8.1 SSH signing vs GPG vs gitsign

| Dimensión | SSH | GPG | gitsign (Sigstore) |
|-----------|-----|-----|---------------------|
| Setup | fácil (1 clave, 3 configs) | duro (keyring, subkeys, expiración) | medio (requiere OIDC IdP) |
| Reuso | puedes reusar tu clave SSH de auth (no recomendado) | clave distinta | identidad corporativa |
| Expiración | gestionas tú (ninguna por default) | subkey con `expire-date` | 10 min (certificado efímero) |
| Revocación | borras del `allowed_signers` / de GitHub | revocation cert | basada en identidad OIDC |
| Verificabilidad por terceros sin confiar en ti | medio (necesita tu `allowed_signers`) | medio (necesita tu `pubkey` en un keyserver) | **alta** (Rekor público) |
| Soporte en GitHub | **sí** | sí (histórico) | sí (como "verified" si el issuer es confiable) |

Recomendación 2024+: **SSH para humanos, gitsign si tienes IdP corporativo y quieres máxima verificabilidad.** GPG solo por legado.

### 8.2 Long-lived secret vs OIDC

**Long-lived secret**:
- Pro: setup trivial, funciona con cualquier proveedor.
- Contra: fuga = compromiso duradero. Nadie rota. Fácil de olvidar.

**OIDC**:
- Pro: cero credenciales persistentes. Pin por repo/branch/env. Audit implícito.
- Contra: solo funciona con proveedores que lo soportan (AWS, GCP, Azure, HashiCorp Vault, Terraform Cloud, PyPI trusted publishers, npm trusted publishers — cada vez más). Requiere entender el trust policy.

En 2024+ si tu proveedor soporta OIDC y no lo usas, estás eligiendo deuda de seguridad consciente.

### 8.3 Pin de actions por tag vs por SHA

**Por tag** (`uses: actions/checkout@v4`):
- Pro: legible, autoupdates "menores" (Dependabot GitHub Actions eco).
- Contra: `v4` es una ref mutable; si el maintainer (o atacante que lo compromete) la mueve a un commit malicioso, lo ejecutas.

**Por SHA** (`uses: actions/checkout@abc123…abc`):
- Pro: inmutable. El commit no cambia.
- Contra: ilegible. Requiere Dependabot para no quedarte sin updates.

Patrón recomendado: **SHA + comentario con versión legible**, Dependabot encargado de actualizarlo:

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

### 8.4 Push protection central vs hook local

**Push protection (GitHub)**:
- Pro: aplica a todos sin configurar su máquina. Autoridad central. Audit log.
- Contra: requiere plan (Advanced Security en privados). El secreto ya existe en la máquina local.

**Hook local (gitleaks pre-commit)**:
- Pro: atrapa antes del `git commit`. Gratis. Educa al autor.
- Contra: depende de que el dev lo instale. Opcional por default.

**Ambas** (defensa en profundidad) es lo correcto.

### 8.5 Attestations vs firma de artefacto (cosign)

**Attestation SLSA (`attest-build-provenance`)**:
- Dice: *de dónde salió* un artefacto (quién lo construyó, en qué commit, con qué workflow).

**Cosign sign (contenedor firmado)**:
- Dice: *quién avala* un artefacto (puede ser el build, puede ser un reviewer humano, puede ser una política).

Son complementarias. Un contenedor productivo moderno tiene **ambas**: una attestation de build (del CI) + un sign de release (de un rol humano/organización).

---

## 9. Errores frecuentes

### 9.1 "Mi commit aparece como Unverified a pesar de estar firmado"

Causas comunes:
- La **clave pública no está subida a GitHub como "Signing key"** (hay dos secciones separadas: Authentication keys vs Signing keys).
- El email en `user.email` **no está verificado** o es distinto al de la clave.
- Firmaste con una clave que **no es la de signingkey** (típico cuando combinas SSH keys y GPG keys cambiando contextos).

Diagnóstico: `git log --show-signature -1` en local da el detalle real.

### 9.2 "Trust policy de OIDC pin con wildcard = catástrofe"

Antipatrón:

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:MyOrg/*"
}
```

Cualquier repo (incluyendo uno nuevo que un atacante abra en tu org si pueden) puede asumir el rol. **Pinnea rama o environment o workflow**:

```json
"token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:ref:refs/heads/main"
```

o mejor:

```json
"token.actions.githubusercontent.com:sub": "repo:MyOrg/MyRepo:environment:production"
```

### 9.3 "`pull_request_target` + checkout del PR = RCE"

`pull_request_target` corre **con el contexto del repo base**, incluyendo secrets. Si haces `actions/checkout` **del ref del PR**, un atacante que abre un PR puede inyectar código que corre con tus credenciales.

Patrón **inseguro**:

```yaml
on: pull_request_target
jobs:
  bad:
    steps:
      - uses: actions/checkout@v4
        with: { ref: ${{ github.event.pull_request.head.sha }} }
      - run: npm install && npm run build  # ejecuta scripts del PR con secrets
```

Si necesitas `pull_request_target` (para labelear, comentar, etc.), **no checkout del PR**, o checkoutea en un filesystem efímero sin acceso a secrets.

### 9.4 "Eché un secret en git y ya lo borré con --amend"

Si no pusheaste: `git reset --soft HEAD~1` + unstage + commit limpio. Si pusheaste: **asumir leaked, rotar YA**. Limpiar historia (`git filter-repo`) no quita el secreto de forks ni de caches de terceros. Rotar es la única mitigación real.

Push protection evita esto preventivamente. Secret scanning retroactivo lo detecta.

### 9.5 "Habilité Dependabot y tengo 300 PRs abiertos"

Síntoma de haber activado version updates en un repo con dependencias viejas.

Mitigación:
- `groups:` en `dependabot.yml` para consolidar.
- `open-pull-requests-limit: 5`.
- Mezclar: solo security updates al principio; version updates una vez el repo esté al día.

### 9.6 "Attestation falla con 'subject-path not found'"

Causa típica: el workflow genera el artefacto en un step y `actions/attest-build-provenance` corre antes. Orden importa, y la ruta del subject debe existir al momento de la ejecución.

### 9.7 "`gitleaks` no detecta mi secreto"

Los detectores funcionan por patrón. Tokens genéricos (p. ej. una API key custom sin prefijo reconocible) pueden pasar. Mitigación: añadir reglas custom al `.gitleaks.toml`.

### 9.8 "SSH signing funciona local pero GitHub dice Unverified"

Verifica que la clave fue subida como **Signing Key** (no sólo Auth Key) y que `user.email` coincide con un email verificado.

---

## 10. Buenas prácticas

- **Firma todo**: commits y tags. Rulesets `required_signatures` en `main`.
- **Clave de firma separada** de la de autenticación.
- **Dependabot desde el día 1**: alerts + security updates mínimo; version updates con `groups`.
- **CodeQL en PR y schedule semanal.** Hallazgos críticos bloquean merge.
- **Secret scanning + push protection activados.** Pre-commit local con gitleaks como defensa en profundidad.
- **OIDC a cualquier cloud que lo soporte.** Cero `AWS_ACCESS_KEY_ID` largos.
- **Pin del `sub`** en el trust policy por repo + rama o environment. Nunca `repo:MyOrg/*`.
- **Permissions mínimas por workflow:** `permissions: {}` top-level, elevar por job.
- **Actions pinneadas por SHA** con comentario de versión. Dependabot GitHub Actions ecosystem.
- **Releases con `actions/attest-build-provenance`.**
- **`SECURITY.md` + PVR habilitado.**
- **Audit log streaming** si tu plan lo permite.
- **Rotación**: lo que no se puede eliminar (secrets inevitables), se rota cada N días con alerta.
- **Documenta cada control** en `docs/security.md` del repo: por qué, qué garantiza, cómo auditarlo.

---

## 11. Ejercicios recomendados

1. **`activities/02-sign-and-verify-commits/`** — guided-lab local: generar clave SSH de firma, configurar git, hacer commits firmados, verificar con `git log --show-signature` y con `ssh-keygen -Y verify` directamente. **Hazlo primero.**
2. **`activities/01-enable-secret-scanning-and-push-protection/`** — guided-lab dual-mode: habilitar los controles en GitHub (MODE=live) o configurar defensa en profundidad local con `pre-commit` + gitleaks (MODE=local). Validator comprueba el hook atrapa un secreto de prueba.
3. **`activities/03-oidc-federation-to-cloud/`** — dual-mode: desplegar el workflow completo con una cuenta AWS real (MODE=live, costo = USD 0 si solo haces `aws sts get-caller-identity`) o validar la **corrección** del workflow YAML + trust policy JSON (MODE=local). Validator inspecciona pin de `sub`, permisos, ausencia de secrets, etc.

---

## 12. Evaluación

Responde sin consultar. Las preguntas combinan los cinco controles del módulo.

**P1.** Explica **cómo GitHub verifica una firma SSH** en un commit, paso por paso. ¿Qué pasa si la clave *no* está registrada como "Signing key" en el perfil del autor?

**P2.** Diferencia **en una frase cada una**:
- Dependabot alerts
- Dependabot security updates
- Dependabot version updates
- CodeQL

**P3.** Verdadero / falso. Justifica los falsos.
- [ ] Secret scanning solo funciona para repos públicos.
- [ ] Push protection bloquea el push *antes* de que el secreto quede en el servidor.
- [ ] `git commit --amend` sobre un commit firmado conserva la firma.
- [ ] Una attestation SLSA de GitHub prueba que el código es seguro.
- [ ] Un rol AWS con `sub: repo:MyOrg/*` y `aud: sts.amazonaws.com` es seguro.
- [ ] `permissions: {}` en el workflow top-level **mejora** la seguridad.

**P4.** Diseña el **trust policy** mínimo de un rol AWS `deploy-prod` que debe ser asumible **solo** por el environment `production` del repo `acme/web`, con `aud=sts.amazonaws.com`. Escríbelo en JSON.

**P5.** Un desarrollador committeó un `AWS_ACCESS_KEY_ID` real y pusheó a `main`. Describe la respuesta en orden (6+ pasos), empezando por el más urgente.

**P6.** Explica **qué garantiza y qué no garantiza** una attestation generada por `actions/attest-build-provenance@v2`. ¿Qué significa que esté anclada en Rekor?

**P7.** Audita este snippet y lista los problemas de seguridad (al menos 5):

```yaml
name: deploy
on: pull_request_target
permissions: write-all
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@main
        with: { ref: ${{ github.event.pull_request.head.sha }} }
      - run: ./build.sh
      - run: aws s3 sync ./dist s3://prod-bucket
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

**P8.** Propón un **baseline de 10 controles** no negociables para un repo productivo de tu organización, ordenados por prioridad. Para cada uno: en una línea, qué riesgo mitiga.

---

## Referencias

- GitHub Docs — **About commit signature verification**. <https://docs.github.com/authentication/managing-commit-signature-verification/about-commit-signature-verification>
- GitHub Docs — **Signing commits** (SSH). <https://docs.github.com/authentication/managing-commit-signature-verification/signing-commits>
- GitHub Docs — **Configuring Dependabot**. <https://docs.github.com/code-security/dependabot>
- GitHub Docs — **Secret scanning + push protection**. <https://docs.github.com/code-security/secret-scanning>
- GitHub Docs — **OIDC with GitHub Actions**. <https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect>
- GitHub Docs — **Using artifact attestations**. <https://docs.github.com/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds>
- GitHub Docs — **CodeQL analysis**. <https://docs.github.com/code-security/code-scanning>
- SLSA v1.0 spec. <https://slsa.dev/spec/v1.0/>
- Sigstore project (gitsign, cosign, fulcio, rekor). <https://www.sigstore.dev/>
- `gitleaks`. <https://github.com/gitleaks/gitleaks>
- AWS IAM — **Create an IAM OIDC identity provider for GitHub**. <https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html>
- SSH signing — `ssh-keygen(1)` section on signing/verifying.
