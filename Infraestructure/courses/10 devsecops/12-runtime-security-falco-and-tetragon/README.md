# sec-12 — Runtime security con Falco y Tetragon

## Identificación

- **ID:** `sec-12-runtime-security-falco-and-tetragon`
- **Curso:** `devsecops`
- **Nivel:** producción
- **Duración estimada:** 4 h
- **Prerrequisitos:** `sec-11` (Kyverno / Validating Admission Policies). Bases de Kubernetes (`kubectl`, Pods, DaemonSets). Nociones de syscalls y eBPF (no obligatorias).

## Objetivo

Montar una capa de **runtime security** sobre un cluster de Kubernetes capaz de **detectar** comportamiento sospechoso en caliente (shell dentro de un contenedor, lectura de `/etc/shadow`, escritura en `/etc/`), y entender la diferencia con **enforcement activo** (bloqueo). Al terminar deberías poder desplegar **Falco** y **Tetragon** en kind, interpretar un evento, escribir una **regla de dominio** propia y redactar un runbook de respuesta.

## Alcance

Este módulo cubre:

- **Por qué runtime**: la admisión (`sec-11`) y el escaneo (`sec-05`, `sec-06`) **no cubren todo** — zero-days, exploits de dependencias en caliente, insiders, cadenas de supply-chain comprometidas en runtime.
- **Falco**: arquitectura (userspace rules engine + driver eBPF / modern BPF / kernel module), **lenguaje de reglas** (condiciones sobre eventos de syscalls y K8s audit), reglas canónicas (`Terminal shell in container`, `Write below etc`, `Read sensitive file untrusted`), outputs (stdout, Falcosidekick → Slack/SIEM/webhook).
- **Tetragon**: proyecto Cilium basado en eBPF, con **detección + enforcement** (TracingPolicy con `enforcer` → `SIGKILL`), visibilidad a nivel de proceso (`exec`, `exit`, `syscall`, acceso a archivos), integración con labels K8s.
- **Detección vs prevención**: Falco **detecta** (envía alerta), Tetragon puede además **bloquear**. Elección por caso de uso: alert fatigue vs riesgo de romper carga legítima.
- **Respuesta**: alerta → SIEM / webhook; o enforcement activo; **runbook** con pasos claros y correlación con audit logs del cluster y CloudTrail.
- **Operación práctica**: empezar en **audit mode**, medir falsos positivos, refinar reglas, luego pasar a enforcement selectivo. Nunca enforcement global en día uno.

Lo que **no** cubre:

- Diseño de agentes eBPF propios → fuera del scope.
- SIEM / plataforma de alertas → se trata como output (Slack / webhook / stdout).
- `sec-13` (Vault / ESO) → módulo siguiente.

## Nota de plataforma — IMPORTANTE

**Falco y Tetragon requieren un kernel Linux real** (eBPF o kernel module). En **macOS con Docker Desktop** el cluster `kind` corre dentro de la VM de Docker — Falco **sí** se puede desplegar en esa VM, pero la carga de módulo kernel puede fallar según la versión; el driver `modern_ebpf` suele funcionar. Para evitar romper la clase si el entorno no coopera:

- Todos los scripts `validate.sh` y de setup **detectan la plataforma** y degradan a modo **walkthrough-only** si Falco no arranca.
- Los ejemplos incluyen **sample event JSON** reales para que puedas practicar parseo y escritura de reglas sin levantar el cluster.
- La actividad 02 (`rule-authoring-exercise`) es 100 % offline — no requiere cluster.

## Materiales

- **`theory/lesson.md`** — lección profunda (12 secciones).
- **`examples/`** — tres ejemplos demostrativos:
  - `01-falco-in-cluster/` — instalar Falco en `kind` con Helm, DaemonSet, driver `modern_ebpf`, lectura de alertas.
  - `02-write-falco-rule/` — anatomía de una regla, custom rule que detecta `curl` descargando binarios a `/tmp` y ejecutándolos.
  - `03-tetragon-tracingpolicy/` — instalar Tetragon, TracingPolicy que registra `openat` en `/etc/shadow` y bloquea con `enforcer`.
- **`activities/`** — dos actividades independientes:
  - `01-trigger-and-detect-shell-in-pod/` — scenario: desplegar workload víctima, provocar `kubectl exec` que abra un shell, verificar que Falco levantó la alerta, redactar `DETECTION.md` con runbook. Si Falco no se puede levantar: usar `sample-events.json` provisto y hacer el análisis offline.
  - `02-rule-authoring-exercise/` — independent: dado un caso ("alguien escribe en `/var/log` con `chmod 777`"), escribir regla Falco custom + racional de FP/FN. 100 % offline.
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué admisión + escaneo no bastan. Diferenciar Falco (detect) de Tetragon (detect + enforce). Enumerar las categorías de reglas Falco canónicas. |
| Operativa | Desplegar Falco en kind (o justificar modo walkthrough), interpretar un evento JSON, escribir una regla propia, aplicar una TracingPolicy de Tetragon. |
| Arquitectónica | Diseñar la salida (SIEM, Slack, webhook), decidir cuándo pasar de audit a enforcement, redactar un runbook. |

## Criterios de evaluación

- Nombra 5 reglas Falco canónicas y qué syscall / evento disparan.
- Dado un evento JSON de Falco, extrae: regla, prioridad, campos `k8s.pod.name`, `proc.cmdline`, `fd.name`.
- Escribe una regla custom con `condition`, `output`, `priority` y `tags` coherentes.
- Explica, con una TracingPolicy, cuándo Tetragon mataría un proceso y cómo volver atrás.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Falco + Tetragon desplegados en `kind` detectando un patrón de prueba (o walkthrough documentado con sample events).
- `DETECTION.md` (actividad 01) con runbook de respuesta.
- `RULES.md` + `custom-rules.yaml` (actividad 02) con una regla propia defendida contra FP/FN.

## Siguiente módulo

→ `sec-13-secrets-at-scale-vault-eso-and-workload-identity` — operar secretos a escala con Vault, ESO y Workload Identity.
