# Starter — aws-01-01-safe-account-setup

Esquema mínimo para arrancar. Copia este contenido a `/tmp/aws-01-setup/ACCOUNT-SETUP.md` y `COSTS.md`, luego rellena.

## Pasos sugeridos

```bash
mkdir -p /tmp/aws-01-setup
cd /tmp/aws-01-setup
touch ACCOUNT-SETUP.md COSTS.md
```

## Esqueleto de `ACCOUNT-SETUP.md`

```markdown
# Runbook: puesta en marcha segura de cuenta AWS

## Paso 1 — MFA en root
Descripcion: ...
Comando/navegacion:
` ` `bash
aws sts get-caller-identity --profile root  # debe mostrar :root — es la unica vez
` ` `
Verificacion: ...

## Paso 2 — Borrar access keys de root
...

## Paso 3 — IAM access to Billing
...

## Paso 4 — Budget con alerta
...

## Paso 5 — Admin humano no-root
...

## Paso 6 — Cerrar sesion de root
...

## Paso 7 — CloudTrail
...

## Cargos silenciosos (fuera de Free Tier)

- NAT Gateway: ~32 USD/mes por existir + 0.045 USD/GB procesado.
- ...
```

## Esqueleto de `COSTS.md`

```markdown
# Estimacion mensual — workload trivial

## Workload
- 1 x EC2 t3.micro, 730 h/mes, us-east-1, Linux on-demand
- 10 GB S3 Standard
- 50 GB egress

## Estimacion
| Item | Precio unitario | Cantidad | Mensual |
|------|-----------------|----------|---------|
| EC2 t3.micro | ... | 730 h | ... |
| S3 Standard | 0.023 USD/GB | 10 GB | ... |
| Egress | 0.09 USD/GB | 50 GB (menos free tier) | ... |
| Total |  |  | X USD |

## Comentarios
...
```

Recuerda: usa `123456789012` como `AccountId` placeholder. **No** pegues IDs reales.
