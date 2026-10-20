# Lección: Modelo mental y ciclo `plan` / `apply` de Terraform

> **ID:** `tf-01-mental-model-and-plan-apply` · **Nivel:** fundamentos · **Duración:** 2–3 h
> **Prerrequisitos:** nociones de cloud (T-7.1), lectura de JSON/YAML, línea de comandos.

---

## 1. Introducción intuitiva

Imagina que acabas de entrar a una empresa que corre su infraestructura "a mano". Cada vez que necesitan un servidor nuevo, alguien entra a la consola web de AWS, hace clic en "Launch instance", elige la AMI, selecciona la red, abre puertos "a ojo" y lo apunta en un spreadsheet. Dev tiene 7 instancias. Staging, 11. Prod, 14. Nadie recuerda por qué `prod-api-3` tiene abierto el puerto 9000. Alguien tocó la Security Group *ayer* "para probar", y nadie lo rolleó. Cuando pides reproducir prod en staging, el DevOps mira al techo.

Hay dos maneras de salir de ahí.

**Opción A — script imperativo.** Escribes un `bash` que llama a `aws ec2 run-instances ...`, `aws ec2 create-security-group ...`, `aws rds create-db-instance ...`. Lo versionas en Git. Mejora: hay historia. Problema: el script describe **cómo** llegar al estado deseado desde cero. Si corres el script dos veces, intenta crear todo *otra vez*. Si quieres cambiar un atributo, tienes que detectar "¿existe ya? ¿qué tiene distinto?" tú mismo. Los `if ... else ...` se multiplican. Lo que empezó como un script termina siendo una herramienta de reconciliación casera.

**Opción B — IaC declarativa.** Describes en archivos de texto **cuál es el estado deseado** de la infraestructura ("una VPC con dos subnets, una instancia `t3.small`, un RDS con esta config"). Una herramienta (Terraform) **compara** ese estado deseado con lo que realmente existe en AWS, calcula el **diff**, te lo muestra, y si lo apruebas lo **ejecuta**. Si corres el mismo código dos veces, la segunda vez no hace nada (es *idempotente*). Si cambias un atributo, la herramienta sabe si puede modificarlo *in-place* o si tiene que destruir y recrear.

Esto es Terraform. Antes de instalarlo, antes de aprender HCL, antes de escribir un `resource` — este módulo construye el modelo mental que hace que todo lo demás tenga sentido.

---

## 2. Fundamentos

Antes de ver cualquier comando, tres ideas que necesitas fijar:

### 2.1 Declarativo vs imperativo

- **Imperativo** = describes *cómo*: una secuencia de pasos. `bash`, `aws` CLI, `boto3`, `kubectl create`.
- **Declarativo** = describes *qué*: cuál es el estado final deseado. HCL de Terraform, YAML de Kubernetes (en modo `apply`), SQL (en gran parte).

La diferencia no es cosmética. En un sistema declarativo, el que decide **cómo llegar** del estado actual al deseado es la herramienta, no tú. Esto exige que la herramienta **sepa**:

1. Cuál es el **estado deseado** (lo lee de tu código).
2. Cuál es el **estado actual real** (lo tiene que averiguar).
3. Cómo calcular un **diff** mínimo entre ambos.
4. Cómo **ejecutar** las operaciones del diff en el orden correcto.

Pierde cualquiera de los cuatro y ya no es IaC declarativa, es un script con corbata.

### 2.2 Idempotencia

Una operación es **idempotente** si aplicarla una vez tiene el mismo efecto que aplicarla N veces. "Pon este archivo con este contenido" es idempotente. "Añade esta línea al archivo" no lo es.

Terraform aspira a ser idempotente en el límite: si tu código describe un estado y la infra real ya está en ese estado, aplicarlo *otra vez* no debería cambiar nada. Esto es un **invariante de diseño**, no una promesa absoluta: hay recursos con atributos computados por el provider (p. ej. un timestamp) donde la idempotencia estricta no se puede garantizar sin `ignore_changes` (lo verás en `tf-09`).

### 2.3 Tres estados, no dos

Un error de principiante es pensar que hay **dos** cosas: "mi código" y "la nube". En realidad son **tres**:

```
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│  Estado deseado  │   │  State de TF     │   │  Infra real      │
│  (tus .tf)       │   │  (.tfstate JSON) │   │  (API cloud)     │
└──────────────────┘   └──────────────────┘   └──────────────────┘
      "lo que yo         "lo que TF cree       "lo que de verdad
       quiero"            que hay"              existe"
```

- **Estado deseado**: lo que escribes en `.tf` (HCL). Es tu *intención*.
- **State de Terraform**: un archivo JSON que Terraform mantiene como su *mejor conocimiento* de la infra real. Se actualiza al terminar un `apply` y en el `refresh` previo al plan.
- **Infra real**: lo que efectivamente existe en AWS, GitHub, Datadog o lo que sea. Puede diferir del state si alguien tocó la consola.

Casi todo lo "difícil" de Terraform ocurre en las fronteras entre estos tres: `plan` las compara, `apply` las reconcilia, `drift` ocurre cuando la infra real se mueve sin que el state se entere.

Memoriza las tres ideas: **declarativo**, **idempotencia**, **tres estados**. Son toda la ingeniería mental que necesitas para este módulo.

---

## 3. Contexto histórico

El problema de "configurar servidores sin volverse loco" tiene décadas. Un recorrido abreviado:

- **~2005** — **CFEngine** y **Puppet** nacen como herramientas de *configuration management*: describen el estado de un servidor (paquetes, archivos, servicios) y lo reconcilian. Son declarativas, pero su alcance es *dentro* de la máquina.
- **~2012** — **Ansible** (imperativo-con-idempotencia por playbooks) y **Chef** compiten en el mismo nicho. Nada de esto *provisiona* la máquina en el cloud; asume que ya existe.
- **2011** — **AWS CloudFormation** aparece como IaC declarativa específica de AWS. YAML/JSON, bien integrado, pero solo AWS.
- **2014** — **HashiCorp Terraform 0.1** se libera como IaC declarativa **multi-cloud**: mismo modelo mental para AWS, GCP, Azure, DigitalOcean, OpenStack, etc. Usa un lenguaje propio (HCL) y un sistema de **providers** como plugins.
- **2017–2019** — Explosión del ecosistema de providers (centenas) y del *Registry* público (`registry.terraform.io`). Terraform se vuelve de facto el estándar.
- **2021** — Terraform **1.0**. Compromiso de estabilidad del lenguaje y del formato del state.
- **2023** — HashiCorp cambia la licencia de BUSL (Business Source License), que restringe uso competitivo. La comunidad reacciona: la Linux Foundation adopta el fork **OpenTofu** (Apache 2.0), que preserva compatibilidad del state, el lenguaje y los providers.
- **2024–2026** — Convergencia funcional entre ambos; divergencias puntuales (p. ej. `removed` blocks, state encryption nativa, provider-defined functions). Para este módulo *no importa* cuál uses: todo lo que ves aplica a los dos.

Qué memorizar: Terraform **no inventó IaC**. Inventó IaC declarativa, **multi-cloud**, con **plan explícito** (dry-run real antes de aplicar) y **state separado** del código.

---

## 4. Funcionamiento interno

### 4.1 Las piezas

Para que todo lo anterior funcione, Terraform tiene cuatro piezas conceptuales:

```
┌───────────────────────────────────────────┐
│ Archivos .tf (HCL)                        │  ← estado DESEADO
│   providers, resources, data, modules,    │     (código, en Git)
│   vars, outputs, locals, backend          │
└───────────────┬───────────────────────────┘
                │  init (descarga providers, inicia backend)
                │  plan (compara estados)
                │  apply (ejecuta diff)
                │  destroy (plan + apply del "todo a cero")
                ▼
┌───────────────────────────────────────────┐
│ Terraform core                            │
│   - parse HCL                             │
│   - construye grafo de dependencias       │
│   - lee state (local o remote)            │
│   - refresca state consultando providers  │
│   - calcula diff                          │
│   - orquesta providers para aplicar       │
└───────────────┬───────────────────────────┘
                │  plugin protocol (gRPC)
                ▼
┌───────────────────────────────────────────┐
│ Providers (plugins)                       │
│   - mapean HCL ↔ API del servicio         │
│   - CRUD de recursos                      │
└───────────────┬───────────────────────────┘
                │  HTTP APIs
                ▼
┌───────────────────────────────────────────┐
│ Cloud / SaaS APIs                         │  ← infra REAL
└───────────────────────────────────────────┘
```

Y, viviendo *al lado* del core, el cuarto componente invisible pero fundamental:

```
┌───────────────────────────────────────────┐
│ State (.tfstate, JSON)                    │  ← lo que TF CREE que hay
│   mapeo recurso-en-HCL ↔ ID-en-cloud      │
│   último valor conocido de cada atributo  │
└───────────────────────────────────────────┘
```

### 4.2 Qué es un provider (conceptualmente)

Un **provider** es un **plugin ejecutable** que Terraform descarga durante `init`. No es parte del binario de Terraform. Cada provider:

- Declara los **tipos de recursos** que sabe gestionar (p. ej. `aws_instance`, `aws_s3_bucket`).
- Para cada tipo, implementa **CRUD**: *create*, *read*, *update*, *delete*.
- Habla con la API del servicio (AWS, GCP, GitHub, Datadog, Kubernetes, lo que sea) por HTTP/gRPC.
- Habla con el core de Terraform por un **plugin protocol gRPC** definido.

Terraform core **no sabe nada** sobre AWS. Lo que sabe sobre AWS lo sabe porque el provider `hashicorp/aws` se lo cuenta. Esto es lo que permite que Terraform sea multi-cloud: la misma herramienta aprende cualquier API para la que exista un provider.

Que exista un provider para X no significa que X soporte IaC: muchos providers son **comunitarios**, con calidad variable. Elegir providers (oficiales ✅ / verificados ⚠️ / comunitarios ⚠️) es una decisión arquitectónica (volveremos en `tf-02`).

### 4.3 El ciclo `init → plan → apply → destroy`

Este es el ciclo entero, en términos conceptuales. Sin comandos: solo *qué pasa* en cada fase.

```
   ┌─────────────────────────────────────────────────────────────┐
   │                                                             │
   │   1. INIT                                                   │
   │   ─────────                                                 │
   │   - Lee tus .tf                                             │
   │   - Averigua qué providers necesita (required_providers)    │
   │   - Los descarga a .terraform/providers/                    │
   │   - Fija versiones y hashes en .terraform.lock.hcl          │
   │   - Inicializa el backend donde vivirá el state             │
   │                                                             │
   │   NO toca infra real. Es "preparación".                     │
   │                                                             │
   └──────────────────────────────┬──────────────────────────────┘
                                  │
                                  ▼
   ┌─────────────────────────────────────────────────────────────┐
   │                                                             │
   │   2. PLAN                                                   │
   │   ─────────                                                 │
   │   a) Lee tu código             → estado DESEADO             │
   │   b) Lee el .tfstate           → state de TF (lo que cree)  │
   │   c) REFRESH: pide a cada provider el estado real actual    │
   │      de cada recurso del state → ajusta el state en memoria │
   │   d) Compara (c) con (a)       → calcula el diff            │
   │   e) Imprime el diff con símbolos:                          │
   │                                                             │
   │        +   crear                                            │
   │        -   destruir                                         │
   │        ~   modificar in-place                               │
   │        -/+ reemplazar (destruir y recrear)                  │
   │        <= leer un data source                               │
   │                                                             │
   │   NO toca infra real para escribir. SÍ lee (refresh).       │
   │                                                             │
   └──────────────────────────────┬──────────────────────────────┘
                                  │  (si lo apruebas)
                                  ▼
   ┌─────────────────────────────────────────────────────────────┐
   │                                                             │
   │   3. APPLY                                                  │
   │   ─────────                                                 │
   │   - Toma el diff del plan (y vuelve a verificarlo si no se  │
   │     guardó con -out)                                        │
   │   - Pide a los providers que ejecuten las ops en el orden   │
   │     del grafo (paralelas donde es seguro)                   │
   │   - A medida que cada op termina, ACTUALIZA el state con    │
   │     los atributos reales del recurso creado/modificado      │
   │   - Si una op falla, deja el state coherente con lo que SÍ  │
   │     se aplicó (no es "todo o nada")                         │
   │                                                             │
   └──────────────────────────────┬──────────────────────────────┘
                                  │
                                  ▼
   ┌─────────────────────────────────────────────────────────────┐
   │                                                             │
   │   4. DESTROY                                                │
   │   ─────────                                                 │
   │   Caso especial de plan+apply donde el estado deseado es    │
   │   "nada". Para cada recurso del state, el diff es "-", y    │
   │   el apply lo elimina en orden inverso del grafo.           │
   │                                                             │
   └─────────────────────────────────────────────────────────────┘
```

Observa dos cosas:

- **Plan no es inocente**: el refresh (fase `c`) **sí** llama a las APIs reales (en modo lectura). Si tu rol IAM no puede *leer*, el plan falla.
- **Apply no es atómico**: si tienes 20 recursos y el 11 falla, los primeros 10 ya existen (y están en el state). Esto es correcto — IaC *no* puede ser transaccional contra APIs ajenas.

### 4.4 Por qué una herramienta declarativa necesita state

Pregunta honesta: ¿**por qué** Terraform mantiene un archivo `.tfstate`? ¿No puede, en cada `plan`, preguntarle a la API "¿qué tienes?" y comparar contra mi código?

En teoría sí. En la práctica no, por tres razones acumulativas:

1. **No todas las APIs permiten listar.** Para muchos tipos de recurso, puedes `GET /resources/<id>` pero no `GET /resources` sin filtros. Y aunque listaras, no sabrías cuáles son *tuyos* vs cuáles pertenecen a otro equipo.

2. **El mapeo HCL ↔ ID real no es derivable del nombre.** Tú escribes:
   ```hcl
   resource "aws_instance" "web" { ami = "ami-abc", ... }
   ```
   Pero AWS no tiene instancias llamadas "web". Las instancias tienen IDs como `i-0123abcd...`. Alguien tiene que **recordar** que *tu* `aws_instance.web` corresponde a *esa* `i-0123abcd`. Ese alguien es el state. Sin ese mapeo, en cada `plan` Terraform no sabría si tu recurso `web` ya existe o hay que crearlo.

3. **Hay atributos computados que solo existen al crear.** El ID de una instancia, el ARN de un bucket, el fingerprint de una key — el provider no los conoce *antes* de crearlos. El state los guarda para que puedas referenciarlos desde otros recursos (`aws_security_group_rule` que necesita el `aws_instance.web.id`) sin volver a consultar la API.

(Más allá: hay atributos cuyo valor por default no es trivial de recomputar; relaciones entre recursos que el provider no expone en los `GET`; metadata interna como el schema version del recurso para migraciones. El state carga con todo esto.)

Conclusión: el state **no es** una caché opcional. Es la **fuente de verdad operacional de Terraform**. Perderlo o corromperlo deja la infra "huérfana" (existe en el cloud, Terraform no la reconoce, el próximo plan intenta re-crearla).

Esto tiene **consecuencias de operación serias** que verás en `tf-05` y `tf-11`:

- El state **nunca** va a Git (contiene valores sensibles en claro: IPs, outputs, a veces secretos).
- El state **vive en un backend remoto** (S3+DynamoDB, GCS, Azure Blob, HCP Terraform) con locking para que dos personas no apliquen al mismo tiempo.
- El state **necesita backup y encriptación at-rest**.
- El state **puede dividirse por bounded context** para reducir blast radius (si corrompes el de "monitoring", no se te va "prod payments").

### 4.5 De dónde salen `+`, `-` y `~`

Ya los nombramos en §4.3. Ampliémoslo:

| Símbolo | Significado | De dónde viene |
|---------|-------------|----------------|
| `+ create`      | El recurso está en tu código pero NO en el state (ni en la infra). | Añadiste un `resource` nuevo. |
| `- destroy`     | El recurso está en el state (y en la infra) pero NO en tu código. | Borraste el `resource` de tu HCL. |
| `~ update in-place` | El recurso existe y la mayoría de atributos coinciden; algunos cambian y el provider sabe que esos atributos se pueden modificar *sin recrear*. | Editaste un atributo "mutable" (p. ej. un tag). |
| `-/+ replace`   | El recurso existe pero cambió un atributo que el provider marca como `ForceNew` (inmutable). Para alcanzar el estado deseado, hay que destruir y recrear. | Editaste un atributo "inmutable" (p. ej. la AMI de una EC2, el motor de un RDS). |
| `<= read`       | Un `data` source se leerá en apply (no en plan) porque sus argumentos dependen de recursos que aún no existen. | Normal; no implica cambio. |

Clave: **el símbolo lo decide el provider**, no Terraform core. El provider es quien sabe que cambiar la AMI implica reemplazar la EC2. Si no lo supiera, Terraform propondría un `~` imposible y el apply fallaría.

### 4.6 Drift

**Drift** = la infra real **se mueve** sin que el state se entere. Causas típicas:

- Alguien tocó la consola web del cloud.
- Otro script/automatización modificó recursos "nuestros".
- Un `terraform apply` falló a medias dejando una op aplicada que el state no registró (raro, posible).
- Un sistema externo *inyectó* algo (p. ej. un SCP que añade tags corporativos a todos los recursos nuevos).

En el **próximo plan**, el `refresh` ve el valor real, el diff aparece como `~` o `-/+`, y Terraform propone "revertir" la realidad hacia el estado deseado. Esto puede ser **correcto** (quieres que la infra vuelva a lo versionado) o **catastrófico** (el cambio manual era legítimo y lo vas a romper).

Dos matices importantes para evaluarse:

- Si **desactivas el refresh** (`-refresh=false`) o si tu plan **no toca** un recurso derivado, Terraform **no detecta** el drift de ese recurso. Correr `apply` sin plan previo tampoco garantiza detectar todo (en versiones recientes `apply` refresca por default, pero no todos los flows lo hacen).
- Hay drift que Terraform **jamás** verá: tags que un SCP añade *fuera-de-banda*, atributos que el provider no mapea del `GET`, cambios en recursos que ni siquiera están en tu código.

Por eso en producción madura se corre un **drift-detection job** scheduled (`plan` periódico que compara state vs real) y se alerta sobre diferencias.

---

## 5. Ejemplo mínimo

**Sin instalar nada**, imagínate que ya tienes Terraform y acabas de escribir estos dos archivos. Vamos a *leer* el flujo. (Los ejemplos reales ejecutables llegan en `tf-02`.)

`main.tf`:

```hcl
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "local" {}

resource "local_file" "hello" {
  filename = "${path.module}/hello.txt"
  content  = "Hola, Terraform"
}
```

**Si fuera la primera vez** (no hay `.tfstate` todavía), un `plan` imaginario diría:

```
Terraform will perform the following actions:

  # local_file.hello will be created
  + resource "local_file" "hello" {
      + content  = "Hola, Terraform"
      + filename = "./hello.txt"
      + id       = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

Léelo despacio:

- `+ resource "local_file" "hello"` — se va a crear.
- `+ content = "Hola, Terraform"` — con este contenido.
- `+ id = (known after apply)` — el `id` es un **atributo computado** por el provider; se sabrá *después* de crear. Esto es exactamente la razón de ser del state (§4.4): guardará ese `id` para la próxima vez.
- `Plan: 1 to add, 0 to change, 0 to destroy.` — resumen.

Un `apply` imaginario:
- Llama al provider `local` → crea el archivo `./hello.txt`.
- Escribe el `id` real en `.tfstate` junto con `content` y `filename`.
- Resultado: 1 recurso en el state, 1 archivo en el disco.

**Si corres `plan` otra vez** (sin cambiar nada):

```
No changes. Your infrastructure matches the configuration.
```

Idempotencia (§2.2) en acción. Lo mismo si corres `apply` otra vez — no hace nada.

---

## 6. Implementación progresiva

Ahora cambia una línea del código:

```hcl
resource "local_file" "hello" {
  filename = "${path.module}/hello.txt"
  content  = "Hola, Terraform 1.0"      # <-- cambió
}
```

El próximo `plan` muestra:

```
  # local_file.hello will be updated in-place
  ~ resource "local_file" "hello" {
      ~ content  = "Hola, Terraform" -> "Hola, Terraform 1.0"
        filename = "./hello.txt"
        id       = "abc123..."
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

Observa:

- `~` → update in-place (el provider `local` sabe cómo cambiar el contenido sin recrear el archivo).
- `filename` sigue mostrándose porque Terraform imprime el objeto completo, pero sin marca (no cambia).
- El `id` sí sale — y es un valor concreto, no `(known after apply)` — porque ya existe en el state.

Ahora cambia el `filename`:

```hcl
  filename = "${path.module}/greet.txt"
```

Para el provider `local`, cambiar el nombre de archivo implica *reemplazar* el recurso (no es mutable). El plan:

```
  # local_file.hello must be replaced
-/+ resource "local_file" "hello" {
      ~ content  = "Hola, Terraform 1.0"
      ~ filename = "./hello.txt" -> "./greet.txt" # forces replacement
      ~ id       = "abc123..." -> (known after apply)
    }

Plan: 1 to add, 1 to destroy.
```

`-/+` → destroy + create. El viejo `./hello.txt` se borra; se crea `./greet.txt`.

Ahora, **borra** el `resource` del `main.tf` por completo. El `plan`:

```
  # local_file.hello will be destroyed
  - resource "local_file" "hello" {
      - content  = "Hola, Terraform 1.0" -> null
      - filename = "./greet.txt" -> null
      - id       = "abc123..." -> null
    }

Plan: 0 to add, 0 to change, 1 to destroy.
```

`-` → destroy. El state todavía lo tiene; tu código ya no. El diff es "quitar".

Finalmente, **drift simulado**: no cambies nada en el HCL, pero *fuera* de Terraform borra el archivo (`rm ./greet.txt`). El próximo `plan`, tras el refresh, detecta que el archivo no existe pero el state cree que sí:

```
  # local_file.hello has been deleted
  # (because local_file.hello is not in configuration)
   ... o, dependiendo del flow:
  # local_file.hello will be created
  + resource "local_file" "hello" { ... }
```

Terraform propone **re-crearlo** para alinear infra real con estado deseado. Si el borrado manual era intencional, estás a punto de deshacerlo. Si no lo era, Terraform te está salvando. Esa ambigüedad **la decide el humano**, no la herramienta.

---

## 7. Aplicación profesional

En el día a día, el ciclo se ve así en una organización madura (verás los detalles de cada capa en módulos posteriores):

```
   Developer                     CI (GitHub Actions)                 Cloud
   ─────────                     ───────────────────                 ─────
   edita .tf     ──PR──>         terraform fmt
                                 terraform validate
                                 terraform plan   ────lectura────>   [refresh]
                                 comentario del plan en el PR
                                       │
                                       ▼
                                 (review humano del plan)
                                       │
                                 ──merge main──
                                       │
                                       ▼
                                 terraform apply  ────escritura──>   [create/update/destroy]
                                 actualiza state remoto
                                 (lock durante el apply)
```

Puntos clave:

- **El plan vive en el PR** como artefacto de revisión. Nunca se aplica "a ciegas".
- **El state es remoto** (S3+DynamoDB, HCP Terraform, GCS, …), con *locking* para que dos pipelines no apliquen al mismo tiempo.
- **Credenciales efímeras** (OIDC desde GHA al cloud, sin access keys estáticas).
- **El plan se puede guardar** (`-out=plan.tfplan`) para que el apply ejecute exactamente lo revisado, sin TOCTOU entre plan y apply.
- **Scheduled drift detection**: un job periódico corre `plan -refresh-only` y alerta si hay diferencias.

Nada de esto es exclusivo de Terraform. Es el **patrón GitOps de infra** y Terraform es su encarnación más adoptada.

---

## 8. Trade-offs

### 8.1 IaC declarativa (Terraform) vs IaC imperativa (Pulumi, CDK)

| Dimensión | Declarativa (HCL) | Imperativa (TS/Python/Go) |
|-----------|-------------------|---------------------------|
| Curva de entrada | Más suave (HCL es pequeño) | Más dura si no sabes el lenguaje |
| Flexibilidad | Limitada a lo que HCL permite | Infinita (loops, abstracciones, tests) |
| Reproducibilidad | Alta (menos "trucos") | Variable (depende de disciplina) |
| Testing | `terraform test` + Terratest | Tests unitarios del lenguaje host |
| Mercado 2026 | Dominante en infra | Creciente en orgs ya en Node/Python |

La elección honesta es "¿tu equipo ya vive en un lenguaje general y le duele el DSL?" vs "¿valoras el techo bajo de HCL para que todos lean lo mismo?".

### 8.2 Terraform vs CloudFormation / ARM / Deployment Manager

Los IaC propietarios de cada cloud (CloudFormation en AWS, ARM/Bicep en Azure, Deployment Manager en GCP) **son nativos**: no necesitan un state separado, el cloud mantiene el "stack" para ti. Ventajas: cero fricción de operación. Desventajas: solo ese cloud, menos ecosistema, modelo mental ligeramente distinto por cada uno.

Si estás *monocloud por decisión* y nunca vas a mover, un IaC nativo es defendible. Si hay cualquier chance de multi-cloud, SaaS, o quieres portabilidad del skill del equipo, Terraform gana.

### 8.3 Terraform vs Configuration Management (Ansible, Chef, Puppet)

**No compiten en lo mismo.** Terraform *provisiona* (crea la VM, la red, el disco). CM *configura dentro* (instala paquetes, edita archivos de config). En el stack real suelen convivir: Terraform crea la VM; Ansible la configura. Alternativa moderna: Terraform crea la VM a partir de una **AMI preconstruida** con Packer; CM se evita en producción.

Usar Ansible para crear recursos cloud es posible pero resulta en pseudo-IaC con menos garantías que Terraform. Usar Terraform para editar `/etc/nginx/nginx.conf` dentro de una VM es antinatural (los `provisioner` existen pero son último recurso).

### 8.4 Terraform vs OpenTofu

**Fork drop-in.** Mismo HCL, mismos providers, state compatible. Diferencias actuales (2026): algunos features puntuales (state encryption nativa, `removed` blocks más agresivos, provider-defined functions en OpenTofu antes que en Terraform). Licencia: OpenTofu es Apache 2.0; Terraform es BUSL (restringe uso competitivo, no uso normal).

Para este módulo: todo aplica a ambos. En `tf-13` se trata el criterio de elección.

---

## 9. Errores frecuentes

### 9.1 "Lo cambié en la consola y ahora Terraform quiere romper mi infra"

Clásico. Alguien tocó la consola; el próximo plan muestra `~` o `-/+` para "revertir" tu cambio. Terraform *está haciendo su trabajo*: la fuente de verdad es el código, no la consola. Resolución: o aplicas el cambio en el HCL (y vuelve a estar alineado), o usas `ignore_changes` para atributos que *sabes* que otro sistema gestiona, o reconsideras si ese cambio debería estar fuera de Terraform.

### 9.2 "Borré el `.tfstate` para 'empezar de cero'"

Error grave. La infra real sigue existiendo; Terraform ya no la reconoce. Al próximo `apply`, intenta *crearla otra vez* y choca con "already exists". Resolución: `terraform import` recurso por recurso (lento) o recuperar el state de backup (siempre tienes backup, ¿no?). En este módulo basta con que entiendas por qué pasa.

### 9.3 "Apply sin plan"

En CI se ve: `terraform apply -auto-approve` como primer paso. Problema: nadie vio el plan. Un cambio inocente en una variable puede desencadenar `-/+` en recursos de prod. **El plan existe para ser leído**, no para saltárselo. En pipelines maduros: `plan` en PR, `apply` del plan guardado en merge.

### 9.4 "Dos personas aplicando al mismo tiempo"

Sin locking, dos `apply` concurrentes corrompen el state. Síntomas: estados inconsistentes, recursos duplicados en el state, apply que falla en medio y deja todo roto. Resolución: backend remoto **con locking** (S3+DynamoDB, GCS con lock nativo, HCP Terraform). Nunca pongas state local en producción.

### 9.5 "Pensar que el state es documentación"

El state es **datos operacionales**, no una fuente para humanos. Contiene valores en claro (incluyendo outputs que puedan ser sensibles). Nunca lo subas a Git. Nunca lo leas "porque sí" en producción — pide los outputs con `terraform output`, no abras el JSON.

### 9.6 "Confundir `data` con `resource`"

(Lo verás en `tf-03`.) Un `resource` lo *gestiona* Terraform (crea/modifica/destruye). Un `data` solo lo *lee* (existe fuera de Terraform; lo consulta). Confundirlos lleva a "¿por qué quiere destruir mi VPC?" (porque la declaraste como `resource` cuando debió ser `data`).

### 9.7 "No existe drift porque yo no toqué nada"

El drift puede venir de SCPs, de otros equipos, de automatizaciones existentes, de operaciones de soporte del cloud. **Siempre** asume que puede haber drift. En producción madura se corre drift detection scheduled, no "cuando toque".

---

## 10. Buenas prácticas

- **Lee el plan línea a línea antes de aplicar.** Los `-/+` son los peligrosos: están destruyendo algo. Si estás viendo `-/+` en prod y no era lo que esperabas, **para**.
- **Guarda el plan** (`-out=plan.tfplan`) en CI y aplica *ese* plan. Evita que algo cambie entre que se revisó y se aplicó.
- **Backend remoto con locking desde el primer día**, aunque solo seas tú. Migrar luego es doloroso.
- **El state nunca a Git.** `.gitignore` con `*.tfstate*`, `.terraform/`, `*.tfvars` (los `.tfvars` suelen tener secretos).
- **Un workspace lógico por ambiente separado físicamente** (directorios o backends distintos para dev/stg/prod). "Workspaces de CLI" para feature environments efímeros, no para prod (ver `tf-08`).
- **Credenciales efímeras** (OIDC) en CI. Nunca access keys estáticas en el runner.
- **Plan en PR, apply en merge, con approval**. GitOps.
- **Drift detection scheduled** en producción.
- **No tengas miedo del state** — explóralo con `terraform state list` y `terraform state show`. Es tu amigo, no magia.
- **"Antes de instalar nada", entiende el modelo.** Este módulo existe por eso.

---

## 11. Ejercicios recomendados

1. **`activities/01-draw-the-cycle/`** — produce un diagrama ASCII del ciclo y responde 7 preguntas sin consultar la lección. **Independent**.
2. **`activities/02-why-do-we-need-state/`** — argumenta por qué el state es necesario, qué es drift, por qué `apply` por sí solo no lo detecta todo. **Independent**.

Son conceptuales. Si no puedes escribirlas con tus palabras, el modelo mental todavía no está firme.

---

## 12. Evaluación

Responde sin consultar la lección ni la documentación. Si tienes que buscar, re-lee la sección correspondiente.

**P1.** Verdadero / falso:
- [ ] Terraform guarda el estado real en los archivos `.tf`.
- [ ] El `.tfstate` es una caché opcional que acelera `plan`.
- [ ] Un provider es parte del binario de Terraform (viene preinstalado).
- [ ] `terraform plan` nunca llama a la API cloud.

**P2.** En tus palabras, explica el ciclo `init → plan → apply → destroy` **sin mencionar comandos** — descríbelo como qué le pasa a "estado deseado", "state de TF" e "infra real" en cada fase.

**P3.** ¿Qué significa cada símbolo en el output de un plan?
- `+` : ...
- `-` : ...
- `~` : ...
- `-/+` : ...
- `<=` : ...

**P4.** Un recurso aparece como `-/+` en el plan. ¿Qué quiere decir? ¿Quién decide que es `-/+` y no `~`?

**P5.** Explica qué es **drift** y da un escenario concreto en el que ocurre. ¿Por qué `terraform apply` por sí solo no garantiza detectar *todo* el drift?

**P6.** Argumenta en 3–5 frases por qué una herramienta IaC declarativa **no puede** prescindir de un state persistente. Nombra al menos dos razones distintas de las obvias ("para saber qué cambió").

**P7.** Un compañero dice: "la próxima vez, mejor que Terraform *no mantenga state* — que en cada plan vaya a AWS y pregunte todo. Es más simple." ¿Qué le respondes, con precisión?

**P8.** Diseño: tu equipo está empezando a usar Terraform. Decides **cinco** cosas antes de escribir el primer `resource`. ¿Cuáles y por qué?

---

## Referencias

Documentación oficial (verificar fecha de consulta):

- *Terraform Introduction* — <https://developer.hashicorp.com/terraform/intro>
- *What is Terraform?* — <https://developer.hashicorp.com/terraform/intro/what-is-terraform>
- *Terraform core workflow* — <https://developer.hashicorp.com/terraform/intro/core-workflow>
- *State overview* — <https://developer.hashicorp.com/terraform/language/state>
- *State purpose (why Terraform needs state)* — <https://developer.hashicorp.com/terraform/language/state/purpose>
- *Plan representation (JSON)* — <https://developer.hashicorp.com/terraform/internals/json-format>
- *OpenTofu docs* — <https://opentofu.org/docs/>

Lectura complementaria:

- Yevgeniy Brikman, *Terraform: Up & Running* (3ª ed.), caps. 1–2. Introducción conceptual canónica.
- *Pro Git* (Chacon/Straub) — no es sobre Terraform pero el patrón "working tree + index + repo" y "deseado + staged + commits" es análogo al "código + state + infra".
- *HashiCorp "Infrastructure as Code in a Private or Public Cloud"* (whitepaper original de 2015, aún útil como contexto histórico).
