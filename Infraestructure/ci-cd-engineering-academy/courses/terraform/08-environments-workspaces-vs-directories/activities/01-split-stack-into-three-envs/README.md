# tf-08-01 — Partir un stack monolítico en tres ambientes

## 1. Identificación

- **ID:** `tf-08-01-split-stack-into-three-envs`
- **Tecnología:** terraform
- **Módulo:** `08-environments-workspaces-vs-directories`
- **Dificultad:** intermediate
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

Recibes un stack **monolítico**: un único root module que crea los recursos de `dev`, `stg` y `prod` **en el mismo state**, con los valores de cada ambiente **hardcodeados** en el HCL y repetidos tres veces. El patrón es común en código "que empezó para un ambiente" y creció sin refactor.

Tu trabajo es refactorizarlo al patrón **directorios separados por ambiente con módulo compartido** (ver `theory/lesson.md` §3). El resultado:

- Un módulo en `solution/modules/app/` con la lógica reutilizable.
- Tres root modules independientes: `solution/envs/dev/`, `solution/envs/stg/`, `solution/envs/prod/`.
- Cada ambiente mantiene **su propio `terraform.tfstate` local**.
- El código del módulo **no** contiene `if env == "prod"` ni similares.

> El validador funciona sobre un directorio de trabajo en `/tmp/`, para no ensuciar tu checkout del curso.

## 3. Objetivos

Al terminar deberías poder:

- Leer un stack monolítico y detectar las variables que son "lo mismo pero con otro valor" entre ambientes.
- Extraer esa lógica a un módulo paramétrico.
- Crear roots por ambiente que consuman el módulo.
- Verificar que los states son físicamente independientes.
- Explicar por qué este refactor reduce el blast radius de un `apply` erróneo.

## 4. Prerrequisitos

- Terraform ≥ 1.3 u OpenTofu ≥ 1.6 instalado y en el `PATH`.
- `bash` ≥ 4, `jq` (opcional pero útil).
- Sin coste: todo corre con providers didácticos (`random`, `local`).
- Puertos: ninguno.

## 5. Instrucciones

Trabajarás en `/tmp/tf-08-01/`. Crea el espacio y copia el starter:

```bash
rm -rf /tmp/tf-08-01
mkdir -p /tmp/tf-08-01
cp -R <ruta-al-repo>/courses/terraform/08-environments-workspaces-vs-directories/activities/01-split-stack-into-three-envs/starter/. /tmp/tf-08-01/
cd /tmp/tf-08-01
ls
```

Vas a trabajar sobre `/tmp/tf-08-01/`. **No edites `starter/` directamente.**

### Paso 1 — explorar el stack monolítico

```bash
cd /tmp/tf-08-01/monolith
terraform init
terraform apply -auto-approve
cat out/*.json
```

Observa que:

- Hay un único `terraform.tfstate` que contiene los recursos de los tres ambientes.
- `main.tf` define tres bloques `random_pet.<env>`, tres `local_file.<env>` casi idénticos, con los valores pegados.
- Si borras el recurso de dev con `terraform destroy -target=random_pet.dev` y haces `apply`, también podrías por error targetear prod. Blast radius = los tres ambientes.

Haz `terraform state list` y lee la salida. Identifica, al menos:

- Qué recursos cambian **por ambiente** sólo en sus *valores* (p. ej. `replicas`, `class`).
- Qué recursos son **idénticos** salvo por el nombre del ambiente.
- Qué cosas podrían vivir en un módulo reusable.

### Paso 2 — crear el módulo compartido

Crea `/tmp/tf-08-01/modules/app/` con:

- `main.tf` que declare los recursos `random_pet`, `random_id` (deploy token con `keepers`) y `local_file` del manifiesto.
- `variables.tf` con, al menos: `environment`, `project`, `replica_count`, `instance_class_label`, `out_dir`.
- `outputs.tf` con `name`, `manifest_path`, `manifest`.

**Prohibido** usar `terraform.workspace` o `var.environment == "prod"` para ramificar comportamiento. El ambiente llega como **dato**.

Pista: puedes mirar `examples/01-env-per-directory/modules/app/` del módulo del curso si te atascas, pero intenta primero tú.

### Paso 3 — crear los tres ambientes

Crea `/tmp/tf-08-01/envs/dev/`, `/tmp/tf-08-01/envs/stg/`, `/tmp/tf-08-01/envs/prod/`. Cada uno debe tener:

- `versions.tf` con `required_version`, `required_providers` (si aplica desde el root) y `backend "local"` apuntando a `terraform.tfstate` **en el propio directorio**.
- `main.tf` con un `module "app" { source = "../../modules/app" ... }` y las variables adecuadas para ese ambiente.
- Opcionalmente, un `terraform.tfvars` con comentarios.

Valores sugeridos (puedes ajustarlos; el validador no exige valores exactos, exige que los tres ambientes queden funcionando y aislados):

| Ambiente | replica_count | instance_class_label |
|----------|---------------|----------------------|
| dev      | 1             | small                |
| stg      | 2             | medium               |
| prod     | 3             | large                |

### Paso 4 — aplicar cada ambiente

```bash
for env in dev stg prod; do
  (cd /tmp/tf-08-01/envs/$env && terraform init && terraform apply -auto-approve)
done
```

Debes ver:

- `/tmp/tf-08-01/envs/dev/terraform.tfstate` (y análogos para stg, prod).
- `/tmp/tf-08-01/envs/dev/out/manifest.json` (y análogos).
- `terraform plan` dentro de cada ambiente dice `No changes`.

### Paso 5 — demostrar aislamiento

```bash
cd /tmp/tf-08-01/envs/dev
terraform state list   # solo recursos de dev
cd /tmp/tf-08-01/envs/prod
terraform state list   # solo recursos de prod
```

El monolito (si no lo has destruido) sigue siendo un recurso aparte. Puedes destruirlo cuando quieras:

```bash
cd /tmp/tf-08-01/monolith
terraform destroy -auto-approve
```

### Paso 6 — validar

```bash
bash <ruta-al-repo>/courses/terraform/08-environments-workspaces-vs-directories/activities/01-split-stack-into-three-envs/tests/validate.sh /tmp/tf-08-01
```

El validador comprueba:

1. Existen `envs/{dev,stg,prod}/main.tf` y cada uno declara `module "app"` con `source = "../../modules/app"`.
2. Existe `modules/app/main.tf` con los recursos esperados.
3. **El módulo NO ramifica por nombre de ambiente** (no hay `var.environment == "prod"` ni `terraform.workspace == ...` en el cuerpo del módulo).
4. Cada ambiente tiene **su propio** `terraform.tfstate` local, y los tres states son distintos entre sí.
5. Cada state menciona su propio `environment` y no menciona los nombres de los otros ambientes.
6. `terraform plan` corre limpio (`No changes`) en los tres.

## 6. Resultado esperado

- `/tmp/tf-08-01/modules/app/{main,variables,outputs}.tf` existe.
- `/tmp/tf-08-01/envs/{dev,stg,prod}/{versions,main}.tf` existen.
- Cada `envs/<X>/` tiene su propio `terraform.tfstate` y su propio `out/manifest.json`.
- `terraform plan` idempotente en los tres.
- Validador imprime `RESULT: 6/6 checks OK`.

## 7. Criterios de aceptación

- No se duplica código entre los tres `envs/<X>/main.tf` — cada uno es casi idéntico, salvo las variables de entrada al módulo.
- El módulo es **portable**: si inventas un cuarto ambiente `qa` basta con crear `envs/qa/` siguiendo el patrón.
- No hay `if`/ternarios dependientes del nombre del ambiente dentro de `modules/app/`.

## 8. Validación

```bash
bash courses/terraform/08-environments-workspaces-vs-directories/activities/01-split-stack-into-three-envs/tests/validate.sh /tmp/tf-08-01
```

## 9. Preguntas de reflexión

1. ¿Qué ganaste al mover la lógica a `modules/app/`? ¿Qué perdiste?
2. Si tuvieras que proteger `prod` de un `apply` desde el runner de PR, ¿qué le añadirías a `envs/prod/`? (Pista: no es más HCL.)
3. En este lab todos los ambientes usan el mismo módulo local. Si quisieras **promoción trazable** (dev corre v1.4.2, stg v1.4.3, prod v1.4.1 porque se hizo rollback), ¿qué cambiarías en `source =`?
4. ¿Por qué el validador exige que *no* aparezca `var.environment == "prod"` en el módulo? ¿Cuál es la crítica concreta a ese patrón?

## 10. Extensiones

- Añade un cuarto ambiente `qa` siguiendo el mismo patrón. Debe funcionar sin modificar `modules/app/`.
- Reemplaza `source = "../../modules/app"` por `source = "git::...?ref=vX.Y.Z"` usando un repo propio (requiere publicar el módulo).
- Añade un `terraform.tfvars` por ambiente y mueve los valores de `main.tf` a ahí.

## 11. Limpieza

```bash
for env in dev stg prod; do
  (cd /tmp/tf-08-01/envs/$env 2>/dev/null && terraform destroy -auto-approve) 2>/dev/null || true
done
(cd /tmp/tf-08-01/monolith 2>/dev/null && terraform destroy -auto-approve) 2>/dev/null || true
rm -rf /tmp/tf-08-01
```
