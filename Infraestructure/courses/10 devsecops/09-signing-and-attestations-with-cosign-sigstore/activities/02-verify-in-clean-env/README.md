# Actividad 02 — Verificar en entorno limpio (política keyless)

> **Independiente.** Ejercicio de diseño. No requiere binarios: produces un documento `VERIFY-POLICY.md` que un consumidor usaría para verificar la imagen del capstone **sin confiar en nada local** (ni cosign.pub previamente distribuida, ni cadena de confianza vendor-específica).

## Objetivo

Diseñar, por escrito, la política de verificación keyless que un consumidor externo (equipo cliente, auditor, admission controller en otro cluster) debería aplicar sobre la imagen del capstone del curso, suponiendo que **se firma con cosign keyless** desde GitHub Actions al taggear releases.

Al terminar debe quedar claro:

- Qué asume el consumidor (binario `cosign` + conexión a Rekor + raíz de confianza TUF).
- El **comando exacto** de verificación con los dos pins obligatorios.
- El patrón de `--certificate-identity-regexp` que acepta solo tags release y rechaza branches.
- Cómo verifica además la **attestation SLSA provenance** (`--type slsaprovenance1`).
- Qué errores espera y cómo los interpreta (sin firma / sin attestation / identidad incorrecta).

## Entregable

Un `VERIFY-POLICY.md` en `/tmp/sec-09-02-verify` con cuatro secciones:

- **Sección A — Supuestos y alcance.**
- **Sección B — Comando canónico de verificación (`cosign verify` + `cosign verify-attestation`).**
- **Sección C — Casos de fallo esperados y lectura.**
- **Sección D — Checklist de 5 preguntas que el consumidor contesta antes de desplegar.**

## Pasos

1. Lee `theory/lesson.md §4` y `§5` + `examples/03-verify-with-identity-pin/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/sec-09-02-verify && cd /tmp/sec-09-02-verify
   ```
3. Redacta `VERIFY-POLICY.md`. Supuesto de trabajo:
   - Repo: `acme/capstone-api`.
   - Workflow release: `.github/workflows/release.yml`.
   - Tags release: `v<MAJOR>.<MINOR>.<PATCH>`.
   - Imagen: `ghcr.io/acme/capstone-api`.
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/devsecops/09-signing-and-attestations-with-cosign-sigstore/activities/02-verify-in-clean-env/tests/validate.sh /tmp/sec-09-02-verify
   ```
5. Compara con `solution/REFERENCE.md`.

## Reglas de diseño

- El comando canónico **debe** incluir `--certificate-identity` o `--certificate-identity-regexp` y `--certificate-oidc-issuer`. Omitir cualquiera = política inválida.
- La verificación de attestation **debe** llevar `--type`.
- El regex de identidad debe anclarse (`^` y `$`) y debe permitir solo tags release.
- No invoques flags vendor-específicos ni asumas infra privada (vale solo cosign + red pública).

## Limpieza

```bash
rm -rf /tmp/sec-09-02-verify
```
