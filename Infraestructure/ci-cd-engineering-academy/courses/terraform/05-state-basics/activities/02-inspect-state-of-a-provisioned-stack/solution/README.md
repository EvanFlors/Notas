# Solución — tf-05-02

El validador comprueba **estructura**, no semántica. Esta solución te permite autoevaluar la calidad del contenido de tu `NOTES.md`.

- `NOTES-reference.md` es una muestra de respuesta correcta con valores de ejemplo (los tuyos serán distintos porque `random_*` genera distintos valores).

Puntos no obvios que un `NOTES.md` sólido debe cubrir:

- **Section 2**: `length` y `separator` son **declarados** (fijados por ti en HCL). `id` es **computado** (lo decide el provider al correr `apply`).
- **Section 3**: para extraer el password real **no** uses `terraform output admin_password` (devuelve `<sensitive>`). Opciones legítimas:
  - `terraform state show random_password.admin` (imprime todos los atributos del recurso del state, incluido `result`).
  - `jq '.resources[] | select(.type=="random_password") | .instances[0].attributes.result' terraform.tfstate`.
  - `terraform output -raw admin_password` (fuerza el valor crudo).
- **Section 4**: `file_permission` del state representa lo que Terraform le pidió al provider; `ls -l` muestra lo que terminó en disco. Si coinciden, bien; si no, hay drift que `plan` detectaría.
- **Section 5**: la contraseña vive en el JSON del state dentro de `resources[].instances[].attributes.result`. `sensitive` sirve para **ocultar en la salida del CLI**, no para cifrar o proteger el state. Mensaje operacional: cualquier backend que guarde este `.tfstate` debe tratarse como almacén de secretos.
- **Section 6**:
  - `serial`: contador monotónico que incrementa en cada escritura del state. Terraform lo usa para detectar escrituras concurrentes.
  - `lineage`: UUID generado al crear el state. Identifica la "línea" de un stack. Dos estados con lineages distintos no se consideran versiones del mismo state (Terraform rehúsa fusionarlos).
- **Section 7**: respuestas aceptables incluyen `random_password.admin.result` (contraseña en claro), `local_file.config.content` (el `.ini` entero con la contraseña dentro), y `random_integer.port.result` (puerto que podría orientar un escaneo). El `random_pet.animal.id` en sí es menos crítico, pero *patrón de naming* puede ser información útil para un atacante.
