# Ejemplo 02 — Cloud Run traffic splitting (canary 95/5)

## Que demuestra

- Un `google_cloud_run_v2_service` con **dos revisiones nombradas** (`capstone-api-v1`, `capstone-api-v2`) y un split 95/5.
- El rollback consiste en cambiar los `percent` a 100/0 — no hay rebuild ni redeploy.

## Validar

```bash
cd examples/02-cloud-run-traffic-splitting-canary
terraform init -backend=false -input=false
terraform validate
```

## Idea

- `template.revision` da nombre explicito a la revision; sin esto Cloud Run genera uno autoincremental y el rollback se vuelve mas delicado.
- Dos bloques `traffic` suman 100%: `v1=95`, `v2=5`.
- Para promover v2 → 100%: dejar un unico `traffic` apuntando a `v2` con `percent=100`. Para rollback inmediato: cambiar los dos `percent` a 100/0.

**No se despliega nada.** Es solo el artefacto Terraform.
