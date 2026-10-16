# argo-13-01 — Portar el capstone de Argo CD a Flux

## 1. Identificación
- **ID:** `argo-13-01-port-capstone-from-argocd-to-flux`
- **Tecnología:** argocd-gitops
- **Módulo:** 13-flux-as-alternative
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

En `argo-04` desplegaste el capstone (una aplicación empaquetada como Helm chart, con values por entorno) usando una `Application` de Argo CD con `source.helm`. Tu tarea aquí: **reimplementar ese mismo despliegue en Flux**, sin modificar los manifests subyacentes (el chart y los values se quedan como están — eso es lo que hace la migración reversible).

Esto no es un lab guiado. Debes decidir estructura, nombres y detalles. El validador comprueba el **resultado observable**, no los pasos.

## 3. Objetivos

Al terminar debes poder demostrar:

1. Flux instalado en un cluster local `kind` llamado `argo-13-01` (o cualquier nombre; el validador acepta el contexto activo).
2. Un `GitRepository` apuntando a algún repo (público o local) donde vive el chart o los values del capstone.
3. Un `HelmRelease` (o alternativamente `Kustomization` si decides renderizar vía Kustomize + plain yaml) desplegando el capstone en el namespace `capstone`.
4. Al menos un `Deployment` desplegado por Flux y reportando `Ready` en ese namespace.
5. Un `README-port.md` tuyo en `solution/` explicando **qué decidiste y por qué** (chart source vs plain yaml, prune on/off, intervalos, dependsOn si aplica).

## 4. Prerrequisitos

- Conocimientos: `argo-04` completado (capstone Argo CD operativo o al menos su chart Helm disponible).
- Software: `kind`, `kubectl`, `flux` CLI, `helm`.
- Infra: capacidad de levantar un cluster `kind` local (Docker running).
- **Costos:** ninguno (todo local).

## 5. Instrucciones

Esta actividad es **independiente**. Decide tu enfoque. Sugerencias no vinculantes:

- Opción A — "sustitución directa": tu `source.helm` de Argo CD apunta a un chart repo o a un repo Git. Crea el `HelmRepository` o `GitRepository` equivalente en Flux, luego un `HelmRelease` con los **mismos** `values`. Nada en el chart cambia.
- Opción B — "podinfo como stand-in": si no tienes capstone propio, usa `podinfo` del repo `stefanprodan/podinfo` como *proxy del capstone*. Es trivial de desplegar y el aprendizaje de portar es idéntico.
- Opción C — "Kustomize path": si tu capstone usa Kustomize overlays, usa `Kustomization` CR en vez de `HelmRelease`.

En cualquier opción:

- Namespace target: **`capstone`** (requerido por el validador).
- Al menos un `Deployment` debe existir y estar `Available`.
- No instales Argo CD y Flux reconciliando el **mismo** recurso al mismo tiempo.

Entrega en `solution/`:

```
solution/
├── README-port.md       (tu decisión y por qué)
├── manifests.yaml       (tus CRs: GitRepository/HelmRepository + HelmRelease/Kustomization)
└── run.sh               (idempotente, instala flux + aplica manifests.yaml)
```

## 6. Resultado esperado

- `kubectl -n flux-system get helmreleases,kustomizations` muestra tu CR.
- `kubectl -n capstone get deploy` muestra al menos un Deployment con `AVAILABLE >= 1`.
- `flux get all -A` reporta `Ready=True` sobre tu release.

## 7. Criterios de aceptación

| Criterio | Verificado por |
|---|---|
| Flux está instalado en el cluster activo | `tests/validate.sh` |
| Existe un `HelmRelease` **o** una `Kustomization` custom (no las del flux-system bootstrap) | `tests/validate.sh` |
| El namespace `capstone` existe y tiene ≥ 1 Deployment con replicas disponibles | `tests/validate.sh` |
| Los CRs reportan `Ready=True` | `tests/validate.sh` |
| Existe `solution/README-port.md` con una decisión documentada | `tests/validate.sh` |

## 8. Validación

```bash
bash tests/validate.sh
```

El validador asume que **ya ejecutaste** tu `solution/run.sh` contra el cluster activo. Si no hay cluster, SKIP limpio.

## 9. Preguntas de reflexión

1. ¿Tu `HelmRelease` ejecuta `helm install` real? ¿Cómo lo compruebas (y por qué eso importa comparado con Argo CD)?
2. ¿Qué pasaría si Argo CD y Flux reconciliaran el **mismo** `Deployment` en paralelo? Explícalo en términos de `fieldManager` y SSA.
3. ¿Es tu solución reversible a Argo CD con cambios mínimos? ¿Qué habría que tocar?
4. Si tuvieras un chart con hooks `pre-install`, ¿se comportaría igual bajo Argo CD y bajo Flux? ¿Por qué?

## 10. Extensiones

- Añade `dependsOn` para separar CRDs vs app (si tu chart instala CRDs).
- Añade un `Alert` + `Provider` tipo `generic` (webhook) para loggear eventos.
- Activa image automation **nativa** para que tu capstone bump el tag solo.

## 11. Limpieza

```bash
bash solution/run.sh cleanup   # si implementaste modo cleanup
# o:
kind delete cluster --name argo-13-01   # si usaste ese nombre
rm -rf /tmp/argo-13-01-*
```
