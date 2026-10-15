# tf-04-02 — Por qué `sensitive = true` no es gestión de secretos

## 1. Identificación

- **ID:** `tf-04-02-why-sensitive-is-not-secret-management`
- **Tecnología:** terraform
- **Módulo:** `04-variables-outputs-locals`
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** independent (análisis escrito con demostración empírica)

## 2. Contexto

Un error muy común en equipos que están empezando con Terraform es asumir que `sensitive = true` **protege** el valor. En realidad hace una sola cosa: lo oculta en la salida de `plan`, `apply` y `output`. El valor **sigue en claro** en el `terraform.tfstate` (y en el `plan` guardado con `-out`, y lo ve el provider cuando llama a la API remota).

Tu trabajo es demostrarlo empíricamente y escribir un análisis defendible: no basta con afirmarlo, hay que **mostrarlo con un `grep`** sobre el state.

El starter contiene un stack minúsculo que genera un "secreto" dummy (claramente marcado como no-real) y lo expone como output `sensitive`. Tu entregable es un `ANALYSIS.md` con la demostración, las conclusiones y la recomendación operacional.

## 3. Objetivos

Al terminar deberías poder:

- Demostrar con un comando reproducible que `sensitive = true` **no cifra** el state.
- Enumerar al menos **tres** lugares distintos donde el valor sigue siendo recuperable.
- Describir el patrón "secreto en secret manager + `data` source + backend protegido" como la mitigación correcta.
- Decidir qué outputs **sí** marcarías sensitive en producción (y por qué, aun sabiendo lo anterior).

## 4. Prerrequisitos

- Terraform >= 1.3.0.
- `bash`, `grep`.
- Sin costo (providers locales).
- Puedes resolverla **sin terraform instalado** si estudias el `terraform.tfstate` incluido como referencia, pero la demostración es más fuerte si lo generas tú.

## 5. Instrucciones

Trabaja en `/tmp/tf-04-02/`. Copia el starter:

```bash
mkdir -p /tmp/tf-04-02
cp -r courses/terraform/04-variables-outputs-locals/activities/02-why-sensitive-is-not-secret-management/starter/* /tmp/tf-04-02/
cd /tmp/tf-04-02
```

El starter contiene:

```
versions.tf          # tls + random (local-only)
main.tf              # genera un tls_private_key + un random_pet con prefix
                     # "DUMMY-SECRET-DO-NOT-USE-"
outputs.tf           # tres outputs: visible, sensitive, derivado-sensitive
ANALYSIS.md.template # plantilla del entregable, con placeholders [RELLENAR]
```

### Paso 1 — generar el state

```bash
terraform init
terraform apply -auto-approve
```

Verifica que `terraform.tfstate` existe en el directorio.

### Paso 2 — comprobar que la CLI oculta los valores sensitive

```bash
terraform output
#    Verás:
#      dummy_token         = <sensitive>
#      derived_fingerprint = <sensitive>
#      public_key          = -----BEGIN PUBLIC KEY----- ...

terraform output -raw dummy_token
#    (ahora SÍ te lo imprime)
```

### Paso 3 — demostrar que el state tiene el valor en claro

Ejecuta y **registra la salida** en `ANALYSIS.md`:

```bash
# a) ¿Está el prefijo "DUMMY-SECRET-DO-NOT-USE-" en el state?
grep -o 'DUMMY-SECRET-DO-NOT-USE-[a-z_-]*' terraform.tfstate | sort -u

# b) ¿Está la llave privada PEM en el state?
grep -c 'BEGIN RSA PRIVATE KEY\|BEGIN PRIVATE KEY' terraform.tfstate

# c) Mira el campo "sensitive_values" del state: marca cuáles están marcados,
#    pero NO cifra el campo "values" paralelo.
python3 -c "
import json
state = json.load(open('terraform.tfstate'))
print('outputs:')
for name, body in state.get('outputs', {}).items():
    print(f'  {name}: sensitive={body.get(\"sensitive\", False)}, value_present={\"value\" in body}')"
```

### Paso 4 — redactar `ANALYSIS.md`

Toma `ANALYSIS.md.template` como base y rellena **todas** las secciones. El validador revisa que:

- Contiene literalmente el comando `grep` del Paso 3.a y su salida (pégala).
- Incluye el conteo de PEM privado del Paso 3.b (debe ser `>= 1`).
- Enumera **al menos 3 lugares** donde el valor sigue siendo recuperable (state, plan guardado con `-out`, API del provider, `terraform output -raw`, logs del provider en modo debug…).
- Contiene la frase (o equivalente clara) **"`sensitive = true` no cifra"**.
- Describe el patrón `data` source + secret manager como mitigación correcta.
- Contiene la palabra "backend" asociada a protección (encriptación at-rest, IAM, versionado).

### Paso 5 — ejecutar el validador

```bash
bash courses/terraform/04-variables-outputs-locals/activities/02-why-sensitive-is-not-secret-management/tests/validate.sh
```

## 6. Resultado esperado

- `terraform.tfstate` existe en `/tmp/tf-04-02/`.
- `grep 'DUMMY-SECRET-DO-NOT-USE-' terraform.tfstate` devuelve una o más coincidencias.
- `ANALYSIS.md` cumple los requisitos del Paso 4.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- La redacción del análisis es **tuya**, no una copia literal del README.
- La recomendación operacional distingue claramente: cosas que `sensitive` **sí** hace (ocultar en CLI/logs superficiales) vs. las que **no** hace (cifrar).

## 8. Validación

```bash
bash courses/terraform/04-variables-outputs-locals/activities/02-why-sensitive-is-not-secret-management/tests/validate.sh
```

Variable opcional: `WORK_DIR=/otra/ruta`.

## 9. Preguntas de reflexión

1. Si `sensitive = true` no cifra, ¿por qué existe? Da dos escenarios reales donde te alegras de haberlo puesto.
2. ¿Qué cambia si el backend es local (`terraform.tfstate` en tu disco) vs. S3 cifrado con bucket privado + IAM mínimo + versionado?
3. ¿Qué pasa si un developer hace `terraform plan -out=plan.tfplan` y sube el archivo a un bucket público "por accidente"? ¿Cómo se compara con subir el state?
4. Supón que una variable `db_password` sin default se setea con `TF_VAR_db_password`. ¿Dónde queda ese valor? ¿Qué partes del pipeline lo ven?
5. ¿Qué outputs **sí** marcarías sensitive aunque sepas que no cifran? ¿Cuáles **no** tiene sentido marcar?

## 10. Extensiones

- Agrega al stack un `terraform plan -out=/tmp/plan.tfplan` y repite el `grep` sobre `plan.tfplan`. ¿Qué ves?
- Reemplaza el `random_pet` por una variable `sensitive = true` llamada `fake_secret` (con default dummy). Aplica y verifica que el valor también aparece en el state.
- Investiga si tu backend favorito (`s3`, `gcs`, `azurerm`, `remote`) soporta encriptación client-side o nativa, y qué proteje cada modo.

## 11. Limpieza

```bash
cd /tmp/tf-04-02 && terraform destroy -auto-approve 2>/dev/null || true
rm -rf /tmp/tf-04-02
```
