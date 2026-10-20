# sec-08 — Lección: SBOM y SLSA en práctica

> 12 secciones. Mixto: concepto + ejemplos reproducibles con `syft`/`grype`. Prerrequisitos: `sec-01`, `sec-05`.

---

## 1. El problema: *¿qué hay dentro de este artefacto y cómo lo construí?*

Cuando un atacante compromete la supply chain, hay **dos** preguntas que la seguridad clásica no puede responder sin ayuda:

1. **¿Qué hay dentro de este binario / imagen / paquete?** — Lista completa de componentes transitivos, versiones, licencias, hashes. Antes de SBOM, responderla implicaba un `strings` + arqueología + confiar en el `requirements.txt` (que no cubre el OS, no cubre deps transitivas resueltas, y no cubre lo que acabó realmente en la imagen).
2. **¿Cómo se construyó, por quién, a partir de qué fuente?** — Esta máquina, estos commits, estos builders, estas instrucciones. Antes de provenance, la respuesta era *"confía en el CI"*; sin forma de probar que ese artefacto salió de ese pipeline.

**SBOM** responde la primera. **Provenance** responde la segunda. Son **ortogonales**: una no reemplaza a la otra.

> Memorízalo: **SBOM es inventario** (*qué*). **Provenance es historia** (*cómo*). Juntas, cierran el perímetro de supply chain. Por separado, dejan huecos obvios.

Casos reales que motivaron la industria:

- **SolarWinds** (2020) — build system comprometido inyectaba malware en el binario firmado. Un SBOM habría mostrado componentes extraños; **provenance firmada por un builder confiable** habría impedido el ataque de raíz.
- **log4shell** (2021) — ninguna organización podía responder *"¿quién de nosotros corre log4j vulnerable?"* en menos de una semana. SBOM centralizado reduce esa pregunta a una query.
- **xz-utils** (2024) — backdoor insertado por un mantenedor en versiones específicas. SBOM + verificación de provenance habrían al menos acotado el blast radius.
- **tj-actions/changed-files** (2025) — una action popular de GitHub Actions fue secuestrada y modificada para filtrar secretos de los workflows que la usaban. Pinning por commit SHA + attestations de las propias actions son parte de la respuesta.

---

## 2. SBOM — definición operativa

Un **Software Bill of Materials** es una **lista estructurada y legible por máquina** de los componentes que forman un artefacto, con sus versiones, hashes y relaciones.

Un SBOM mínimo contiene, por cada componente:

- **Nombre + versión** (`openssl 3.0.14`).
- **Identificador universal** (`pkg:deb/debian/openssl@3.0.14-1~deb12u2`, un **PURL** — package URL).
- **Hash** del artefacto resuelto (`sha256:...`).
- **Relación con otros componentes** (`openssl` es dependencia de `curl`).
- **Licencia** declarada.
- Opcional pero muy útil: **origen** (upstream URL, repo).

Lo que un SBOM **no** es:

- No es un informe de vulnerabilidades. Un escáner (Grype, Trivy) **consume** el SBOM y lo correlaciona con una base de datos de CVEs.
- No es prueba de autenticidad. Un SBOM sin firma es un documento *reclamado* — se asume honesto. La firma (vía cosign) le añade autenticidad.
- No es prueba de que el artefacto *haga* lo que dice. Para eso están los tests, el fuzzing y la auditoría de código.

---

## 3. CycloneDX vs SPDX — equivalentes funcionales, convenciones distintas

Hoy hay **dos** formatos SBOM dominantes:

| Dimensión | CycloneDX | SPDX |
|-----------|-----------|------|
| **Origen** | OWASP (2017). | Linux Foundation (2010). |
| **Formato nativo** | JSON (más usado), XML, protobuf. | tag-value (`.spdx`), JSON (`.spdx.json`), YAML, RDF. |
| **Enfoque principal** | **CI/CD + supply chain security**. | **License compliance + legal**. |
| **Granularidad de licencia** | Buena pero sencilla. | **Muy fuerte** (SPDX License List es *la* referencia). |
| **Relaciones** | `dependencies`, `components`, `services`. | 20+ relationship types (`DEPENDS_ON`, `DESCRIBES`, `GENERATED_FROM`...). |
| **Soporte en herramientas** | Syft, Trivy, cdxgen, Snyk, Dependency-Track. | Syft, Trivy, SPDX tools, FOSSology, Tern. |
| **Adopción regulatoria** | US EO 14028 acepta ambos. | US EO 14028 acepta ambos. |

**Regla práctica** en pipelines CI:

- Si tu objetivo principal es **detectar CVEs y gestionar supply chain** → **CycloneDX** (menos campos, más directo, mejor integración con Dependency-Track y con la mayoría de scanners).
- Si tu objetivo principal es **compliance de licencias y legal** → **SPDX** (los abogados hablan SPDX).
- Si tu organización necesita ambos → **emítelos los dos**. `syft` los genera en una sola pasada y pesa microsegundos.

> El error #1 es tratarlos como incompatibles. Son isomorfos en ~95% del contenido útil. La elección es sobre todo cultural y de herramienta aguas abajo.

---

## 4. Tres momentos del SBOM: source, build, runtime

Un mismo proyecto puede producir **tres** SBOMs **diferentes**, cada uno útil para preguntas distintas:

### 4.1 Source SBOM

- Generado desde el **repositorio** antes de construir (`syft dir:.`).
- Contiene: lo declarado en manifests (`requirements.txt`, `package-lock.json`, `go.mod`, `pom.xml`, `Pipfile.lock`).
- Útil para: *"¿qué dependencias direct + transitive declara mi proyecto?"*.
- Limitación: no contiene packages del OS base, no contiene lo que acabó realmente en el binario tras `pip install --no-deps` o tras poda del linker.

### 4.2 Build SBOM

- Generado desde la **imagen final / artefacto final** (`syft <image-ref>`).
- Contiene: todo lo que **efectivamente está** en la imagen — OS packages (debian/alpine/distroless), lenguaje packages instalados, binarios estáticos detectables, licencias.
- Útil para: *"¿qué CVEs tiene MI imagen desplegable?"* y *"¿qué licencias viajan con mi binario?"*.
- Es el SBOM más valioso para scanners (Grype/Trivy): escanean lo que de verdad vas a desplegar.

### 4.3 Runtime SBOM

- Generado desde un **proceso en ejecución** (menos común, requiere agentes tipo *dynamic SCA* o eBPF-based).
- Contiene: solo lo que el proceso **cargó realmente** (libs cargadas, módulos linkeados en runtime, código JIT-compilado).
- Útil para: *"de los 300 packages instalados en la imagen, ¿cuáles ejecuta mi app?"* (reduce blast radius de CVEs — una lib instalada pero nunca cargada tiene superficie de ataque ≈ 0).
- Herramientas tempranas: **Rapid7 InsightVM**, **Edera**, **Oligo**, **Red Hat Advanced Cluster Security** (reachability).

**Regla práctica**: para un pipeline estándar, emite **source + build**. Runtime es optimización para equipos de seguridad maduros con muchos CVEs y necesidad de priorización fina.

---

## 5. Syft — la herramienta canónica

**Syft** (Anchore, OSS, en Go) es hoy el generador de SBOM más usado en pipelines CI junto con **Trivy** (que también lo hace, con sintaxis distinta).

Comandos clave:

```bash
# Source SBOM desde el repo actual (CycloneDX JSON).
syft dir:. -o cyclonedx-json=sbom-source.cdx.json

# Mismo contenido en SPDX JSON (para compliance).
syft dir:. -o spdx-json=sbom-source.spdx.json

# Build SBOM desde una imagen local.
syft my-image:latest -o cyclonedx-json=sbom-build.cdx.json

# Build SBOM desde una imagen en registry (sin pull manual).
syft registry:ghcr.io/org/app:v1.2.3 -o cyclonedx-json=sbom.cdx.json

# Formato human-readable para inspección rápida.
syft my-image:latest -o table
```

Puntos finos:

- **Catálogos**: Syft identifica packages por **catalogadores** por ecosistema (apt, apk, python, javascript, go-module, ruby-gem, rust-cargo, java-archive, ...). Puedes limitar con `--scope all-layers` vs `--scope squashed`.
- **Catalog squashed vs all-layers**: *squashed* ve la imagen final (lo que corre). *all-layers* ve también lo que estuvo en layers intermedias (útil si quieres detectar que una herramienta de build *estuvo* presente aunque ya no esté).
- **PURL** (`pkg:pypi/requests@2.31.0`): identificador canónico que Grype y el ecosistema CVE entienden. Sin PURL, correlacionar con una base de CVEs es frágil.
- **Multi-arch**: para imágenes multi-arch, Syft escanea una plataforma por invocación. Especifica `--platform linux/arm64` si no es la del host.

---

## 6. Grype — consumidor del SBOM

**Grype** (también Anchore) toma un SBOM o una imagen y produce un **vulnerability report**. Es el consumidor natural del output de Syft.

```bash
# Escaneo directo de imagen (grype hace su propio SBOM internamente).
grype my-image:latest

# Escaneo del SBOM ya emitido (más rápido, reproducible, ideal en CI).
grype sbom:sbom-build.cdx.json -o json > vulns.json

# Fallar si hay vulns de severidad HIGH o superior.
grype my-image:latest --fail-on high

# Ignorar CVEs específicos con razón documentada (`.grype.yaml`).
grype my-image:latest --config .grype.yaml
```

**Por qué escanear el SBOM en vez de la imagen** en CI:

- Determinismo: el SBOM es inmutable. Si re-escaneas la misma imagen mañana, Grype encontrará **más** CVEs porque la DB se actualizó — eso está bien. Pero escanear el SBOM te garantiza que **estás escaneando exactamente los mismos componentes**, no una versión actualizada del registry.
- Velocidad: parsear JSON es más rápido que redescargar y re-catalogar la imagen.
- Separación de responsabilidades: *generar* SBOM es trabajo del build. *Encontrar CVEs* es trabajo del scanner. El SBOM es el contrato.

**Comparación con Trivy** (`sec-05`): Trivy también escanea imágenes y genera SBOMs. En la práctica muchos equipos usan Trivy para *scan* y Syft para *SBOM generation* porque los catálogos de Syft tienden a ser un poco más completos; otros equipos usan solo Trivy por simplicidad. Ambas son defendibles.

---

## 7. SLSA v1.0 — el marco

**SLSA** (Supply chain Levels for Software Artifacts, pron. *"salsa"*) es un marco de la **OpenSSF** (Linux Foundation) que define **niveles crecientes** de garantías de supply chain. v1.0 salió en 2023 tras una reorganización profunda del draft previo.

v1.0 tiene dos **tracks** declarados: *Build* (ya publicado) y *Source* (todavía en diseño). El curso cubre el **Build track**.

### 7.1 Niveles Build

| Nivel | Garantía | Implica |
|-------|----------|---------|
| **L0** | Ninguna. | No hay build script versionado; builds ad-hoc en workstations. |
| **L1** | **Build script existe y produce provenance** (aunque sea manual). | Hay un `Dockerfile`, un `Makefile`, un workflow — algo versionado. La *provenance* puede ser auto-reportada. |
| **L2** | **Hosted builder** (CI gestionado) genera provenance **firmada automáticamente**. | GitHub Actions, GitLab CI, Google Cloud Build, Buildkite hosted — el builder atestigua el build. Nadie puede falsificar provenance *haciéndose pasar por el builder*. |
| **L3** | **Non-forgeable + builder isolation**: el builder garantiza que la provenance **no puede ser modificada ni por el propio workflow**. Las credenciales efímeras no son accesibles al código del build. | GitHub Actions con `actions/attest-build-provenance` cumple L3 porque el token OIDC + Sigstore + Rekor hacen la provenance a prueba de modificación. |
| **L4** | **Reservado para el futuro**: *two-party review*, *builds herméticos y reproducibles end-to-end*. Pocos sistemas lo implementan hoy. | Un cambio de código requiere revisión por un segundo humano; el build no accede a internet; dos máquinas distintas producen el mismo artefacto bit-a-bit. |

### 7.2 Cada nivel ataca una clase distinta de atacante

- **L1** elimina al atacante que dice *"se construyó mágicamente"*. Ya hay un script.
- **L2** elimina al atacante que **falsifica provenance** desde su laptop. La provenance la emite un servicio confiable.
- **L3** elimina al atacante que **compromete el workflow** y modifica la provenance para ocultar su cambio. La provenance se emite **fuera** del alcance del build.
- **L4** (futuro) elimina al atacante que **compromete un reviewer único** o inyecta cambios no reproducibles.

Mensaje clave: **subir de nivel SLSA es más caro cada escalón**, pero **cada escalón elimina una clase entera de amenazas**. L0→L1 es casi gratis. L2→L3 requiere infraestructura (hosted CI + OIDC + Sigstore). L3→L4 requiere disciplina organizacional (two-party review universal, builds reproducibles).

---

## 8. Provenance — el documento

Una **provenance** SLSA v1.0 es un documento JSON que responde:

- **Qué** se construyó (`subject` — hash sha256 del artefacto).
- **Quién** lo construyó (`builder.id` — identidad del runner).
- **A partir de qué** (`buildDefinition.resolvedDependencies` — commit SHA del source, inputs del build).
- **Con qué instrucciones** (`buildDefinition.buildType` — p. ej. `https://actions.github.io/buildtypes/workflow/v1`).
- **Cuándo** (`runDetails.metadata.startedOn`, `finishedOn`).

Ejemplo esqueleto (abreviado):

```json
{
  "_type": "https://in-toto.io/Statement/v1",
  "subject": [{
    "name": "ghcr.io/org/app",
    "digest": {"sha256": "abc123..."}
  }],
  "predicateType": "https://slsa.dev/provenance/v1",
  "predicate": {
    "buildDefinition": {
      "buildType": "https://actions.github.io/buildtypes/workflow/v1",
      "externalParameters": {
        "workflow": {
          "ref": "refs/heads/main",
          "repository": "https://github.com/org/repo",
          "path": ".github/workflows/release.yml"
        }
      },
      "resolvedDependencies": [{
        "uri": "git+https://github.com/org/repo@refs/heads/main",
        "digest": {"gitCommit": "deadbeef..."}
      }]
    },
    "runDetails": {
      "builder": {
        "id": "https://github.com/actions/runner/github-hosted"
      },
      "metadata": {
        "invocationId": "https://github.com/org/repo/actions/runs/12345/attempts/1"
      }
    }
  }
}
```

Nota importante: la provenance **sin firma** vale lo que vale un `README.md` cualquiera. La **firma vía Sigstore keyless** + el **transparency log en Rekor** es lo que la convierte en non-forgeable (y por tanto apta para L3).

---

## 9. GitHub Actions como builder L3-capable

GitHub proporciona dos piezas que, combinadas, hacen a GHA un builder SLSA L3:

### 9.1 `actions/attest-build-provenance`

Action oficial (GA en 2024). Toma el *subject-digest* (el hash de la imagen o artefacto que acabas de construir) y:

1. Obtiene un **OIDC token** del runner con claims `repo:org/repo:ref:refs/heads/main` + `job_workflow_ref` + `runner_environment`.
2. Lo intercambia con **Fulcio** por un **certificado efímero** (vive minutos).
3. Firma la provenance con la clave privada efímera (que nunca sale del runner).
4. Publica la firma + el certificado en **Rekor** (transparency log público e inmutable).
5. Adjunta la attestation a la imagen OCI (si es imagen) o al release (si es artefacto).

Esqueleto típico:

```yaml
jobs:
  build:
    permissions:
      id-token: write        # OIDC
      attestations: write    # emitir attestation
      contents: read
      packages: write        # push a GHCR
    steps:
      - uses: actions/checkout@v4
      - name: Build and push
        id: push
        uses: docker/build-push-action@v6
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
      - name: Attest
        uses: actions/attest-build-provenance@v2
        with:
          subject-name: ghcr.io/${{ github.repository }}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true
```

### 9.2 `actions/attest-sbom` (opcional, complementario)

Misma mecánica pero el *predicate* es un SBOM (CycloneDX o SPDX) en vez de provenance. Resultado: la imagen tiene **dos** attestations adjuntas: *qué contiene* (SBOM) y *cómo se construyó* (provenance).

### 9.3 Por qué esto es L3

- **Hosted builder** (runner de GitHub) — ✓ L2.
- **El workflow no puede manipular el OIDC token** después de que `attest-build-provenance` lo use (la step tiene acceso efímero, no persiste). ✓ Non-forgeable.
- **Builder isolation**: el runner es un entorno descartable por job; el estado no persiste entre jobs. ✓ Isolation.
- **Rekor**: la firma queda en un log público — cualquier modificación posterior sería detectable. ✓ Non-forgeable fuerte.

**Caveat** del L3 "GHA out-of-the-box": si usas **self-hosted runners** sin el aislamiento adecuado, pierdes L3. Para capstones y proyectos personales, el runner hosted alcanza; para producción, revisa `SLSA Hosted vs Self-hosted` en la doc oficial.

---

## 10. Verificación — la mitad olvidada

Un error común: *"ya firmamos y emitimos SBOM + provenance; estamos protegidos."* **No**. La firma sin verificación **no vale nada**. Un atacante puede publicar su propia imagen con su propia provenance firmada con su propia identidad y pretender que es la tuya si no verificas el *identity binding*.

### 10.1 Verificar provenance con `gh attestation verify`

```bash
# Verificación de alto nivel vía gh CLI (identity-aware por defecto).
gh attestation verify oci://ghcr.io/org/app@sha256:abc123... \
  --repo org/repo
```

### 10.2 Verificar con `cosign verify-attestation`

```bash
cosign verify-attestation \
  --type slsaprovenance1 \
  --certificate-identity-regexp '^https://github\.com/org/repo/\.github/workflows/release\.yml@refs/heads/main$' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/org/app@sha256:abc123...
```

Puntos a NO olvidar:

1. **Siempre** pasar `--certificate-identity` (o `--certificate-identity-regexp`) **y** `--certificate-oidc-issuer`. Sin esto, aceptas provenance firmada por cualquiera.
2. **Pin por digest** (`@sha256:...`), no por tag. Los tags son mutables.
3. **Para L3 fuerte**: pin además al **workflow concreto** y a la **ref** (`refs/heads/main` o `refs/tags/v*`). Esto previene que un workflow comprometido en una branch random genere provenance "válida".
4. La verificación debe ocurrir **antes** del despliegue — en admisión K8s (`sec-11`) o en el deploy step del propio CD.

### 10.3 Verificar SBOM

Si el SBOM está adjunto como attestation (`cosign attest --type cyclonedx`), se verifica igual que una provenance pero con `--type cyclonedx`:

```bash
cosign verify-attestation \
  --type cyclonedx \
  --certificate-identity-regexp ... \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/org/app@sha256:abc123... | jq -r .payload | base64 -d | jq .
```

---

## 11. Patrones de publicación

Tres patrones habituales:

### 11.1 Artefactos del build (CI artifacts)

- `sbom.cdx.json` + `provenance.intoto.jsonl` subidos como artifact del workflow.
- **Pro**: fácil, no requiere OCI.
- **Contra**: desacoplado del artefacto que describe. Si alguien pulls la imagen del registry, no ve el SBOM.

### 11.2 Attestations adjuntas a la imagen OCI (recomendado)

- `cosign attest` o `actions/attest-*` publica las attestations **junto a la imagen** en el registry.
- **Pro**: productor y consumidor hablan el mismo lenguaje OCI. `cosign verify-attestation <image>` encuentra todo.
- **Contra**: requiere un registry que soporte OCI 1.1 referrers (ghcr.io sí; algunos registries antiguos no).

### 11.3 Store centralizado (Dependency-Track, GUAC)

- SBOMs se envían a un **store** (Dependency-Track, GUAC) para queries agregadas: *"¿quién corre log4j 2.14?"*.
- **Pro**: inventario central, queries SQL/GraphQL, alertas al llegar un nuevo CVE.
- **Contra**: requiere operar la plataforma. Es el patrón `sec-14`.

**Regla práctica**: haz los **tres**. Son complementarios. El OCI attachment resuelve verificación en admisión; el store centralizado resuelve inventario; los artifacts del CI son el fallback.

---

## 12. Qué llevarse y qué sigue

Al terminar este módulo deberías poder:

- Explicar en 60 segundos **qué** responde un SBOM y **qué** responde una provenance SLSA — sin confundirlos.
- Enumerar los **4 niveles SLSA v1.0** y qué clase de atacante elimina cada uno.
- Emitir un SBOM CycloneDX **y** SPDX con `syft` sobre una imagen local.
- Consumir ese SBOM con `grype` para producir un vulnerability report.
- Leer un workflow `actions/attest-build-provenance` y saber qué garantiza (y qué no).
- Verificar una attestation con `--certificate-identity` + `--certificate-oidc-issuer` y detectar una verificación insegura (sin esos flags).

Lo que **sigue**:

- `sec-09` — firma de artefactos **a fondo** con cosign + Sigstore keyless (Fulcio, Rekor); `cosign attest` sobre arbitrary predicates; verificación con *identity pin*.
- `sec-10` → `sec-11` — Policy as Code y admisión K8s que **verifica** firma + attestation antes de admitir Pods.
- `sec-14` — SBOM inventory centralizado + vuln management lifecycle como plataforma.

Síntesis final en una frase:

> **SBOM dice qué hay dentro; provenance dice cómo entró; firma dice quién lo asegura; verificación es lo que convierte todo lo anterior en una garantía real.**
