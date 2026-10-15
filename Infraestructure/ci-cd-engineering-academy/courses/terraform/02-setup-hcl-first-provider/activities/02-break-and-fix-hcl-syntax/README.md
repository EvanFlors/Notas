# Actividad 02 — Break-and-fix: 4 errores de HCL

## 1. Identificación

- **ID:** `tf-02-02-break-and-fix-hcl-syntax`
- **Tecnología:** terraform
- **Módulo:** `02-setup-hcl-first-provider`
- **Dificultad:** beginner
- **Duración estimada:** 40 min
- **Tipo:** debug

## 2. Contexto

En un día cualquiera de trabajo con Terraform vas a leer código ajeno (o tuyo de hace meses) y lidiar con errores de HCL. Esta actividad planta **cuatro** errores en un stack que *debería* funcionar: tres sintácticos/semánticos los detecta `terraform validate`, y uno adicional lo detecta `terraform fmt -check` + lectura humana. Tu trabajo es dejarlo todo en verde **sin cambiar la intención del código**.

## 3. Objetivos

- Leer un error de `terraform validate` y mapearlo a la línea exacta del `.tf`.
- Diferenciar errores de **sintaxis HCL** (parseo), de **referencia** (identificador no declarado), de **schema del provider** (atributo inválido/requerido faltante) y de **formato**.
- Dejar `terraform fmt -check` y `terraform validate` en verde.

## 4. Prerrequisitos

- `terraform` ≥ 1.5.
- Haber completado la actividad 01.

## 5. Instrucciones

### Paso 0 — Montar el starter

```bash
export WORK="/tmp/tf-02-02"
rm -rf "$WORK" && mkdir -p "$WORK"
cp courses/terraform/02-setup-hcl-first-provider/activities/02-break-and-fix-hcl-syntax/starter/*.tf "$WORK/"
cd "$WORK"
```

(ajusta la ruta de origen al clon de este repo).

### Paso 1 — Reproduce los errores

```bash
terraform init    # debería tener éxito (los providers son correctos)
terraform validate
```

Verás **múltiples diagnósticos**. En total hay **4 errores** repartidos entre `main.tf` y `providers.tf`:

- 1 de **sintaxis HCL** (parseo falla).
- 1 de **schema** (atributo que no existe en el recurso).
- 1 de **referencia** (identificador que no existe en el stack).
- 1 de **formato** (válido pero `terraform fmt -check` falla).

### Paso 2 — Arréglalos

Edita los archivos **sin cambiar la intención**:

- Mantén el nombre de los recursos.
- Mantén los providers declarados.
- No elimines recursos.
- Sí puedes agregar atributos requeridos faltantes, corregir sintaxis, renombrar referencias.

### Paso 3 — Verifica

```bash
terraform fmt -check
terraform validate
terraform plan
```

Los tres deben pasar. `plan` debe mostrar `Plan: 2 to add, ...` (no debería intentar destruir nada).

### Paso 4 — Opcional: aplica y destruye

```bash
terraform apply -auto-approve
terraform destroy -auto-approve
```

Deja el state vacío al terminar.

## 6. Resultado esperado

- `terraform fmt -check` → exit 0.
- `terraform validate` → `Success!`.
- `terraform plan` → sin errores; muestra `+ create` de los recursos definidos.

## 7. Criterios de aceptación

- Fix mínimo: no reescribas el stack entero.
- Sin cambiar nombres de recurso ni providers.
- Sin agregar `# TODO` ni comentarios de "aquí había un bug".

## 8. Validación

```bash
bash tests/validate.sh
```

El validador corre `fmt -check` y `validate`; ambos deben pasar.

## 9. Preguntas de reflexión

1. ¿Cuál de los 4 errores atrapa `terraform validate` y cuál solo lo atrapa `terraform plan`? ¿Por qué?
2. Si `init` hubiera fallado, ¿`validate` podría igual darte información útil?
3. ¿Qué cambiaría si el error de referencia apuntara a un recurso **que sí existe en otro módulo** (no en el root)?

## 10. Extensiones

- Agrega un `pre-commit` hook que corra `terraform fmt -check` y `terraform validate` antes de cada commit.
- Escribe un 5º error "trampa" para un compañero y haz que `validate` + `fmt -check` sigan siendo suficientes para detectarlo.

## 11. Limpieza

```bash
cd /tmp
terraform -chdir=/tmp/tf-02-02 destroy -auto-approve 2>/dev/null || true
rm -rf /tmp/tf-02-02 /tmp/tf-02-02-out
```
