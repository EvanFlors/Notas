# Ejemplo 02 — Walkthrough de los 4 principios de OpenGitOps

## Concepto que demuestra

Los **4 principios de OpenGitOps** (declarative, versioned & immutable, pulled automatically, continuously reconciled) **uno por uno**, con el enunciado formal, un ejemplo que lo cumple y la **violación típica**. Es un ejemplo **conceptual**: no requiere cluster.

## Contexto

En `theory/lesson.md` §4.1 se enunciaron los 4 principios. Aquí los **recorres de uno en uno** con el ojo puesto en reconocer violaciones. Es la preparación directa para la actividad 01 (identificar GitOps-washing).

## Objetivo

Al terminar, podrás:

- Enunciar cada principio con sus palabras.
- Dar al menos **un ejemplo** concreto de un sistema que lo cumple y **uno** que lo viola.
- Reconocer **ambigüedades** típicas (¿bash en Git cuenta como declarativo? ¿polling cada hora cuenta como continuo?).
- Enlazar cada violación con una **consecuencia operativa** real (drift, blast radius, pérdida de auditoría).

## Prerrequisitos

- Haber leído §4 de `theory/lesson.md`.
- Haber recorrido `examples/01-push-vs-pull-diagram/`.

## Enunciado formal

Fuente: **OpenGitOps v1.0.0** — `https://github.com/open-gitops/documents/blob/main/PRINCIPLES.md`.

> A system that follows GitOps principles must have the following properties:
>
> 1. **Declarative** — A system managed by GitOps must have its desired state expressed declaratively.
> 2. **Versioned and Immutable** — Desired state is stored in a way that enforces immutability, versioning and retains a complete version history.
> 3. **Pulled Automatically** — Software agents automatically pull the desired state declarations from the source.
> 4. **Continuously Reconciled** — Software agents continuously observe actual system state and attempt to apply the desired state.

Los 4 son **conjunción**. Falla uno → no es GitOps.

---

## Principio 1 — Declarative

### Enunciado con tus palabras

El estado deseado se expresa como **datos** (YAML, HCL, Jsonnet, Starlark), no como una **secuencia de comandos** que lo produce. Un observador puede leer el estado deseado sin ejecutar nada.

### Cumple

```yaml
# envs/prod/web-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: web
          image: ghcr.io/acme/web:1.2.1
          resources:
            requests: { cpu: 100m, memory: 128Mi }
```

Lee el YAML y sabes el estado deseado. No tienes que ejecutar nada.

### Viola

```bash
#!/usr/bin/env bash
# deploy-web.sh — "manifiesto" en Git
set -euo pipefail

if [ "$ENV" = "prod" ]; then
  REPLICAS=3
else
  REPLICAS=1
fi

kubectl create deployment web \
  --image=ghcr.io/acme/web:1.2.1 \
  --replicas="$REPLICAS"
kubectl set resources deploy/web \
  --requests=cpu=100m,memory=128Mi
```

Script bash en Git. **Da los mismos resultados** (más o menos), pero **no es declarativo**: no puedes observar el estado deseado sin ejecutarlo, no es idempotente sin cuidado, el estado real depende de **cuándo** y **con qué `$ENV`** se ejecutó, no hay diff posible.

### Ambigüedades

- **Helm chart** — ¿declarativo? **Sí**. Un chart renderiza a YAML; el YAML es el estado deseado. Que haya templating no lo hace imperativo.
- **Kustomize overlay** — igual: declarativo.
- **CDK8s / Jsonnet / Pulumi** — generan YAML a partir de código. **Declarativo** si lo que vive en Git es la *descripción* y la generación es determinista y revisable; frontera gris si genera on-the-fly en el cluster sin estado intermedio.
- **Terraform HCL** — declarativo. (OpenGitOps es agnóstico de K8s; aplicar GitOps a Terraform es un patrón real: Atlantis + Terraform Cloud.)
- **ArgoCD Application CR** — es *él mismo* declarativo (apunta a un source declarativo).

### Consecuencia operativa de violarlo

- **No se puede hacer diff**: `argocd app diff` no tiene nada que comparar.
- **No es reversible trivialmente**: `git revert` del script no revierte el estado, solo elimina el script.
- **No es idempotente por diseño**: ejecutar dos veces puede fallar ("ya existe el Deployment").

---

## Principio 2 — Versioned and Immutable

### Enunciado con tus palabras

El estado deseado está en un sistema que **retiene historia completa** y es **inmutable** una vez publicado. Puedes ir a cualquier versión pasada y leerla exactamente como estaba.

### Cumple

- **Git** — commits son SHAs inmutables; history linealizable; branches y tags apuntan a commits concretos.
- Branch protection activado: nadie hace `--force-push` a `main`; releases tagged con tags inmutables.

### Viola

- **Bucket S3** con la última versión de los manifests, sin versionado habilitado. Si sobreescribes `web-deployment.yaml`, la versión anterior **desaparece**.
- Repo Git **con force-push permitido en main**. Técnicamente Git, pero la history es mutable → viola la inmutabilidad en la práctica.
- "Manifests generados on-the-fly por un script del CI y persistidos solo en el cluster" — no hay versión intermedia inspeccionable.

### Ambigüedades

- **S3 con versionado + object lock** — cumple técnicamente, pero perdiste branch/PR/review. Es GitOps con un pésimo UX.
- **Repo Git privado sin branch protection** — cumple **técnicamente** pero sin disciplina. En producción no es defendible.
- **Rebase que reescribe history de un branch de feature antes de merge** — ok si al mergear a `main` el merge commit es inmutable. En `main` no rebases.

### Consecuencia operativa de violarlo

- **Rollback imposible o manual**: sin history no sabes a qué volver.
- **Auditoría débil**: SOC2/HIPAA exigen trazabilidad; sin history no la hay.
- **Debugging imposible**: "¿qué cambió entre ayer y hoy?" no tiene respuesta sin diff.

---

## Principio 3 — Pulled Automatically

### Enunciado con tus palabras

Un **agente dentro del sistema** halla el estado deseado desde la fuente (Git). El actor externo (humano, CI) **nunca** aplica directo al sistema; solo escribe en la fuente.

### Cumple

- Argo CD corriendo en el cluster: polling cada 3 min + webhook de Git → pulls → apply.
- Flux `source-controller` + `kustomize-controller` haciendo igual.

### Viola

- **CI runner que hace `kubectl apply`** al cluster al merge. Clásico anti-patrón.
- **CI runner que hace `helm upgrade --install`** desde fuera. Aunque los charts estén en Git, quien aplica es el runner externo. **No es pull.**
- **Operador humano que corre `terraform apply` desde su laptop** contra un state remoto. (Hay variantes "GitOps-like" para Terraform — Atlantis — que mueven el apply a un bot in-cluster o in-GitOps-system y empiezan a cumplir el principio).

### Ambigüedades

- **Webhook de Git al cluster que gatilla un apply**: si el apply lo hace el agente (en respuesta al webhook), **sí** es pull — el agente decide y aplica. Si el webhook es un endpoint que ejecuta `kubectl` directamente, **no**.
- **Pipeline que escribe en el repo de infra** (en vez de aplicar al cluster): **sí** es pull. El pipeline modificó la fuente de verdad; el agente reconcilia después.

### Consecuencia operativa de violarlo

- **Credenciales de admin del cluster en el runner** → blast radius enorme.
- **No hay separación CI/CD limpia** — mismo actor construye y despliega.
- **Multi-cluster difícil** — cada cluster necesita kubeconfig distribuido a los runners.

---

## Principio 4 — Continuously Reconciled

### Enunciado con tus palabras

El agente **observa el estado real continuamente** y actúa (o alerta) ante desviaciones. **No** aplica una sola vez al commit y "olvida".

### Cumple

- Argo CD con reconciliation loop (default: cada 3 min).
- Flux `kustomize-controller` con `interval: 10m` + drift detection.
- Agente con `selfHeal: true` que revierte cambios manuales en el próximo tick.

### Viola

- Agente configurado para "aplicar al commit y nada más". Un `kubectl edit` manual queda **para siempre** hasta el próximo cambio en Git.
- Pipeline que ejecuta `kubectl apply` al merge sin agente — mismo problema, con el añadido de que viola también el principio 3.
- Cron job que corre `kubectl apply -f manifests/` cada hora **sin diff**: cumple "aplicar continuo" pero no "observar y actuar"; aplica aunque no haya diff — ineficiente y, si hay apply hooks, destructivo.

### Ambigüedades

- **Polling cada hora**: ¿es "continuo"? OpenGitOps no define cadencia exacta. En la práctica, 1–5 minutos es común; una hora empieza a ser "demasiado tarde" para considerarse reconciliación verdaderamente continua.
- **`selfHeal: false`** (solo detecta y alerta) — **sí cumple**. El principio pide "observar y aplicar"; alertar es una forma válida de "aplicar" si la política del equipo es "humano aprueba la reversión". Lo que **no** cumple es "no detectar en absoluto".
- **Modo manual sync** en Argo CD — en Argo CD, "manual sync" significa "no aplica automáticamente, pero sigue observando y reportando OutOfSync". **Cumple** porque reconcilia (observa + reporta); la aplicación la gatilla un humano. Ir más allá y desactivar el loop completo sería la violación.

### Consecuencia operativa de violarlo

- **Drift silencioso**: igual que push. "Agente que solo aplica al commit" = push disfrazado.
- **Alertas inexistentes**: si no observa, no puede alertar.
- **Pérdida del beneficio clave**: la razón número uno para adoptar GitOps es eliminar drift. Sin reconciliación continua, no lo elimina.

---

## Matriz de casos reales

| Caso | 1 Decl | 2 Ver/Inm | 3 Pull | 4 Cont | GitOps? |
|------|:------:|:---------:|:------:|:------:|:-------:|
| Argo CD + Git + `syncPolicy.automated` + `selfHeal` | OK | OK | OK | OK | SI |
| Flux + Git + `interval: 5m` | OK | OK | OK | OK | SI |
| CI runner con `kubectl apply` + manifests en Git | OK | OK | FAIL | FAIL | NO (washing) |
| Argo CD + Git **pero** sync solo al webhook, sin loop | OK | OK | OK | FAIL | NO |
| Script bash en Git + CI que lo ejecuta | FAIL | OK | FAIL | FAIL | NO |
| Terraform HCL en Git + Atlantis in-cluster-ish | OK | OK | ~OK | ~OK | SI-ish (patrones) |
| Manifests en S3 (sin versionado) + Argo CD que lee de S3 | OK | FAIL | OK | OK | NO |
| Argo CD manual-sync (no auto) | OK | OK | OK | OK | SI (reconcilia aunque no aplique solo) |

---

## Resultado esperado

Después de recorrer los 4 principios deberías poder:

1. Enunciarlos con tus palabras sin consultar.
2. Dar un ejemplo que cumpla cada uno y uno que lo viole.
3. Clasificar un sistema arbitrario (como los de la matriz) marcando los 4 checks y concluyendo si es GitOps.
4. Identificar la consecuencia operativa específica de violar cada uno.

Si no puedes hacer esto, re-lee `theory/lesson.md` §4.1 y §9.

## Interpretación

- Los 4 principios son **conjunción**. Falta uno → no es GitOps, aunque suene parecido.
- La violación más común es **la del principio 3 (pulled)**: la gente instala Argo CD y sigue haciendo push desde el pipeline, dejando a Argo CD como "visor bonito".
- La segunda más común es **la del principio 4 (continuously reconciled)** en una variante sutil: desactivar el loop pensando que "ahorra recursos", perdiendo el beneficio principal.

## Errores frecuentes

- **"Script bash en Git es GitOps"** — no. Viola el principio 1 (no declarativo). Da los mismos efectos *a veces*; no describe un estado inspeccionable.
- **"Repo Git = versionado + inmutable automático"** — solo si `main` tiene branch protection sin force-push. Sin disciplina, es mutable.
- **"Si el agente aplica al merge, ya es continuo"** — no. Continuo = sigue observando después del apply. "Apply al merge" sin loop = drift silencioso.
- **"Manual sync no es GitOps"** — sí lo es. Reconcilia (observa + reporta OutOfSync); solo delega el apply al humano.

## Relación con escenarios reales

- **Startup** con 1 cluster y pipeline simple: fácil cumplir los 4 si eligen el stack correcto desde el inicio.
- **Enterprise migrando desde push**: típicamente adoptan **Argo CD primero como visor** y luego "cortan" el pipeline del acceso al cluster. Durante la transición hacen **GitOps-washing temporal** — explícito y con roadmap es aceptable; silencioso y "ya migramos" sin cortar el pipeline es antipatrón.
- **Multi-cluster regulated**: SOC2 pide trazabilidad. Los 4 principios bien cumplidos la dan nativamente — un auditor abre Git history y ve "qué cambió en prod y quién lo aprobó".

## Limpieza

Nada que limpiar — este ejemplo es conceptual.
