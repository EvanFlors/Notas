# ADR 011 — Rollout de Binary Authorization en prod-autopilot

## Estado

Propuesto (Fase 3). Objetivo: aceptado y materializado antes de que la actividad 01 (WIF) salga a prod. Sin WIF no hay firma; sin firma no hay admisión; el orden importa.

## Contexto

El cluster `prod-autopilot` (GKE Autopilot, `europe-west1`) admite hoy cualquier imagen cuyo pull desde Artifact Registry no falle. Un operador que subiera manualmente una imagen a `europe-west1-docker.pkg.dev/.../prod-images/checkout:latest` desde su máquina **podría** desplegarla si tiene permisos de K8s, sin que ningún control detectara el bypass del pipeline.

El pipeline WIF de la actividad 01 firma cada imagen con `cosign` usando una clave en Cloud KMS tras build+test+scan. Si el cluster se niega a admitir imágenes sin esa firma, cerramos la vía manual.

Constraints:

- GKE Autopilot restringe algunos privilegios de admisión: los pods de sistema deben seguir arrancando. Olvidar `admissionWhitelistPatterns` para `gcr.io/gke-release/*` **rompe el cluster**.
- Hay dos clusters: `prod-autopilot` y `dev-autopilot`. En dev queremos aprender sin bloquear.

## Decisión

### 1. Binauthz habilitado a nivel project con policy single-tón

Un único recurso `google_binary_authorization_policy` por project. La policy define default y reglas por cluster.

### 2. Default deny

```yaml
defaultAdmissionRule:
  evaluationMode: ALWAYS_DENY
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
```

Cualquier cluster del project que no caiga en una regla específica deniega todo. Esto obliga a declarar explícitamente qué permitimos.

### 3. Reglas por cluster

- `europe-west1.prod-autopilot`: `REQUIRE_ATTESTATION` + `ENFORCED_BLOCK_AND_AUDIT_LOG`, exigiendo `build-attestor`.
- `europe-west1.dev-autopilot`: `REQUIRE_ATTESTATION` + `DRYRUN_AUDIT_LOG_ONLY`. Audita sin bloquear — para que developers aprendan el patrón sin friccionar iteración.

### 4. Attestor con clave en KMS, verificable con PEM público

`build-attestor` referencia una Container Analysis Note y una `pkixPublicKey` con `signatureAlgorithm: ECDSA_P256_SHA256`. La clave privada vive en Cloud KMS (`gcpkms://...binauthz/build-signer/1`); el PEM público se extrae con `cosign public-key` y se embebe en el attestor.

### 5. `admissionWhitelistPatterns` para pods de sistema

Mínimo obligatorio:

- `gcr.io/gke-release/*` — control plane managed de GKE Autopilot.
- `registry.k8s.io/*`, `k8s.gcr.io/*` — core de Kubernetes.
- `gke.gcr.io/*` — add-ons gestionados.
- `europe-west1-docker.pkg.dev/my-project-123/system/*` — nuestros sidecars de observability.

### 6. Rollout en dos fases: DRYRUN → ENFORCED

**Semana 1-2 (DRYRUN en ambos clusters)**:

- Policy aplicada con `enforcementMode: DRYRUN_AUDIT_LOG_ONLY` en ambos clusters.
- Revisamos los logs: `logName="projects/my-project-123/logs/binaryauthorization.googleapis.com%2Fcontinuous_validation"` y `admissionReview` en Audit Logs.
- Ajustamos la whitelist hasta cero rechazos espurios.

**Semana 3**:

- `dev-autopilot` permanece en `DRYRUN` (hábito y aprendizaje para developers).
- `prod-autopilot` pasa a `ENFORCED_BLOCK_AND_AUDIT_LOG`.

**Validación continua**:

- `continuousValidationMode: ENABLE` (vía `globalPolicyEvaluationMode: ENABLE`) comprueba periódicamente los pods ya corriendo. Captura el caso "la policy cambió, el pod viejo ya no cumple pero sigue corriendo".

### 7. Emergencias (break-glass)

Un rol `roles/binaryauthorization.policyEditor` concedido al grupo `oncall-admins` permite editar temporalmente la policy. Cada cambio se audita. Procedimiento documentado en runbook: incidente → añadir image al whitelist durante la mitigación → eliminar entrada en el post-mortem.

## Consecuencias

### Positivas

- Imposible desplegar una imagen no firmada en `prod-autopilot`.
- Audit trail de cada admisión en Cloud Audit Logs.
- `dev-autopilot` acostumbra al equipo sin friccionar iteración.
- Continuous validation añade defensa en profundidad.

### Negativas

- Primera semana de rollout genera ruido en Audit Logs mientras afinamos la whitelist.
- Si cosign falla en el pipeline (p. ej. KMS caído), ningún deploy nuevo entra. Mitigación: documentar el break-glass; **no** desactivar enforcement como atajo.
- Rotación de la clave KMS exige coordinar la actualización del attestor **antes** de que la nueva clave empiece a firmar. Mitigación: dejar ambas claves válidas durante 48 h.

## Alternativas descartadas

### Alternativa A: Kyverno o policy-controller (OPA/Gatekeeper)

Instalar un admission controller OSS dentro del cluster. **Descartada**: duplica funcionalidad que Binauthz ofrece nativa, añade un componente que mantener, y el failure mode "el controller cae" es menos aislado que el de un servicio managed.

### Alternativa B: solo escanear en pipeline, sin admisión

Confiar en que el pipeline bloquea publicar imágenes vulnerables. **Descartada**: no cubre el escenario "alguien hace push manual bypass pipeline". El punto de control debe estar lo más cerca posible del cluster.

### Alternativa C: pasar directo a ENFORCED en prod sin DRYRUN

**Descartada**: experiencia operacional conocida — una whitelist incompleta tira el cluster y la mitigación requiere editar la policy bajo presión. El coste de 1-2 semanas de DRYRUN es despreciable frente al coste de una outage de prod por un control mal configurado.

### Alternativa D: firma por tag en vez de por digest

**Descartada**: los tags son mutables. La firma debe ser sobre el `sha256:` del digest para que la garantía sea criptográfica.
