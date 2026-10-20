# Ejemplo 01 — Procesos vs contenedores vs VMs (diagramas)

## Concepto que demuestra

Un contenedor **no es** una mini-VM. Es un **proceso Linux normal** al que el kernel le aplica aislamientos (namespaces) y límites (cgroups). Este ejemplo contrasta visualmente las tres categorías: proceso Linux desnudo, contenedor, VM.

## Contexto

Antes de tocar la CLI de Docker, necesitas poder **dibujar** mentalmente la diferencia. Este ejemplo es conceptual (no requiere Docker instalado). Son diagramas comentados.

## Objetivo

Al terminar, podrás responder sin consultar:

- ¿Qué comparte un contenedor con el host, y qué no?
- ¿Qué cambia *físicamente* entre dos procesos: uno "normal" y uno "en un contenedor"?
- ¿Dónde encaja el hypervisor en una VM y por qué un contenedor no lo necesita?

## Prerrequisitos

- Haber leído §4 de `theory/lesson.md`.

## Diagrama 1 — Proceso Linux "normal"

```
┌───────────────────────────────────────────────────────────────┐
│                         HOST (Linux)                          │
│                                                               │
│   PID 1  systemd                                              │
│   PID 100  sshd                                               │
│   PID 523  bash                                               │
│   PID 847  python app.py       ← nuestro proceso              │
│                                                               │
│   Comparte con el resto:                                      │
│     - tabla de PIDs (ve todos los procesos)                   │
│     - / (filesystem root del host)                            │
│     - interfaces de red (eth0, lo, ...)                       │
│     - hostname del host                                       │
│     - IPC (colas, shm) del host                               │
│     - UIDs/GIDs del host                                      │
│                                                               │
│   Sin cuotas (puede consumir toda la RAM/CPU que haya).       │
└───────────────────────────────────────────────────────────────┘
                              │
                              ▼
                       Kernel Linux
                              │
                              ▼
                         Hardware
```

Un proceso ordinario corre con **todas las vistas globales** del host y sin más límites que `ulimit` individual. Si lanzas una fork-bomb, afecta al host entero.

## Diagrama 2 — El mismo proceso, en un contenedor

```
┌───────────────────────────────────────────────────────────────┐
│                         HOST (Linux)                          │
│                                                               │
│   PID 1  systemd                                              │
│   PID 100  sshd                                               │
│   PID 2314 containerd-shim                                    │
│   PID 2340 python app.py   ← nuestro proceso (visto del HOST) │
│                                                               │
│   ┌───────────────────────────────────────────────────────┐   │
│   │  CONTAINER (vista interna del mismo proceso)          │   │
│   │                                                       │   │
│   │  PID 1   python app.py   ← SE CREE PID 1              │   │
│   │                                                       │   │
│   │  Namespaces propios:                                  │   │
│   │    pid   → solo ve a sí mismo (y a sus hijos)         │   │
│   │    mnt   → "/" es un overlayfs de la imagen           │   │
│   │    net   → eth0 virtual conectada a bridge docker0    │   │
│   │    uts   → hostname = <container-id>                  │   │
│   │    ipc   → colas separadas                            │   │
│   │    cgroup→ ve su propio cgroup, no la jerarquía       │   │
│   │                                                       │   │
│   │  cgroup aplicado por el host:                         │   │
│   │    memory.max = 512M                                  │   │
│   │    cpu.max    = 0.5 CPU                               │   │
│   │    pids.max   = 100                                   │   │
│   │                                                       │   │
│   │  Capabilities DROP por default:                       │   │
│   │    sin CAP_SYS_ADMIN, sin CAP_NET_ADMIN, ...          │   │
│   │                                                       │   │
│   │  Seccomp profile cargado: bloquea ~44 syscalls        │   │
│   │  (ptrace, kexec_load, mount, ...)                     │   │
│   └───────────────────────────────────────────────────────┘   │
│                                                               │
└───────────────────────────────────────────────────────────────┘
                              │
                              ▼
                       Kernel Linux  (EL MISMO del host)
                              │
                              ▼
                         Hardware
```

Lo clave:

- **El kernel es uno solo**. El proceso del contenedor hace syscalls al kernel del host. No hay un segundo kernel.
- **Los PIDs son dos vistas de lo mismo**: el host ve PID 2340; el contenedor ve PID 1. Son el *mismo proceso*.
- **El filesystem es overlayfs**: `/` dentro del contenedor es el merged de las capas de la imagen + un upperdir efímero.
- **cgroups aplican cuotas**: una fork-bomb dentro del contenedor pega contra `pids.max` y muere, sin tocar al host.
- **Capabilities y seccomp reducen el blast radius**: aunque el proceso corra como `root` dentro, no puede `mount(2)` ni `ptrace(2)` al host.

## Diagrama 3 — Una VM (para contrastar)

```
┌───────────────────────────────────────────────────────────────┐
│                         HOST (Linux)                          │
│                                                               │
│   PID 1  systemd                                              │
│   PID 500 qemu-system-x86_64   ← la VM es UN proceso del host │
│                                                               │
│   La VM internamente:                                         │
│   ┌───────────────────────────────────────────────────────┐   │
│   │  GUEST OS (Linux, Windows, BSD, lo que quieras)       │   │
│   │                                                       │   │
│   │  PID 1  systemd (del GUEST)                           │   │
│   │  PID 234 python app.py                                │   │
│   │                                                       │   │
│   │  Tiene SU PROPIO KERNEL (distinto al del host).       │   │
│   │  Tiene SU PROPIO filesystem, red, usuarios, drivers.  │   │
│   │  "Cree" tener su propio hardware (vCPU, vNIC, vDisk). │   │
│   └───────────────────────────────────────────────────────┘   │
│                                                               │
└───────────────────────────────────────────────────────────────┘
                              │
                              ▼
             Hypervisor (KVM, Hyper-V, ESXi, ...)
                              │
                              ▼
                       Kernel Linux (del HOST)
                              │
                              ▼
                         Hardware
```

Lo clave de la VM:

- **Dos kernels corriendo**: el del host y el del guest. El hypervisor orquesta.
- **Aislamiento más fuerte**: un escape del guest requiere romper el hypervisor o la MMU — mucho más difícil que escapar de un namespace.
- **Costo**: GBs de disco, segundos–minutos de arranque, overhead de un kernel completo por VM.
- **Puedes correr OS distintos**: un guest Windows sobre un host Linux es trivial para un hypervisor; es imposible para un contenedor.

## Resultado esperado

Después de leer los tres diagramas deberías poder:

1. Decir *en qué sentido* un contenedor "es un proceso" (literalmente lo es; es un proceso del host con vistas y cuotas distintas).
2. Enumerar al menos 4 cosas que un proceso normal ve y un contenedor NO ve (todos los procesos del host, el `/` real del host, las interfaces reales de red, los usuarios reales).
3. Explicar por qué una VM es "más pesada": kernel completo adicional, hypervisor, hardware virtualizado.

## Interpretación

- "Contenedor Linux sobre host macOS": no existe directamente. Docker Desktop corre una **VM Linux pequeña** (LinuxKit en el pasado, hoy un VMM nativo) y *dentro* de esa VM corre tus contenedores. Es: `macOS → hypervisor → Linux VM → contenedor`.
- "Contenedor Windows": existe (Windows tiene sus propios "job objects" + silos como análogo a namespaces/cgroups). Son otro ecosistema; este curso se enfoca en contenedores Linux.
- "Contenedor privileged": la caja del medio con **la mayoría de aislamientos y capabilities relajados**. Prácticamente un proceso del host corriendo como root. Nunca lo uses sin saber lo que haces.

## Errores frecuentes

- **"El contenedor tiene su propio kernel"** — no. Es el kernel del host. Esa confusión viene de la analogía errónea con VMs.
- **"docker ps me muestra los PIDs del contenedor"** — no, muestra los PIDs del host. El contenedor por dentro ve otros PIDs. Verificable con `docker exec <id> ps auxf` vs `ps auxf` en el host.
- **"Si el host está en un hypervisor, mis contenedores también están virtualizados"** — sí, en un sentido pedante; pero los contenedores siguen compartiendo el kernel del host (que a su vez es un guest del hypervisor). Son dos capas de aislamiento distintas.

## Relación con escenarios reales

- **Elección en cloud**: ¿instancia EC2 corriendo tus contenedores (VM del cloud + contenedores dentro) vs Fargate/Cloud Run (contenedores "sin VM visible" para ti, pero el proveedor sí tiene VMs por debajo)? Entender la jerarquía te permite razonar costos y aislamiento.
- **Debugging**: si tu app ve 32 CPUs cuando el contenedor tiene `--cpus=2`, es porque herramientas como `/proc/cpuinfo` reflejan el **host** (no cgroup-aware). Librerías modernas (`JAVA_TOOL_OPTIONS=-XX:+UseContainerSupport`, Node `--max-old-space-size`) saben de cgroups; algunas viejas no.
- **Seguridad**: cuando leas una CVE de "container escape", la cuenta de impacto va con las capas: un escape de contenedor te da acceso al kernel del host; en una VM necesitarías además escapar del hypervisor.

## Limpieza

Nada que limpiar — este ejemplo es conceptual.
