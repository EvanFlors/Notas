# tf-06-01 — Escribir tu primer módulo (`greeting-site`)

## 1. Identificación

- **ID:** `tf-06-01-write-your-first-module`
- **Tecnología:** terraform
- **Módulo:** `06-modules`
- **Dificultad:** intermediate
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a diseñar y publicar (localmente) un **módulo propio** llamado `greeting-site`. Simula un "sitio" como un conjunto de archivos: `index.html`, `robots.txt` y un `metadata.json`. Internamente usa los providers `local` y `random`, igual que el ejemplo 01, pero esta vez **lo escribes tú**.

El objetivo no es el contenido del sitio: es **demostrar que puedes aterrizar las convenciones de un módulo** (inputs tipados y documentados, outputs útiles, `README.md`, pin de providers, ejemplo de uso que hace `init`/`validate` sin error).

El validador comprueba la **estructura** y la **documentación** del módulo, no estilo prosa. Es exigente con lo que importa (hay `README.md`, hay `variables.tf`, cada variable tiene `description`, hay un ejemplo que `terraform init` sin error) y permisivo con lo que no (nombres de recursos, orden de archivos).

## 3. Objetivos

Al terminar deberías poder:

- Estructurar un módulo con `README.md`, `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, y un subdirectorio `examples/basic/`.
- Declarar `required_providers` en el módulo sin configurar `provider "..." {}` (eso es del root).
- Escribir variables con `type` y `description`; outputs con `description`.
- Añadir al menos una `validation {}` sobre un input.
- Escribir un ejemplo ejecutable (`examples/basic/`) que use `source = "../.."`.
- Documentar el módulo en su `README.md` con secciones: Qué hace, Uso, Inputs, Outputs.

## 4. Prerrequisitos

- Terraform **o** OpenTofu instalado (≥ 1.3). Verifica: `terraform version` o `tofu version`.
  - Linux/macOS: `brew install terraform` o `brew install opentofu`, o binario de <https://developer.hashicorp.com/terraform/install>.
- `bash` ≥ 4.
- Sin costo (providers didácticos `local` y `random`).

> Si no tienes Terraform/OpenTofu, el validador imprime instrucciones de instalación y sale con SKIP.

## 5. Instrucciones

Trabaja en `/tmp/tf-06-01/` (así el validador sabe dónde mirar). Crea el directorio:

```bash
rm -rf /tmp/tf-06-01
mkdir -p /tmp/tf-06-01/greeting-site
cd /tmp/tf-06-01/greeting-site
```

### Paso 1 — estructura mínima del módulo

Crea en `/tmp/tf-06-01/greeting-site/`:

```
greeting-site/
├── README.md
├── versions.tf
├── variables.tf
├── main.tf
├── outputs.tf
└── examples/
    └── basic/
        ├── versions.tf
        ├── providers.tf
        └── main.tf
```

### Paso 2 — `versions.tf` del módulo

Declara `required_version >= 1.3.0` y `required_providers` para `local` (`~> 2.4`) y `random` (`~> 3.5`). **No** declares `provider "..." {}`.

### Paso 3 — `variables.tf` del módulo

Mínimo con estas variables (todas con `description`):

| Variable | Tipo | Default | Requisito |
|----------|------|---------|-----------|
| `site_name` | string | — (sin default) | **Debe** tener `validation` que exija kebab-case (`^[a-z0-9-]+$`), 3-40 chars. |
| `base_path` | string | `/tmp/tf-06-01/sites` | — |
| `allow_crawlers` | bool | `false` (safe default) | — |
| `greeting` | string | `"hello"` | — |

### Paso 4 — `main.tf` del módulo

Debe:

- Generar un sufijo random con `random_string` (longitud 4, alfanumérico sin especiales), `keepers = { name = var.site_name }`.
- Materializar un `index.html` en `${var.base_path}/${var.site_name}-<sufijo>/index.html` con el `greeting` embebido.
- Materializar un `metadata.json` con `{ name, greeting, allow_crawlers }`.
- Materializar un `robots.txt`: si `allow_crawlers = true`, `User-agent: *\nAllow: /`; si no, `User-agent: *\nDisallow: /`.

### Paso 5 — `outputs.tf` del módulo

Expón, con `description` cada uno:

- `site_name_effective` — el nombre con el sufijo random.
- `site_path` — ruta en el host.
- `index_file` — ruta al `index.html`.

### Paso 6 — `README.md` del módulo

Debe contener, como mínimo, las secciones (headers `##`):

- `## Qué hace`
- `## Uso`
- `## Inputs`
- `## Outputs`

Y dentro de `## Uso`, un bloque de código HCL que muestre un `module "..." {}` consumiendo tu módulo.

### Paso 7 — `examples/basic/`

Un root module ejecutable que consume tu módulo con `source = "../.."`:

- `versions.tf`: mismos `required_providers`.
- `providers.tf`: `provider "local" {}` y `provider "random" {}`.
- `main.tf`: `module "demo" { source = "../.." ; site_name = "my-demo" ; greeting = "hola tf-06" }`.

### Paso 8 — validar que `init` y `validate` funcionen

```bash
cd /tmp/tf-06-01/greeting-site/examples/basic
terraform init -input=false
terraform validate
```

Si `init` falla por red (`local` y `random` no están en cache), vuelve a intentar. Son providers pequeños oficiales.

### Paso 9 — correr el validador

```bash
bash /ruta/al/repo/courses/terraform/06-modules/activities/01-write-your-first-module/tests/validate.sh
```

El validador comprueba estructura, documentación y que `examples/basic` haga `init`+`validate` sin error. **No** corre `apply`.

## 6. Resultado esperado

- Árbol de archivos de los pasos 1-7 presente en `/tmp/tf-06-01/greeting-site/`.
- `terraform validate` en `examples/basic/` sale con `Success!`.
- `README.md` del módulo tiene las 4 secciones.
- Al menos una variable con `validation {}`.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- El módulo **no** tiene `provider "..." {}` dentro.
- Cada `variable` tiene `description`; cada `output` tiene `description`.
- `examples/basic/main.tf` referencia `source = "../.."` (no copia-pega).

## 8. Validación

```bash
bash courses/terraform/06-modules/activities/01-write-your-first-module/tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Qué pasa si pones `provider "local" {}` dentro del módulo y luego el consumidor también? ¿Quién gana?
2. ¿Por qué `site_name` no tiene default y `greeting` sí?
3. Cambias `greeting` de `string` a `list(string)` en la próxima versión del módulo. ¿Es breaking change? ¿Qué deberías hacer con la versión?
4. Si publicas este módulo en Git y lo consumen con `source = "git::...?ref=main"`, ¿qué riesgo asumen? ¿Qué les recomiendas?

## 10. Extensiones

- Añade un input `tags` (`map(string)`) que se materialice en `tags.json`. Documenta en `README.md`.
- Añade un output `all_files` (`list(string)`) con las rutas de los 3 archivos. Pruébalo desde `examples/basic/` con un `output`.
- Añade un segundo ejemplo `examples/with-tags/` que use el nuevo input.
- Añade `terraform-docs` para generar las tablas Inputs/Outputs automáticamente (opcional, requiere binario).

## 11. Limpieza

```bash
rm -rf /tmp/tf-06-01
```
