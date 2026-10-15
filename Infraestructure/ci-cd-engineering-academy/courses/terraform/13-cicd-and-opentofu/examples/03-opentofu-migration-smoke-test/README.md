# Ejemplo 03 — Smoke test de migración Terraform → OpenTofu

Script que, dado un stack HCL, corre el mismo ciclo con `terraform` y con `tofu`, compara outputs, confirma compatibilidad del state y del lockfile, y reporta cualquier divergencia.

## Archivos

- [`smoke-test.sh`](smoke-test.sh) — script ejecutable, parametrizable con `STACK_DIR` y `WORK_DIR`.
- [`stack/main.tf`](stack/main.tf) — stack mínimo (`random_pet` + `local_file`) sin dependencias cloud, para que el ejemplo sea reproducible sin credenciales.

## Qué prueba

1. **Instalación detectada**: `terraform --version` y `tofu --version`. Si falta `tofu`, aborta con instrucciones.
2. **Lockfile compatible**: `terraform init` genera `.terraform.lock.hcl`; `tofu init -lockfile=readonly` lo acepta sin regenerarlo.
3. **Plan equivalente**: `terraform plan -out=t.plan` y `tofu plan -out=o.plan` sobre el mismo state producen el mismo diff conceptual (comparación del `show -json`, ignorando campos volátiles como timestamps).
4. **State cross-read**: tras `terraform apply`, `tofu plan` sobre el mismo state file reporta "no changes".
5. **Vuelta atrás**: tras `tofu apply` (sin cambios), `terraform plan` también reporta "no changes" — el state sigue siendo legible por ambos.

## Cómo correrlo

```bash
# requisitos: terraform, tofu, jq
bash smoke-test.sh
# o con directorios custom:
STACK_DIR=./stack WORK_DIR=/tmp/tf-tofu-smoke bash smoke-test.sh
```

Salida esperada (resumida):

```
[1/5] versions          -> terraform 1.9.5 / tofu 1.8.x
[2/5] lockfile          -> OK: tofu reused terraform's lockfile
[3/5] plan equivalence  -> OK: show -json diff is empty
[4/5] state tf -> tofu  -> OK: no changes
[5/5] state tofu -> tf  -> OK: no changes
SMOKE TEST: PASS
```

## Qué NO prueba

- Features propias de OpenTofu (state encryption, provider-defined functions). Por diseño: el stack usa solo features comunes a ambos. Si tu stack usa esas features, no es portable *de vuelta* a TF.
- Comportamiento con providers cloud reales. El `random`/`local` quita costo y permisos; el principio ("misma estructura del plan") se traslada igual.
- Rendimiento. Para benchmarks reales, correr el smoke test con un stack grande y medir `time`.
