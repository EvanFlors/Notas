# Ejemplo 01 — Push vs pull: diagramas anotados y camino de credenciales

## Concepto que demuestra

Las dos arquitecturas de entrega — **push** (CI aplica al cluster) y **pull** (agente in-cluster aplica desde Git) — dibujadas en paralelo, con énfasis en **dónde viven las credenciales** y qué pasa si se compromete cada actor. Es un ejemplo **conceptual**: no requiere cluster ni Argo CD.

## Contexto

En `theory/lesson.md` §4.2 ya se describieron los dos modelos. Aquí los **ves dibujados** y comentados pieza a pieza, con el camino de las credenciales trazado explícitamente. Si cuando termines este ejemplo no puedes reproducir los dos diagramas de memoria, re-lee la lección antes de hacer las actividades.

## Objetivo

Al terminar, podrás:

- Dibujar los dos modelos de memoria.
- Nombrar en cada uno **dónde vive el `kubeconfig`** con admin del cluster.
- Explicar qué pasa, en términos de blast radius, si se compromete el **CI runner**, el **repo de código**, el **repo de infra** o el **agente**.
- Explicar por qué el modelo pull no elimina riesgos — los **reubica** a sitios más defendibles.

## Prerrequisitos

- Haber leído §2 y §4 de `theory/lesson.md`.

## Diagrama 1 — Modelo push (anti-GitOps)

```
┌─────────────────┐
│   Developer     │
│  (laptop)       │
└────────┬────────┘
         │ git push
         ▼
┌─────────────────────────────┐
│   Repo de codigo            │
│   (app + Dockerfile +       │
│    manifests YAML)          │
└────────┬────────────────────┘
         │ trigger
         ▼
┌─────────────────────────────────────────┐
│   CI runner (GitHub Actions)            │
│   -----------------------------         │
│   SECRETS DEL REPO:                     │
│     KUBECONFIG_PROD   (admin!)          │
│     KUBECONFIG_STG    (admin!)          │
│     REGISTRY_TOKEN                      │
│                                         │
│   Steps:                                │
│     1. docker build + push a GHCR       │
│     2. aws eks update-kubeconfig        │
│     3. kubectl apply -f manifests/      │
│         (abre conexion al API server    │
│          del cluster target)            │
└──────────┬──────────────────────────────┘
           │  TLS, token/cert cliente
           │  (admin del cluster)
           ▼
┌─────────────────────────────────────────┐
│   Cluster target (prod)                 │
│                                         │
│   API server recibe apply:              │
│     authn OK (cert valido)              │
│     authz OK (role=cluster-admin)       │
│     admission OK                        │
│     persistido en etcd                  │
│                                         │
│   Controllers reconcilian el cambio.    │
│                                         │
│   (Nadie observa drift. Si manana       │
│    alguien edita a mano, nadie se       │
│    entera hasta el proximo apply.)      │
└─────────────────────────────────────────┘
```

**Credenciales de admin del cluster viven**: en el **CI runner** (secretos del repo de GitHub). Potencialmente **en varios runners** (uno por entorno) y **en varios repos** (uno por app).

**Blast radius si se compromete**:

- **Developer laptop** — puede commitear malicioso; vía CI escala a cluster. Mitigacion: branch protection + revisores.
- **Repo de codigo** — mismo nivel; branch protection + CODEOWNERS protegen.
- **CI runner** — **catastrofico**. Tiene kubeconfig con admin. Un workflow malicioso puede hacer cualquier cosa en el cluster. Mitigacion: OIDC federation en vez de token estatico ayuda pero no elimina — el runner sigue teniendo acceso.
- **Registry** — puede inyectar imagen maliciosa; si no hay cosign + Kyverno, el cluster la ejecuta.

## Diagrama 2 — Modelo pull (GitOps)

```
┌─────────────────┐
│   Developer     │
│  (laptop)       │
└────────┬────────┘
         │ git push
         ▼
┌─────────────────────────────┐
│   Repo de codigo            │
│   (app + Dockerfile +       │
│    chart base)              │
└────────┬────────────────────┘
         │ trigger CI
         ▼
┌─────────────────────────────────────────┐
│   CI runner (GitHub Actions)            │
│   -----------------------------         │
│   SECRETS DEL REPO:                     │
│     REGISTRY_TOKEN                      │
│     GH_APP_TOKEN  (write a repo infra)  │
│   NO HAY kubeconfig. NO TOCA cluster.   │
│                                         │
│   Steps:                                │
│     1. docker build + push a GHCR       │
│     2. cosign sign imagen               │
│     3. clone repo-infra                 │
│     4. yq eval -i '.image.tag="v1.2.1"' \
│          envs/dev/values.yaml           │
│     5. git commit + push                │
│        (o abrir PR; segun politica)     │
└──────────┬──────────────────────────────┘
           │ commit
           ▼
┌─────────────────────────────────────────┐
│   Repo de infra (manifests)             │
│   -----------------------------         │
│   branch protection: main               │
│     requires 1 approving review         │
│     requires CODEOWNERS                 │
│     requires status checks              │
│   Promocion dev -> stg -> prod:         │
│     PRs explicitos entre carpetas o     │
│     entre branches.                     │
└──────────┬──────────────────────────────┘
           │
           │ pull (polling 3 min + webhook)
           │
           ▼
┌─────────────────────────────────────────┐
│   Cluster target (prod)                 │
│                                         │
│   Agente GitOps (Argo CD o Flux)        │
│   DENTRO del cluster:                   │
│     ServiceAccount local                │
│     TokenRequest / cert cliente         │
│     RBAC acotado al scope del agente    │
│                                         │
│   Loop continuo:                        │
│     1. git fetch del repo infra         │
│     2. render (helm template / kustom)  │
│     3. diff desired vs actual           │
│     4. apply via API server local       │
│     5. actualiza status.sync / health   │
│     6. repite cada N minutos            │
│                                         │
│   Si alguien edita a mano:              │
│     drift visible al instante           │
│     (y revertido si selfHeal: true)     │
└─────────────────────────────────────────┘
```

**Credenciales de admin del cluster viven**: **dentro del cluster**, en el agente. Hay **una** instalacion (o pocas, con multi-cluster) — no hay dispersion.

**Blast radius si se compromete**:

- **Developer laptop** — igual que antes. Mitigacion: branch protection.
- **Repo de codigo** — puede inyectar codigo malicioso en la imagen. Mitigacion: scanning + cosign + Kyverno que exija firma al desplegar.
- **CI runner** — **mucho menor**. Puede subir imagenes maliciosas al registry y escribir en el repo de infra (si tiene write). Mitigacion: push al repo de infra via **PR** con revisores, no via commit directo; cosign + Kyverno impiden desplegar imagen no firmada.
- **Repo de infra** — ahora es el punto caliente. Mitigaciones: branch protection + CODEOWNERS + rulesets + revisores de release.
- **Agente in-cluster** — compromiso = admin del cluster. Pero esta en el mismo cluster, bajo las mismas politicas que el resto; es un workload mas que endurecer. Hardening: ver `argo-11`.

## Comparativa de credenciales lado a lado

| Actor | Push | Pull |
|-------|------|------|
| CI runner | kubeconfig(cluster_admin) | registry_token + git_write(infra_repo) |
| Repo de codigo | — | — |
| Repo de infra | n/a o solo lectura | branch_protection + CODEOWNERS |
| Agente in-cluster | n/a | ServiceAccount local con RBAC acotado |
| Human operator | kubectl con admin ad-hoc | kubectl *restringido*; cambios reales via PR |

**Lo clave**: el modelo pull **no elimina las credenciales de admin**. Las **reubica** a un sitio donde:

1. Hay **menos actores** con acceso (un agente in-cluster vs N runners externos).
2. El actor esta **dentro del cluster** (misma superficie que ya endureces).
3. El punto humano de intervencion es el **repo de infra** (defendible con PR + revisores + rulesets — una interfaz explicita y auditable).

## Qué pasa en un incidente

Escenario: Pod crashea en prod a las 3 AM; alguien decide "apagar temporalmente la readiness probe para que no entre en loop".

**Push**:
- Operador hace `kubectl edit deploy/web` → quita la probe. Sistema estabiliza.
- No hay registro automatico del cambio. El operador debe recordar documentarlo.
- Dias despues, un deploy normal (pipeline push) sobreescribe el cambio sin avisar — la probe vuelve, el bug vuelve.

**Pull**:
- Opcion A: operador hace `kubectl edit` igual → agente revierte en 3 minutos (selfHeal). Problema persistente.
- Opcion B: operador hace PR al repo de infra con la probe modificada + comentario del incidente → merge con un reviewer → agente aplica. **Documentado automaticamente** en Git.
- Opcion C: operador desactiva sync temporal en Argo CD UI → hace cambio manual → hay **registro de "sync disabled"** visible a todo el equipo. Al re-activar, se reconcilia.

En todas, el cambio queda **visible**. En push, muchas veces no.

## Resultado esperado

Después de leer los dos diagramas deberías poder:

1. Dibujar ambos modelos de memoria.
2. Nombrar dónde vive el `kubeconfig` con admin en cada caso.
3. Explicar por qué el agente in-cluster es **más defendible** que un runner externo con kubeconfig.
4. Dar un ejemplo concreto de drift silencioso en push y cómo pull lo hace visible.

## Interpretación

- **GitOps no es "más seguro" por magia.** Es más seguro porque **reduce el número de actores con credenciales de admin del cluster** y los pone en un lugar más defendible.
- **El modelo pull introduce un nuevo punto crítico**: el **repo de infra**. Si no tiene branch protection + revisores, no has mejorado — has movido el problema.
- **El agente in-cluster corre con permisos de dios**. Operarlo bien es parte del contrato (hardening, backup, upgrade — `argo-11`).

## Errores frecuentes

- **"Pull elimina las credenciales de admin"** — no, las concentra. Hay que endurecer el agente igual que endurecerías cualquier workload con permisos amplios.
- **"GitOps resuelve la seguridad"** — no. Reduce surface de kubeconfig, pero sigues necesitando cosign, Kyverno, scanning, RBAC estricto.
- **"El repo de infra privado no necesita secretos cifrados"** — error peligroso. Privado no es vault. Fugas pasan.
- **"Con pull no puedo hacer nada manual"** — si puedes: sync disabled temporal, `kubectl edit` sabiendo que será revertido (o PR explícito). El punto es que todo cambio quede **registrado**.

## Relación con escenarios reales

- **Compliance (SOC2, PCI, HIPAA)**: GitOps da auditoría nativa — history de Git es history de cambios al cluster. En push hay que armar logs correlacionados a mano.
- **Multi-cluster**: en push, N kubeconfigs dispersos en N pipelines; en pull, N clusters registrados en 1 (o pocas) instalación de Argo CD.
- **Rotación de credenciales**: en push, cada runner, cada entorno. En pull, el ServiceAccount del agente — un solo lugar.

## Limpieza

Nada que limpiar — este ejemplo es conceptual.
