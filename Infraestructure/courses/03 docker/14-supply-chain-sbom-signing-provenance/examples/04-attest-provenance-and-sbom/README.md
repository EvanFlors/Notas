# Ejemplo 04 — Attestations: SLSA Provenance + SBOM

## Concepto que demuestra

Adjuntar al mismo digest de una imagen OCI **dos attestations tipadas**:

- `--type slsaprovenance` con un predicate SLSA Provenance v1 (quién construyó, con qué commit, qué builder, qué invocation).
- `--type cyclonedx` con el SBOM CycloneDX generado por syft como predicate.

Ambas firmadas por cosign (key pair local en `MODE=local`, keyless en `MODE=live`) y verificadas con `cosign verify-attestation`.

## Contexto

`cosign sign` demuestra "los bytes no cambiaron". `cosign attest` **añade semántica**: un documento *in-toto* tipado dice algo específico sobre el digest. Son documentos distintos; en una release seria publicas ambos.

- `theory/lesson.md` §4.5 (sign vs attest).
- `theory/lesson.md` §4.6 (SLSA responsabilidades).

## Archivos

- `Dockerfile.sample` — imagen demo.
- `provenance.sample.json` — predicate SLSA Provenance plantilla (el script lo rellena con digest real).
- `run.sh` — orquesta build + push + sbom + sign + attest(provenance) + attest(sbom) + verify.
- `workflow.yml` — snippet de GHA equivalente para `MODE=live`.

## Ejecución

```bash
bash run.sh                           # MODE=local, /tmp/dkr-14-ex04
MODE=local bash run.sh /tmp/mi-ex04
```

Flujo:

1. Registry local + build + push.
2. Captura digest.
3. `syft -o cyclonedx-json=sbom.cdx.json <IMG>`.
4. `cosign generate-key-pair`.
5. `cosign sign` (firma base).
6. `cosign attest --type slsaprovenance --predicate provenance.json`.
7. `cosign attest --type cyclonedx --predicate sbom.cdx.json`.
8. `cosign verify` + `cosign verify-attestation` para ambos tipos.
9. Prueba negativa: `verify-attestation` con `--type <otro>` falla.

## Qué mirar

### Predicate SLSA Provenance (resumido)

```json
{
  "buildType": "https://example.com/dkr-14/local-demo/v1",
  "builder":   { "id": "https://example.com/dkr-14/local-demo" },
  "invocation": {
    "configSource": { "uri": "git+file:///tmp/dkr-14-ex04", "digest": {"sha1": "..."} }
  },
  "metadata": {
    "invocationID": "local-demo-...",
    "startedOn":    "2026-...",
    "finishedOn":   "2026-..."
  }
}
```

En `MODE=live` (vía `actions/attest-build-provenance`) el predicate es generado automáticamente por GHA con los claims OIDC embebidos.

### Verificación

```bash
cosign verify-attestation \
  --key keys/cosign.pub --insecure-ignore-tlog \
  --type slsaprovenance <IMG@DIGEST>

cosign verify-attestation \
  --key keys/cosign.pub --insecure-ignore-tlog \
  --type cyclonedx <IMG@DIGEST>
```

El output es una lista JSON de attestations válidas. Para extraer el predicate:

```bash
cosign verify-attestation --key keys/cosign.pub --insecure-ignore-tlog \
  --type cyclonedx <IMG@DIGEST> --output-file att.json
# El payload de dsseEnvelope.payload está base64:
jq -r '.payload' att.json | base64 -d | jq '.predicate | {components_count: (.components|length)}'
```

## Limpieza

```bash
docker stop dkr-14-ex04-reg 2>/dev/null || true
rm -rf /tmp/dkr-14-ex04
```

## Referencias

- `theory/lesson.md` §4.5, §4.6.
- `resources/links.md` → cosign, SLSA, CycloneDX.
