# Actividad cap-12-02 — Kyverno verifyImages (cosign keyless)

## Objetivo

Escribir desde cero una `ClusterPolicy` que rechace cualquier pod con imagen `ghcr.io/acme/capstone*` que no venga firmada en modo keyless por el workflow `release.yml` del repo capstone en `refs/heads/main`.

## Instrucciones

1. Copia el starter:
   ```bash
   cp -R starter/ /tmp/cap-12-02
   ```
2. Completa `verify-images.yaml`:
   - `kind: ClusterPolicy`, `apiVersion: kyverno.io/v2beta1`.
   - `validationFailureAction: Enforce`, `failurePolicy: Fail`.
   - `verifyImages[]` con `imageReferences`, `mutateDigest: true`, `verifyDigest: true`, `required: true`.
   - `attestors[].entries[].keyless.subject` apuntando a `.github/workflows/release.yml@refs/heads/main`.
   - `issuer: https://token.actions.githubusercontent.com`.
3. Deja listo `tests/kyverno-test.yaml` con casos pass/fail y recursos de ejemplo.
4. Corre `kyverno test .` (si tienes el binario). Si no, `validate.sh` chequea estructura.

## Entregable

- `verify-images.yaml` completo.
- `tests/kyverno-test.yaml` con al menos 1 caso `result: pass` y 1 `result: fail`.
- `NOTES.md` explicando como pasarias de Enforce a Audit mode temporalmente.

## Qué chequea el validator

- Estructura YAML y keys clave de la ClusterPolicy.
- Subject/issuer coherentes.
- `NOTES.md` mencionando Audit vs Enforce.
