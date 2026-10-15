# tf-14-01 — Adoptar infra legada vía `import {}` + `-generate-config-out`

## 1. Identificación

- **ID:** `tf-14-01-adopt-legacy-infra-via-import`
- **Tecnología:** terraform
- **Módulo:** `14-platform-patterns-drift-and-refactoring-at-scale`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Tu equipo heredó tres archivos de configuración creados a mano hace meses por otro equipo. Nadie los ha gestionado con IaC. El objetivo de hoy es **adoptarlos al state de Terraform sin modificar los archivos reales**, usando el flujo moderno (`import {}` block + `terraform plan -generate-config-out`).

Este es el flujo canónico de **bootstrap** cuando una org empieza a adoptar Terraform sobre una cuenta cloud con infra pre-existente. Lo practicas aquí sobre `local_file` para que sea reproducible sin cloud ni coste.

## 3. Objetivos

- Declarar bloques `import {}` para tres recursos pre-existentes.
- Generar HCL inicial con `terraform plan -generate-config-out=generated.tf`.
- Limpiar el HCL generado hasta que el plan sea `No changes`.
- Verificar que `terraform state list` muestra los tres recursos adoptados.

## 4. Prerrequisitos

- Terraform ≥ 1.5.
- Shell POSIX.
- Haber leído `theory/lesson.md` secciones 4.2 y 5.
- Haber hecho el ejemplo 02.
- **Costos**: ninguno (todo local).

## 5. Instrucciones

### 5.1 Bootstrap de la infra "legacy"

Desde esta carpeta:

```bash
bash starter/bootstrap.sh
```

Esto crea tres archivos en `/tmp/tf14-act01-legacy/`:

- `app-alpha.conf`
- `app-beta.conf`
- `app-gamma.conf`

Y copia el starter a `/tmp/tf14-act01/` como tu working directory. **Trabaja ahí**, no edites `starter/` directamente.

```bash
cd /tmp/tf14-act01
ls starter-notes.md   # tu guía dentro del workdir
```

### 5.2 Escribir los `import {}` blocks

Edita `imports.tf` (ya existe vacío con comentarios) para declarar un bloque `import` por cada archivo:

```hcl
import {
  to = local_file.app_alpha
  id = "/tmp/tf14-act01-legacy/app-alpha.conf"
}
# ... beta, gamma
```

Nombres sugeridos en el state: `local_file.app_alpha`, `local_file.app_beta`, `local_file.app_gamma`.

### 5.3 Generar el HCL

```bash
terraform init
terraform plan -generate-config-out=generated.tf
```

Si Terraform se queja de que `generated.tf` ya existe, bórralo y vuelve a intentar. Revisa el archivo generado.

### 5.4 Limpiar el HCL generado

Renombra `generated.tf` a `adopted.tf` y deja solo los atributos **relevantes** (`filename`, `content`, `file_permission`). Deja fuera atributos deprecados, `null`, o campos computados ruidosos que no quieras versionar.

### 5.5 Aplicar y verificar

```bash
terraform apply -auto-approve
terraform plan     # debe decir: No changes
terraform state list
```

### 5.6 Validar

```bash
bash /ruta/al/repo/courses/terraform/14-platform-patterns-drift-and-refactoring-at-scale/activities/01-adopt-legacy-infra-via-import/tests/validate.sh
```

(Puedes pasar un directorio con `bash tests/validate.sh /tmp/tf14-act01` o dejar el default).

## 6. Resultado esperado

- `/tmp/tf14-act01/terraform.tfstate` contiene **3 recursos** `local_file.app_{alpha,beta,gamma}`.
- `terraform plan` sobre el workdir produce `No changes`.
- Los 3 archivos originales en `/tmp/tf14-act01-legacy/` **siguen existiendo con el mismo contenido** (no fueron recreados).

## 7. Criterios de aceptación

| Criterio | Cómo se mide |
|----------|--------------|
| 3 recursos en state | `terraform state list` muestra `local_file.app_alpha`, `..._beta`, `..._gamma` |
| Plan limpio | `terraform plan` sale sin cambios |
| Archivos legacy intactos | Timestamp y contenido no cambian tras el `apply` |
| HCL versionable | `adopted.tf` existe, no hay `generated.tf` residual |

## 8. Validación

El script `tests/validate.sh` comprueba todo lo anterior y reporta `PASS/FAIL` por chequeo.

## 9. Preguntas de reflexión

1. ¿Por qué `terraform import` CLI (imperativo) es peor para una org con PRs obligatorios que `import {}` + `-generate-config-out`?
2. ¿Qué pasaría si corrieras `apply` **sin** limpiar primero el HCL generado y hubiera un atributo con un `default` distinto del valor real?
3. Si tuvieras **300** recursos legacy en lugar de 3, ¿cómo partirías el trabajo? ¿Lo harías en un solo PR?
4. ¿Qué controles de seguridad agregarías en el PR de adopción? (pista: policy-as-code sobre el plan JSON).

## 10. Extensiones

1. Simula un error: edita el `id` de un bloque import a una ruta inexistente y observa el error de `plan`.
2. Agrega un `moved {}` para renombrar `local_file.app_alpha` → `local_file.alpha` en un segundo paso. ¿Qué dice el plan?
3. Escribe un script Bash que lea un YAML `services.yaml` y genere los bloques `import {}` automáticamente (bulk de verdad).

## 11. Limpieza

```bash
cd ~
rm -rf /tmp/tf14-act01 /tmp/tf14-act01-legacy
```
