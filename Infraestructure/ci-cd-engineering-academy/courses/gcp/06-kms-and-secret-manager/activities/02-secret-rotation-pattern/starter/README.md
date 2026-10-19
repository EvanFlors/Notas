# Starter — gcp-06-02

```bash
mkdir -p /tmp/gcp-06-secret
cp -r starter/* /tmp/gcp-06-secret/
```

Edita cada archivo siguiendo `../README.md`.

## Placeholders obligatorios

- `project_id = "demo-secret-example"`.
- `member = "serviceAccount:sa-run-app@demo-secret-example.iam.gserviceaccount.com"`.
- Todo `secret_data` debe empezar por `fake-sk-`.

## Qué NO hacer

- No pegar valores reales de API keys ni tokens.
- No usar project IDs reales de ningún ambiente (dev/prod/sandbox).
- No commit del archivo `terraform.tfstate` si en algún momento ejecutas `init` localmente.
