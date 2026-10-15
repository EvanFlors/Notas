# Lección: Supply chain para imágenes OCI — SBOM, firma y provenance

> **ID:** `dkr-14-supply-chain-sbom-signing-provenance` · **Nivel:** producción · **Duración:** 5 h
> **Prerrequisitos:** `dkr-09`, `dkr-13`, puente conceptual con `gha-14`.

---

## 1. Introducción intuitiva

Cuando un cliente consume una imagen OCI que publicaste —`docker pull registry.example.com/acme/billing@sha256:abcd...`— está descargando bytes construidos por un pipeline que no vio correr, a partir de un árbol de código que puede o no coincidir con el repo público, usando dependencias que pudieron haber cambiado desde el último `pip install`. La pregunta operativa, idéntica a la de cualquier cadena de suministro física, es: **¿qué puede afirmar sobre esos bytes antes de ejecutarlos?**

La respuesta se construye por capas:

- **"Sé qué hay dentro"** → genera un **SBOM** (Software Bill of Materials): inventario firmado de componentes, versiones, licencias y hashes.
- **"Sé que no tiene CVEs críticas conocidas"** → escanea con **Trivy** o **Grype** y corta el release si hay severidad alta.
- **"Sé que la imagen no fue modificada desde que la publiqué"** → **firma** con cosign; el digest OCI es content-addressed, la firma lo autentica.
- **"Sé con qué código y qué pipeline se construyó"** → **attestation** de SLSA Provenance firmada por el builder.
- **"Sé que el SBOM corresponde a esta imagen y no a otra"** → **attestation de SBOM** anclada al mismo digest.

Esta lección trabaja la cadena desde el ángulo *Docker*: el artefacto es una imagen OCI, las herramientas corren sobre capas, el registry (local o remoto) es quien almacena firma y attestations. El módulo hermano `gha-14` cubre la misma lógica desde el ángulo *workflow de CI*; ambos son complementarios y conviene cursarlos juntos.

---

## 2. Fundamentos y herramientas

### 2.1 Qué instala cada herramienta

| Herramienta | Qué hace | Instalación rápida |
|-------------|----------|--------------------|
| `docker` | motor y CLI | ver `dkr-02` |
| `syft` | genera SBOM desde imagen, directorio o archivo | `brew install syft` · `curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \| sh -s -- -b /usr/local/bin` |
| `trivy` | escanea vulnerabilidades y misconfig | `brew install trivy` · `curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \| sh -s -- -b /usr/local/bin` |
| `grype` | scanner alternativo (consume SBOM) | `brew install grype` · `curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh \| sh -s -- -b /usr/local/bin` |
| `cosign` | firma, atesta, verifica | `brew install cosign` · `go install github.com/sigstore/cosign/v2/cmd/cosign@latest` |
| `registry:2` | registry OCI local | `docker run -d --rm -p 5000:5000 --name registry registry:2` |

**Si alguna no está instalada, los scripts del módulo detectan y saltan la comprobación runtime, pero los validators siguen verificando los artefactos estructurales** (Dockerfile, workflow YAML, formato de SBOM, presencia de firma).

### 2.2 Las cuatro piezas y qué afirma cada una

| Pieza | Formato típico | Qué afirma | Cómo se verifica |
|-------|----------------|------------|------------------|
| **SBOM** | CycloneDX JSON / SPDX JSON | "esta imagen contiene estos N paquetes con estas versiones y hashes" | parseo + comparación con listas de CVE |
| **Scan report** | SARIF, JSON Trivy | "en esta imagen hay / no hay vulnerabilidades de severidad X" | gate en CI por `--exit-code 1` |
| **Firma** | binario DSSE firmado + cert X.509 | "el digest D de la imagen no cambió desde que fue firmado por la identidad Y" | `cosign verify` |
| **Attestation** | in-toto Statement firmado (DSSE) | "la identidad Y afirma el predicate P (SLSA Provenance, SBOM, VEX…) sobre el digest D" | `cosign verify-attestation` |

Las cuatro son **ortogonales**. Un release serio emite las cuatro. Una imagen con SBOM pero sin firma no demuestra que el SBOM corresponda a ella. Una imagen firmada pero sin attestation no demuestra con qué código se construyó. Un scan report sin SBOM es poco auditable (no sabes qué escaneó).

### 2.3 Las dos modalidades de cosign

**Keyless (OIDC, Sigstore)**: la clave de firma es efímera (par nuevo por operación, destruido en segundos). La identidad del firmante se demuestra con un **token OIDC** emitido por un IdP (en GHA: GitHub mismo). Una CA llamada **Fulcio** entrega un certificado X.509 de 10 min con los claims OIDC como `Subject Alternative Name`. La firma se publica en **Rekor** (log append-only público). Ideal para CI, pero requiere internet y un IdP compatible.

**Key pair local**: `cosign generate-key-pair` produce `cosign.key` + `cosign.pub`. Firmas con `--key cosign.key`, verificas con `--key cosign.pub`. Útil para demos locales, registries air-gapped y bootstraps donde no hay IdP. Se **debe** combinar con `--tlog-upload=false` (y en verify `--insecure-ignore-tlog`) si no quieres que la firma intente subirse a Rekor público.

Toda esta lección usa **key pair local** para `MODE=local` y **keyless OIDC** para `MODE=live` (vía GHA).

---

## 3. Contexto histórico

| Año | Hito |
|-----|------|
| 2015 | Linux Foundation inicia **SPDX** como formato SBOM. |
| 2017 | OWASP publica **CycloneDX** v1.0, orientado a security. |
| 2018 | Anchore libera **syft** y **grype**. |
| 2019 | Aqua Security libera **Trivy**. |
| 2020 | **SolarWinds**: ataque a la build chain, el tema entra al mainstream. |
| 2021 | Google + LF publican **SLSA v0.1** y **sigstore/cosign** v1.0. Executive Order 14028 (US) obliga a SBOM. |
| 2022 | `cosign attest` + `cosign verify-attestation` estables. Trivy añade misconfig scanner (ex-`tfsec`). |
| 2023 | **SLSA v1.0** estable. `cosign` v2 (breaking: argumentos `--key` explícitos, `--yes` obligatorio para keyless). |
| 2024 | GitHub artifact attestations GA. OCI 1.1 referrers API extendida en todos los registries mayores. Chainguard images con firma y SBOM nativos. |
| 2025 | Kyverno, OPA Gatekeeper y sigstore policy-controller consumen attestations en admission control; EU CRA aprobado. |

Lo relevante: **la tooling cambia rápido**. Pinnear versiones (incluidas las de `syft`, `trivy` y `cosign` en CI).

---

## 4. Funcionamiento interno

### 4.1 Qué hace `syft` sobre una imagen

```
┌─────────────────────────────────────────────────────────────┐
│  syft registry.example.com/app@sha256:abcd...               │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ 1. Resuelve el image index → image manifest por plataforma  │
│ 2. Descarga config JSON + capas (si no están cacheadas)     │
│ 3. Monta las capas en overlayfs virtual (en memoria)        │
│ 4. Corre catalogadores por ecosistema sobre el merged FS:   │
│      apk-db-cataloger        → /lib/apk/db/installed        │
│      dpkg-db-cataloger       → /var/lib/dpkg/status         │
│      rpm-db-cataloger        → /var/lib/rpm/...             │
│      python-package-cataloger→ *.dist-info/METADATA         │
│      binary-cataloger        → ELF/Mach-O headers           │
│      ...                                                    │
│ 5. Produce documento CycloneDX / SPDX con:                  │
│      - metadata (image digest, timestamp, syft version)     │
│      - componentes (purl, name, version, licenses, hashes)  │
│      - relationships (A depends_on B)                       │
└─────────────────────────────────────────────────────────────┘
```

El SBOM resultante está **anclado al digest** de la imagen (lo lleva en metadata). Si la imagen cambia, el digest cambia, y el SBOM antiguo deja de aplicar.

### 4.2 Trivy: scan + gate

```
┌────────────────────────────────────────────────────────────┐
│  trivy image --severity CRITICAL --exit-code 1 app:v1      │
└────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────┐
│ 1. Analiza la imagen (reutiliza catalogadores propios)     │
│ 2. Cruza componentes contra DB de vulnerabilidades:        │
│      - NVD, GHSA, GitLab, Red Hat, Debian, Ubuntu, Alpine  │
│ 3. Filtra por severidad                                    │
│ 4. Emite report (tabla/JSON/SARIF) + exit code 0 o 1       │
│    exit 1 → el step de CI falla → gate                     │
└────────────────────────────────────────────────────────────┘
```

Flags clave:

- `--severity CRITICAL,HIGH` — qué cuenta como falla.
- `--exit-code 1` — el gate (sin esto, trivy siempre sale 0).
- `--ignore-unfixed` — ignora CVEs sin parche disponible (útil para no bloquear por ruido inarreglable).
- `--format sarif --output trivy.sarif` — para subir al GitHub Security tab.
- `--vuln-type os,library` — qué cataloga.
- `--scanners vuln,secret,misconfig` — qué tipos de hallazgo.

### 4.3 Flujo cosign keyless (Sigstore)

```
┌─────────────────────────────────────────────────────────────────┐
│ Runner GHA (release.yml)                                        │
│                                                                 │
│  1. Solicita OIDC token a GitHub                                │
│     POST ACTIONS_ID_TOKEN_REQUEST_URL?audience=sigstore         │
│     ← JWT con claims {sub, repository, workflow_ref, ref, sha}  │
│                                                                 │
│  2. Genera par de claves efímero (ECDSA P-256)                  │
│                                                                 │
│  3. Pide certificado a Fulcio (fulcio.sigstore.dev)             │
│     POST /api/v2/signingCert  { pubkey, OIDC JWT }              │
│     ← X.509 cert 10 min; SAN = URI con claims                   │
│                                                                 │
│  4. Firma el digest de la imagen con la privada efímera         │
│                                                                 │
│  5. Sube firma+cert a Rekor (rekor.sigstore.dev)                │
│     ← inclusion proof (índice en el log)                        │
│                                                                 │
│  6. Sube firma al REGISTRY como artefacto OCI relacionado       │
│     ghcr.io/owner/app:sha256-<digest>.sig                       │
│     (o referrer OCI 1.1)                                        │
│                                                                 │
│  7. Destruye la privada efímera. Fin.                           │
└─────────────────────────────────────────────────────────────────┘
```

### 4.4 Dónde se guarda la firma en el registry

cosign puede usar dos convenciones:

**A) Legacy tag convention** (default para compatibilidad con registries antiguos):

```
registry/app:v1.0.0                        ← imagen (digest sha256:abcd...)
registry/app:sha256-abcd...sig             ← firma (tag derivado del digest)
registry/app:sha256-abcd...att             ← attestations
registry/app:sha256-abcd...sbom            ← SBOM si se usó cosign attach sbom
```

**B) OCI 1.1 referrers API** (moderno, soportado por GHCR, ECR, GAR, Harbor recientes):

```
registry/app@sha256:abcd...                ← imagen
  ↑ referrers:
    - { artifactType: application/vnd.dev.sigstore.bundle.v0.3+json, ... }   ← firma
    - { artifactType: application/vnd.in-toto+json, ... }                     ← attestation provenance
    - { artifactType: application/vnd.in-toto+json, ... }                     ← attestation sbom
```

Para la práctica: `cosign sign`, `cosign attest`, `cosign verify` abstraen ambas. Si usas `registry:2` local (compatible OCI 1.1 desde v2.8), funciona la vía moderna. Si usas un registry viejo, cosign automáticamente cae al tag convention.

### 4.5 cosign sign vs cosign attest

```
cosign sign IMG                         → firma el DIGEST (sin predicate)
cosign attest IMG --predicate X.json \  → firma un predicate TIPADO sobre el digest
  --type slsaprovenance
```

Diferencia:

- `sign` dice "este digest no cambió desde que lo firmé".
- `attest` dice "este digest tiene la propiedad P según el predicate adjunto, y lo afirmo yo".

**Siempre ambos**. `sign` es la base; `attest` añade semántica (provenance, SBOM, VEX, pentest-report, …).

### 4.6 SLSA: qué le toca al builder, qué al consumidor

**SLSA v1.0** define *tracks* L1–L3+ según garantías del build:

| Nivel | Qué garantiza | Quién lo prueba |
|-------|---------------|-----------------|
| L1 | Existe build provenance declarativa | Builder (CI) la emite |
| L2 | Provenance firmada por el build service | Builder firma; consumidor verifica cert |
| L3 | Build hermético, aislado, imposible manipular desde el pipeline | Requiere infra dedicada (reusable workflows SLSA, hosted larger runners) |

Un pipeline GHA típico con `actions/attest-build-provenance` emite **L2**. Para L3 hace falta usar los *reusable workflows* del `slsa-framework/slsa-github-generator` (fuera del scope de este módulo).

**Responsabilidad del builder (CI/productor):**
- Emitir provenance correcta y completa.
- Firmar con identidad verificable.
- Publicar firma + attestations al mismo registry que la imagen.
- Documentar la identidad esperada para el consumidor.

**Responsabilidad del consumidor:**
- Verificar la firma contra la **identidad regex esperada** (no `.*`).
- Verificar la attestation de provenance (coincide repo, workflow, ref).
- Decidir qué hacer si Rekor no responde (fail-closed vs degraded).
- No fiarse solo de la tag mutable: verificar por digest.

### 4.7 Policy enforcement (introducción)

En producción la verificación no la hace una persona corriendo `cosign verify`; la hace un **admission controller** antes de permitir que el pod corra:

- **sigstore policy-controller** (Kubernetes) — CRD `ClusterImagePolicy` con la identidad esperada.
- **Kyverno** — regla `verifyImages` con `attestors` (keyless identity, keys).
- **OPA / Gatekeeper** — Rego policy que consulta Rekor y valida.

Las tres son profundizadas en D8 (Kubernetes) y D9 (DevSecOps). Aquí basta con reconocer la arquitectura:

```
kubectl apply pod.yaml
      │
      ▼
┌─────────────────────────────────────────┐
│ API server                              │
│   ValidatingAdmissionWebhook            │
│   → policy-controller / kyverno         │
│       cosign verify <image>             │
│       cosign verify-attestation <image> │
│       si FAIL → rechaza el pod          │
└─────────────────────────────────────────┘
```

---

## 5. Ejemplo mínimo (end-to-end, MODE=local)

```bash
# 0) Setup: registry local
docker run -d --rm --name reg -p 5000:5000 registry:2

# 1) Build + push
cat > /tmp/Dockerfile <<'EOF'
FROM alpine:3.19
RUN apk add --no-cache ca-certificates
CMD ["echo", "hello"]
EOF
docker build -t localhost:5000/app:v1 /tmp
docker push localhost:5000/app:v1

# 2) Digest
DIGEST=$(docker inspect localhost:5000/app:v1 --format='{{index .RepoDigests 0}}' | awk -F@ '{print $2}')
IMG="localhost:5000/app@${DIGEST}"

# 3) SBOM
syft -o cyclonedx-json=/tmp/sbom.cdx.json "$IMG"

# 4) Scan + gate
trivy image --severity CRITICAL --exit-code 1 "$IMG"   # falla si hay CRITICAL

# 5) Key pair local
mkdir -p /tmp/keys && cd /tmp/keys
export COSIGN_PASSWORD=''
cosign generate-key-pair

# 6) Sign
cosign sign --key /tmp/keys/cosign.key --tlog-upload=false --yes "$IMG"

# 7) Attest SLSA provenance
cat > /tmp/provenance.json <<EOF
{
  "buildType": "https://example.com/local-demo/v1",
  "builder": {"id": "https://example.com/local-demo"},
  "invocation": {"configSource": {"uri": "git+file:///tmp"}}
}
EOF
cosign attest --key /tmp/keys/cosign.key --tlog-upload=false --yes \
  --predicate /tmp/provenance.json --type slsaprovenance "$IMG"

# 8) Attest SBOM
cosign attest --key /tmp/keys/cosign.key --tlog-upload=false --yes \
  --predicate /tmp/sbom.cdx.json --type cyclonedx "$IMG"

# 9) Verify (lo que un consumidor haría desde otra máquina)
cosign verify --key /tmp/keys/cosign.pub --insecure-ignore-tlog "$IMG"
cosign verify-attestation --key /tmp/keys/cosign.pub --insecure-ignore-tlog \
  --type slsaprovenance "$IMG"
cosign verify-attestation --key /tmp/keys/cosign.pub --insecure-ignore-tlog \
  --type cyclonedx "$IMG"
```

Para `MODE=live` cambia pasos 5–8 por `cosign sign --yes IMG` (keyless, abre browser para OIDC si corres local; usa el token del runner si corres en GHA).

---

## 6. Implementación progresiva

Orden sugerido para construir confianza:

1. **SBOM local**: `syft dir:.` sobre un repo. Léelo. Cuenta cuántas deps directas tiene.
2. **SBOM de imagen**: `syft <IMG>`. Compara con el anterior — no son iguales.
3. **Trivy local**: `trivy image <IMG>`. Observa severidades. Añade `--exit-code 1`.
4. **Firma con key pair**: `generate-key-pair`, `sign`, `verify`. Entiende qué se publica en el registry.
5. **Modifica la imagen**: rebuild, repush, intenta `verify` otra vez. Falla. Entiende por qué.
6. **Attestation provenance**: emite y verifica. Observa que el predicate es tipado.
7. **Attestation SBOM**: adjunta tu `sbom.cdx.json` como predicate.
8. **Modo keyless** (si tienes GHA): workflow que firma + atesta + publica a GHCR.
9. **Consumidor en máquina limpia**: desde `/tmp/`, descarga el *script de verificación* y correlo.

Cada paso puede corromper el anterior; verifica en cada capa.

---

## 7. Aplicación profesional

### 7.1 Pipeline típico de release de imagen

```
┌───────────────────────────────────────────────────────────────────┐
│  GHA release.yml                                                  │
│                                                                   │
│  checkout → build (buildx) → push a GHCR                          │
│    │                                                              │
│    ▼                                                              │
│  syft (SBOM CycloneDX)                                            │
│    │                                                              │
│    ▼                                                              │
│  trivy --severity CRITICAL --exit-code 1   ← GATE                 │
│    │ (si pasa)                                                    │
│    ▼                                                              │
│  cosign sign (keyless OIDC)                                       │
│    │                                                              │
│    ▼                                                              │
│  cosign attest --type slsaprovenance                              │
│    │                                                              │
│    ▼                                                              │
│  cosign attest --type cyclonedx (SBOM)                            │
└───────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                   ┌────────────────────┐
                   │ GHCR               │
                   │  image + sig +     │
                   │  attestations      │
                   │  (como referrers)  │
                   └────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
   ┌───────────┐       ┌────────────┐      ┌────────────┐
   │ dev k8s   │       │ staging    │      │ prod k8s   │
   │ sin policy│       │ warn only  │      │  ENFORCE   │
   └───────────┘       └────────────┘      └─admission──┘
```

### 7.2 Reglas operativas

- **Firma siempre por digest**. `cosign sign ghcr.io/x/app@sha256:abcd...`, no `cosign sign ghcr.io/x/app:v1`. Los tags son mutables.
- **Scan antes de firmar**. Firmar primero es *bendecir* una imagen vulnerable con un sello criptográfico.
- **Identidad regex precisa en verify**: `--certificate-identity-regexp '^https://github\.com/acme/billing/\.github/workflows/release\.yml@refs/tags/v[0-9].*$'`. `--identity-regexp '.*'` convierte la firma en un sello decorativo.
- **Fail-closed en producción**. Si Rekor no responde, decide a priori si abortas o degradas. Decidir en medio del incidente es tarde.
- **Pin de tags de actions a SHA** (ver `gha-13`).
- **No almacenes la privada de cosign en Git**. Si usas key pair, va en KMS (AWS KMS, GCP KMS, Vault). Para dev local, OK en el workspace y no commitear.
- **No montes `docker.sock` en el contenedor del scanner** (ver `dkr-13`): equivale a dar root al host.

### 7.3 Qué garantiza y qué no una attestation

| Garantiza | NO garantiza |
|-----------|--------------|
| Esta imagen la produjo *ese* workflow en *ese* commit | Que el workflow sea seguro |
| El runner era GitHub-hosted (o self-hosted documentado) | Que el código fuente sea seguro |
| Momento exacto (timestamp Rekor) | Que no haya payload malicioso en el binario |
| Los bytes no cambiaron desde la firma | Que las dependencias del SBOM estén limpias |

Las attestations son **parte** del modelo de confianza, no lo reemplazan. Review de código, auditoría de deps, scanning, SCA, SAST siguen siendo necesarios.

---

## 8. Trade-offs

| Decisión | A favor | En contra |
|----------|---------|-----------|
| **Keyless (Sigstore)** vs key pair en KMS | Cero gestión de claves, auditoría pública | Depende de Sigstore (SPOF soft) y de un IdP; claims públicos en Rekor revelan estructura interna |
| **CycloneDX** vs SPDX | Security-first, VEX nativo | SPDX es exigido por algunas regulaciones (NTIA, FOSSology) |
| **Trivy** vs Grype | Trivy escanea misconfig+secret+vuln | Grype consume SBOM directamente (más auditable: escaneas lo que atestas) |
| **Firmar en el mismo workflow** que build | Simple, un run | Si el build se corrompe, firmas la corrupción. Alternativa: *double-signing* en workflow separado con reviewers |
| **Attest SBOM** vs solo subir SBOM como artifact | Vinculado criptográficamente al digest | Más complejidad y storage en registry |
| **Registry local (`registry:2`)** vs GHCR | Air-gapped, sin dependencia red | No obtienes keyless ni Rekor público |

---

## 9. Errores frecuentes

1. **Firmar el tag en vez del digest**. `cosign sign app:v1` firma lo que `v1` apunte *ahora*. Si mañana `v1` apunta a otra imagen, la firma deja de aplicar.
2. **Verificar sin `--certificate-identity-regexp` o con regex demasiado laxo**. Permite que cualquiera firme y pase.
3. **Olvidar `--tlog-upload=false` en MODE=local** → cosign intenta subir a Rekor público y falla o filtra metadata.
4. **Olvidar `--insecure-ignore-tlog` en verify local** → verify falla porque no encuentra entrada en Rekor.
5. **`cosign sign` sin `--yes`** → cuelga esperando confirmación interactiva en CI.
6. **Scan después de firmar** → ya firmaste una imagen vulnerable.
7. **`trivy image` sin `--exit-code 1`** → el gate no gatea; el step sale 0 aunque haya CRITICAL.
8. **Confundir SBOM del source (`syft dir:.`) con SBOM de la imagen (`syft <IMG>`)** → el consumidor quiere el segundo (lo que realmente se ejecuta).
9. **Attestation sobre `v1`** → se guarda referida al digest que `v1` apuntaba al momento, pero el consumidor que resuelva `v1` después puede ver otro digest.
10. **No pushar la imagen antes de firmar** → cosign necesita el manifest en el registry para resolver el digest.
11. **Usar `latest` como tag firmado** → anti-patrón; se mueve.
12. **Olvidar `permissions: id-token: write`** en el workflow GHA keyless → `Error: Unable to get OIDC token`.

---

## 10. Buenas prácticas

- **Siempre por digest**, nunca por tag en el pipeline de verify.
- **Emitir las cuatro evidencias** (SBOM, scan report, firma, attestations). Son baratas; combinadas suben mucho la confianza.
- **Documentar el comando `cosign verify` en el README del repo productor**. El consumidor que no sabe qué verificar, no verifica.
- **Verificar en el admission controller del cluster**, no solo en el CI de deploy (defensa en profundidad).
- **Separar firma de release en workflow distinto** con `environment: production` + required reviewers.
- **Pinnear versiones** de syft, trivy, cosign en CI (reproducibilidad y evitar breaking changes).
- **Monitorear Rekor** si usas keyless: busca tu identidad OIDC para detectar firmas no autorizadas.
- **Rotar key pair** si usas modo con claves locales (cuentos anuales mínimo).
- **No commitear `cosign.key`**. En este módulo las claves van a `/tmp/` o se gitignorean.

---

## 11. Ejercicios recomendados

1. Reproduce `examples/01-syft-sbom/`. Compara `-o cyclonedx-json` vs `-o spdx-json`. Cuenta componentes.
2. En `examples/02-trivy-scan-gate/`, corre `trivy image` sin `--exit-code` y luego con él. Observa la diferencia.
3. En `examples/03-cosign-keyless-and-verify/`, firma, modifica la imagen (rebuild), intenta verify. Observa el fallo.
4. En `examples/04-attest-provenance-and-sbom/`, genera un predicate falso (otro digest) y atesta. Verify debería fallar.
5. Completa `activities/02-fail-build-on-critical-cve/`. Reduce el ruido con `--ignore-unfixed`.
6. Completa `activities/01-build-sign-and-verify-pipeline/` en modo `local`.
7. Extensión: añade `grype` que consuma el SBOM (`grype sbom:sbom.cdx.json`) y compara con trivy.
8. Extensión: emite un **VEX** (vulnerability exploitability exchange) con CycloneDX y atéstalo.

---

## 12. Evaluación

Deberías poder responder sin consultar docs:

1. **¿Qué firma `cosign sign IMG`? ¿El tag, el manifest, el digest?** Explica por qué.
2. **Diferencia entre `cosign sign` y `cosign attest`.** ¿Puedes tener uno sin el otro? ¿Qué pierdes?
3. **¿Dónde se publican la firma y las attestations?** Describe las dos convenciones (tag legacy y OCI 1.1 referrers).
4. **Diseña el `--certificate-identity-regexp` correcto** para aceptar solo firmas producidas por `release.yml` en tags `v*` del repo `acme/billing`. ¿Qué garantía pierdes con `https://github\.com/acme/.*`?
5. **Un atacante compromete tu `cosign.key` local.** ¿Qué puede hacer? ¿Qué detecta un consumidor?
6. **Trivy encuentra una CVE CRITICAL pero `--ignore-unfixed` filtra.** ¿Está bien? ¿En qué caso sí, en qué caso no?
7. **El SBOM del source y el SBOM de la imagen son distintos.** Da tres razones concretas (hint: deps transitivas de base image, binarios copiados).
8. **Rekor está caído y el admission controller debe decidir.** ¿Fail-closed o degraded? Defiende tu respuesta.
9. **Explica qué nivel SLSA alcanza un pipeline GHA típico y qué habría que cambiar para subir.**
10. **Si tu `cosign verify` sale OK pero `cosign verify-attestation --type slsaprovenance` falla, ¿qué significa?**

---

## Referencias

Ver `resources/links.md`. Documentos ancla:

- Especificación **SLSA v1.0** — <https://slsa.dev/spec/v1.0/>.
- **Sigstore** docs — <https://docs.sigstore.dev/>.
- **cosign** v2 docs — <https://docs.sigstore.dev/cosign/signing/overview/>.
- **syft** — <https://github.com/anchore/syft>.
- **trivy** — <https://aquasecurity.github.io/trivy/>.
- **CycloneDX** spec — <https://cyclonedx.org/specification/overview/>.
- **OCI 1.1 referrers API** — <https://github.com/opencontainers/distribution-spec>.
