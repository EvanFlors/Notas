# Actividad 01 — Pipeline de validación local pre-apply

## 1. Identificación

- **ID:** `tf-12-01-add-validation-pipeline-locally`
- **Tecnología:** `terraform`
- **Módulo:** `12-testing-and-policy-as-code`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab

## 2. Contexto

Antes de automatizar en CI, el estudiante construye el pipeline **localmente** como un script `pre-apply.sh`. Esto fija la secuencia correcta de validaciones, obliga a decidir qué es `fail` vs `warn`, y produce un artefacto reutilizable (puede volverse un hook pre-commit o la base del job de GHA en `tf-13`).

## 3. Objetivos

- Escribir `pre-apply.sh` que encadene **cinco capas**: `terraform fmt -check`, `terraform validate`, `tflint`, `checkov`, `conftest`.
- Cada paso degrada con un mensaje `SKIP` si su binario no está instalado — el script **no falla por binario ausente**.
- Si el binario está presente y la validación falla, el script retorna `exit 1`.
- El script imprime un **resumen final** con `PASS` / `FAIL` / `SKIP` por capa.

## 4. Prerrequisitos

- `bash` ≥ 4.
- Opcionalmente: `terraform` ≥ 1.6, `tflint`, `checkov`, `conftest`. Si no están, el script debe seguir corriendo.
- Un módulo de ejemplo (incluido en `sample-module/`).

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Explorar el módulo de ejemplo

```bash
cd courses/terraform/12-testing-and-policy-as-code/activities/01-add-validation-pipeline-locally
ls sample-module/
cat sample-module/main.tf
```

Es un stack simple con un `random_pet` y un `local_file`. Está bien formateado y es sintácticamente válido — pero puede que no apruebe todas las capas en todas las máquinas (p. ej. tflint sin plugin de random podría warn).

### 5.2 Escribir `pre-apply.sh`

Crea `starter/pre-apply.sh` con la siguiente estructura. Rellena las secciones marcadas con `# TODO`.

```bash
#!/usr/bin/env bash
# pre-apply.sh — pipeline de validacion local pre-apply.
# Uso: ./pre-apply.sh <dir-del-modulo>

# NOTA: deliberadamente NO usamos 'set -o pipefail' porque algunos checks
# pipean a 'grep -q' y pipefail reportaria SIGPIPE como fallo espurio.
set -u

MOD_DIR="${1:-.}"
pass=0; fail=0; skip=0
report=""

add_result() { # label, status
  local label="$1" status="$2"
  report+="  [$status] $label\n"
  case "$status" in
    PASS) pass=$((pass+1));;
    FAIL) fail=$((fail+1));;
    SKIP) skip=$((skip+1));;
  esac
}

have() { command -v "$1" >/dev/null 2>&1; }

echo "== pre-apply pipeline on: $MOD_DIR =="

# TODO 1: terraform fmt -check -recursive "$MOD_DIR"
# TODO 2: terraform -chdir="$MOD_DIR" init -backend=false -input=false
# TODO 3: terraform -chdir="$MOD_DIR" validate
# TODO 4: tflint --chdir "$MOD_DIR"
# TODO 5: checkov -d "$MOD_DIR" --quiet --compact
# TODO 6: conftest test --policy "$MOD_DIR/policy" (si existe policy/)

echo
echo "== summary =="
printf "%b" "$report"
echo "PASS=$pass FAIL=$fail SKIP=$skip"
[ "$fail" -eq 0 ]
```

Para cada TODO, implementa el patrón:

```bash
if have terraform; then
  if terraform -chdir="$MOD_DIR" validate >/dev/null 2>&1; then
    add_result "terraform validate" PASS
  else
    add_result "terraform validate" FAIL
  fi
else
  add_result "terraform validate" SKIP
fi
```

### 5.3 Dar permisos y probar

```bash
chmod +x starter/pre-apply.sh
./starter/pre-apply.sh sample-module
```

En una máquina **sin ninguno de los binarios instalados**, deberías ver `SKIP` en todas las capas y el script debe salir con `exit 0`.

En una máquina con `terraform` instalado, al menos `fmt`, `init`, `validate` deben pasar en PASS sobre `sample-module/`.

### 5.4 Validar con el harness

```bash
bash tests/validate.sh
```

Debe terminar con `OK`.

## 6. Resultado esperado

- `starter/pre-apply.sh` existe, es ejecutable, y:
  - Imprime una línea por capa con `[PASS|FAIL|SKIP]`.
  - Devuelve `exit 0` si no hay fallos (aunque todo esté en SKIP).
  - Devuelve `exit 1` si alguna capa está en FAIL.

## 7. Criterios de aceptación

- [ ] Funcional: el script maneja las 5 capas y encadena en el orden correcto (fmt → validate → tflint → checkov → conftest).
- [ ] Degradación: ausencia de binario → `SKIP`, nunca `FAIL`.
- [ ] Idempotente: dos corridas seguidas sobre el mismo módulo producen la misma salida.
- [ ] Reproducible: el script no asume rutas absolutas; recibe el directorio como argumento.
- [ ] Mantenible: cada capa está en una función o bloque identificable.

## 8. Validación

```bash
bash tests/validate.sh
```

Verifica: script existe + ejecutable + corre sin error sobre `sample-module/` + emite líneas `PASS/FAIL/SKIP` + termina en `exit 0` cuando no hay FAIL.

## 9. Preguntas de reflexión

1. ¿Por qué este script **no** debería usar `set -o pipefail`? Da un ejemplo concreto donde pipefail rompería un check correcto.
2. ¿Por qué los binarios ausentes son `SKIP` y no `FAIL`? ¿Cuándo cambiarías esta decisión (CI vs local)?
3. Si una organización quiere **obligar** que todos los devs tengan `checkov` instalado, ¿cómo lo harías sin modificar `pre-apply.sh`? (pista: hook del repo).
4. ¿Qué pasaría si pusieras `conftest` **antes** de `terraform validate`? Explica el fallo que verías.
5. Para pasar este script a GitHub Actions en `tf-13`, ¿qué cambios harías? ¿Qué dejarías igual?

## 10. Extensiones

- **E1** — Añade medición de tiempos por capa (`time`) y súmalos en el resumen.
- **E2** — Añade un flag `--strict` que convierte SKIP en FAIL.
- **E3** — Produce un reporte JSON además del texto, para consumo por otro step de CI.
- **E4** — Añade capa 6: `terraform plan -out=plan.tfplan` + `terraform show -json plan.tfplan > plan.json` + `conftest test plan.json`.

## 11. Limpieza

```bash
rm -rf sample-module/.terraform sample-module/.terraform.lock.hcl /tmp/preapply-*
```
