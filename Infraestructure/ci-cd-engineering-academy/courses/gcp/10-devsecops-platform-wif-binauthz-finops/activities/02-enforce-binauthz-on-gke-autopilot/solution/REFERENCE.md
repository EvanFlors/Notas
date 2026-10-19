# REFERENCE — gcp-10-02-enforce-binauthz-on-gke-autopilot

> Referencia razonada. No es la única respuesta correcta.

## Archivos

- `binauthz-policy.yaml` — policy completa con default DENY, reglas por cluster y whitelist.
- `attestor.yaml` — nota de Container Analysis + attestor con PKIX.
- `terraform/binauthz.tf` — plantilla TF que materializa todo.
- `ADR-BINAUTHZ-ROLLOUT.md` — ADR del rollout DRYRUN → ENFORCED.

## Decisiones clave

1. **Default deny** forzado. Toda regla específica es un allow explícito.
2. **Dos clusters, dos modos**: prod `ENFORCED`, dev `DRYRUN`. Dev enseña, prod protege.
3. **Whitelist mínima** cubre pods de sistema de GKE Autopilot. Omitirla rompe el cluster.
4. **Attestor con PKIX** vinculado a una clave KMS. La clave privada no sale de KMS.
5. **Rollout en 2 fases** con observación de logs antes de endurecer.

## Trampas comunes

- Olvidar `admissionWhitelistPatterns` para `gcr.io/gke-release/*` en `ENFORCED` → el cluster no arranca.
- Firmar por tag → la garantía criptográfica desaparece.
- Pasar a `ENFORCED` sin observar los logs de `DRYRUN` → outage probable.
- Dar `roles/binaryauthorization.policyEditor` a developers → la policy pierde valor (cualquiera la relaja).
