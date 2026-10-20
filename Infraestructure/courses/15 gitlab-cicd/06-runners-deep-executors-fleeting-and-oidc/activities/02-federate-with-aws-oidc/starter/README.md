# Starter — gl-06-02

Crea `/tmp/gl-06-oidc/` y produce tres archivos:

- `trust-policy.json` — para el role `gitlab-deployer-prod`.
- `.gitlab-ci.yml` — pipeline consumidor con `id_tokens:`.
- `README-INTENT.md` — tres secciones justificativas (ver README §5.4).

Guías rápidas:

- `Principal.Federated` es el ARN del provider: `arn:aws:iam::<ACCOUNT>:oidc-provider/gitlab.com`.
- `aud` suele ser `https://gitlab.com`; coincide con lo que declaras en `id_tokens:` del pipeline.
- Pinning recomendado del `sub`: `project_path:acme/web:ref_type:branch:ref:main:environment:production`.
- `aws sts assume-role-with-web-identity` requiere `--role-arn`, `--role-session-name`, `--web-identity-token`.
- Encabezados exactos para el Markdown: `## Trust policy — pinning`, `## Antipatrones`, `## Pipeline consumidor`.

Valida con:

```bash
bash ../tests/validate.sh /tmp/gl-06-oidc
```
