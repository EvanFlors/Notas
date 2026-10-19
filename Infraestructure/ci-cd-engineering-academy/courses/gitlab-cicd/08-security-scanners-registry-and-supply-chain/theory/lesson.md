# gl-08 — Lección: scanners, registry y cadena de suministro

> 8 secciones. Prerrequisitos: `gl-02`, curso `devsecops` ≥ Nivel 2.

---

## 1. Scanners nativos como templates oficiales

GitLab mantiene un repositorio público de **plantillas CI/CD** (`gitlab-org/gitlab` → `lib/gitlab/ci/templates/`). Las de seguridad viven en `Jobs/` y se incluyen con `include:template:`. La forma mínima:

```yaml
include:
  - template: Jobs/SAST.gitlab-ci.yml
  - template: Jobs/Secret-Detection.gitlab-ci.yml
  - template: Jobs/Dependency-Scanning.gitlab-ci.yml
  - template: Jobs/Container-Scanning.gitlab-ci.yml
  - template: Jobs/DAST.gitlab-ci.yml
```

Cada template define uno o más **jobs reales** que corren en runners (consumen minutos). Lo que ganas al usar `include:template:` en lugar de copiar el YAML:

- **Versión gestionada por GitLab**: el template evoluciona con la versión del GitLab server (SaaS: la última; Self-Managed: la de tu release).
- **Variables documentadas**: cada scanner expone variables (`SAST_EXCLUDED_PATHS`, `DS_EXCLUDED_PATHS`, `CS_IMAGE`, …) para configurar sin reescribir el job.
- **Reporte homogéneo**: cada job sube un artifact `gl-*-report.json` que el Security Dashboard consume automáticamente.

> **Trampa habitual**: copiar el YAML del template a tu repo y "customizarlo". Pierdes updates y acabas corriendo un scanner de hace 2 años con CVEs sin cubrir.

### 1.1 Scanners disponibles (y gating por plan)

| Scanner | Qué cubre | Plan mínimo |
|---------|-----------|-------------|
| **SAST** | Code analysis multi-lenguaje (Semgrep, SpotBugs, …) | Free (reporte básico), Ultimate (dashboard) |
| **Secret Detection** | Gitleaks sobre el histórico y el diff | Free |
| **Dependency Scanning (SCA)** | CVEs en manifests (`package.json`, `requirements.txt`, `pom.xml`, …) | Free (reporte), Ultimate (fix MRs) |
| **Container Scanning** | Trivy sobre la imagen construida | Free (reporte), Ultimate (dashboard) |
| **DAST** | Scan dinámico (ZAP) contra una URL desplegada | Ultimate |
| **IaC Scanning** | Checkov/kics sobre Terraform/K8s/CFN | Free |
| **License Scanning (License Compliance)** | Licencias de deps | Ultimate |
| **Fuzz Testing** | Coverage-guided fuzz | Ultimate |

**Regla de bolsillo**: si el plan es Free, cuentas con SAST + Secret Detection + Dependency Scanning + IaC Scanning + Container Scanning (los *reportes* existen; el **Security Dashboard** completo requiere Ultimate).

### 1.2 Estructura típica del `.gitlab-ci.yml` con scanners

```yaml
stages: [build, test, deploy]

include:
  - template: Jobs/SAST.gitlab-ci.yml
  - template: Jobs/Secret-Detection.gitlab-ci.yml
  - template: Jobs/Dependency-Scanning.gitlab-ci.yml
  - template: Jobs/Container-Scanning.gitlab-ci.yml

variables:
  SECURE_LOG_LEVEL: "info"
  SAST_EXCLUDED_PATHS: "spec,test,tests,tmp,vendor/ruby,.venv"
```

Los jobs del template se adhieren al stage `test` por defecto. Si tu `stages:` no incluye `test`, el pipeline falla con *"stage not configured"*.

---

## 2. Security Dashboard y vulnerability report

El **Security Dashboard** vive en `Secure → Vulnerability report` del project (y agregado a nivel Group/Instance en Ultimate). Cada job de scanner publica un artifact con `reports:` (por ejemplo `reports: sast: gl-sast-report.json`). GitLab consume el JSON, normaliza y persiste cada finding con:

- **Severity** (Critical / High / Medium / Low / Info).
- **Confidence** (Confirmed / High / Medium / Low).
- **Identifier** (CVE, CWE, OWASP, scanner-specific).
- **Status**: `Detected`, `Confirmed`, `Dismissed`, `Resolved`.

Triage habitual:

- **Confirm** una vulnerabilidad real → crea un issue linkeado para fix.
- **Dismiss** un falso positivo → requiere justificación textual (queda en el audit log).
- **Resolve** cuando el fix está en main → el próximo scan la cierra automáticamente si ya no la detecta.

> **Idea clave**: el reporte es *idempotente*: si un commit nuevo ya no incluye la vulnerabilidad, el estado pasa a *Resolved* automáticamente. No lo gestionas a mano.

---

## 3. Merge Request security widget

En cada MR aparece un **widget de seguridad** con dos vistas:

- **Nuevas vulnerabilidades introducidas por la MR** (diff contra la target branch).
- **Vulnerabilidades existentes en la target branch** (contexto).

Con `rules:` y la variable `AST_ENABLE_MR_PIPELINES: "true"` (o configuración de `MR Pipelines`), los scanners corren tanto en el pipeline de branch como en el de MR, de modo que el diff es exacto.

**Bloqueo de merges por severidad** (Ultimate): se configura en `Settings → Merge requests → Merge checks → "Require approval if ... high or critical vulnerabilities introduced"`. En Free/Premium se bloquea con `rules: if: ... when: manual` o con un job de gating custom que lee `gl-sast-report.json` y falla si hay severidad >= High.

---

## 4. Container Registry nativo

Cada project trae un **Container Registry** gratuito en `registry.gitlab.com/<group>/<project>` (SaaS) o `registry.<tu-dominio>/<group>/<project>` (Self-Managed). Autenticación desde pipeline con dos variables **predefinidas**:

- `$CI_REGISTRY` — host del registry.
- `$CI_REGISTRY_USER` / `$CI_REGISTRY_PASSWORD` — credenciales efímeras del job (válidas solo durante el job).
- `$CI_REGISTRY_IMAGE` — path completo `host/group/project`.

Patrón mínimo de push (con **Kaniko** para evitar DinD):

```yaml
build:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:v1.21.0-debug
    entrypoint: [""]
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$CI_REGISTRY\":{\"username\":\"$CI_REGISTRY_USER\",\"password\":\"$CI_REGISTRY_PASSWORD\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor
        --context "$CI_PROJECT_DIR"
        --dockerfile "$CI_PROJECT_DIR/Dockerfile"
        --destination "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA"
        --destination "$CI_REGISTRY_IMAGE:latest"
```

> **Por qué Kaniko y no DinD**: no requiere `--privileged`, no abre un socket Docker en el runner, y el build es *rootless*. En SaaS runners, DinD obliga a `services: docker:dind` + `DOCKER_TLS_CERTDIR`, y el runner compartido debe soportarlo.

### 4.1 Cleanup policies

En `Settings → Packages and registries → Container Registry → Cleanup policy`:

- **Keep N most recent** tags que matchen un regex (`v\d+\.\d+\.\d+`).
- **Remove tags older than X days** que matchen otro regex (`pr-\d+`).
- **Dry-run** disponible para ver qué borraría antes de aplicar.

Patrón recomendado: `main-*` y `v*` nunca se borran; `pr-*` se borra a los 7 días; `sha-*` a los 30.

### 4.2 Dependency proxy

GitLab ofrece un **Dependency Proxy** para Docker Hub a nivel group:

```yaml
image: ${CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX}/alpine:3.19
```

Convierte `docker.io/alpine:3.19` en un pull-through cache en tu group, evitando el rate limit público de Docker Hub (100 pulls/6h anónimo).

---

## 5. Package Registry

Un project puede alojar packages en formato nativo:

- **npm** (`.npmrc` apuntando a `${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/npm/`),
- **PyPI** (`twine upload --repository-url ${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/pypi`),
- **Maven**, **Gradle**, **NuGet**, **Composer**, **Conan**, **Go** modules, **Helm** charts, **Generic** files.

El token para publicar es un **CI_JOB_TOKEN** (efímero, por job) o un **Deploy Token** (persistente, scoped). Para consumir desde otro project, hay que habilitar `CI_JOB_TOKEN` cross-project en `Settings → CI/CD → Job token permissions`.

---

## 6. SBOM nativo (CycloneDX)

Los scanners de GitLab generan **SBOM en formato CycloneDX 1.4** como artifact adicional. Por ejemplo, `Dependency-Scanning` produce `gl-sbom-*.cdx.json`. El Dashboard de **Dependency List** del project agrega todos los SBOMs y permite buscar "¿qué projects usan `log4j < 2.17`?" a nivel group.

Patrón para extraer el SBOM del artifact y adjuntarlo a una release:

```yaml
publish-sbom:
  stage: deploy
  needs: ["dependency_scanning"]
  script:
    - cp gl-sbom-*.cdx.json release/
  artifacts:
    paths: [release/]
```

---

## 7. SLSA provenance: estado parcial

A fecha de redacción de este módulo, GitLab emite **provenance parcial** para builds nativos (ver `Checklist de verificación requerida en Fase 4` del ROADMAP). Lo que sí es **GA y estable**:

- **Signed commits** y **signed tags** (GPG).
- **Protected tags** + **protected environments** → cadena de autoría trazable.
- **ID Tokens** firmados por GitLab (JWT con `iss: https://gitlab.com`), que son el input de cualquier atestación externa.

Para SLSA Level 2–3 completo se recomienda hoy combinar GitLab + **Sigstore cosign** (firma + atestación transparente en Rekor) + **in-toto attestations** generadas con `cosign attest`. GitLab Ultimate planifica provenance L3 nativa; verificar en Fase 4.

---

## 8. cosign keyless con ID Tokens de GitLab

El patrón moderno de firma **sin claves de larga vida** usa el **ID Token** de GitLab como credencial OIDC para Sigstore. GitLab emite un JWT por job con claims `iss`, `sub`, `aud`, `project_path`, `ref`, `environment` y lo expone al job via `id_tokens:`.

```yaml
sign:
  stage: sign
  image: gcr.io/projectsigstore/cosign:v2.2.3
  id_tokens:
    SIGSTORE_ID_TOKEN:
      aud: sigstore
  script:
    - cosign sign --yes
        --identity-token "$SIGSTORE_ID_TOKEN"
        "$CI_REGISTRY_IMAGE@$IMAGE_DIGEST"
```

Al verificar, se exige una identidad y un issuer concretos:

```yaml
verify:
  stage: verify
  image: gcr.io/projectsigstore/cosign:v2.2.3
  script:
    - cosign verify
        --certificate-identity "https://gitlab.com/$CI_PROJECT_PATH//.gitlab-ci.yml@refs/heads/main"
        --certificate-oidc-issuer "https://gitlab.com"
        "$CI_REGISTRY_IMAGE@$IMAGE_DIGEST"
```

> **Idea clave**: el `--certificate-identity` **pinnea** al path exacto del project y a la ref. Un atacante que forkee el repo y firme en su propio namespace **no** pasa la verificación, aunque obtenga un ID Token válido.

### 8.1 ¿Por qué keyless vale la pena?

- No hay `COSIGN_KEY` que rotar ni leakear (lo peor que puede filtrar el runner es un ID Token caducado en minutos).
- La firma queda registrada en **Rekor** (log transparente) → trazabilidad pública verificable sin GitLab.
- La verificación es *stateless* en consumidores: no necesitan configurar nada propio de GitLab, solo cosign + política.

### 8.2 Attestations (SLSA / in-toto)

Más allá de la firma, se puede adjuntar una **attestation** al artifact:

```yaml
attest:
  stage: sign
  image: gcr.io/projectsigstore/cosign:v2.2.3
  id_tokens:
    SIGSTORE_ID_TOKEN: { aud: sigstore }
  script:
    - cosign attest --yes
        --predicate provenance.json
        --type slsaprovenance
        --identity-token "$SIGSTORE_ID_TOKEN"
        "$CI_REGISTRY_IMAGE@$IMAGE_DIGEST"
```

El `predicate` describe cómo se construyó la imagen (fuente, builder, materiales). Consumidores que apliquen **cosign policy-controller** en Kubernetes pueden rechazar imágenes sin attestation válida.

---

## Resumen operativo

1. `include:template:` para los scanners — nunca copies el YAML.
2. Stage `test` presente, `rules:` para MR y branch.
3. Build con **Kaniko**, push a `$CI_REGISTRY_IMAGE`.
4. **Cleanup policy** para `pr-*` y `sha-*`.
5. Firma con **cosign keyless** + `id_tokens: { aud: sigstore }`.
6. Verifica con `--certificate-identity` pinneado a `project_path` + `ref`.
7. Triagea desde el **Security Dashboard**; bloquea merges por severidad en MR.
