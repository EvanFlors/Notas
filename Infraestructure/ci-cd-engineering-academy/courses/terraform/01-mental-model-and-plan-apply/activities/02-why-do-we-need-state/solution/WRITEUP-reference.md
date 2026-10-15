# WRITEUP (reference) — tf-01: Por qué el state es necesario

> Autoevaluación. **No** es la única respuesta correcta — es *una* respuesta correcta y profesional.

## A. Tres razones por las que el state es necesario

**1. Mapeo HCL ↔ IDs reales.** Tú escribes `resource "aws_instance" "web"`. AWS no tiene instancias con nombres: tiene `i-0abc1234567890def`. Alguien tiene que recordar que *tu* `aws_instance.web` corresponde a *esa* instancia concreta. Ese alguien es el state: contiene el par `(address_en_hcl, id_real)` para cada recurso que gestionas. Sin él, en cada `plan` Terraform no podría saber si tu `web` ya existe (y hay que modificarlo o reemplazarlo) o si hay que crearlo desde cero.

**2. Atributos computados que solo existen tras crear.** El `id` de una EC2, el `arn` de un bucket S3, la `public_ip` de una instancia, el `fingerprint` de una llave SSH, el `endpoint` de una RDS — ninguno existe antes de que el provider ejecute la operación de creación. Pero otros recursos dependen de ellos (una Security Group Rule necesita el `aws_instance.web.id`; una Route 53 record necesita el `endpoint` del Load Balancer). El state guarda estos valores para que puedan referenciarse sin re-consultar la API en cada plan — y, lo más importante, para que estén disponibles al próximo `apply`.

**3. Falta de listado barato o preciso en las APIs.** Muchas APIs permiten `GET /resources/<id>` pero no `GET /resources` sin filtros, o lo permiten con rate limits agresivos. Y aunque pudieras listar todo, no sabrías cuáles son *tuyos* vs cuáles pertenecen a otro equipo que opera la misma cuenta. Un state resuelve el "¿qué debo gestionar?" sin tener que descubrirlo cada vez (lo cual tampoco es posible de forma determinista).

**Bonus — Metadata interna.** El state guarda la *schema version* de cada recurso (para que el provider sepa aplicar migraciones si evolucionó el schema), guarda outputs del root module (para que otros stacks los consuman vía `terraform_remote_state`), y guarda `depends_on` resueltos. Nada de esto es derivable del `GET` del cloud.

## B. Experimento mental "Terraform stateless"

Imagina que Terraform no tiene state. En cada `plan`, llama a AWS y lista "todas las VPCs, todas las instancias, todas las SG, …". Entonces:

- **No sabes qué es tuyo.** Si en la cuenta hay 42 VPCs y tu HCL declara una, ¿cuál es la tuya? Podrías etiquetar con `terraform:true`, pero eso lo tiene que mantener el humano (y nadie lo hace al 100%).
- **No puedes referenciar atributos computados.** Al crear tu `aws_instance`, AWS devuelve `i-0abc1234`. Si no lo guardas, en el próximo plan Terraform no sabe que tu `web` es esa instancia; ve la instancia, no sabe que es tuya, intenta **crearla de nuevo**.
- **Ambigüedad masiva.** Dos EC2 idénticas por configuración son indistinguibles si no tienes algo que las ancle (y los tags son metadata editable).
- **Costo de API.** Listar todo en cada plan en una cuenta con 10.000 recursos es minutos de llamadas y rate limits al borde del 429.

**¿Funcionaría? No.** Es por eso que incluso herramientas "stateless en apariencia" (como Crossplane, que usa Kubernetes como control plane) **sí** mantienen state — solo que vive en etcd en lugar de en un `.tfstate`.

## C. Drift y por qué `apply` por sí solo no lo detecta todo

**Drift** es cuando la infra real se mueve fuera de Terraform: alguien edita la consola, otro script modifica un recurso, un SCP inyecta un tag, etc. En el **próximo plan**, el `refresh` ve el valor real, el diff aparece y Terraform propone "revertir" la realidad hacia el estado deseado.

**Por qué `apply` por sí solo no basta:**

- Si corres `apply -refresh=false`, Terraform asume que el state es correcto y **no consulta** el cloud. No ve drift en recursos que no toca el diff.
- Si corres `apply` sin plan previo, versiones recientes de Terraform **sí** refrescan por default, pero no todos los flows lo hacen; en pipelines antiguos (o con `-refresh=false` forzado por velocidad) puedes aplicar sobre drift sin verlo.
- Hay drift que Terraform **jamás** detecta: tags que un SCP corporativo añade después de la creación (si no están en tu `.tf`, el refresh los ignora); atributos que el provider no mapea del `GET` (el provider decide qué leer); cambios en recursos que **ni siquiera** están en tu state (otro equipo creó una SG que colisiona con la tuya, y tu plan no sabe de ella).

**Ejemplo concreto:** mantienes una Lambda. Alguien añade un trigger de EventBridge por consola. Tu HCL solo declara la función. En el próximo plan, el refresh de la Lambda no mira los triggers externos (son otro recurso); el plan sale limpio; aplicas; nada se rompe — pero *crees* que gestionas la Lambda al 100% y no la gestionas.

## D. Consecuencias operativas del state

- **Nunca va a Git.** Contiene valores reales en claro (IPs, outputs, incluso secretos de salida como passwords generados). Un repo público expone infra; un repo privado todavía expone a cualquiera con acceso al repo (que no es lo mismo que acceso a producción).
- **Debe vivir en backend remoto (S3+DynamoDB, GCS, Azure Blob, HCP Terraform, …).** Para que colabores en equipo necesitas que el state esté donde todos pueden leerlo y escribirlo con auditoría. Local-only es "equipo de uno" y nada más.
- **Debe tener locking.** Dos `apply` concurrentes sobre el mismo state lo corrompen. El backend debe soportar lock (DynamoDB para S3, lock nativo en GCS, etc.).
- **Debe estar encriptado at-rest.** El bucket donde vive el state debe tener encriptación habilitada (y versionado, para poder restaurar backups si algo se corrompe).
- **(Bonus) Conviene dividirlo por bounded context.** Un state monolítico con 500 recursos es un blast radius enorme: una corrupción, una locking stuck, y nada se mueve. Separa por dominio (red / data / compute / monitoring) para reducir el radio de daño.

## Preguntas

1. (a) **Mapeo** entre nombres en HCL e IDs reales: sin algo que recuerde que `aws_instance.web` es `i-0abc1234`, en cada plan Terraform no sabría qué recursos modificar vs crear. (b) **Atributos computados**: muchos atributos (ID, ARN, IP, fingerprint) solo existen tras crear el recurso; otros recursos los referencian, y mantenerlos como una fuente de verdad consultada en cada plan es caro y a veces imposible (el provider no siempre expone todo en los `GET`).

2. Un atributo computado es un valor que el provider **calcula** cuando crea el recurso; no se declara en el HCL. Ejemplos:
- `aws_instance.web.id` (ID de la instancia, formato `i-xxxx`, lo asigna AWS al crear).
- `aws_s3_bucket.logs.arn` (ARN completo, formato `arn:aws:s3:::...`).
- `aws_db_instance.main.endpoint` (hostname + puerto para conectarse, generado por AWS).
- `tls_private_key.key.public_key_fingerprint_md5` (lo calcula el provider al generar la llave).

3. El próximo `plan` ve el `.tfstate` vacío (o re-inicializado) y, al compararlo con tu HCL, propone **crear todo desde cero** (`+ create` para cada recurso). Al aplicar, el provider llama al cloud, el cloud dice "ya existe un recurso con ese nombre/CIDR/key" y falla con "already exists". **Recuperación:** si tenías backup del state (debiste), restáuralo. Si no, hay que `terraform import` (o `import` blocks) recurso por recurso, pegando el ID real al bloque de HCL. Es lento y propenso a error. Moraleja: backend remoto con versionado y backups.

4. Sin locking, dos `apply` A y B empiezan al mismo tiempo. A refresca el state y empieza a crear recursos; B refresca el state (todavía el viejo), decide crear algunos de los mismos recursos. A escribe el state con los IDs reales creados por A; B escribe el state con los IDs reales creados por B — **sobrescribiendo** lo de A. Resultado: en el cloud existen 2 copias de algunos recursos; el state solo apunta a una. El drift es permanente hasta que lo importes a mano.

5. Depende de la versión y el flow:
- En versiones recientes, `terraform apply` ejecuta un refresh implícito antes de calcular el diff, así que **sí** detecta drift en los recursos del state.
- Si corres `apply -refresh=false`, **no** detecta drift (asume state correcto).
- En CI/CD, muchos pipelines guardan un `plan.tfplan` con `-out=` y luego `apply plan.tfplan`. El apply ejecuta exactamente el diff del plan, sin re-refrescar. Si entre `plan` y `apply` alguien tocó la consola, el apply puede aplicar sobre un drift sin verlo (el plan ya era "viejo").
- Hay drift fuera del alcance del refresh (recursos no gestionados, atributos no mapeados) — ese **nunca** se detecta.

6. (a) Tags que un SCP inyecta corporativamente a todos los recursos nuevos. (b) Recursos creados en el cloud que no están en el state de Terraform (otro equipo, otra automatización). (c) Cambios en atributos que el provider no incluye en el schema del recurso (p. ej. metadata interna del cloud que el provider decidió no exponer).

7. (a) **Secretos en claro**: el state contiene valores reales — IPs, hostnames, outputs sensibles, a veces passwords generados por recursos como `random_password`. Verlo en Git es verlo en todos los forks, backups y clones. (b) **Conflictos de concurrencia**: dos personas corren `apply` desde su clon local, cada una genera un state distinto, intentan hacer merge en Git. Es imposible — el state es un snapshot binario coherente, no una fuente para merge textual. (c) **No hay locking**: Git no es un backend transaccional para state; dos commits pueden pisarse. El state necesita un backend real (S3+DynamoDB, GCS, HCP) con locking atómico, no Git.
