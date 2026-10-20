# Ejemplo 02 — Tiller vs Helm 3: contexto histórico

## Concepto que demuestra

Por qué **Helm 2 + Tiller** fue abandonado y qué cambió al pasar a **Helm 3 client-side**. Es un ejemplo **conceptual** — no se ejecuta nada. El objetivo es que, cuando alguien proponga "resucitar algo tipo Tiller" o cuando leas un tutorial viejo, reconozcas inmediatamente el problema.

## Contexto

Entre 2016 y 2019 Helm 2 fue el estándar. Su arquitectura incluía un componente **in-cluster** llamado **Tiller**. En noviembre de 2019 Helm 3 GA lo eliminó. Entender por qué es parte del vocabulario profesional, aunque no vayas a tocar Helm 2 nunca.

## Objetivo

Al terminar podrás:

- Dibujar la arquitectura de Helm 2 (cliente + Tiller + API server) y de Helm 3 (solo cliente + API server).
- Enumerar al menos **cuatro** problemas de Tiller.
- Explicar por qué el modelo client-side de Helm 3 es más seguro, más auditable y más apto para multi-tenancy.
- Reconocer tutoriales obsoletos por su mención a `helm init`, `tiller-deploy`, `TILLER_NAMESPACE`, etc.

## Prerrequisitos

- Haber leído `theory/lesson.md` §3 (contexto histórico) y §4 (funcionamiento interno).

## Diagrama 1 — Helm 2 (con Tiller) — **OBSOLETO**

```
┌─────────────────┐              ┌──────────────────────────────┐
│  cliente helm   │   gRPC       │  CLUSTER                     │
│  (tu laptop)    │─────────────▶│                              │
│                 │   (TLS opt)  │  ┌────────────────────────┐  │
│   helm install  │              │  │  Tiller (Deployment)   │  │
│   helm upgrade  │              │  │  namespace: kube-system│  │
│   helm rollback │              │  │                        │  │
└─────────────────┘              │  │  ServiceAccount:       │  │
                                 │  │   tiller               │  │
                                 │  │  ClusterRoleBinding:   │  │
                                 │  │   cluster-admin (!!)   │  │
                                 │  │                        │  │
                                 │  │  render templates      │  │
                                 │  │  → apply al apiserver  │  │
                                 │  │  guarda release en CMs │  │
                                 │  │  del namespace kube-   │  │
                                 │  │  system                │  │
                                 │  └──────────┬─────────────┘  │
                                 │             │ apply como     │
                                 │             │ 'tiller' SA    │
                                 │             ▼                │
                                 │  ┌────────────────────────┐  │
                                 │  │  kube-apiserver        │  │
                                 │  └────────────────────────┘  │
                                 └──────────────────────────────┘
```

### Problemas de este modelo

1. **Permisos amplios por diseño.** Tiller necesitaba poder crear *cualquier* tipo de recurso en *cualquier* namespace para que *cualquier* chart funcionara. La configuración documentada era `ClusterRoleBinding` a `cluster-admin`. **Cualquiera con acceso a Tiller era `cluster-admin` del cluster.**

2. **Autenticación débil cliente → Tiller.** Entre `helm` y Tiller había gRPC. TLS mutuo era **opt-in** y mal documentado. En clusters mal configurados, cualquier Pod con red hacia `kube-system` podía invocar al Tiller y escalar privilegios inmediatamente.

3. **Auditoría distorsionada.** El API server veía todas las operaciones como hechas por `ServiceAccount: tiller`. No sabías *qué humano* había pedido *qué release*. El `audit log` perdía utilidad forense.

4. **Multi-tenancy imposible.** Un solo Tiller por cluster servía a todos los equipos. Aislar tenants con el *mismo* Tiller era un ejercicio hostil (y a menudo imposible). Workarounds con "Tiller por namespace" eran parches, no una solución.

5. **Punto único de operación / consistencia.** Un `helm upgrade` que fallaba a mitad podía dejar el estado de Tiller inconsistente y bloquear futuras operaciones sobre la misma release. Los operadores pasaban horas depurando "lo que piensa Tiller".

6. **Un componente más que operar.** Tiller era un Deployment más que mantener: upgrades, HA, TLS, backups de ConfigMaps de estado...

## Diagrama 2 — Helm 3 (sin Tiller) — **ACTUAL**

```
┌─────────────────────────────────────┐
│  cliente helm (tu laptop / runner)  │
│                                     │
│  1. carga chart (local o pull)      │
│  2. merge values                    │
│  3. render templates (Go + Sprig)   │
│  4. produce YAML plano              │
└───────────────────┬─────────────────┘
                    │  apply vía kubeconfig
                    │  (identidad del usuario / SA del runner)
                    │  REST sobre HTTPS
                    ▼
       ┌──────────────────────────────┐
       │  kube-apiserver              │
       │   authn → authz (RBAC)       │
       │   → admission → persist      │
       └──────────────┬───────────────┘
                      │
                      ▼
       ┌──────────────────────────────┐
       │  Namespace de la release:    │
       │   - recursos aplicados       │
       │     (Deployment, Service, …) │
       │   - Secret                   │
       │     sh.helm.release.v1.<r>.<N>│
       │     (estado de la release)   │
       └──────────────────────────────┘
```

### Qué resuelve

| Problema de Helm 2 | Cómo lo resuelve Helm 3 |
|--------------------|-------------------------|
| Tiller con `cluster-admin` | **No hay Tiller.** Helm usa tu kubeconfig; tus permisos son los que vigen. |
| Autenticación débil cliente ↔ Tiller | **No hay gRPC a Tiller.** El cliente habla directo con el API server (TLS + authn del kubeconfig). |
| Auditoría distorsionada | **Audit log registra tu usuario / tu SA.** Trazabilidad real. |
| Multi-tenancy imposible | **Cada operador trae su kubeconfig / SA.** Natural: RBAC estándar de Kubernetes gobierna. |
| Punto único de operación | **No hay singleton.** El estado de cada release vive en un Secret de *su* namespace, independiente. |
| Un componente más que operar | **No hay nada que operar.** `helm` es un binario local. |

### Otros cambios notables de Helm 3

- **Estado en Secrets** (default) en el **namespace de la release**, no ConfigMaps en `kube-system`.
- **Releases namespace-scoped.** En Helm 2 el nombre de la release era global al cluster; en Helm 3 el mismo nombre puede repetirse en namespaces distintos.
- **Directorio `crds/`** especial para CRDs: se crean en `install`, **no** en `upgrade` (seguridad: evitar romper a otros usuarios de la CRD).
- **Soporte OCI** (desde 3.8): los charts se publican como artefactos OCI en los mismos registries que las imágenes.
- **`helm serve` eliminado** (servía un repo local). Si quieres un repo HTTP, levántalo tú con nginx o usa OCI.

## Pistas para reconocer un tutorial de Helm 2 obsoleto

- Menciona `helm init` o `helm reset`.
- Habla de "instalar Tiller en el cluster".
- Usa `tiller-deploy`, `TILLER_NAMESPACE`, `tiller-system`.
- Enseña a dar `cluster-admin` a un ServiceAccount `tiller`.
- `Chart.yaml` con `apiVersion: v1` (Helm 2); Helm 3 usa `apiVersion: v2`.
- Habla de "dependencies" en `requirements.yaml` separado (Helm 2); Helm 3 las integra en `Chart.yaml` bajo `dependencies:`.

Si ves cualquiera de esos, **cierra la pestaña** y busca una guía de Helm 3.

## Observaciones

1. **La decisión no fue cosmética.** Pasar a client-side cambió el modelo de seguridad entero. Esto es raro — proyectos maduros rara vez rompen compatibilidad por diseño; cuando lo hacen, suele indicar que el problema original era grave.
2. **No hay vuelta atrás razonable.** Hoy nadie serio propone un modelo con daemon in-cluster para rendering. Las necesidades de "centralización" se cubren con GitOps (Argo CD, Flux) — un controller que *consume* Helm, no un Helm que *es* el controller.
3. **El audit log ganó valor.** En producción regulada, poder decir "la release X la aplicó el pipeline Y como SA Z en el tag commit abc123" es un requisito, no un lujo. Helm 3 lo permite nativamente.
4. **El modelo escala a GitOps.** Argo CD y Flux prefieren rendering client-side (ellos mismos renderizan el chart y aplican) porque les da control del lifecycle. Un Tiller intermedio sería un impedimento.

## Próximo paso

→ `activities/01-install-helm-and-explore/` — instala `helm` y verifica que todo lo del ejemplo 01 funciona en tu entorno.
