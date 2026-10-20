# MAP (reference) — tf-01: Ciclo init → plan → apply → destroy

> Autoevaluación. **No** es la única respuesta correcta — es *una* respuesta correcta y profesional.

## A. Los tres estados

```
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  Estado deseado  │    │  State de TF     │    │  Infra real      │
│  (tus .tf)       │    │  (.tfstate JSON) │    │  (API cloud/SaaS)│
└──────────────────┘    └──────────────────┘    └──────────────────┘
   escribe: tú             escribe: TF              escribe: TF (via
   lee: TF (parse)         (apply/refresh)          providers), humanos
   vive en Git             lee: TF (plan)           (consola), SCPs
                           vive en backend          vive en el cloud
                           remoto (S3/HCP/…)
```

- **Estado deseado** — lo que *tú* quieres. En tus archivos `.tf` versionados en Git. Lo escribe el humano; lo lee Terraform al parsear.
- **State** — lo que *Terraform cree* que hay. Un JSON (`.tfstate`), idealmente en backend remoto con locking. Lo escribe Terraform tras cada `apply` y tras `refresh`. Nunca va a Git (contiene valores en claro, incluidos outputs sensibles).
- **Infra real** — lo que *realmente* existe en el cloud. Lo escribe Terraform (vía providers), pero **también** humanos por consola y automatizaciones externas (SCPs, otros scripts).

## B. El ciclo init → plan → apply → destroy

```
┌─────────────────────────────────────────────────────────────┐
│  INIT                                                       │
│  Lee required_providers, descarga plugins a .terraform/,    │
│  fija versiones+hashes en .terraform.lock.hcl, inicializa   │
│  el backend donde vive el state.                            │
│  Toca:    disco (.terraform/), red (download providers),    │
│           backend (crea/verifica).                          │
│  NO toca: infra real.                                       │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  PLAN                                                       │
│  1. Lee tus .tf          → ESTADO DESEADO                   │
│  2. Lee el .tfstate      → STATE (lo que TF cree)           │
│  3. REFRESH: por cada recurso del state, pregunta al        │
│     provider "¿cómo está ahora?" → actualiza state en       │
│     memoria con la realidad.                                │
│  4. Calcula el diff deseado ↔ state refrescado.             │
│  5. Imprime el diff con símbolos +, -, ~, -/+, <=.          │
│  Toca:    API cloud (SOLO LECTURA, via refresh).            │
│  NO toca: nada de escritura en infra real.                  │
└──────────────────────────┬──────────────────────────────────┘
                           │  (si lo apruebas / si usas -out)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  APPLY                                                      │
│  Ejecuta el diff en el orden del grafo de dependencias      │
│  (paralelo donde es seguro). Tras cada op OK, actualiza     │
│  el state con los atributos reales del recurso. Si una op   │
│  falla, deja el state coherente con lo que SÍ se aplicó     │
│  (no es "todo o nada").                                     │
│  Toca:    API cloud (lectura + ESCRITURA), state (write).   │
│  NO toca: tu HCL.                                           │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  DESTROY                                                    │
│  Caso particular de plan+apply: el estado deseado es NADA.  │
│  Para cada recurso del state, el diff es "-"; apply los     │
│  elimina en orden inverso al grafo (hojas primero).         │
│  Toca:    igual que apply (API cloud + state).              │
└─────────────────────────────────────────────────────────────┘
```

## C. Los símbolos del plan

- `+` — **create**. El recurso está en tu código pero NO en el state. Lo decide **core** mirando el diff.
- `-` — **destroy**. Está en el state pero NO en tu código (lo quitaste o nunca lo pusiste). Core.
- `~` — **update in-place**. Existe en ambos y algún atributo mutable cambió. El **provider** marca el atributo como mutable.
- `-/+` — **replace**. Un atributo "ForceNew" (inmutable) cambió. Para alcanzar el estado deseado hay que destruir y recrear. Lo decide el **provider** (es el que sabe qué atributos no se pueden modificar in-place).
- `<=` — **read**. Un `data` source cuyo valor se resuelve en apply (sus args dependen de recursos aún inexistentes).
- `# forces replacement` — anotación que acompaña al atributo culpable de un `-/+`.
- `(known after apply)` — valor computado por el provider al crear; aún no se conoce.

## D. Idempotencia y drift

- **Idempotencia** — aplicar el mismo código N veces tiene el mismo efecto que aplicarlo una vez. Si corres `apply` y luego `apply` sin cambiar nada, la segunda vez el plan debe estar vacío ("No changes"). Es un invariante *de diseño*; algunos recursos con atributos no deterministas requieren `ignore_changes` para mantenerlo estricto.
- **Drift** — la infra real se mueve sin que el state se entere. Ejemplo: alguien edita la Security Group por consola para abrir el puerto 22. El `.tf` no cambia. En el próximo plan, el refresh ve la realidad, el diff aparece como `~` y Terraform propone **cerrar** el puerto (deshacer el cambio manual). Puede ser lo correcto o un desastre: depende de si el cambio manual era legítimo.

## Preguntas

1. `init` tiene que: (a) descargar los providers declarados en `required_providers` a `.terraform/providers/`, (b) fijar versiones y hashes en `.terraform.lock.hcl` para reproducibilidad, (c) inicializar el backend donde vive el state (lo configura/crea si corresponde). Sin eso, el `plan` no tiene cómo hablar con la API ni dónde leer el state.

2. Sí. El `plan` llama a la API cloud durante el **refresh**: pregunta a los providers por el estado actual de cada recurso del state, para detectar drift y basar el diff en la realidad. **No escribe nada** en la infra. Si tu rol IAM no tiene permisos de lectura, el plan falla.

3. Lo que YA se aplicó existe en la infra real y está en el state. Lo que estaba después del punto de fallo no existe. **No es "todo o nada"**: no puede serlo, porque las APIs cloud no son transaccionales entre sí. El próximo plan reflejará el estado parcial y propondrá cómo completarlo (o revertir, si borras el `.tf`).

4. `-/+` = destroy + create. Aparece cuando un atributo cambia y el provider sabe que ese atributo no se puede modificar in-place (es `ForceNew`). Ejemplo típico: cambiar la `ami` de una `aws_instance` — AWS no permite cambiar la AMI de una EC2 existente; hay que recrearla. Otro: cambiar el `engine` de una `aws_db_instance` (de `mysql` a `postgres`), o cambiar el `name` de una Lambda.

5. El atributo es **computado por el provider** al crear el recurso y Terraform aún no lo conoce. Se "sabrá" durante el apply, cuando el provider responda con el valor real (ID, ARN, IP). Es por esto que el state es necesario: tras el apply, Terraform guarda ese valor y en adelante aparece en los planes como un valor concreto, no como `(known after apply)`.

6. Escenario: hoy aplico un stack con una SG que permite 80 desde 0.0.0.0/0. Mañana el equipo de seguridad abre por consola el 22 desde 0.0.0.0/0 (para debug, "un momento"). Pasado mañana corro `terraform plan` sin tocar el `.tf`. El refresh ve el 22 abierto; el diff muestra `~` proponiendo **cerrar** el 22 (porque mi HCL no lo tiene). Si corro `apply` sin leer el plan, cierro el 22 — y rompo la sesión de debug activa. Correcto o no, es una decisión que debería tomarse viendo el plan.

7. Porque `destroy` es `plan` con un *estado deseado implícito igual a vacío*, seguido de `apply`. El diff resultante tiene solo `-` para todo lo que esté en el state. No hay un algoritmo distinto; es el mismo motor con un input distinto. Internamente es `terraform plan -destroy` + `terraform apply`.
