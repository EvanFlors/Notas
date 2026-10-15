# Lección: Supply chain — SBOM, attestations y firma

> **ID:** `gha-14-supply-chain-sbom-attestations-signing` · **Nivel:** producción · **Duración:** 5 h
> **Prerrequisitos:** `gha-13-security-hardening`, Docker básico.

---

## 1. Introducción intuitiva

Imagina que compras un medicamento genérico de un fabricante que no conoces. En la caja hay una etiqueta con número de lote, fecha de producción, planta, código del principio activo, y un sello holográfico. Si el sello está intacto puedes creer que la caja no fue abierta; si el número de lote está en el registro público del regulador puedes creer que ese lote existió y pasó control. **No necesitas confiar en el fabricante previamente**: la combinación etiqueta + sello + registro público te deja verificar la cadena por tu cuenta.

El software funciona casi igual. Cuando tiras `docker pull ghcr.io/alguien/app:v1.2.3`, estás descargando bytes de un servidor que no controlas, construidos por un pipeline que no viste correr, a partir de código que puede o no coincidir con el repositorio público. La pregunta operativa es: **¿qué puedes afirmar, con prueba criptográfica, sobre esa imagen antes de ejecutarla?**

- Que fue firmada por **ese workflow** de **ese repo** en **ese commit** → *attestation de build provenance*.
- Que su **inventario de componentes** (binarios, librerías, versiones, licencias) es *este* → *SBOM*.
- Que **no fue modificada** desde que se firmó → *firma de la imagen (cosign)*.

Esta lección te enseña a emitir las tres evidencias desde un workflow de GitHub Actions, cómo las ancla Sigstore en un log público para que un tercero pueda confirmarlas sin confiar en ti, y cómo verificarlas desde el workflow del consumidor.

---

## 2. Fundamentos

### 2.1 Las tres piezas: SBOM, attestation, firma

| Pieza | Qué es | Qué afirma |
|-------|--------|------------|
| **SBOM** (Software Bill of Materials) | JSON/XML listando componentes, versiones, licencias, hashes | "esta imagen contiene estos N paquetes" |
| **Attestation** | Documento firmado `in-toto` con un *predicate* tipado (`slsa-provenance/v1`, `cyclonedx/vex`, …) sobre un *subject* (hash del artefacto) | "quien emitió esta attestation afirma P sobre el artefacto X" |
| **Firma (signature)** | Firma criptográfica sobre el digest del artefacto | "el artefacto X no cambió desde que fue firmado por la identidad Y" |

Tres cosas distintas. Un release serio emite las **tres**. Y las tres se verifican de formas distintas con herramientas que se parecen pero no son intercambiables.

### 2.2 ¿Por qué keyless?

El modelo histórico de firma de software requiere que el productor custodie una **clave privada** y que el consumidor conozca de antemano la **clave pública** del productor. Esto escala mal: cada productor tiene que proteger su clave (y rotarla si se compromete), y cada consumidor tiene que distribuir/actualizar su llavero.

**Sigstore keyless** reemplaza esto: la clave es **efímera** (un par nuevo por firma, destruido en segundos). La identidad del firmante se demuestra con un **token OIDC** emitido por un IdP de confianza (en GHA, GitHub mismo emite el OIDC token). Una CA llamada **Fulcio** le entrega al firmante un certificado X.509 de **10 minutos** cuyo `Subject Alternative Name` lleva los claims OIDC (repo, workflow, commit). La firma se publica en **Rekor**, un log transparente *append-only*, para que exista prueba pública de que ocurrió.

El consumidor verifica: "¿la firma es válida contra una clave pública que Fulcio certificó para la identidad `repo=OWNER/REPO, workflow=release.yml, ref=refs/tags/v1.2.3`? ¿Rekor confirma que esto se registró en tal momento?" Si sí, puede confiar — sin haber hablado jamás con el productor.

### 2.3 SLSA: niveles, no un sello único

**SLSA v1.0** (Supply-chain Levels for Software Artifacts) define *build tracks* de L1 a L3+:

- **L1** — existe build provenance declarativa (puede no estar firmada).
- **L2** — provenance firmada por el build service (Sigstore cuenta).
- **L3** — build hecho en una plataforma *aislada* (hermeticidad del runner, imposible manipular desde el pipeline mismo).

Un workflow GHA típico con `actions/attest-build-provenance` emite provenance **L2**. Para L3 necesitas correr en una infra que GitHub documenta aparte (SLSA-GitHub-Generator reusable workflows). Es honesto decir "SLSA L2" y no inflar.

---

## 3. Contexto histórico

| Año | Hito |
|-----|------|
| 2015 | Linux Foundation inicia **SPDX** como formato de SBOM. |
| 2017 | OWASP publica **CycloneDX** v1.0, orientado a security. |
| 2020 | SolarWinds — ataque a la supply chain del build. El tema entra al mainstream político. |
| 2021 | Google + Linux Foundation publican **SLSA** v0.1. **sigstore/cosign** v1.0. Fulcio y Rekor. |
| 2021 | Executive Order 14028 (US) obliga a SBOM en proveedores federales. |
| 2022 | GitHub lanza beta de artifact attestations (`actions/attest-*`). |
| 2023 | SLSA v1.0 estable. `cosign` v2 (breaking: argumentos `--key` explícitos). |
| 2024 | `actions/attest-build-provenance` GA. `gh attestation verify` disponible en gh CLI. |
| 2025+ | Policy engines (Kyverno, OPA, cosign-policy-controller) consumen attestations en admission control. |

Lo relevante: **la tooling es relativamente nueva**. Esperar que el ecosistema cambie; pinnear versiones.

---

## 4. Funcionamiento interno

### 4.1 El flujo keyless Sigstore, paso a paso

```
┌─────────────────────────────────────────────────────────────────┐
│ Runner GHA (workflow release.yml)                               │
│                                                                 │
│  1. Pide OIDC token a GitHub                                    │
│     POST ACTIONS_ID_TOKEN_REQUEST_URL?audience=sigstore         │
│     ← JWT con claims:                                           │
│         sub = repo:OWNER/REPO:ref:refs/tags/v1.2.3              │
│         repository = OWNER/REPO                                 │
│         workflow_ref = OWNER/REPO/.github/workflows/release.yml@…│
│         job_workflow_ref = …                                    │
│         sha = <commit>                                          │
│         ...                                                     │
│                                                                 │
│  2. Genera par de claves efímero (ECDSA P-256)                  │
│                                                                 │
│  3. Pide certificado a Fulcio                                   │
│     POST /api/v2/signingCert  { pubkey, OIDC JWT }              │
│     ← X.509 cert válido 10 min, SAN incluye URI con claims      │
│       issuer OIDC puesto como OID extensión                     │
│                                                                 │
│  4. Firma el digest del artefacto con la privada efímera        │
│                                                                 │
│  5. Sube firma + cert + metadata a Rekor                        │
│     POST /api/v1/log/entries                                    │
│     ← inclusion proof (índice en el log, SET)                   │
│                                                                 │
│  6. Destruye la privada efímera. Fin.                           │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│ Rekor (log append-only público)                                 │
│   Entrada {firma, cert, digest, timestamp, SET}                 │
└─────────────────────────────────────────────────────────────────┘

Consumidor (otro repo, otra org, cualquiera):

┌─────────────────────────────────────────────────────────────────┐
│  cosign verify ghcr.io/OWNER/REPO/app:v1.2.3 \                  │
│    --certificate-identity-regexp "https://github\.com/OWNER/.*" \│
│    --certificate-oidc-issuer    "https://token.actions.githubusercontent.com"│
│                                                                 │
│  1. Descarga firma + cert desde el registry (OCI 1.1 referrers) │
│  2. Verifica cadena del cert contra el root de Fulcio           │
│  3. Comprueba SAN del cert vs patrón esperado                   │
│  4. Verifica inclusión en Rekor (SET + log consistency)         │
│  5. Verifica firma sobre el digest de la imagen                 │
│  OK → la imagen fue firmada por un runner GHA con esa identidad │
└─────────────────────────────────────────────────────────────────┘
```

Observa que **ninguna clave de larga vida** aparece en el runner. Si un atacante compromete el runner tras los 10 minutos, el cert ya expiró y no sirve.

### 4.2 Formato de la attestation (in-toto)

Una attestation es un documento JSON con esta forma simplificada:

```json
{
  "_type": "https://in-toto.io/Statement/v1",
  "subject": [
    { "name": "ghcr.io/OWNER/REPO/app", "digest": { "sha256": "abc..." } }
  ],
  "predicateType": "https://slsa.dev/provenance/v1",
  "predicate": {
    "buildDefinition": {
      "buildType": "https://actions.github.io/buildtypes/workflow/v1",
      "externalParameters": { ... },
      "internalParameters": { "github": { "repository_id": "...", "workflow_sha": "..." } }
    },
    "runDetails": {
      "builder": { "id": "https://github.com/actions/runner" },
      "metadata": { "invocationID": "https://github.com/OWNER/REPO/actions/runs/123/attempts/1" }
    }
  }
}
```

Este JSON se envuelve en un **DSSE** (Dead Simple Signing Envelope), que es firmado por la clave efímera cuyo cert lleva los claims OIDC. El `subject.digest` ancla la attestation a bytes específicos — si cambian, la verificación falla.

### 4.3 Dónde se guardan las cosas

GitHub expone attestations en **dos lugares**:

1. **El repo** (`Actions → Attestations`): búsqueda por digest, API `/repos/{owner}/{repo}/attestations/{subject_digest}`.
2. **El registry OCI** (via OCI 1.1 referrers API): la firma y la attestation se suben como *referring artifacts* al mismo digest de la imagen. Esto es lo que hace `cosign` cuando firma una imagen y lo que `cosign download attestation` recupera.

Para artefactos **que no son imágenes OCI** (binarios, SBOMs sueltos, tarballs), solo existe el lugar #1 → se verifica con `gh attestation verify`.

### 4.4 SBOM: CycloneDX vs SPDX

| Dimensión | CycloneDX | SPDX |
|-----------|-----------|------|
| Mantenedor | OWASP | Linux Foundation |
| Formatos | JSON, XML, Protobuf | JSON, XML, YAML, tag-value |
| Foco histórico | security (VEX, vulnerabilidades) | licencias y compliance |
| Adoptado por | OWASP, Dependency-Track, Trivy | NTIA EO 14028, Kubernetes releases |

Ambos describen *lo mismo* conceptualmente: componentes, versiones, hashes, licencias, relaciones (A depende de B). `syft` genera cualquiera de los dos con `-o cyclonedx-json` o `-o spdx-json`. La elección suele ser dictada por el consumidor downstream (si tu cliente usa Dependency-Track → CycloneDX; si audita compliance con FOSSology → SPDX).

### 4.5 Firma de imágenes OCI con cosign

Dos modos:

**Modo keyless** (recomendado en CI):

```bash
cosign sign ghcr.io/owner/app@sha256:abc...
# → abre browser para OIDC si local; en GHA usa el token del runner
# → pide cert a Fulcio, firma, sube a Rekor y como referrer al OCI
```

**Modo con key pair** (útil para demos locales sin IdP):

```bash
cosign generate-key-pair                # produce cosign.key + cosign.pub
export COSIGN_PASSWORD=''               # vacío para demos; en prod: KMS
cosign sign --key cosign.key ghcr.io/owner/app@sha256:abc...
cosign verify --key cosign.pub ghcr.io/owner/app@sha256:abc...
```

Para producción multi-persona la mejor práctica es keyless. Local sin red → key pair.

---

## 5. Ejemplo mínimo

### 5.1 Workflow completo (ilustrativo)

```yaml
name: release
on:
  push:
    tags: ["v*"]

permissions: {}  # default-deny

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write          # GHCR push
      id-token: write          # Sigstore keyless
      attestations: write      # subir attestations al repo
    outputs:
      digest: ${{ steps.push.outputs.digest }}

    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - uses: docker/login-action@74a5d142397b4f367a81961eba4e8cd7edddf772  # v3.4.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - id: push
        uses: docker/build-push-action@471d1dc4e07e5cdedd4c2171150001c434f0b7a4  # v6.15.0
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}/app:${{ github.ref_name }}

      - name: Generate SBOM (CycloneDX)
        uses: anchore/sbom-action@f325610c9f50a54015d37c8d16cb3b0e2c8f4de0  # v0.18.0
        with:
          image: ghcr.io/${{ github.repository }}/app@${{ steps.push.outputs.digest }}
          format: cyclonedx-json
          output-file: sbom.cdx.json

      - name: Attest build provenance
        uses: actions/attest-build-provenance@c074443f1aee8d4aeeae555aebba3282517141b2  # v2.2.3
        with:
          subject-name: ghcr.io/${{ github.repository }}/app
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true

      - name: Attest SBOM
        uses: actions/attest-sbom@bd218ad0dbcb3e146bd073d1d9c6d78e08aa8a0b  # v2.4.0
        with:
          subject-name: ghcr.io/${{ github.repository }}/app
          subject-digest: ${{ steps.push.outputs.digest }}
          sbom-path: sbom.cdx.json
          push-to-registry: true

      - name: Sign image with cosign (keyless)
        env:
          IMAGE: ghcr.io/${{ github.repository }}/app@${{ steps.push.outputs.digest }}
        run: cosign sign --yes "$IMAGE"
```

### 5.2 Verificación por un consumidor

```bash
# Verifica firma cosign
cosign verify ghcr.io/owner/repo/app:v1.2.3 \
  --certificate-identity-regexp '^https://github\.com/owner/repo/\.github/workflows/release\.yml@refs/tags/v.*$' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com'

# Verifica attestation de provenance
gh attestation verify oci://ghcr.io/owner/repo/app:v1.2.3 \
  --repo owner/repo

# Verifica attestation de SBOM
gh attestation verify oci://ghcr.io/owner/repo/app:v1.2.3 \
  --repo owner/repo --predicate-type https://spdx.dev/Document
```

---

## 6. Implementación progresiva

Orden recomendado para construir confianza:

1. **Hello SBOM**: genera un SBOM local con `syft dir:.` sobre un repo pequeño. Léelo. Entiende qué incluye.
2. **SBOM en CI**: añade `anchore/sbom-action` a un workflow que builds imagen. Súbelo como artifact.
3. **Attestation (sin firma todavía)**: añade `actions/attest-build-provenance` sobre el binario. Verifica con `gh attestation verify`.
4. **Firma OCI**: añade `cosign sign` keyless sobre la imagen pusheada a GHCR. Verifica con `cosign verify`.
5. **Attestation de SBOM**: añade `actions/attest-sbom`. Verifica con `gh attestation verify --predicate-type`.
6. **Workflow consumidor**: en otro repo, escribe un job que verifique todo antes de desplegar.
7. **Policy**: define qué identidades aceptas y qué rechaza tu downstream (regex, environment, ref patterns).

Cada paso puede corromper el anterior; añadir en orden y verificar en cada capa.

---

## 7. Aplicación profesional

### 7.1 Modelo de confianza típico en una org

```
┌─────────────────────────────────────────────────────────────┐
│ Equipo productor (repo app)                                 │
│   release.yml → sign + attest (cosign + actions/attest-*)   │
└─────────────────────────────────────────────────────────────┘
                           │ publica a GHCR
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ GHCR (ghcr.io/org/app)                                      │
│   layers + firma + attestations (referrers)                 │
└─────────────────────────────────────────────────────────────┘
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
    ┌────────────┐  ┌────────────┐  ┌────────────┐
    │ cluster-dev│  │cluster-stg │  │cluster-prod│
    │ sin policy │  │ warn only  │  │ ENFORCE    │
    └────────────┘  └────────────┘  └────────────┘
                                       │
                                       ▼
                            ┌─────────────────────┐
                            │ admission controller│
                            │ verifica firma +    │
                            │ attestation +       │
                            │ identity regex      │
                            │ (cosign/kyverno)    │
                            └─────────────────────┘
```

### 7.2 Reglas operativas

- **Firma siempre con digest, no con tag**: los tags son mutables en el registry; el digest es content-addressed. `cosign sign` admite ambos pero firma el digest en todo caso.
- **Verifica con regex de identidad precisa**: `--certificate-identity-regexp '^https://github\.com/OWNER/REPO/\.github/workflows/release\.yml@refs/tags/v[0-9].*$'`. Un patrón laxo como `^https://github\.com/OWNER/.*$` permite que *cualquier* workflow de la org firme — pérdida de garantía.
- **No verifiques solo la firma**: una imagen firmada por el workflow correcto pero *con un SBOM inconsistente* sigue siendo sospechosa. Pide attestation de SBOM también.
- **El consumidor debe fallar cerrado**: si Rekor no responde, decide a priori si *abortas* o *degradas con warning*. No improvises en producción.
- **Rota el pin del action a SHA**: `actions/attest-build-provenance@v2` es un tag mutable; en workflows críticos pinnear a commit SHA (`gha-13`).

### 7.3 Qué garantiza una attestation GHA, qué no

| Garantiza | NO garantiza |
|-----------|--------------|
| Este artefacto fue producido por ese workflow en ese commit de ese repo | Que el workflow sea correcto o seguro |
| Que el runner era GitHub-hosted (o self-hosted documentado) | Que el código fuente sea seguro |
| Momento exacto (timestamp Rekor) | Que no haya telemetría maliciosa dentro del binario |
| Que no cambió desde la firma | Que las dependencias del SBOM no estén comprometidas |

**Attestations son parte del modelo de confianza, no lo reemplazan.** Las políticas de review de código, auditoría de deps, scanning (CodeQL, Dependabot) siguen siendo necesarias.

---

## 8. Trade-offs

| Decisión | A favor | En contra |
|----------|---------|-----------|
| **Keyless** vs key pair gestionado en KMS | Cero gestión de claves, mejor auditoría pública | Depende de Sigstore (SPOF soft); dependencia de IdP (GitHub); claims públicos en Rekor pueden revelar estructura interna |
| **CycloneDX** vs SPDX | Mejor para security tooling; VEX nativo | SPDX es más adoptado por compliance; algunas regulaciones específicamente lo exigen |
| **`anchore/sbom-action`** vs invocar `syft` directo | Menos boilerplate, upload automático | Menos control; una dep más que pinnear |
| **GHCR** vs otro registry | Integra con `GITHUB_TOKEN`, attestations UI, política IAM del repo | Lock-in; límite de storage; costos |
| **Firma en el mismo workflow** que build | Simple, un run | Si el build se corrompe, la firma lo bendice. Alternativa: workflow separado con review manual (**double-signing**) |
| **Attestar imagen** vs attestar también cada binario intermedio | Más completo | Más complejidad, más puntos de falla |

---

## 9. Errores frecuentes

1. **Olvido de `permissions: id-token: write`** → `Error: Unable to get OIDC token`. Es el error #1.
2. **Olvido de `permissions: attestations: write`** → la attestation se firma pero no se guarda en el repo.
3. **Olvido de `permissions: packages: write`** → `denied: permission_denied: write_package`.
4. **Firmar el tag en vez del digest**: el tag puede moverse; la verificación posterior falla si el tag cambió a otra imagen.
5. **Verificar con identity regex demasiado laxo**: `https://github\.com/.*` permite a *cualquier* repo firmar y pasar la verificación.
6. **No usar `--certificate-oidc-issuer`**: cosign por default no obliga a Sigstore pública; un atacante podría crear su propia CA.
7. **`gh attestation verify` sin `--repo` o `--owner`**: la verificación requiere al menos una restricción de la identidad esperada.
8. **Correr `actions/attest-build-provenance` antes de que exista el `subject-path`/`subject-digest`**: el step falla silenciosamente o atestea un hash de archivo vacío.
9. **Confundir SBOM del *source* con SBOM de la *imagen***: `syft dir:.` lee archivos del workspace; `syft <image>` escanea las capas. En CI casi siempre quieres la segunda (lo que de verdad se publica).
10. **Pin a `@v2`** cuando `v2` es tag flotante → mañana puede apuntar a otro SHA. En producción crítica, pin a commit SHA.
11. **Depender del formato humano de `cosign verify`**: en scripts, parsear JSON (`cosign verify ... --output=json`), no texto.

---

## 10. Buenas prácticas

- **Default-deny permissions** en el workflow (`permissions: {}`) y escalada mínima por job.
- **Emitir las tres evidencias siempre** (provenance + SBOM + firma). Son baratas y combinadas suben mucho el nivel de confianza.
- **Documentar el comando de verificación en el `README.md`** del repo productor. El consumidor que no sabe qué verificar, no verifica.
- **Verificar en el admission controller del cluster** (Kyverno `verifyImages`, cosign policy controller), no solo en el CI de deploy. Defensa en profundidad.
- **Separar firma de release en workflow distinto** con `environment: production` + required reviewers. Impide que un commit malicioso dispare auto-firma.
- **Monitorear Rekor**: si usas keyless, puedes buscar en Rekor firmas con tu identidad OIDC para detectar firmas no autorizadas.
- **Pin a SHA** todas las actions de la cadena de supply chain (attest-*, cosign-installer, sbom-action, docker/build-push-action, docker/login-action).
- **No almacenar la clave privada de cosign en secrets de GitHub** si usas modo con key pair: usa KMS (AWS KMS, GCP KMS, HashiCorp Vault). Si por alguna razón sí la guardas, scope por environment protegido.

---

## 11. Ejercicios recomendados

1. Reproduce `examples/01-sbom-with-syft/`. Abre el JSON. Cuenta cuántas dependencias de nivel 1 tiene la imagen.
2. En `examples/02-attest-build-provenance/`, modifica el binario después de la attestation y vuelve a verificar. Observa el fallo.
3. En `examples/03-cosign-sign-and-verify/`, firma una imagen y verifícala con un regex de identidad **incorrecto**. Observa qué dice el error.
4. Completa `activities/01-publish-signed-image-to-ghcr/` en modo `local`.
5. Completa `activities/02-verify-in-downstream-workflow/`: te damos una imagen de referencia y una identidad esperada.
6. Extensión: añade a tu workflow la generación de un **VEX** (Vulnerability Exploitability eXchange) con `grype` + attéstalo como `cyclonedx-vex`.

---

## 12. Evaluación

Deberías poder responder sin consultar:

1. **Explica el flujo keyless Sigstore paso a paso**, desde que el runner pide el OIDC token hasta que la firma aparece en Rekor. ¿Dónde está la clave privada 5 minutos después del step de firma?
2. **¿Qué nivel SLSA alcanza un workflow GHA típico con `actions/attest-build-provenance`? ¿Qué tendrías que hacer para subir de nivel?**
3. **Diferencia entre SBOM y attestation de SBOM.** ¿Es útil publicar un SBOM sin attestation? ¿Y una attestation sin SBOM?
4. **¿Qué garantía NO da una attestation GHA?** Da tres ejemplos de afirmaciones falsas que a veces se asumen.
5. **Un atacante compromete una action de tercero usada en tu workflow de release**. ¿La firma Sigstore detecta esto? ¿Qué sí lo detectaría?
6. **Diseña el regex de `--certificate-identity-regexp`** para aceptar solo firmas producidas por `release.yml` en tags `v*` del repo `acme/billing`. Explica qué pasaría si en vez de ese regex pones `https://github\.com/acme/.*`.
7. **Rekor está caído** cuando el consumidor intenta verificar. ¿Qué debe pasar? Defiende tu respuesta.

---

## Referencias

Ver `resources/links.md` del módulo. Documentos ancla:

- Especificación SLSA v1.0 — <https://slsa.dev/spec/v1.0/>.
- Documentación Sigstore — <https://docs.sigstore.dev/>.
- GitHub: "Using artifact attestations to establish provenance" — <https://docs.github.com/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds>.
- `cosign` v2 docs — <https://docs.sigstore.dev/cosign/signing/overview/>.
- Syft (`anchore/syft`) — <https://github.com/anchore/syft>.
