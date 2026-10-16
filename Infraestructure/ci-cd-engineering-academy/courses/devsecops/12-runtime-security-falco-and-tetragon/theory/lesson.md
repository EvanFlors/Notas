# sec-12 — Lección: runtime security con Falco y Tetragon

> 12 secciones. Explica por qué la admisión no basta, cómo funciona Falco y Tetragon, cómo escribir reglas sin ahogarte en falsos positivos, y cómo pasar de detectar a bloquear sin romper producción.

---

## 1. Por qué runtime security — las tres cosas que la admisión no cubre

Si vienes del módulo `sec-11` tienes un cluster con **Kyverno** o **Validating Admission Policies** rechazando Pods sin firma, con `runAsRoot`, o con imágenes de registries no autorizados. ¿Y entonces?

La admisión es un **gate estático**. Mira el manifiesto una vez, dice sí/no, y se olvida. Tres clases de amenaza se le escapan por diseño:

1. **Zero-days en runtime.** Una imagen que pasó Trivy ayer puede tener mañana un CVE crítico recién publicado. Nadie bloqueó su despliegue porque el CVE no existía. El contenedor ya está corriendo.
2. **Exploits de dependencias en caliente.** Un `requests==2.31.0` instalado puede estar siendo explotado por una payload que llega vía HTTP. La imagen es "limpia", lo que no es limpio es la **ejecución**.
3. **Insider threats y supply-chain post-admisión.** Alguien con `kubectl exec` abre un shell dentro de un Pod de producción y empieza a leer `/etc/shadow`. El manifiesto estaba perfecto; el **comportamiento** no.

El patrón se repite: la seguridad **antes** de que la carga corra (escaneo + firma + admisión) **no puede ver** lo que la carga hace **mientras** corre. Para eso hace falta observar el **kernel**: cada `execve`, cada `openat`, cada `connect`. Esa es la capa que Falco y Tetragon ocupan.

> **Idea clave:** admisión responde "¿puedo arrancar esto?". Runtime responde "¿lo que está arrancado se está portando bien?".

---

## 2. eBPF: el sustrato común

Tanto Falco como Tetragon usan **eBPF** como mecanismo de observación. En una frase: eBPF permite ejecutar **pequeños programas verificados** dentro del kernel, enganchados a puntos de interés (syscalls, tracepoints, kprobes), **sin cargar módulos propios y sin reiniciar**.

Lo relevante para nosotros:

- **Visibilidad total**: cualquier `execve` ocurre en kernel; eBPF lo ve.
- **Overhead bajo**: los programas se compilan a bytecode BPF y los ejecuta la VM del kernel.
- **Seguridad**: el verificador rechaza programas que puedan colgar el kernel (sin loops, sin accesos arbitrarios).
- **Portable**: `CO-RE` (Compile Once, Run Everywhere) permite distribuir un binario que funciona en kernels distintos.

Antes de eBPF, Falco usaba un **kernel module propio** (invasivo, difícil de distribuir, roto en cada versión de kernel). Hoy el driver recomendado es `modern_ebpf`.

---

## 3. Falco — arquitectura y modelo de reglas

**Falco** (CNCF, originalmente de Sysdig) es un **motor de reglas sobre eventos del kernel**. Su arquitectura mínima:

```
┌──────────────────────────────────────────────────────────────┐
│                        Falco DaemonSet                       │
│                                                              │
│   driver (modern_ebpf | kmod | ebpf)                         │
│       │                                                      │
│       ▼                                                      │
│   libscap  ──► eventos de syscalls (execve, openat, ...)     │
│       │                                                      │
│       ▼                                                      │
│   libsinsp ──► enriquecimiento (container, k8s, proc tree)   │
│       │                                                      │
│       ▼                                                      │
│   rules engine ──► evalúa condiciones ──► output             │
│                                              │               │
│                                              ▼               │
│   stdout | file | gRPC | Falcosidekick → Slack / SIEM / ...  │
└──────────────────────────────────────────────────────────────┘
```

Un **evento Falco** es un diccionario rico: tiene campos como `proc.name`, `proc.cmdline`, `proc.pname`, `fd.name`, `fd.directory`, `container.id`, `container.image.repository`, `k8s.ns.name`, `k8s.pod.name`, `user.name`, `evt.time`.

Una **regla** combina esos campos con operadores (`=`, `in`, `startswith`, `contains`) y macros reutilizables:

```yaml
- rule: Terminal shell in container
  desc: A shell was spawned by a program in a container with an attached terminal.
  condition: >
    spawned_process and container
    and shell_procs
    and proc.tty != 0
    and container_entrypoint
    and not user_expected_terminal_shell_in_container_conditions
  output: >
    A shell was spawned in a container with an attached terminal
    (user=%user.name user_loginuid=%user.loginuid %container.info
    shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline terminal=%proc.tty)
  priority: NOTICE
  tags: [container, shell, mitre_execution]
```

Observa:

- `spawned_process`, `container`, `shell_procs`, `container_entrypoint` son **macros** definidas en `falco_rules.yaml`.
- `not user_expected_terminal_shell_in_container_conditions` es la **puerta de supresión** — así se exceptúan hosts/namespaces/pods legítimos.
- `priority` controla la severidad (`EMERGENCY` → `DEBUG`). Para pipelines de alerta: `WARNING` suele ser el filtro.
- `tags` son metadata (MITRE ATT&CK, dominio).

---

## 4. Las reglas canónicas que debes conocer

Falco ships con ~80 reglas en `falco_rules.yaml` + `k8s_audit_rules.yaml`. Las que casi todo equipo activa primero:

| Regla | Qué detecta | Por qué importa |
|-------|-------------|-----------------|
| `Terminal shell in container` | `bash`/`sh`/`zsh` con TTY en un contenedor | Primer indicador de intrusión manual o `kubectl exec` indebido. |
| `Write below etc` | Escritura en `/etc/*` | Modificación de configuración del sistema desde runtime. |
| `Read sensitive file untrusted` | `openat` sobre `/etc/shadow`, `/etc/sudoers`, llaves SSH | Credential harvesting. |
| `Launch Privileged Container` | Container con `privileged: true` corriendo | Combinarlo con admisión; detecta drift. |
| `Change thread namespace` | `setns`, breakout de namespaces | Intento de container escape. |
| `Unexpected egress connection` | `connect` a IP no en whitelist | C2 / exfiltración. |
| `Modify binary dirs` | Escritura en `/bin`, `/usr/bin`, `/sbin` | Trojanización del sistema. |
| `Mkdir binary dirs` | `mkdir` bajo `/bin`, etc. | Igual que arriba. |
| `K8s Secret Get Successfully` (audit) | `kubectl get secret` exitoso | Enumeración de secretos. |
| `K8s ServiceAccount Created` (audit) | SA nuevo | Preparación de persistencia. |

Nota: las reglas `K8s*` **no** vienen de syscalls — vienen del **audit log del API server**, que Falco también sabe consumir vía webhook.

---

## 5. Falsos positivos — la razón nº 1 por la que Falco "no funciona"

El patrón que mata a los equipos: activan Falco con reglas por defecto, el canal de Slack recibe 3.000 alertas por hora, nadie las mira, Falco se desinstala al mes. La causa es siempre la misma: **las reglas por defecto están pensadas para contenedores de producción "limpios"**, y la realidad incluye operadores que hacen `kubectl exec` legítimos, jobs que escriben logs en lugares raros, agentes de observabilidad que leen `/proc` y `/etc/os-release`, etc.

El workflow correcto:

1. **Audit mode** primero: Falco corre, loguea, nadie actúa.
2. **Mide base rate**: cuántos eventos por hora, por regla, por namespace.
3. **Suprime lo esperado**: añade `and not <excepción>` a las condiciones ruidosas, o usa el mecanismo de `exceptions` de Falco (desde Falco 0.31) que es más mantenible.
4. **Promueve a alerta** solo lo que ya sobrevivió al filtrado.
5. **Revisa trimestralmente**: cada deploy nuevo puede introducir FP; sin revisión las supresiones se vuelven ciegas.

> Regla operativa: una regla que genera >5 alertas/día sin acción humana es una regla **rota**. Suprime o reescribe.

---

## 6. Tetragon — detección + enforcement, por eBPF

**Tetragon** (del proyecto Cilium / Isovalent) viene de la misma familia conceptual: observar eventos del kernel vía eBPF. La diferencia clave:

| | Falco | Tetragon |
|---|-------|----------|
| Mecanismo | eBPF / kmod | eBPF (BTF/CO-RE) |
| DSL | `falco_rules.yaml` (campos + macros) | `TracingPolicy` CRD (K8s nativo) |
| Alcance eventos | syscalls + k8s audit | syscalls + exec + exit + file + network + Linux Security Modules |
| Enforcement | **No** (solo detecta) | **Sí**: `enforcer` puede matar el proceso o devolver `-EPERM` |
| Integración K8s | Pod/NS enrichment | Pod/NS/labels nativo |
| Output | stdout, gRPC, falcosidekick | stdout JSON, gRPC, export a OTel/SIEM |

Una `TracingPolicy` que detecta y **mata** cualquier `openat` sobre `/etc/shadow`:

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: block-shadow-read
spec:
  kprobes:
    - call: "security_file_permission"
      syscall: false
      args:
        - index: 0
          type: "file"
        - index: 1
          type: "int"
      selectors:
        - matchArgs:
            - index: 0
              operator: "Equal"
              values:
                - "/etc/shadow"
            - index: 1
              operator: "Mask"
              values:
                - "4"   # MAY_READ
          matchActions:
            - action: Sigkill
```

Esto es cualitativamente distinto a Falco: no genera "una alerta" — **termina el proceso**. Esa es la razón por la que Tetragon se usa a menudo **junto** a Falco (Falco amplio y detectivo, Tetragon selectivo y preventivo), no en lugar de él.

---

## 7. Detección vs prevención — cómo elegir

Marco de decisión por regla:

| ¿Qué detecta? | ¿Falso positivo rompería negocio? | Recomendación |
|---------------|-----------------------------------|---------------|
| Shell en contenedor | Sí (operadores legítimos durante incidentes) | **Falco detect** + runbook humano |
| Lectura de `/etc/shadow` desde un Pod | Casi nunca | **Tetragon enforce** (`Sigkill`) |
| Escritura en `/etc/passwd` | Casi nunca | **Tetragon enforce** |
| Egress a IP externa no esperada | Depende (microservicio con webhooks a Stripe) | **Falco detect** y, si hay allowlist estable, Tetragon enforce |
| Carga de módulo kernel desde Pod | Nunca legítimo | **Tetragon enforce** |

**Nunca** empieces por enforce global. El patrón que funciona: audit por N semanas → ver el ruido → promover a enforce **regla por regla** y **con rollback plan** (basta borrar la `TracingPolicy`).

---

## 8. Output y respuesta — a quién le llega la alerta

Una alerta sin receptor es ruido en disco. Opciones típicas:

- **stdout + logs centralizados** (Loki, CloudWatch, ELK): obliga a tener detección en el stack de logs. Lo más universal.
- **Falcosidekick**: proyecto hermano de Falco que redirige a Slack, PagerDuty, Teams, OpsGenie, SIEM, Kafka, S3, webhook arbitrario.
- **gRPC**: para plataformas que consumen el stream en vivo.
- **SIEM** (Splunk, Elastic Security, Sentinel): correlación con otros signals (CloudTrail / Audit Logs / NetFlow).

Un **runbook** mínimo por regla debe incluir:

1. **Qué significa** esta alerta (en una línea).
2. **Qué información mirar primero** (campos clave: pod, imagen, usuario, cmdline).
3. **Query de correlación** (audit log del API server; CloudTrail si hubo acceso cross-service).
4. **Decisión**: ¿cuarentena del Pod? ¿evacuación del nodo? ¿reset de credenciales?
5. **Postmortem checklist**.

---

## 9. Integración con audit logs — por qué el forense necesita dos lados

Cuando llega una alerta "shell en contenedor", quieres saber **cómo** llegó esa shell:

- ¿Vino de `kubectl exec`? → Audit log del API server (`verb: create, resource: pods/exec, user: <quien>`).
- ¿Vino de un exploit en la app? → No habrá entrada en audit; sí la hay en Falco (padre del shell = proceso de la app).
- ¿Vino de un atacante que ya se movió? → Audit log del API server + CloudTrail (quién creó el token, desde qué IP).

Falco por sí solo responde "qué pasó dentro del contenedor". Audit log responde "quién lo autorizó". **El forense sólido requiere los dos**.

---

## 10. Operación — del día 1 al día 90

| Fase | Semana | Objetivo | Qué entregar |
|------|--------|----------|--------------|
| 0 | 0 | Decisión + diseño | ADR de "Falco sí/no", output elegido, roles. |
| 1 | 1–2 | Deploy audit-only | DaemonSet Falco en kind/dev; stdout + Loki. |
| 2 | 3–4 | Medir base rate | Tabla reglas × alertas/día × namespace. |
| 3 | 5–6 | Suprimir ruido | Reglas con `exceptions`; documentar cada supresión. |
| 4 | 7–8 | Alertas accionables | Falcosidekick → Slack con 1 canal por severidad. |
| 5 | 9–12 | Tetragon selectivo | TracingPolicies de enforcement para 2–3 casos "nunca legítimos". |
| ∞ | trimestral | Revisión | ¿Qué reglas no dispararon nunca? ¿cuáles son todas FP? ¿qué CVEs nuevos requieren regla nueva? |

---

## 11. Anti-patrones comunes

- **"Instalamos Falco y ya estamos cubiertos."** Falco **detecta**; sin runbook ni dueño, no estás cubierto.
- **Enforcement global desde día 1.** Vas a matar un Pod legítimo en producción en menos de una semana.
- **Ignorar `k8s_audit_rules.yaml`.** Más de la mitad de los TTPs relevantes para Kubernetes están ahí.
- **No versionar reglas custom.** Las reglas son código: Git, PR, review.
- **Mezclar reglas globales con reglas por servicio** sin namespaceear. Imposible mantener.
- **Alertar a #general.** Un canal dedicado + rotación on-call o se vuelve folklore.

---

## 12. Checklist de salida del módulo

- [ ] Puedes explicar en una frase qué cubre runtime security que admisión no cubre.
- [ ] Nombras 5 reglas Falco canónicas y qué syscall / evento disparan.
- [ ] Diferencias Falco (detect) de Tetragon (detect + enforce).
- [ ] Dado un evento JSON de Falco, extraes la regla, el Pod, el comando y el usuario.
- [ ] Escribes una regla custom con `condition`, `output`, `priority`, `tags` y `exceptions`.
- [ ] Aplicas una TracingPolicy con `matchActions: Sigkill` y entiendes cómo revertir.
- [ ] Redactas un runbook de respuesta para la regla "shell in container".
- [ ] Decides, dado un escenario, si usar Falco detect o Tetragon enforce — y defiendes la elección contra FP/alert fatigue.
