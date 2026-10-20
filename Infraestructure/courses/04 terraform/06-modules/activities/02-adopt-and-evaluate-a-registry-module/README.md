# tf-06-02 — Adoptar (o no) un módulo del Registry: evaluación crítica

## 1. Identificación

- **ID:** `tf-06-02-adopt-and-evaluate-a-registry-module`
- **Tecnología:** terraform
- **Módulo:** `06-modules`
- **Dificultad:** intermediate
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

Tu equipo necesita un bucket S3 y Google te lanzó al primer resultado del Terraform Registry. Antes de poner `source = "x/y/z"` en producción, tu trabajo es **evaluar** ese módulo con criterios objetivos y escribir una **recomendación por escrito** con tu veredicto: **adopt**, **adopt con cambios**, o **reject**.

Esta actividad es **independiente**: no te damos el módulo "correcto". Eliges tú entre tres candidatos sugeridos (o uno de tu elección) y produces el documento. El validador no evalúa tu veredicto — evalúa que tu `EVALUATION.md` tenga **estructura completa** y que los campos tengan contenido real.

## 3. Objetivos

Al terminar deberías poder:

- Clonar o descargar la fuente de un módulo público y leerla con criterio.
- Aplicar los 8 criterios de evaluación de la sección 11 de la lección a un módulo real.
- Escribir una recomendación por escrito con **evidencia** (citas de archivos del módulo).
- Decidir un veredicto defendible.

## 4. Prerrequisitos

- `git` instalado (clonar el fuente del módulo).
- Terraform **o** OpenTofu opcional (útil para `init` y leer `.terraform/modules/modules.json`).
- Acceso a internet para clonar.
- Un editor para escribir el `EVALUATION.md`.

## 5. Instrucciones

### Paso 1 — elige un módulo

Elige **uno** de los candidatos:

- `terraform-aws-modules/vpc/aws` → <https://github.com/terraform-aws-modules/terraform-aws-vpc>
- `terraform-aws-modules/s3-bucket/aws` → <https://github.com/terraform-aws-modules/terraform-aws-s3-bucket>
- `cloudposse/label/null` → <https://github.com/cloudposse/terraform-null-label>

O uno de tu elección del Registry público. **No** uses el `safe-bucket` del ejemplo 01 (es nuestro, no cuenta).

### Paso 2 — baja la fuente

Trabaja en `/tmp/tf-06-02/`:

```bash
rm -rf /tmp/tf-06-02
mkdir -p /tmp/tf-06-02
cd /tmp/tf-06-02

# Ejemplo con s3-bucket; sustituye por el que hayas elegido:
git clone --depth 50 https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git module-src
```

### Paso 3 — lee la fuente

Dedica tiempo real. Mira:

- `README.md` principal.
- `main.tf`, `variables.tf`, `outputs.tf` (del root del repo, no de `examples/`).
- `versions.tf` para `required_providers` y `required_version`.
- `examples/` para ver cómo se consume.
- `.github/workflows/` o `.gitlab-ci.yml` para ver si tiene CI.
- `CHANGELOG.md` para ver política de versionado.
- `tests/` o `*.tftest.hcl` para tests.
- Issues abiertos recientes y respuesta del maintainer.

### Paso 4 — escribe `EVALUATION.md`

En `/tmp/tf-06-02/EVALUATION.md`. Debe tener **todas** estas secciones como headers `##` (el validador las busca por nombre):

- `## Módulo evaluado` — nombre + URL + versión evaluada.
- `## Mantenimiento` — último commit, cadencia de releases, respuesta a issues. Da evidencia.
- `## Pin de providers` — ¿`required_providers` con constraint? ¿cuál? Cita el `versions.tf`.
- `## Safe defaults` — ¿crea recursos seguros por default? P. ej. ¿bucket privado?, ¿SG cerrado? Cita.
- `## Tests` — ¿tiene `terraform test`, Terratest, o solo `examples/`? Cita rutas.
- `## Documentación` — ¿`README.md` completo? ¿Inputs/Outputs tabulados? ¿`terraform-docs`?
- `## SemVer y breaking changes` — ¿breaking changes van a major? Cita CHANGELOG.
- `## Superficie (tamaño de API)` — número de inputs/outputs. Es grande/mediana/pequeña y qué implica.
- `## Riesgos` — lo que te preocupa (p. ej. "configura `provider "aws"` dentro", "default `public-read`", "no pinnea provider").
- `## Veredicto` — una de `adopt`, `adopt-con-cambios`, `reject`. Justifica en 2-5 frases.

Cada sección (excepto `## Módulo evaluado` y `## Veredicto`) debe tener al menos **40 caracteres** de contenido real. No vale escribir "ok" o "sí".

### Paso 5 — valida

```bash
bash /ruta/al/repo/courses/terraform/06-modules/activities/02-adopt-and-evaluate-a-registry-module/tests/validate.sh
```

El validador:

- Verifica que `/tmp/tf-06-02/module-src/` existe (hiciste clone).
- Verifica que `/tmp/tf-06-02/EVALUATION.md` tiene las 10 secciones.
- Verifica que cada sección tiene suficiente contenido.
- Verifica que el `## Veredicto` contiene una de las tres palabras clave.
- **NO** evalúa tu veredicto; solo que exista y sea una de las opciones válidas.

## 6. Resultado esperado

- `/tmp/tf-06-02/module-src/` con el repo clonado del módulo elegido.
- `/tmp/tf-06-02/EVALUATION.md` con las 10 secciones completas.
- Tu veredicto defendible frente a un code review.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- Cada sección cita **evidencia** del repo del módulo (nombre de archivo, línea aproximada o cita).
- El veredicto es consistente con las secciones anteriores (si listas 3 riesgos graves, no puedes decir "adopt" sin explicar por qué los aceptas).

## 8. Validación

```bash
bash courses/terraform/06-modules/activities/02-adopt-and-evaluate-a-registry-module/tests/validate.sh
```

## 9. Preguntas de reflexión

1. Si tu veredicto fue "adopt", ¿qué controles pondrías en el PR que lo introduce (pin de versión, revisor específico, lint, policy as code)?
2. Si fue "reject", ¿qué alternativas consideraste? ¿Escribirlo tú (como en `activities/01`) sería más barato que arrastrar la dependencia?
3. ¿Qué pasaría si en 6 meses el módulo deja de recibir commits? ¿Cómo lo detectas y cuál es tu plan?
4. Un compañero propone subir el `version` del módulo de `~> 5.0` a `~> 6.0` sin leer el CHANGELOG. ¿Qué le dices?

## 10. Extensiones

- Repite la evaluación con un **segundo** módulo y compáralos (`EVALUATION-compare.md`).
- Escribe un pequeño script que use `terraform init` + `cat .terraform/modules/modules.json` para extraer la versión real resuelta.
- Propón un **ADR** interno con la política de adopción de módulos de terceros de tu equipo (criterios obligatorios, revisor, pin, CI).

## 11. Limpieza

```bash
rm -rf /tmp/tf-06-02
```
