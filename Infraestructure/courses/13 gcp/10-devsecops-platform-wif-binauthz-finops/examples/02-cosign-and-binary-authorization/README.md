# Ejemplo 02 — Cosign + Binary Authorization (lectura y análisis)

**No se ejecuta nada.** Lectura y discusión.

## 1. Objetivo

Mostrar el flujo end-to-end: el pipeline firma con `cosign` usando una clave en Cloud KMS, publica la attestation, y el cluster GKE Autopilot admite el pod gracias a la policy Binauthz que exige un attestor que verifica esa clave.

## 2. Firma en el pipeline

```yaml
# Fragmento del workflow, continuando el ejemplo 01.
- name: Sign image with cosign (KMS key)
  env:
    COSIGN_EXPERIMENTAL: "1"
  run: |
    IMAGE=europe-west1-docker.pkg.dev/my-project-123/prod-images/checkout:${{ github.sha }}
    DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE")
    cosign sign \
      --key gcpkms://projects/my-project-123/locations/europe-west1/keyRings/binauthz/cryptoKeys/build-signer/versions/1 \
      "$DIGEST"
```

Puntos:

- Se firma el **digest** (`sha256:...`), no el tag. El tag es mutable; el digest no.
- La clave vive en Cloud KMS. La SA del pipeline (impersonada vía WIF) tiene `roles/cloudkms.signerVerifier` **solo** sobre esa clave.
- `cosign sign` publica la firma como un artifact OCI adjunto al digest, consumible por el attestor.

## 3. Attestor en GCP (Terraform)

```hcl
resource "google_container_analysis_note" "build_note" {
  name = "build-attestation-note"
  attestation_authority {
    hint { human_readable_name = "Build attestor (cosign + KMS)" }
  }
}

resource "google_binary_authorization_attestor" "build" {
  name = "build-attestor"
  attestation_authority_note {
    note_reference = google_container_analysis_note.build_note.name
    public_keys {
      id = "projects/my-project-123/locations/europe-west1/keyRings/binauthz/cryptoKeys/build-signer/cryptoKeyVersions/1"
      pkix_public_key {
        public_key_pem      = file("${path.module}/build-signer.pub.pem")
        signature_algorithm = "ECDSA_P256_SHA256"
      }
    }
  }
}
```

## 4. Policy mínima (lado cluster)

```yaml
# binauthz-policy.yaml
defaultAdmissionRule:
  evaluationMode: ALWAYS_DENY
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG

clusterAdmissionRules:
  europe-west1.prod-autopilot:
    evaluationMode: REQUIRE_ATTESTATION
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    requireAttestationsBy:
      - projects/my-project-123/attestors/build-attestor

admissionWhitelistPatterns:
  - namePattern: gcr.io/gke-release/*
  - namePattern: registry.k8s.io/*
  - namePattern: europe-west1-docker.pkg.dev/my-project-123/system/*
```

## 5. Qué observar

1. Hay **tres piezas** que se deben alinear: la clave en KMS (quién firma), el attestor (quién valida), y la policy (quién exige).
2. Si cambias la clave en KMS, debes actualizar el attestor **antes** de que la policy rechace nuevas imágenes.
3. `admissionWhitelistPatterns` para pods del sistema GKE Autopilot es **obligatorio**; omitirlo tira el cluster.
4. `continuousValidationMode: ENABLED` (no está en el YAML de arriba, se añade en la policy global) comprueba periódicamente que los pods ya corriendo siguen cumpliendo la policy.

## 6. Rollout

- Semana 1: policy en `DRYRUN_AUDIT_LOG_ONLY`. Observar `logName:binaryauthorization.googleapis.com%2Fcontinuous_validation`.
- Semana 2: pasar a `ENFORCED_BLOCK_AND_AUDIT_LOG` solo en el cluster de dev.
- Semana 3: promocionar a prod.

## 7. Pregunta de discusión

Si en una emergencia necesitas correr una imagen no firmada en prod durante 2 h, ¿cómo lo haces de forma auditable sin desactivar la policy?
