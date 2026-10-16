# Ejemplo 01 — `helm create`: qué genera y qué recortar

## Concepto que demuestra

El scaffold que produce `helm create <name>`, archivo por archivo, y el criterio
para **recortar** los knobs innecesarios antes de hacer tuyo el chart.

## Contexto

`helm create` es cómodo pero genera un chart "demo" con parámetros que casi
ninguna app real necesita (HPA, ingress con TLS, `imagePullSecrets`,
`autoscaling`, `podSecurityContext`, `tolerations`, `nodeSelector`, `affinity`,
etc.). Dejar todo "por si acaso" es cómo nacen los charts inmantenibles.

## Objetivo

Al terminar, podrás responder:

- ¿Qué archivos genera `helm create` y cuál es el rol de cada uno?
- ¿Qué puedo eliminar y por qué?
- ¿Por qué `_helpers.tpl` **sí** vale la pena conservarlo?

## Prerrequisitos

- `helm` instalado (`helm version` → `v3.x`).
- Shell POSIX.

> Si no tienes `helm` instalado, lee el walkthrough: la salida está transcrita
> abajo.

## Ejecución

```bash
# Preparar
rm -rf /tmp/helm-scaffold && mkdir -p /tmp/helm-scaffold && cd /tmp/helm-scaffold

# 1. Generar scaffold
helm create demo-app
tree demo-app -a    # (si no tienes tree: find demo-app -maxdepth 2)
```

Salida típica (resumida):

```
demo-app/
├── .helmignore
├── Chart.yaml
├── charts/
├── templates/
│   ├── NOTES.txt
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   └── tests/
│       └── test-connection.yaml
└── values.yaml
```

```bash
# 2. Ver el tamaño del values.yaml por default
wc -l demo-app/values.yaml
# ~90-130 líneas de knobs, la mayoría comentados.

# 3. Render con defaults para ver qué sale
helm template demo-app ./demo-app | head -80
```

### Recorte deliberado

Para una app FastAPI simple que solo necesita Deployment + Service + probes,
borra lo siguiente:

```bash
cd demo-app
rm -f templates/hpa.yaml
rm -f templates/ingress.yaml
rm -f templates/serviceaccount.yaml   # (opcional: si no gestionas RBAC acotado aún)
rm -f templates/httproute.yaml        # Helm v4 scaffold trae Gateway API
rm -rf templates/tests                # (lo veremos en helm-07)
```

> Nota: la lista exacta depende de la versión de Helm. **v3** scaffoldea
> `hpa.yaml`, `ingress.yaml`, `serviceaccount.yaml`, `tests/`. **v4** scaffoldea
> `httproute.yaml`. `rm -f` tolera archivos ausentes y cubre ambos casos.

Simplifica `values.yaml` (reemplazo mínimo sugerido):

```yaml
image:
  repository: ghcr.io/acme/demo-app
  tag: ""                 # fallback a .Chart.AppVersion
  pullPolicy: IfNotPresent

replicaCount: 2

service:
  type: ClusterIP
  port: 80
  targetPort: 8000

resources:
  requests: { cpu: 100m, memory: 128Mi }
  limits:   { cpu: 500m, memory: 512Mi }
```

Y en `templates/deployment.yaml`, elimina los bloques de `nodeSelector`,
`tolerations`, `affinity`, `podSecurityContext`, `imagePullSecrets`,
`serviceAccountName`, `autoscaling`. Mantén `_helpers.tpl` **intacto** — sus
labels y nombres estables son correctos.

```bash
# 4. Verificar que sigue siendo válido
helm lint .
helm template release-x . | wc -l   # <<< menos líneas que antes
```

## Resultado esperado

- Scaffold generado y entendido archivo por archivo.
- Versión recortada con solo `deployment.yaml`, `service.yaml`,
  `_helpers.tpl`, `NOTES.txt` y un `values.yaml` reducido.
- `helm lint` pasa.

## Interpretación

- Un chart "demo" minimiza decisiones del autor exponiendo *todo* como
  parámetro. Un chart propio toma decisiones y expone solo lo que **debe** ser
  configurable.
- `_helpers.tpl` del scaffold es *el único activo real* que vale la pena
  conservar: labels y nombres estables alineados con la convención
  `app.kubernetes.io/*`.

## Errores frecuentes

- Dejar `templates/ingress.yaml` "por si acaso": si tu app no se expone por
  Ingress, es ruido que confunde a quien lee `values.yaml`.
- Borrar `_helpers.tpl` entero: pierdes `fullname`, `labels`, `selectorLabels`
  y rompes las convenciones estándar de Kubernetes.

## Limpieza

```bash
rm -rf /tmp/helm-scaffold
```
