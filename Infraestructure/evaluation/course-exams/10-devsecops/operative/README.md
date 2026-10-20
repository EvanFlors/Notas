# Ejercicio operativo — DevSecOps

Entorno: **local**, sin cloud, sin secretos reales. Solo dummies.

## Herramientas requeridas

| Tool | Versión mínima sugerida | Verificación |
|------|-------------------------|--------------|
| `syft` | 1.0 | `syft version` |
| `trivy` | 0.50 | `trivy --version` |
| `cosign` | 2.2 | `cosign version` |
| `conftest` | 0.49 | `conftest --version` |
| `opa` | 0.60 | `opa version` |
| `kyverno` CLI | 1.11 | `kyverno version` |
| `jq` | 1.6 | `jq --version` |

Si alguna no está instalada, crea `SKIP.md` siguiendo las instrucciones del enunciado (sección 3 de `EXAM.md`). El SKIP justificado **no reprueba** el ejercicio pero limita la nota máxima a nivel **Básico (1)**.

## Estructura esperada al entregar

```
operative/
  README.md                 (este archivo, no editar)
  SKIP.md                   (si aplica)
  validate.sh               (ya incluido)
  fixtures/
    tfplan.json             (ya incluido)
    pod-good.yaml           (ya incluido)
    pod-bad.yaml            (ya incluido)
  policy/
    s3.rego                 (tú lo escribes)
    s3_test.rego            (tú lo escribes)
    kyverno-verify-images.yaml  (tú lo escribes)
  out/
    sbom.cdx.json           (tú lo generás con syft)
    sbom-notes.md           (tú lo escribes)
    trivy.sarif             (tú lo generás con trivy)
    trivy-policy.md         (tú lo escribes)
    cosign-verify.md        (tú lo escribes)
```

## Pasos sugeridos

1. Crear `out/`: `mkdir -p out`.
2. Elegir imagen inocua: `IMAGE=cgr.dev/chainguard/static:latest` (o `alpine:3.20`).
3. **O1:** `syft "$IMAGE" -o cyclonedx-json=out/sbom.cdx.json`.
4. **O2:** `trivy image --severity HIGH,CRITICAL --format sarif --output out/trivy.sarif "$IMAGE"`.
5. **O3:** Escribir `policy/s3.rego` + `policy/s3_test.rego`; correr `opa test policy` y `conftest test --policy policy fixtures/tfplan.json`.
6. **O4:** Escribir `policy/kyverno-verify-images.yaml`; probar con `kyverno apply policy/kyverno-verify-images.yaml --resource fixtures/pod-good.yaml` y `pod-bad.yaml`.
7. **O5:** Escribir `out/cosign-verify.md` con comando inseguro, por qué lo es, y la corrección usando dummy identity. **No** ejecutar contra Rekor real.
8. Correr `./validate.sh`.

## Reglas (no negociables)

- **Prohibido** incluir cualquier credencial real. Dummy identity válida de ejemplo:
  `https://github.com/acme/api/.github/workflows/release.yml@refs/heads/main`.
- **Prohibido** usar `--insecure-ignore-tlog` sin justificar en `cosign-verify.md`.
- **Prohibido** firmar/subir imágenes al Rekor público real.
- Si descargás una imagen pública, hacelo sin credenciales.
- Mantené el **código, nombres y comandos en inglés**. La prosa de los `.md` en **español**.
