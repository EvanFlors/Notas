# tf-03-02 — Cuándo `depends_on` es imprescindible (y cuándo sobra)

## 1. Identificación

- **ID:** `tf-03-02-force-depends-on-and-explain`
- **Tecnología:** terraform
- **Módulo:** `03-resources-data-sources-and-references`
- **Dificultad:** beginner
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

En la lección aprendiste que `depends_on` suele ser **el último recurso, no el primero**: Terraform infiere la mayoría de dependencias leyendo las referencias que escribes. Pero hay casos (minoría, no excepción) donde `depends_on` **es necesario** porque la dependencia operacional no viaja como atributo entre los dos recursos.

Aquí te damos **dos escenarios**. Ambos usan los providers `tls` y `docker` (sin coste). Tu trabajo es:

1. **Diagnosticar** cuál es el escenario donde `depends_on` sobra (redundante) y cuál es el que lo requiere.
2. **Dejar la versión correcta** del código en los directorios indicados.
3. **Explicar por escrito** (en el `ANSWER.md` que crees) por qué.

El validator no te dice la respuesta: comprueba que el código resultante aplique bien y que `ANSWER.md` responda a las preguntas obligatorias. La parte conceptual la validará un revisor humano.

## 3. Objetivos

- Diferenciar una dependencia **expresable por referencia** de una dependencia **operacional lateral** que no viaja como atributo.
- Decidir cuándo `depends_on` es un *code smell* (redundante) y cuándo es la herramienta correcta.
- Escribir el `depends_on` **con un comentario** que justifique su presencia.

## 4. Prerrequisitos

- `tf-03` leído.
- `terraform` >= 1.5, `docker` >= 20.10 con daemon arriba.
- Sin coste.
- Puertos `18082` y `18083` libres.

## 5. Instrucciones

Trabaja en `/tmp/tf-03-02/`. Copia `starter/`:

```bash
mkdir -p /tmp/tf-03-02
cp -R starter/. /tmp/tf-03-02/
cd /tmp/tf-03-02
ls
# scenario-A/
# scenario-B/
```

### Escenario A — Repo "stack cert + nginx"

Mira `scenario-A/main.tf`. El stack genera:

- Un `tls_private_key`.
- Un `tls_self_signed_cert` que firma con esa llave (contiene `private_key_pem = tls_private_key.deploy.private_key_pem`).
- Un `docker_container` nginx que recibe por `env` el **fingerprint SHA1 del cert** (`cert_fingerprint = tls_self_signed_cert.srv.cert_pem` → se calcula fuera, aquí basta con pasarle el PEM).

En este `main.tf` alguien añadió un `depends_on` **extra** entre dos recursos que ya están ligados por referencia.

**Tu tarea A:** elimina ese `depends_on` redundante del `scenario-A/main.tf`. El resto del código debe quedarse igual. Aplica y verifica que todo funcione.

### Escenario B — "Marcador en disco antes de arrancar"

Mira `scenario-B/main.tf`. El stack:

- Usa `null_resource "marker"` con un `local-exec` provisioner que escribe el archivo `/tmp/tf-03-02/scenario-B-marker.txt` (simula "preparar un prerequisito operacional").
- Monta ese archivo como **bind mount** dentro del contenedor (`volumes { host_path = "/tmp/tf-03-02/scenario-B-marker.txt", container_path = "/data/marker" }`).

Pero el `host_path` dentro del contenedor es un **literal string** — no referencia atributo alguno del `null_resource`. Resultado: Terraform **no** sabe que el contenedor depende del `null_resource`, y en el primer `apply` puede crear el contenedor **antes** de que el marker exista. El bind mount fallaría o montaría un directorio vacío.

**Tu tarea B:** añade `depends_on = [null_resource.marker]` al `docker_container.app` del `scenario-B/main.tf` con un comentario explicando por qué es necesario. Aplica y verifica.

### `ANSWER.md`

Crea `/tmp/tf-03-02/ANSWER.md` con **al menos** este contenido:

```markdown
# tf-03-02 — Respuestas

## Escenario A — depends_on redundante

- ¿Qué depends_on quité y por qué?
- ¿Qué arista implícita ya existía?

## Escenario B — depends_on necesario

- ¿Por qué el bind mount con host_path literal no crea una arista en el DAG?
- ¿Qué pasaría exactamente en un primer apply sin el depends_on?
- ¿Por qué no basta con reordenar los bloques en el archivo?

## Regla práctica

En 2-3 líneas: ¿cuál es tu criterio personal para decidir si usar depends_on?
```

### Correr y validar

```bash
cd /tmp/tf-03-02/scenario-A
terraform init && terraform apply -auto-approve && terraform destroy -auto-approve

cd /tmp/tf-03-02/scenario-B
terraform init && terraform apply -auto-approve && terraform destroy -auto-approve

cd /path/to/repo/courses/terraform/03-resources-data-sources-and-references/activities/02-force-depends-on-and-explain
bash tests/validate.sh
```

## 6. Resultado esperado

- `scenario-A/main.tf` **ya no contiene** `depends_on`.
- `scenario-B/main.tf` **contiene exactamente un** `depends_on` dentro de `docker_container.app`, apuntando a `null_resource.marker`, con un comentario que lo justifique.
- Ambos escenarios aplican y destruyen limpiamente.
- Existe `/tmp/tf-03-02/ANSWER.md` con las tres secciones obligatorias.

## 7. Criterios de aceptación

- Decisión correcta en cada escenario.
- `depends_on` en B viene con un **comentario que lo justifique** (no es decorativo).
- `ANSWER.md` explica, en tus palabras, qué arista existe en A y por qué B no la tiene.
- Los dos stacks `apply`/`destroy` sin errores y sin modificar nada más.

## 8. Validación

```bash
bash tests/validate.sh
```

El script:

1. Verifica `terraform` y `docker` (SKIP si faltan).
2. Confirma que `scenario-A/main.tf` **no** tiene `depends_on`.
3. Confirma que `scenario-B/main.tf` **sí** tiene `depends_on` apuntando a `null_resource.marker` (y que esa línea va **acompañada de un comentario** cercano).
4. Corre `init && apply && destroy` en cada escenario.
5. Verifica que exista `ANSWER.md` con las secciones obligatorias.

> El validator **no** evalúa si tu prosa es correcta; eso lo revisa un humano. Pero verifica que las decisiones estructurales lo sean.

## 9. Preguntas de reflexión

(Ya cubiertas en `ANSWER.md`.) Extra:

- Si en el escenario B pasaras el `host_path` como `"${null_resource.marker.triggers.path}"` (y añadieras `triggers = { path = "/tmp/.../marker.txt" }` al null_resource), **¿seguirías necesitando** `depends_on`? Pista: no.
- ¿Qué pasaría si en A, en vez de quitar el `depends_on` redundante, lo **duplicas** (añades el mismo recurso dos veces en la lista)? ¿Terraform se queja?

## 10. Extensiones

- **E1:** convierte el `host_path` literal del escenario B en una referencia a un atributo del `null_resource` (p. ej., vía `triggers`), demuestra que ya **no** necesitas `depends_on`, y argumenta por qué esta variante es preferible.
- **E2:** en el escenario A, reemplaza el `tls_self_signed_cert` por un `tls_locally_signed_cert` que requiera también una `tls_cert_request`. Observa cómo crece el DAG y confirma que sigue sin necesitar `depends_on`.

## 11. Limpieza

```bash
for d in /tmp/tf-03-02/scenario-A /tmp/tf-03-02/scenario-B; do
  [ -d "$d" ] && (cd "$d" && terraform destroy -auto-approve 2>/dev/null || true)
done
docker rm -f tf-03-02-nginx tf-03-02-app >/dev/null 2>&1 || true
rm -rf /tmp/tf-03-02
```
