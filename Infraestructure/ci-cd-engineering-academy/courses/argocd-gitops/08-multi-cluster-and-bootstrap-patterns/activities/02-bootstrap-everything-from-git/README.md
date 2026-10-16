# argo-08-02 — Bootstrap: cluster vacío a estado objetivo con un solo `apply`

## 1. Identificación
- **ID:** `argo-08-02-bootstrap-everything-from-git`
- **Tecnología:** argocd-gitops
- **Módulo:** `08-multi-cluster-and-bootstrap-patterns`
- **Dificultad:** advanced
- **Duración estimada:** 120 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a construir un **bootstrap repo local** y demostrar que, partiendo de un cluster
kind vacío, un único `kubectl apply` lo lleva a un estado objetivo:

- Argo CD instalado (imperativo, primera vez).
- Argo CD gestionado por sí mismo (declarativo).
- Dos add-ons más (metrics-server, un AppProject "platform").
- Una app demo (guestbook) desplegada.
- Un segundo cluster kind **registrado** como spoke a través de un Secret declarativo.

Es el ejercicio canónico del módulo. Es también el punto donde se *siente* el ciclo
chicken-and-egg del self-managing.

## 3. Objetivos

- Materializar un **bootstrap repo** mínimo con el layout de referencia.
- Aplicar un **root ApplicationSet** y observar la cascada de Applications generadas.
- **Registrar un segundo cluster** declarativamente y desplegar algo en él.
- Verificar la convergencia con la **validación automatizada** del lab.

## 4. Prerrequisitos

- **Conocimientos:** `argo-02`, `argo-07`, teoría de este módulo.
- **Software:**
  - `kind` ≥ 0.20
  - `kubectl` ≥ 1.28
  - `docker` corriendo
  - `git` ≥ 2.30
  - `jq` (para el script de validación)
  - `curl` (para fetch del chart Argo CD)
- **Variables de entorno:** ninguna requerida; los scripts aceptan overrides opcionales
  (`BASE`, `HUB_CONTEXT`, `SPOKE_CONTEXT`).
- **Infraestructura:** 2 clusters kind locales (uno hub + uno spoke). ~4 GB RAM libres.
- **Costos potenciales:** **$0** (todo local). Si tu máquina no tiene ≥ 4 GB libres,
  **salta** este lab — el script `starter/bootstrap.sh` detecta `--spoke-only` para hacer
  una versión reducida con un solo cluster.
- **Permisos:** ninguno fuera de tu máquina.

## 5. Instrucciones

Scratch base: `/tmp/argo08`. Todo el lab se materializa ahí; `starter/bootstrap.sh` crea
el layout, los repos locales file:// (sin GitHub), los clusters kind, aplica el root y
espera convergencia.

```bash
cd starter/
./bootstrap.sh                         # crea /tmp/argo08, clusters, bootstrap repo, apply
# Observá:
kubectl --context kind-argo08-hub -n argocd get applications
kubectl --context kind-argo08-hub -n argocd get secret -l argocd.argoproj.io/secret-type=cluster
kubectl --context kind-argo08-spoke -n guestbook get deploy
```

Cuando creas que terminó, corré la validación:

```bash
cd ../tests/
./validate.sh                          # verifica el estado objetivo
```

### Opcional (más interesante)

- Cambiá un `values.yaml` de un add-on, commiteá al repo local, y observá que Argo CD
  reconcilia.
- Simulá "pérdida del hub": `kind delete cluster --name argo08-hub && ./bootstrap.sh`.
  Verificá que el spoke conserva lo desplegado y que el hub recupera el estado.
- Rompé el `Application` que gestiona Argo CD (poné un chart version inexistente) y
  verificá que **nada se cae** porque `selfHeal: false`.

### Pistas

- Si `kind create cluster` falla con "no space left" o "memory", bajá a `--spoke-only`:
  `./bootstrap.sh --spoke-only` (crea solo el hub con guestbook `in-cluster`).
- El Secret del spoke se construye con el IP del container Docker del nodo spoke
  (no 127.0.0.1).
- Argo CD tarda ~2 min en estar listo la primera vez.

## 6. Resultado esperado

- `/tmp/argo08/bootstrap-repo/` existe con el layout canónico.
- En el hub: namespace `argocd` con `argocd-server` Running; `Applications`
  `argo-cd`, `metrics-server`, `guestbook` presentes; Secret `cluster-spoke` presente.
- En el spoke: namespace `guestbook` con los Deployments de la app.
- `tests/validate.sh` imprime `RESULT: 6/6 checks OK` y exit 0.

## 7. Criterios de aceptación

- Un `kubectl apply -f bootstrap/root.yaml` (dentro de `bootstrap.sh`) produce el estado
  objetivo sin más intervención.
- Los Applications del root tienen `selfHeal: true` *excepto* el que gestiona Argo CD,
  que tiene `selfHeal: false` y `prune: false`.
- El Secret `cluster-spoke` tiene la label `argocd.argoproj.io/secret-type: cluster`.
- La validación es reproducible: ejecutada dos veces seguidas devuelve el mismo pass.
- Al terminar, `cleanup.sh` deja la máquina como estaba (ambos kind borrados, scratch
  removido).

## 8. Validación

```bash
cd tests/
./validate.sh
```

Imprime chequeos y el resumen. Exit 0 = aceptación.

## 9. Preguntas de reflexión

- ¿Qué pasaría si pusieras `selfHeal: true` en la `Application` `argo-cd` y commitearas
  una `targetRevision` inexistente?
- ¿Por qué el Secret del spoke no usa `127.0.0.1`? Probá ponerlo así y mirar los logs del
  `application-controller` del hub.
- Si pudieras cambiar *una* cosa del layout para una org real, ¿cuál sería y por qué?
- ¿Cómo cambia el ejercicio si el repo bootstrap vive en GitHub (no `file://`)?

## 10. Extensiones

1. Añadí un tercer cluster `edge` y haceá que ApplicationSet **cluster-generator**
   despliegue guestbook en *todos* los clusters con label `env=lab`.
2. Añadí **cert-manager** al bootstrap y verificá orden por `sync-wave`.
3. Reemplazá los repos file:// por un **Gitea in-cluster** instalado por el mismo
   bootstrap (meta-GitOps).

## 11. Limpieza

```bash
cd starter/
./cleanup.sh                           # borra kind + /tmp/argo08
```

Si algo quedó colgado:

```bash
kind delete clusters argo08-hub argo08-spoke
rm -rf /tmp/argo08
```
