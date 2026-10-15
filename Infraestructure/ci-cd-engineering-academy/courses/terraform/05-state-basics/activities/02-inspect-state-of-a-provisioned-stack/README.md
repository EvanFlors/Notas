# Actividad 02 — Inspeccionar el state de un stack aprovisionado

## 1. Identificación

- **ID:** `tf-05-02-inspect-state-of-a-provisioned-stack`
- **Tecnología:** `terraform`
- **Módulo:** `tf-05-state-basics`
- **Dificultad:** beginner
- **Duración estimada:** 40–50 min
- **Tipo:** independent

## 2. Contexto

El state de Terraform es tu primera fuente de información cuando algo no cuadra. No basta con "saber que `terraform state show` existe": hace falta tener los dedos entrenados en navegar el state, extraer el atributo que necesitas y argumentar por qué está donde está. Esta actividad **no** te dice qué comandos ejecutar — te dice qué atributos extraer y por qué.

## 3. Objetivos

Al terminar deberías poder:

- Aprovisionar un stack local con varios tipos de recursos y leer su state entero.
- Extraer atributos específicos (incluyendo **computados** por el provider) con `terraform state show`.
- Diferenciar atributos declarados en HCL de atributos calculados post-apply.
- Documentar los hallazgos en un `NOTES.md` reproducible, incluyendo análisis.
- Argumentar por qué un valor marcado `sensitive` sigue siendo visible en el state.

## 4. Prerrequisitos

- Terraform ≥ 1.5.
- Bash y `/tmp/` escribible.
- `jq` (opcional pero recomendado — hace mucho más cómoda la exploración).
- Ningún provider cloud, ningún coste.

## 5. Instrucciones

### 5.1 Preparar

```bash
WORK=/tmp/tf-05-02-inspect
rm -rf "$WORK" && mkdir -p "$WORK"
cp -R starter/. "$WORK/"
cd "$WORK"
```

### 5.2 Aprovisionar

```bash
terraform init
terraform apply -auto-approve
```

Deberías tener en el state al menos 4 recursos de 3 tipos diferentes (ver `main.tf`). **No mires el `main.tf` como receta** — mira el **state** a continuación.

### 5.3 Produce `NOTES.md`

Partiendo de la plantilla en `NOTES.template.md` (copiada al `$WORK`), produce `NOTES.md` **en `$WORK`** respondiendo las secciones siguientes. **Debes** usar `terraform state list` y `terraform state show` para extraer los valores. No vale copiar de `main.tf`.

Secciones obligatorias de `NOTES.md`:

1. **Inventario del state** — resultado literal de `terraform state list`. Comentar cuántos recursos y de qué tipos hay.
2. **Resource #1 — `random_pet.animal`**: extraer `id`, `length`, `separator`. Indicar cuáles son declarados en HCL y cuáles computados.
3. **Resource #2 — `random_password.admin`**: extraer `id`, `length`, `special`, y **el valor real de `result`**. Comentar: ¿cómo lo obtuviste si el output está marcado `sensitive`?
4. **Resource #3 — `local_file.config`**: extraer `filename`, `content_sha256`, `file_permission`. Verificar que el archivo real existe con `ls -l` sobre `filename` y comparar permisos.
5. **Análisis — sensitive vs claro**: ¿en qué parte del state concreto vive la contraseña? Transcribe el fragmento JSON (con `grep` o `jq`) que lo muestra.
6. **Análisis — serial y lineage**: valores actuales de `serial` y `lineage` en el `.tfstate`. Describe qué significa cada uno (en tus palabras, no copiando la lección).
7. **Reflexión — Git**: en 3–5 líneas, ¿qué 3 cosas concretas de este state **no** querrías ver nunca en un commit público? ¿Por qué?

### 5.4 Validar

Desde el directorio de la actividad (no desde `$WORK`):

```bash
bash tests/validate.sh /tmp/tf-05-02-inspect
```

El validador comprueba **estructura**, no semántica. Tú eres responsable de la calidad semántica de las respuestas — compáralas con `solution/NOTES-reference.md`.

## 6. Resultado esperado

- `$WORK/NOTES.md` existe y contiene:
  - Las 7 secciones nombradas.
  - Al menos un hash de 64 caracteres (p. ej. el `content_sha256`).
  - Mención explícita a `serial`, `lineage`, `sensitive`.
  - Al menos un fragmento del `terraform.tfstate` citado (p. ej. el que contiene la contraseña).
- `tests/validate.sh` pasa.

## 7. Criterios de aceptación

- [ ] **Funcionalidad**: valores extraídos corresponden al state (no inventados).
- [ ] **Calidad**: fragmentos citados con herramientas (`grep`, `jq`), no transcritos a mano.
- [ ] **Seguridad**: el `NOTES.md` queda en `$WORK` (en `/tmp/`), no en el repo del curso.
- [ ] **Reproducibilidad**: cualquiera que corra `terraform apply` sobre el mismo starter y repita los comandos obtendría los mismos atributos (los valores concretos variarán — los *tipos* y *campos* no).
- [ ] **Mantenibilidad**: `NOTES.md` tiene secciones nombradas que un colega puede escanear.

## 8. Validación

```bash
bash tests/validate.sh /tmp/tf-05-02-inspect
```

Verifica:

1. `$WORK/.terraform` existe (hubo `init`).
2. `$WORK/terraform.tfstate` existe (hubo `apply`).
3. `$WORK/NOTES.md` existe y contiene las 7 secciones esperadas.
4. `NOTES.md` cita al menos un hash de 64 chars (SHA-256).
5. `NOTES.md` menciona `serial`, `lineage`, `sensitive`.
6. `terraform state list` sobre `$WORK` lista los 4 recursos esperados.

## 9. Preguntas de reflexión

Están incorporadas en las secciones 2–7 de `NOTES.md`. Adicionalmente, responde en `$WORK/REFLECTION.md` (no evaluado por el validador):

1. Si tuvieras que **rotar** la contraseña de `random_password.admin`, ¿qué comando usarías? ¿Qué pasaría con el `local_file.config` que la referencia?
2. ¿Por qué `terraform state show random_pet.animal` imprime atributos que **nunca** escribiste en el HCL?
3. ¿Qué información del state podrías considerar "estructural" (tipo, address, provider) vs "sensible" (valores de atributos)? ¿Qué controles aplicarías a cada parte?
4. Si tuvieras acceso de solo-lectura al bucket donde vive un state remoto de prod, ¿qué podrías aprender del equipo que lo gestiona?

## 10. Extensiones (opcional)

- **E1** — Ejecuta `terraform state show -no-color random_password.admin > admin.out` y compara con el output JSON de `terraform output -json`. ¿Dónde está el valor en claro y dónde está "sensitive"?
- **E2** — Edita `main.tf` para añadir un `random_integer`. Corre `terraform apply`. Observa que `serial` incrementa. Vuelve a correr `apply` sin cambios y confirma que `serial` **no** incrementa.
- **E3** — Haz `terraform state pull > snapshot.json` y compara `snapshot.json` con `terraform.tfstate`. En backend local son idénticos; en remoto, `pull` sería la vía oficial.
- **E4** — Rompe el state intencionalmente: edita `terraform.tfstate` cambiando el `lineage` por un UUID distinto. Corre `terraform plan`. Observa el error y recupera copiando el backup `terraform.tfstate.backup` sobre `terraform.tfstate`.

## 11. Limpieza

```bash
cd "$WORK"
terraform destroy -auto-approve
cd /
rm -rf /tmp/tf-05-02-inspect
```
