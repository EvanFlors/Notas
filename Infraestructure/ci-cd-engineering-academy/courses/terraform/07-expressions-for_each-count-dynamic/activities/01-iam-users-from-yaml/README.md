# tf-07-01 — Usuarios "IAM" desde YAML con `for_each`

## 1. Identificación

- **ID:** `tf-07-01-iam-users-from-yaml`
- **Tecnología:** terraform
- **Módulo:** `07-expressions-for_each-count-dynamic`
- **Dificultad:** intermediate
- **Duración estimada:** 50 min
- **Tipo:** guided-lab

## 2. Contexto

En plataformas reales, los usuarios/roles/grupos los administra el equipo de seguridad editando un YAML en un repo de Git. Terraform **consume** ese YAML y materializa los recursos. Separar datos (YAML) de código (HCL) es lo que hace sostenible el stack a escala.

En esta actividad vas a emular ese patrón sin cloud: a partir de un YAML con 4 "usuarios", crear un `local_file` por usuario con sus datos. La clave del `for_each` será el `username`.

## 3. Objetivos

- Usar `yamldecode(file(...))` para cargar datos externos.
- Transformar una lista de objetos a un map con una `for` expression.
- Alimentar `for_each` con el map resultante usando claves estables.
- Verificar que el stack es idempotente (segundo `apply` no cambia nada).

## 4. Prerrequisitos

- Terraform ≥ 1.3 (`for_each`, `optional()`, `templatefile` ya estables).
- Haber leído `theory/lesson.md` y hecho los tres ejemplos del módulo.
- Software: `bash`, `grep`.
- Costos: 0 (todo local).

## 5. Instrucciones

Trabaja en `/tmp/tf-07-01/` para no ensuciar el repo:

```bash
mkdir -p /tmp/tf-07-01
cp -r starter/* /tmp/tf-07-01/
cd /tmp/tf-07-01
```

Dentro de `starter/` tienes:

- `users.yaml` — ya tiene 4 usuarios (`alice`, `bob`, `carol`, `dave`).
- `variables.tf` — vacío a propósito; no necesitas variables para esta actividad.
- `main.tf` — con 3 `TODO` numerados que debes completar.

Pasos:

1. **TODO 1**: en `locals`, carga `users.yaml` con `yamldecode(file(...))` y transfórmalo a un **map keyed por `username`**. Usa `for u in local.users_raw : u.username => u`.
2. **TODO 2**: declara el recurso `local_file.user` con `for_each = local.users` y:
   - `filename  = "${path.module}/out/${each.key}.txt"`
   - `content` con `name`, `email`, `role` y `groups` (concatenados con `,`).
3. **TODO 3**: declara un `output "created_users"` que devuelva **las claves** del map (`keys(local_file.user)`).

Luego:

```bash
terraform init
terraform apply -auto-approve
ls out/        # alice.txt bob.txt carol.txt dave.txt
terraform apply -auto-approve   # idempotente: "No changes"
```

Finalmente, corre el validador desde el directorio de la actividad (en el repo):

```bash
bash tests/validate.sh /tmp/tf-07-01
```

## 6. Resultado esperado

- 4 archivos en `/tmp/tf-07-01/out/`: `alice.txt`, `bob.txt`, `carol.txt`, `dave.txt`.
- Cada uno contiene `name=...`, `email=...`, `role=...`, `groups=...`.
- Segunda ejecución de `terraform apply` reporta `No changes`.

## 7. Criterios de aceptación

- `main.tf` usa `yamldecode(file(...))`.
- `main.tf` usa `for_each` (no `count`).
- Los 4 archivos existen con contenido correcto.
- `terraform plan` es `No changes` tras el `apply` inicial.

## 8. Validación

```bash
bash tests/validate.sh /tmp/tf-07-01
```

El script verifica:
- Existencia de `alice.txt`, `bob.txt`, `carol.txt`, `dave.txt` en `out/`.
- Que cada archivo contiene el `name` y `email` esperado.
- Que `main.tf` menciona `yamldecode` y `for_each`.

## 9. Preguntas de reflexión

1. ¿Qué pasaría si `users.yaml` tuviera dos entradas con el mismo `username`? ¿Qué error te mostraría Terraform?
2. ¿Por qué `for_each` necesita que las claves del map se conozcan en plan time, y por qué un YAML satisface eso?
3. Si decidieras cambiar `username` por un ID numérico generado al vuelo, ¿se te caería el stack? ¿Por qué?

## 10. Extensiones

- **E1**: añade `oncall` como campo opcional al YAML; si existe, incluye `oncall=true` en el archivo. Usa `try()`.
- **E2**: añade un segundo recurso `local_file.user_json` que serialice con `jsonencode(each.value)`.
- **E3**: filtra con `for ... if ...` para que solo los usuarios con rol `admin` tengan archivo.

## 11. Limpieza

```bash
cd /tmp/tf-07-01
terraform destroy -auto-approve
cd /
rm -rf /tmp/tf-07-01
```
