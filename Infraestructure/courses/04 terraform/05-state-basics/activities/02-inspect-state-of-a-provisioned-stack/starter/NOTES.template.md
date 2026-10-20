# NOTES — tf-05-02-inspect-state-of-a-provisioned-stack

> Rellena este archivo guardándolo como `NOTES.md` en el mismo directorio.
> Los comandos *recomendados* se dan como pista, pero puedes usar otros.

## 1. Inventario del state

Salida de:
```bash
terraform state list
```

```
# pega aquí la salida literal
```

Resumen: hay `_____` recursos de `_____` tipos distintos.

## 2. Resource #1 — `random_pet.animal`

```bash
terraform state show random_pet.animal
```

- `id` = `_______________________`
- `length` = `_______________________`
- `separator` = `_______________________`

¿Cuál de estos atributos es **declarado en HCL** y cuál es **computado por el provider**?

- Declarados: `_______________________`
- Computados: `_______________________`

## 3. Resource #2 — `random_password.admin`

```bash
terraform state show random_password.admin
```

- `id` = `_______________________`
- `length` = `_______________________`
- `special` = `_______________________`
- `result` = `_______________________`   <!-- el valor real -->

Pregunta: el output `admin_password` está marcado `sensitive`, y `terraform output admin_password` imprime `<sensitive>`. ¿Cómo obtuviste entonces el valor real para esta nota?

```
# tu respuesta
```

## 4. Resource #3 — `local_file.config`

```bash
terraform state show local_file.config
```

- `filename` = `_______________________`
- `content_sha256` = `_______________________`   <!-- hash de 64 chars -->
- `file_permission` = `_______________________`

Verificación en disco:
```bash
ls -l <filename>
```

Permisos reales en disco: `_______________________`.
¿Coinciden con `file_permission` del state? `_______________________`.

## 5. Análisis — sensitive vs claro

Localiza y pega el fragmento concreto del `terraform.tfstate` donde vive el valor de la contraseña:

```bash
grep -o '"result": *"[^"]*"' terraform.tfstate | head -1
# o:
jq '.resources[] | select(.type=="random_password") | .instances[0].attributes.result' terraform.tfstate
```

Fragmento:
```
# pega aquí
```

Conclusión en una frase: `sensitive` sirve para `_______________________` y **no** sirve para `_______________________`.

## 6. Análisis — `serial` y `lineage`

```bash
grep -E '"(serial|lineage)"' terraform.tfstate
# o:
jq '{serial, lineage}' terraform.tfstate
```

- `serial` = `_______________________`
- `lineage` = `_______________________`

En tus palabras (no copiando la lección):

- `serial` significa: `_______________________`
- `lineage` significa: `_______________________`

## 7. Reflexión — Git

Enumera 3 cosas concretas de **este** state que no querrías ver nunca en un commit público, y por qué:

1. `_______________________`
2. `_______________________`
3. `_______________________`
