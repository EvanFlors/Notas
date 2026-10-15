# NOTES — tf-05-02 (reference)

> Ejemplo. Los valores concretos varían por ejecución; lo que no varía son los
> tipos de atributo, los campos presentes y el análisis.

## 1. Inventario del state

```
$ terraform state list
local_file.config
random_integer.port
random_password.admin
random_pet.animal
```

Resumen: hay **4** recursos de **3** tipos distintos (`local_file`, `random_integer`, `random_password`, `random_pet` — 4 tipos si contamos `random_*` por separado).

## 2. Resource #1 — `random_pet.animal`

- `id` = `fast_sturdy_lemming`
- `length` = `3`
- `separator` = `_`

- Declarados: `length`, `separator`.
- Computados: `id` (el nombre aleatorio generado por el provider; junto con `keepers`, los demás).

## 3. Resource #2 — `random_password.admin`

- `id` = `none`
- `length` = `20`
- `special` = `true`
- `result` = `"abcDEF123!@#%&*xyzQR"`   <!-- ejemplo -->

El output está marcado `sensitive`, pero el valor existe en el state en claro. Para obtenerlo:

```bash
terraform output -raw admin_password
# o:
jq -r '.resources[] | select(.type=="random_password") | .instances[0].attributes.result' terraform.tfstate
```

## 4. Resource #3 — `local_file.config`

- `filename` = `/tmp/tf-05-02-inspect/app.ini`
- `content_sha256` = `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` <!-- ejemplo, 64 hex chars -->
- `file_permission` = `0600`

En disco:
```
$ ls -l /tmp/tf-05-02-inspect/app.ini
-rw-------  1 user  staff  142 Oct 15 10:00 /tmp/tf-05-02-inspect/app.ini
```

Permisos reales: `-rw-------` (es decir `0600`). Coinciden con el state.

## 5. Análisis — sensitive vs claro

```bash
$ grep -o '"result": *"[^"]*"' terraform.tfstate | head -1
"result": "abcDEF123!@#%&*xyzQR"
```

`sensitive` sirve para **ocultar el valor en la salida de la CLI** (`terraform plan`, `apply`, `output`) y **no** sirve para cifrarlo ni protegerlo en el state. Cualquiera con acceso al `.tfstate` lo lee.

## 6. Análisis — `serial` y `lineage`

```bash
$ jq '{serial, lineage}' terraform.tfstate
{
  "serial": 5,
  "lineage": "5d8b2f06-9f61-4b2c-9d1e-c3a7e8d9b1a0"
}
```

- `serial`: contador que **incrementa en cada escritura** del state. Permite detectar escrituras concurrentes (si dos clientes hacen push con el mismo serial, el backend rechaza al segundo).
- `lineage`: **UUID generado al crear el state**. Identifica unívocamente la "línea" de un stack. Terraform rehúsa fusionar dos estados con lineages distintos — defensa contra apuntar al backend equivocado.

## 7. Reflexión — Git

Tres cosas que **nunca** querría en un commit público:

1. `random_password.admin.result` — contraseña en claro, directa.
2. `local_file.config.content` — el `.ini` entero contiene la misma contraseña en claro.
3. `random_integer.port.result` — puerto efectivo del servicio; orienta un escaneo a un atacante con contexto.

Más allá de esos, la **estructura** del state (tipos y addresses) también es informacón reconocible, aunque menos crítica.
