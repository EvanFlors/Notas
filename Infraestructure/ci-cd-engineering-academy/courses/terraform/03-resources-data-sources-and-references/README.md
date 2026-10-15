# tf-03 — Resources, data sources y referencias

## Identificación

- **ID:** `tf-03-resources-data-sources-and-references`
- **Curso:** `terraform`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** `tf-02-setup-hcl-first-provider`. Haber corrido al menos un ciclo `init → plan → apply → destroy` con providers "seguros" (`null`, `random`, `local`).

## Objetivo

Modelar recursos reales con **dependencias correctas**. Al terminar deberías poder:

- Diferenciar `resource` de `data` por semántica y por efecto en el ciclo de vida.
- Leer una expresión como `aws_instance.web.id` y predecir qué pasa cuando se evalúa.
- Explicar por qué, por lo general, **no** necesitas `depends_on`: Terraform infiere las dependencias de las **referencias** que escribes.
- Saber cuándo sí lo necesitas y defenderlo con un ejemplo concreto.
- Leer el state resultante con `terraform state list` y `terraform state show`.

## Alcance

Este módulo cubre:

- `resource` vs `data` source: qué CRUDa cada uno y qué no.
- Atributos **argumentos** (los que escribes) vs atributos **computados** (los que el provider rellena después del apply).
- Referencias cross-resource (`<tipo>.<nombre>.<atributo>`) y por qué construyen el **grafo** implícito.
- `depends_on` como herramienta de **último recurso** para dependencias **no expresables** por referencia.
- Providers didácticos **sin coste**: `tls` (puro HCL, siempre funciona), `docker` (contra daemon local), `github` (recursos SaaS, se usa como demo de lectura — no se aplica contra GitHub real en los validators).
- `terraform state list / show` sobre un stack recién creado.

Lo que **no** cubre:

- Variables, outputs y locals a fondo → `tf-04`.
- Formato interno del state file y backend remoto → `tf-05`.
- Módulos → `tf-06`.
- `lifecycle` meta-arguments (`ignore_changes`, `create_before_destroy`, etc.) → `tf-09`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones (modelo mental → fundamentos → práctica → trade-offs → ejercicios de lectura).
- **`examples/`**:
  - `01-github-repo-with-tls-key/` — genera una llave privada con el provider `tls` y la publica como deploy key de un repo de GitHub. Demuestra una cadena de 3 recursos (`tls_private_key` → `github_repository` → `github_repository_deploy_key`) con dependencias **todas implícitas**.
  - `02-docker-container-via-tf/` — tira una imagen y arranca un contenedor con el provider `docker`. Dos recursos (`docker_image` → `docker_container`), dependencia implícita.
- **`activities/`**:
  - `01-dependency-graph-exercise/` (guided-lab) — construyes un stack `tls` + `docker` de 3+ recursos y lo visualizas con `terraform graph` y `terraform state list`.
  - `02-force-depends-on-and-explain/` (independent) — se te dan dos escenarios: en uno la dependencia implícita basta; en otro **debes** añadir `depends_on` y explicar por qué.
- **`resources/links.md`** — documentación oficial de los providers usados y lecturas sobre el grafo.

## Temas y subtemas

1. `resource` vs `data`
   - `resource`: Terraform **posee** el objeto (CRUD completo).
   - `data`: Terraform **lee** un objeto que no posee (no lo crea ni lo destruye).
   - Semántica en el plan: `data` se resuelve en `read` (fase refresh); nunca aparece como `+ create` ni `- destroy`.
2. Atributos: argumentos vs computados
   - Argumentos: los que escribes en el bloque.
   - Computados: los que rellena el provider tras `apply` (IDs, ARNs, timestamps, fingerprints).
   - Qué significa un atributo "known after apply".
3. Referencias y el grafo implícito
   - Sintaxis: `<tipo>.<nombre>.<atributo>` para `resource`; `data.<tipo>.<nombre>.<atributo>` para `data`.
   - Cómo Terraform usa cada referencia para añadir una arista al **DAG** (grafo acíclico dirigido).
   - El plan recorre el DAG en orden topológico; recursos independientes se crean en paralelo (hasta `-parallelism=10` por default).
4. `depends_on`
   - Qué es y qué **no** es: ordena nodos del DAG, no "espera a que algo esté listo" en sentido fuerte (eso lo hace el provider).
   - Por qué suele ser el **último** recurso, no el primero: si lo escribes mucho, probablemente estás ocultando una referencia que te faltó.
   - Casos legítimos: dependencias **laterales** no expresables por atributo (políticas IAM que condicionan a otro recurso, orden de instalación en un contenedor, etc.).
5. Providers didácticos sin coste
   - `tls`: genera llaves y certificados **en memoria/HCL**, sin red. Siempre funciona.
   - `docker` (kreuzwerker/docker): habla con `dockerd` local. Requiere daemon arriba.
   - `github` (integrations/github): habla con la API de GitHub. Útil para demo de lectura; en los validators del repo lo tratamos como material teórico (no se aplica contra GitHub real).
6. Leer el state resultante
   - `terraform state list` — qué recursos conoce.
   - `terraform state show <addr>` — todos los atributos conocidos de un recurso (los que escribiste y los computados).
   - Dirección de recurso: `<tipo>.<nombre>` (o `module.X.<tipo>.<nombre>`).

## Conceptos internos (fundamentos)

- Terraform construye el DAG **antes** del plan, parseando todas las expresiones del HCL y detectando cada referencia cross-resource. El grafo es la fuente de verdad del orden; `depends_on` solo añade aristas extra.
- Un atributo computado que no está disponible en `plan` aparece como `(known after apply)`. Esto no es un error: es Terraform diciendo "sé que existirá, pero no sé el valor hasta que ejecute el apply del nodo del que depende".
- `data` sources se refrescan en cada `plan`. Si tu `data` apunta a un recurso que **sí** gestiona Terraform (en el mismo stack), estás creando un ciclo lógico de "pescadilla que se muerde la cola": Terraform avisa con un ciclo en el grafo o con un valor desconocido en el plan. Regla práctica: no uses `data` para leer algo que acabas de declarar como `resource` en el mismo stack — usa la referencia directa.
- `depends_on` es útil, pero cada vez que lo escribes deberías preguntarte: "¿puedo expresar esto como una referencia?". Si la respuesta es sí, prefiere la referencia: es más declarativa, más legible y menos frágil ante refactors (si renombras el recurso dependiente, Terraform re-resuelve la referencia; con `depends_on` tienes una cadena de strings que puede desincronizarse).
- El provider `tls` nunca llama a la red: todo pasa en el proceso Terraform. Esto lo hace ideal para enseñar porque elimina el ruido operacional y deja la discusión limpia sobre el modelo de referencias.

## Competencias

- **Conceptual:** explicar la diferencia `resource`/`data` y por qué las dependencias implícitas son el mecanismo primario.
- **Operativa:** escribir un stack de 3+ recursos con dependencias implícitas correctas; leer el state tras aplicar; usar `terraform graph` para visualizar el DAG.
- **Arquitectónica:** diagnosticar cuándo un `depends_on` es necesario, cuándo es redundante, y cuándo es un *code smell* que oculta una referencia faltante.

## Ejemplos

- [`examples/01-github-repo-with-tls-key/`](examples/01-github-repo-with-tls-key/) — cadena `tls → github_repository → github_repository_deploy_key`.
- [`examples/02-docker-container-via-tf/`](examples/02-docker-container-via-tf/) — `docker_image → docker_container` contra el daemon local.

## Actividades

- [`activities/01-dependency-graph-exercise/`](activities/01-dependency-graph-exercise/) — guided-lab (60 min).
- [`activities/02-force-depends-on-and-explain/`](activities/02-force-depends-on-and-explain/) — independent (60 min).

## Entregables

- Un stack local sin coste con **3+ recursos interrelacionados** aplicado correctamente.
- Salida de `terraform state list` y `terraform state show` sobre al menos dos recursos.
- Un documento corto (en el README de la actividad 02) que distinga, para dos escenarios, cuándo la dependencia es necesaria vs redundante.

## Criterios de evaluación

- **Correctitud:** el stack aplica, destruye y vuelve a aplicar sin cambios inesperados.
- **Diseño:** las dependencias se expresan por **referencia** siempre que es posible; `depends_on` aparece solo donde se justifica.
- **Lectura del state:** el estudiante identifica atributos computados y los distingue de los argumentos escritos.
- **Comunicación:** el estudiante explica, con el DAG en la mano, por qué un `depends_on` concreto no se podía expresar por referencia.

## Recursos

Ver [`resources/links.md`](resources/links.md).
