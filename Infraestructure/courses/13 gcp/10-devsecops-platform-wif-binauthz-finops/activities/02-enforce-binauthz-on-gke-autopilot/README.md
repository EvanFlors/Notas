# Actividad 02 — Policy Binauthz + attestor para GKE Autopilot

## 1. Identificación

- **ID:** `gcp-10-02-enforce-binauthz-on-gke-autopilot`
- **Tecnología:** `gcp`
- **Módulo:** `gcp-10-devsecops-platform-wif-binauthz-finops`
- **Dificultad:** advanced
- **Duración estimada:** 90–110 min
- **Tipo:** architecture (independent)

## 2. Contexto

El cluster `prod-autopilot` (región `europe-west1`, GKE Autopilot) acepta hoy cualquier imagen cuyo pull funcione. El equipo quiere **exigir attestation** para toda imagen en prod, con una excepción explícita para los pods de sistema de GKE y para una lista corta de imágenes bendecidas.

El pipeline WIF (actividad 01) firma las imágenes con `cosign` usando una clave en Cloud KMS. Tu encargo: escribir la **policy YAML**, el **attestor YAML**, el **Terraform** que habilita Binauthz en el cluster, y un **ADR** que explica el rollout.

**Importante**: no hay cluster real. Nada se aplica. Ningún coste GCP. Los IDs son placeholders.

## 3. Objetivos

- Escribir una policy Binauthz coherente (deny-by-default + exempt sistema + require-attestation en prod).
- Definir un attestor con clave PKIX (public_key_pem) y note de Container Analysis.
- Diseñar un rollout DRYRUN → ENFORCED defendible.

## 4. Prerrequisitos

- `gcp-02`, `gcp-07`.
- Herramientas: `bash`, `python3` (para parsear YAML), `grep`. Opcional: `yq`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/gcp-10-02-binauthz/terraform
cd /tmp/gcp-10-02-binauthz
```

### 5.2 Escribe `binauthz-policy.yaml`

Claves obligatorias (el validador parsea YAML y comprueba):

- `defaultAdmissionRule` con:
  - `evaluationMode: ALWAYS_DENY`
  - `enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG` (o `DRYRUN_AUDIT_LOG_ONLY` si el ADR lo justifica — pero por el default el validador exige `ENFORCED_BLOCK_AND_AUDIT_LOG`).
- `clusterAdmissionRules` con **al menos una entrada** cuya clave sea `<region>.<cluster-name>` (p. ej. `europe-west1.prod-autopilot`), con:
  - `evaluationMode: REQUIRE_ATTESTATION`
  - `enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG` (o `DRYRUN_AUDIT_LOG_ONLY`).
  - `requireAttestationsBy` con al menos un attestor referenciado (`projects/<p>/attestors/<name>`).
- `admissionWhitelistPatterns` con **al menos 2 entradas**: debe incluir `gcr.io/gke-release/*` y una de `registry.k8s.io/*` o similar — sin esto, el cluster se rompe.

### 5.3 Escribe `attestor.yaml`

Documento YAML (puede ser un archivo con una lista de recursos o uno solo) que incluya:

- Un `attestor` con `name`, `attestationAuthorityNote.noteReference`, y `attestationAuthorityNote.publicKeys[]` con al menos una entrada con `pkixPublicKey.publicKeyPem` y `signatureAlgorithm` (`ECDSA_P256_SHA256` recomendado).
- El `publicKeyPem` puede ser un placeholder tipo `-----BEGIN PUBLIC KEY-----\n...PLACEHOLDER...\n-----END PUBLIC KEY-----`.

### 5.4 Escribe `terraform/binauthz.tf`

Debe declarar al menos:

- `google_binary_authorization_policy` (puede referenciar los archivos YAML o inline).
- `google_binary_authorization_attestor`.
- `google_container_analysis_note`.
- Una referencia a un cluster GKE Autopilot (puede ser `data` o `resource`); el validador busca mención de `enable_binary_authorization` **o** del bloque `binary_authorization { evaluation_mode = ... }` (depende de la versión del provider).

### 5.5 Escribe `ADR-BINAUTHZ-ROLLOUT.md`

Secciones obligatorias (como siempre): `# ADR`, `## Estado`, `## Contexto`, `## Decisión`, `## Consecuencias`, `## Alternativas` (>=2).

Contenido mínimo (tokens que el validador busca):

- Menciona **Binary Authorization** (o Binauthz).
- Menciona **GKE Autopilot** (y `prod-autopilot` o similar).
- Menciona **cosign** o **Sigstore** (prueba del vínculo con el pipeline).
- Menciona el **rollout DRYRUN → ENFORCED** (ambas palabras).
- Menciona **admissionWhitelistPatterns** y por qué (pods de sistema).
- Menciona `continuousValidationMode` o continuous validation.

### 5.6 Entregables

```
/tmp/gcp-10-02-binauthz/
├── binauthz-policy.yaml
├── attestor.yaml
├── terraform/binauthz.tf
└── ADR-BINAUTHZ-ROLLOUT.md
```

## 6. Validación

```bash
bash tests/validate.sh /tmp/gcp-10-02-binauthz
```

Compara con `solution/REFERENCE.md` después para autoevaluarte.

## 7. Preguntas de reflexión

1. ¿Qué pasa si olvidas `admissionWhitelistPatterns` con los pods de sistema en modo `ENFORCED`?
2. ¿Por qué firmar el **digest** y no el tag?
3. ¿Cómo manejas una emergencia donde necesitas correr una imagen no firmada durante 2 h en prod?
4. ¿Qué diferencia hay entre `continuousValidationMode: ENABLED` y la admisión en tiempo de creación de pod?

## 8. Limpieza

```bash
rm -rf /tmp/gcp-10-02-binauthz
```
