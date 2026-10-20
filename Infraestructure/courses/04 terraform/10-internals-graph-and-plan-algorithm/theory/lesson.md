# Lección: Internals — grafo, refresh y algoritmo del plan

> **ID:** `tf-10-internals-graph-and-plan-algorithm` · **Nivel:** avanzado · **Duración:** 4 h
> **Prerrequisitos:** `tf-05-state-basics`, `tf-09-providers-deep-and-lifecycle`.

---

## 1. Introducción intuitiva

Hasta aquí has tratado a `terraform plan` como una caja casi mágica: lees HCL, miras un diff bonito con `+`, `~` y `-`, y aplicas. Funciona el 90 % del tiempo. Pero el otro 10 % duele: un recurso que Terraform propone destruir sin que lo hayas tocado, un `null_resource` que se recrea en cada run, un cambio de un atributo pequeño que cascada en replace de media infraestructura. En esos momentos necesitas una respuesta mejor que "pues eso dijo el plan".

Este módulo te mete bajo el capó. Terraform no es magia: es un **grafo de dependencias**, una **fase de refresh** contra los providers, y un **algoritmo de diff** atributo por atributo. Cada "plan raro" se explica por una combinación concreta de esas tres piezas, y una vez las ves, se depura con `terraform graph`, `terraform show -json` y `jq`.

La promesa del módulo: después de esto, cuando un plan te sorprenda, no te quedas rascándote la cabeza. Abres el JSON y lo demuestras.

---

## 2. Fundamentos

### 2.1 Terraform es un DAG walker

Un stack de Terraform se compila a un **grafo dirigido acíclico (DAG)**. Nodos: `resource`, `data`, `provider`, `module`, `output`, `local`. Aristas: dependencias (A depende de B si A referencia un atributo de B, o si lo declara en `depends_on`).

```
      ┌──────────┐
      │ provider │
      │   null   │
      └────┬─────┘
           │
    ┌──────┴──────┐
    │             │
┌───▼───┐    ┌────▼────┐
│ res A │    │ res B   │
└───┬───┘    └────┬────┘
    │             │
    └─────┬───────┘
          ▼
      ┌───────┐
      │ res C │   (depende de A y B por referencia)
      └───────┘
```

El core camina este grafo en orden topológico. Dentro de "generaciones" independientes paraleliza (hasta `-parallelism=N`, default 10).

### 2.2 El plan tiene tres fases, no una

```
┌────────────────────┐
│ 1. Build the graph │  parse HCL + state → nodos y aristas
└──────────┬─────────┘
           ▼
┌────────────────────┐
│ 2. Refresh          │ para cada resource en state:
│                     │   provider.ReadResource(id) → state_now
└──────────┬─────────┘
           ▼
┌────────────────────┐
│ 3. Diff             │ para cada resource en config:
│                     │   compare desired vs state_now
│                     │   emit action: no-op|create|update|replace|destroy
└────────────────────┘
```

Si corres `terraform plan`, por default pasan las tres. Si corres `terraform plan -refresh=false`, se salta la 2. Si corres `terraform plan -refresh-only`, se detiene al final de la 2 y te enseña qué cambió en la realidad **sin proponer cambios de configuración**.

### 2.3 El provider decide, el core orquesta

Terraform core no sabe nada de AWS, GitHub o `local_file`. Sabe grafos y diffs. Las reglas específicas (qué atributos son `Optional`, cuáles `ForceNew`, qué pasa cuando cambian) viven en el **schema del provider**, que el core le pide al provider en `GetProviderSchema` al arrancar.

Esto desacopla ciclos de release: AWS puede sacar un nuevo recurso sin tocar el core; el core puede mejorar el planificador sin romper providers.

---

## 3. Contexto histórico

- **2014** — Terraform 0.1 ya es un DAG walker.
- **2017** — Introducción del `terraform graph` CLI con tipos (`plan`, `apply`, `plan-destroy`).
- **2018** — Protocolo de plugins se separa en gRPC (v4/v5).
- **2020** — Terraform 0.13: proveedor de providers "oficial" vía Registry; grafo de providers vs recursos se refina.
- **2021** — Terraform 1.0: `terraform show -json` estabiliza su `format_version`.
- **2022** — `-refresh-only` deja de ser experimental y se vuelve el patrón recomendado para reconciliar drift.
- **2023** — Plugin protocol v6 generalizado; soporta función-por-provider (OpenTofu adoptó funciones definidas por provider antes que Terraform).

---

## 4. El grafo con detalle

### 4.1 Tipos de nodo

- **ManagedResource** — un `resource`.
- **DataResource** — un `data`.
- **Provider** — configuración de un provider (puede haber varias con `alias`).
- **Module** — expansión de módulos (cada `module` crea un sub-grafo).
- **Variable / Local / Output** — enlaces de datos.
- **Root** — nodo artificial sin aristas de entrada; punto de arranque del walker.

### 4.2 Aristas

- **Dependencia por referencia** (implícita): `b` referencia `a.id` → arista `a → b`.
- **`depends_on`** (explícita): declara una arista que no se puede inferir por referencias (p. ej. "espera a que esta política IAM exista aunque mi recurso no la nombre").
- **Dependencia a través del provider**: todo recurso depende del nodo provider que lo gestiona (de ahí que renombrar un provider con alias afecte a la topología).

### 4.3 `terraform graph`

```bash
terraform graph                            # grafo de apply (default)
terraform graph -type=plan                 # grafo de plan
terraform graph -type=plan-refresh-only
terraform graph -type=plan-destroy
```

Salida: **DOT** (lenguaje de Graphviz). Para visualizar: `terraform graph | dot -Tsvg > graph.svg`. Si no tienes `dot`, el texto plano ya se lee bien para stacks pequeños.

Tip de lectura: un ciclo en el grafo rompe el plan ("Cycle: ..."). La única solución es romper la referencia circular (quizá partiendo el recurso, quizá moviendo una dependencia a `depends_on`).

---

## 5. La fase de refresh con detalle

Para cada resource con una entrada en el state, el core llama al provider:

```
core ──gRPC: ReadResource(id, prior_state)──▶ provider
     ◀──── new_state (o "ya no existe") ────
```

El provider consulta la API del cloud y devuelve el estado actual de ese recurso. El core sobrescribe esa entrada del state en memoria (en disco todavía no — eso pasa al final del plan si procede).

Casos interesantes:

- **El recurso ya no existe** (alguien lo borró a mano): el provider devuelve "gone". El core marca ese recurso para `create` en el diff — porque la config dice que debe existir.
- **El recurso cambió atributos** (drift): el provider devuelve el nuevo estado. El core verá luego, en el diff, que la config quiere algo distinto y propondrá `update` (o `replace`).
- **El provider timeouteó**: el plan falla. No hay forma correcta de "adivinar" el estado.

Por qué desactivar el refresh (`-refresh=false`) es tentador y peligroso:

- *Tentador*: para stacks grandes, refrescar 500 recursos puede tardar 2 minutos. En CI con muchas corridas, se nota.
- *Peligroso*: trabajas con un snapshot stale. Puedes aplicar un cambio contra un estado real distinto al que crees. Puede ser inocuo (dos tags inconsistentes) o catastrófico (crear algo que "según el state" no existía pero "en la realidad" sí).

Regla práctica: `-refresh=false` solo en runs cortos, de un recurso específico, cuando sabes que nadie tocó la nube desde el último `apply`.

---

## 6. El algoritmo del diff con detalle

Para cada recurso en la configuración, Terraform compara:

- **estado deseado** (`config`, el HCL),
- vs **estado real post-refresh** (`prior_state` actualizado).

La comparación es **atributo por atributo**, usando el schema del provider como guía:

| Caso en el schema | Resultado del diff |
|---|---|
| atributo igual | sin cambio |
| atributo cambia, es `Optional`/`Required` | `update` in-place |
| atributo cambia, es `ForceNew: true` | `replace` (destroy + create) |
| atributo es `Computed` | no se compara; el provider lo rellenará |
| atributo es `Computed + Optional` ("optional+computed") | si lo pones, se compara; si no, lo rellena el provider |
| se ignora por `ignore_changes` | no se compara |

### 6.1 `replace` y sus dos sabores

```
default:                    create_before_destroy = true:
  destroy A → create A'       create A' → destroy A
  (hay downtime)              (sin downtime, A' debe no colisionar)
```

Un `replace` encadena: si B dependía de A (por `a.id`), y A se recrea, B puede quedar afectado (p. ej. `replace_triggered_by` en B).

### 6.2 `(known after apply)`

Aparece en el plan cuando un atributo no se puede predecir hasta que el apply ocurra: típicamente IDs generados por la API (ARN, UUID, timestamp del cloud). Si **otro recurso lee** ese atributo, cascada en más `(known after apply)`. No es error, es honestidad.

### 6.3 Acciones posibles

- `no-op` — nada que hacer.
- `create` — no estaba, hay que crear.
- `read` — para `data` sources que no se pudieron resolver en plan y se diferirán a apply.
- `update` — modificación in-place.
- `delete` — fuera de la config, hay que destruir.
- `replace` (destroy-then-create, o create-then-destroy).

---

## 7. `-refresh-only`: la herramienta de reconciliación

```bash
terraform plan -refresh-only -out=refresh.tfplan
terraform apply refresh.tfplan   # aplica SOLO el update del state
```

Qué hace:

1. Build graph.
2. Refresh (lee la realidad vía providers).
3. **Para el pipeline normal**. No propone cambios de infra.
4. Reporta: "state dice X, realidad dice Y, para N recursos".

Opciones del usuario tras verlo:

- **Aceptar el drift**: aplicas el refresh plan → el state se actualiza para reflejar la realidad. La próxima `plan` normal, en vez de proponer "deshacer el drift", mostrará `no changes` o propondrá tus cambios reales.
- **Revertir el drift**: no aplicas el refresh plan. Haces `terraform apply` normal: la config pisa la realidad, devolviéndola al estado deseado.

Lo opuesto peligroso: ignorar el drift y aplicar `plan` normal "a ciegas" → sobrescribes cambios que quizá otra persona hizo con intención.

---

## 8. `-target`: el *escape hatch*

```bash
terraform plan -target=aws_instance.web
```

Qué hace: construye un **subgrafo** con `aws_instance.web` y sus dependencias (transitivas), ignora el resto, y planifica solo eso.

Por qué es peligroso en producción:

- **Fragmenta la verdad.** El state actualizado parcialmente puede quedar inconsistente con outputs, con módulos consumidores, con policies que miran el plan global.
- **Oculta cambios.** El siguiente plan completo revelará todo lo que `-target` no vio.
- **Normaliza una mala práctica.** Si un equipo usa `-target` para "evitar un cambio molesto", el cambio molesto nunca se arregla y crece.

Casos legítimos (documentados por HashiCorp):

- Desbloquear un provider roto que no deja planear.
- Reparar un recurso específico tras un fallo de API irrecoverable.
- Debugging local de un cambio aislado.

Si lo usas en prod, documenta el porqué y haz después un `plan` completo para confirmar que el state está consistente.

---

## 9. `terraform show -json`: la interfaz pública

```bash
terraform plan -out=plan.out
terraform show -json plan.out > plan.json
```

Estructura de `plan.json` (simplificada):

```
{
  "format_version":  "1.2",
  "terraform_version": "...",
  "variables":        { ... },
  "planned_values":   { ... },   # cómo quedaría todo tras el apply
  "resource_changes": [
    {
      "address": "null_resource.boot",
      "mode":    "managed",
      "type":    "null_resource",
      "name":    "boot",
      "change": {
        "actions": ["replace"],        # <- esto es lo que te interesa
        "before":  { ... },
        "after":   { ... },
        "after_unknown":    { ... },
        "replace_paths":    [["triggers","ts"]]
      }
    }
  ],
  "prior_state":     { ... },
  "configuration":   { ... },
  "output_changes":  { ... }
}
```

Lo que importa casi siempre: `.resource_changes[] | select(.change.actions != ["no-op"])` para ver "qué va a cambiar". Para el "por qué", `.change.replace_paths` o diffear `.change.before` vs `.change.after`.

### 9.1 Patrones `jq` útiles

```bash
# qué recursos tienen alguna acción no trivial
jq '.resource_changes[] | select(.change.actions != ["no-op"]) | .address + " -> " + (.change.actions|tostring)' plan.json

# por qué un recurso se recrea (atributo que disparó el ForceNew)
jq '.resource_changes[] | select(.address=="null_resource.boot") | .change.replace_paths' plan.json

# conteo por tipo de acción
jq '[.resource_changes[].change.actions[]] | group_by(.) | map({action: .[0], n: length})' plan.json
```

---

## 10. El plugin protocol (gRPC)

Core y provider son **procesos distintos**. Al arrancar un comando, el core lanza al provider como subproceso y abre un canal gRPC local. El provider implementa un servicio con operaciones como:

```
GetProviderSchema       -> schema del provider y de sus recursos
ValidateProviderConfig  -> validar el bloque provider "x" { ... }
ValidateResourceConfig  -> validar un resource en HCL (pre-plan)
ReadResource            -> refresh de un recurso existente
PlanResourceChange      -> propuesta de diff (incluye lógica custom)
ApplyResourceChange     -> ejecutar el diff
ImportResourceState     -> traer un recurso existente al state
ReadDataSource          -> resolver un data source
```

```
┌──────────────┐   gRPC localhost   ┌──────────────────┐   HTTPS   ┌───────────┐
│ terraform    │ ─────────────────▶ │  provider plugin │ ────────▶ │ cloud API │
│ core         │                    │  (p. ej. aws)    │           │           │
└──────────────┘                    └──────────────────┘           └───────────┘
```

Dos consecuencias:

1. **Logs separados.** `TF_LOG=TRACE` emite logs del core; `TF_LOG_PROVIDER=TRACE` los del provider. Útil para aislar en qué lado está el bug.
2. **Fallo del provider ≠ fallo del core.** Si el provider revienta, el core lo reporta como "provider crashed"; el state (si no se escribió) queda íntegro.

---

## 11. Errores comunes y antipatterns

- **"El `null_resource` se recrea en cada plan"** — casi siempre un `triggers` no determinista (`timestamp()`, `uuid()`, un hash de archivo que cambia). Diagnóstico: `jq '.resource_changes[] | select(.type=="null_resource") | .change.before, .change.after'`.
- **"Un cambio pequeño está haciendo replace de medio stack"** — un atributo `ForceNew` cambió y otros recursos tienen `replace_triggered_by` sobre él. Mira `.change.replace_paths` del origen y busca `replace_triggered_by` en la config.
- **"Cada vez que planeo, un atributo oscila entre valor1 y valor2"** — drift externo. Opciones: `ignore_changes = [ese_atributo]`, o adoptar el nuevo valor con `-refresh-only`.
- **Usar `-target` como forma habitual de aplicar** — delatas que el stack está mal particionado. Pártelo en módulos/stacks separados con state propio.
- **Desactivar `-refresh` sistemáticamente en CI** — acelera, sí, pero vas a aplicar contra un snapshot stale. Si tienes que hacerlo, pon un drift-detection scheduled job que corra con refresh.

---

## 12. Preguntas de evaluación

Responde sin consultar:

1. Enuncia las tres fases del `plan` y qué hace cada una.
2. ¿Por qué `-refresh=false` es "rápido pero peligroso"? Da un escenario concreto donde produciría un apply erróneo.
3. ¿Quién decide que un atributo requiere `replace` en vez de `update`, el core o el provider? ¿Dónde se declara eso?
4. ¿Qué significa `(known after apply)` en un plan? ¿Es un error?
5. Describe cómo depurarías un `null_resource` que se recrea en cada `plan`, usando `terraform show -json` y `jq`.
6. ¿Qué diferencia hay entre `terraform plan -refresh-only` y `terraform plan -refresh=false`?
7. ¿Por qué `-target` es "escape hatch, no práctica"? Cita dos riesgos concretos.
8. ¿Qué hace `terraform graph` y qué información te da que no te da el plan textual?
9. Dibuja (en ASCII) la cadena core ↔ provider ↔ API y explica qué viaja por cada tramo.
10. ¿Cómo construirías un drift report automatizado a partir de `plan.json`?
