# sec-09 — Lección: firma y attestations con cosign / Sigstore

> 10 secciones. Prerrequisito: `sec-08` (SBOM + SLSA).

---

## 1. Por qué firmar artefactos

Una imagen de contenedor en un registry es, al final, **un conjunto de capas y un manifest** cuyo nombre (`repo:tag`) es un alias mutable y cuyo digest (`sha256:…`) es inmutable **pero no autenticado**. Que un digest sea estable te dice que *las capas no cambiaron desde que se publicaron*; **no** te dice quién las publicó ni desde qué fuente se construyeron.

Firmar un artefacto responde a tres preguntas distintas:

1. **Integridad** — ¿lo que descargo coincide bit a bit con lo que firmaron?
2. **Autenticidad** — ¿quién firmó, verificado por una autoridad en la que confío?
3. **No-repudio** — ¿puede el firmante negar haberlo firmado más tarde?

Un hash SHA-256 responde solo (1). Hace falta criptografía asimétrica (clave privada firma, clave pública verifica) para (2). Para (3) hace falta un **log público e inmutable** donde la firma queda registrada: nadie, ni siquiera el firmante, puede *desfirmar* a posteriori.

> **Idea clave:** firmar sin un log de transparencia es como vender un coche de segunda mano sin registro — mañana el firmante puede negar que esa firma fuera suya o que fuera reciente. Rekor existe precisamente para cerrar esa puerta.

---

## 2. El modelo clásico con claves (y por qué duele operarlo)

El modelo "de toda la vida":

```
  equipo ──► genera par (priv, pub) ──► custodia priv en vault/HSM
             │
             └─► firma(artefacto, priv) → signature.sig
                                            │
  consumidor ◄── distribuye pub ◄───────────┘
             │
             └─► verify(artefacto, signature.sig, pub)
```

Problemas operativos reales:

- **Custodia** — la clave privada tiene que vivir en algún sitio seguro (vault, HSM, KMS). Si se filtra, hay que **rotar y reemitir** todas las firmas en vuelo.
- **Rotación** — si rotas por política (cada N meses), tienes que coordinar con todos los consumidores para actualizar la pub.
- **Revocación** — ¿cómo le dices al mundo que una clave ya no vale? CRLs y OCSP existen pero son frágiles.
- **Blast radius** — una sola clave que firma todo lo de la organización concentra riesgo. Si la pierdes, pierdes la confianza global.
- **Humanos firmando desde laptops** — anti-patrón: la clave vive en el `~/.cosign/` de alguien. Es solo cuestión de tiempo que acabe filtrada.

cosign soporta este modelo (`cosign generate-key-pair`, `cosign sign --key cosign.key`, `cosign verify --key cosign.pub`) y es útil para **arrancar** o para entornos sin acceso a OIDC. Pero no es a donde quieres llegar en producción.

---

## 3. El modelo keyless (Sigstore)

Sigstore ataca el problema invirtiendo la pregunta: **en lugar de custodiar una clave de larga vida, generamos una clave efímera por firma y vinculamos esa firma a una identidad OIDC verificada por una CA pública**.

Las tres piezas:

```
   ┌───────────────────────────────────────────────────────────────┐
   │                     1. IDENTITY PROVIDER                      │
   │   (GitHub Actions, Google, GitLab, Buildkite, SPIFFE, etc.)   │
   │   Emite un OIDC ID-token para el workload del CI.             │
   └───────────────────────┬───────────────────────────────────────┘
                           │ (ID-token con claims: sub, iss, …)
                           ▼
   ┌───────────────────────────────────────────────────────────────┐
   │                       2. FULCIO (CA)                          │
   │   Recibe (OIDC token, CSR con pubkey efímera).                │
   │   Emite un X.509 válido ~10 minutos con la identidad          │
   │   embebida en el SAN (p.ej. OtherName:URI).                   │
   └───────────────────────┬───────────────────────────────────────┘
                           │ (certificado efímero + priv key en RAM)
                           ▼
   ┌───────────────────────────────────────────────────────────────┐
   │                       cosign sign                             │
   │   Firma(hash(artefacto), priv). Descarta priv (en memoria).   │
   └───────────────────────┬───────────────────────────────────────┘
                           │ (bundle: signature + cert + proof)
                           ▼
   ┌───────────────────────────────────────────────────────────────┐
   │                      3. REKOR (transparency log)              │
   │   Añade la entrada al Merkle tree público, inmutable,         │
   │   firmado. Devuelve inclusion proof + timestamp firmado.      │
   └───────────────────────────────────────────────────────────────┘
```

Resultado práctico:

- **No hay clave privada que custodiar** — vivió milisegundos en RAM del runner y se perdió.
- **No hay clave que rotar** — cada firma usa una clave nueva.
- **La "clave pública" es la identidad OIDC** — "lo firmó `repo:acme/payments:ref:refs/heads/main` ejecutándose en GitHub Actions".
- **Rekor** da el no-repudio: la firma está en un log público; nadie puede retirarla sin que se note.

> **Idea clave:** keyless no "elimina la criptografía" — mueve la raíz de confianza de *"custodio bien mi clave"* a *"confío en la CA (Fulcio) y en el log (Rekor), ambos públicos y auditables"*.

---

## 4. Anatomía del certificado efímero de Fulcio

Si extraes el cert de un bundle firmado por Fulcio verás, entre otros campos:

```
X509v3 Subject Alternative Name:
    URI:https://github.com/acme/payments/.github/workflows/release.yml@refs/heads/main

X509v3 extensions (OIDs de Sigstore, 1.3.6.1.4.1.57264.1.*):
    1.3.6.1.4.1.57264.1.1  Issuer                 https://token.actions.githubusercontent.com
    1.3.6.1.4.1.57264.1.2  GitHub Workflow Trigger push
    1.3.6.1.4.1.57264.1.3  GitHub Workflow SHA    <commit>
    1.3.6.1.4.1.57264.1.4  GitHub Workflow Name   release
    1.3.6.1.4.1.57264.1.5  GitHub Workflow Repository acme/payments
    1.3.6.1.4.1.57264.1.6  GitHub Workflow Ref    refs/heads/main
    …
```

Verificar significa validar que **la cadena X.509 llega a la raíz de Fulcio** (publicada en TUF) **y** que los campos de identidad coinciden con lo que *esperas*. Si no fijas qué esperas, aceptas cualquier identidad válida — ese es el fallo del siguiente apartado.

---

## 5. El fallo más común: `cosign verify` sin pin de identidad

```bash
# INSEGURO — acepta CUALQUIER firma emitida por Fulcio.
cosign verify ghcr.io/acme/payments:v1

# INSEGURO — fija el issuer pero no la identidad; vale la firma de otro repo.
cosign verify \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ghcr.io/acme/payments:v1

# CORRECTO — fija ambos: issuer + identidad concreta.
cosign verify \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity=https://github.com/acme/payments/.github/workflows/release.yml@refs/heads/main \
  ghcr.io/acme/payments:v1

# CORRECTO (patrón) — permite tags/branches controlados.
cosign verify \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='^https://github.com/acme/payments/\.github/workflows/release\.yml@refs/tags/v[0-9]+' \
  ghcr.io/acme/payments:v1
```

Si tu cadena de suministro acepta una verificación sin `--certificate-identity[-regexp]`, un atacante que consiga ejecutar un workflow en **otro repo** (incluso suyo, público) y firme algo con Fulcio tiene una firma válida que pasa tu `verify`. **La política es parte de la firma**, no un adorno.

---

## 6. Attestations tipadas — firma + semántica

Una **attestation** es un documento JSON *sobre* un artefacto (un SBOM, una provenance SLSA, un resultado de tests) empaquetado en el formato **in-toto Statement**:

```
{
  "_type": "https://in-toto.io/Statement/v1",
  "predicateType": "https://cyclonedx.org/bom/v1.5",
  "subject": [ { "name": "ghcr.io/acme/payments", "digest": { "sha256": "…" } } ],
  "predicate": { ... SBOM CycloneDX ... }
}
```

`cosign attest --predicate sbom.cdx.json --type cyclonedx` empaqueta ese Statement en un **DSSE envelope**, lo firma (keyless o con clave), y lo publica como artefacto OCI adjunto a la imagen (tag `sha256-<digest>.att`).

Verificar es simétrico y **debe filtrar por `--type`**:

```bash
cosign verify-attestation \
  --type=cyclonedx \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity=https://github.com/acme/payments/.github/workflows/release.yml@refs/heads/main \
  ghcr.io/acme/payments:v1 \
  | jq -r '.payload' | base64 -d | jq '.predicate'
```

Sin `--type` aceptarías cualquier attestation adjunta (una SBOM, pero también cualquier "cosa.json" que alguien firmara y adjuntara). El tipo es la **capa de contrato semántico**.

> **Idea clave:** firma sin attestation = "esto lo publiqué yo". Attestation sin firma = "aquí hay un JSON". Las dos juntas = "yo (identidad verificada) afirmo (contenido verificado) que este artefacto (digest verificado) tiene estas propiedades".

---

## 7. SLSA provenance como caso particular

SLSA provenance es una attestation con `predicateType=https://slsa.dev/provenance/v1`. Describe **cómo** se construyó el artefacto: builder, source repo, commit, parámetros, materiales. GitHub Actions con `actions/attest-build-provenance` emite esa attestation **y la firma keyless con Fulcio** automáticamente.

Verificar provenance = `cosign verify-attestation --type=slsaprovenance1 …`. Un consumidor estricto rechaza imágenes **sin** provenance adjunta, aunque la imagen esté firmada: la firma dice "yo publiqué esto", la provenance dice "y lo construí así, desde este commit".

---

## 8. Formato bundle vs señales sueltas

cosign maneja dos formas de empaquetar la salida:

- **"Attached" en OCI** — la firma se publica en el mismo registry que la imagen, con la convención de tag `sha256-<digest>.sig` / `.att`. Es lo típico para imágenes en registries OCI.
- **Bundle local** (`--bundle`) — un único JSON con firma + cert + proof de Rekor. Útil para firmar blobs sueltos (binarios, SBOMs independientes), release artifacts, etc.

En ambos casos la **verificación** incluye consultar Rekor para confirmar la inclusión. Esa consulta puede hacerse online (default) o offline con `--offline` si el bundle incluye el proof pre-cacheado.

---

## 9. gitsign — el mismo patrón para commits

`gitsign` reutiliza Sigstore para firmar **commits** (y tags) sin GPG:

- No hay clave GPG ni keyring que mantener.
- El commit queda firmado por tu identidad OIDC (SSO corporativo, GitHub, Google).
- La firma se registra en Rekor.

El mismo criterio de verificación aplica: `gitsign verify --certificate-identity=<tú>@acme.com --certificate-oidc-issuer=<SSO> <commit>`.

---

## 10. Integración en Kubernetes (preview de `sec-11`)

En admisión, dos piezas típicas aplican estas verificaciones **antes** de que un pod se cree:

- **Kyverno** con regla `verifyImages` — bloquea pods cuyas imágenes no estén firmadas por una identidad concreta o no tengan la attestation requerida.
- **sigstore/policy-controller** — controller específico para políticas Sigstore; mapping declarativo entre imágenes y las identidades aceptadas.

El patrón: la imagen entra solo si (a) la firma es válida, (b) la identidad coincide con el pin de la política, (c) opcionalmente, hay una attestation del tipo esperado (SBOM, SLSA provenance). Toda la cadena termina en `cosign verify` ejecutándose dentro del admission controller.

---

## Errores comunes a cazar

- `cosign verify` sin `--certificate-identity[-regexp]` → acepta cualquier firma.
- `cosign verify-attestation` sin `--type` → acepta cualquier attestation adjunta.
- Firmar con clave de larga vida almacenada en el repo (incluso `cosign.key` cifrada con password) → anti-patrón si existe la opción keyless.
- Fijar identidad por **nombre de workflow** (`release.yml`) sin fijar también ref/branch → un PR que renombra el workflow a `release.yml` desde otro branch firmaría.
- No verificar provenance además de la firma → se autentica "quién publicó" pero no "cómo se construyó".
- Confiar en que `registry → kubelet` ya valida firmas → **no lo hace** por defecto; hace falta un admission controller.
