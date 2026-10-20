# argo-09-01 — Secretos del capstone vía ESO (guided-lab)

## 1. Identificación

- **ID:** `argo-09-01-capstone-secrets-via-eso`
- **Tecnología:** argocd-gitops
- **Módulo:** `09-secrets-with-gitops`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

Hasta aquí el capstone venía resolviendo sus secretos con `kubectl create secret` manual — útil para aprender, inaceptable para GitOps. Esta actividad introduce **ESO** como mecanismo de materialización: el repo declara *qué* se necesita, un provider externo guarda el *valor*, y el operator junta las dos cosas en runtime. Es el patrón recomendado hoy para la mayoría de las organizaciones.

El provider usado es el `Fake` que ESO trae de fábrica para tests: los valores se declaran dentro del propio `ClusterSecretStore`. En producción cambiarías `provider.fake` por `provider.aws` / `provider.gcpsm` / `provider.vault`; la forma del `ExternalSecret` **no cambia**.

## 3. Objetivos

Al terminar deberías poder:

- Instalar ESO en un cluster kind.
- Declarar un `ClusterSecretStore` con el provider `Fake`.
- Crear un `ExternalSecret` que materialice un `Secret` nativo con `username` y `password`.
- Rotar un valor en el provider y verificar la propagación automática en < `refreshInterval`.
- Verificar que ningún valor en claro ha quedado en los manifiestos commiteables.

## 4. Prerrequisitos

- Conocimientos: módulo `argo-03`, módulo `k8s-05`.
- Software: `kind` 0.23+, `kubectl`, `helm` 3.14+, `bash`.
- Infraestructura: 2 GB libres, Docker/containerd funcionando.
- Variables de entorno: ninguna.
- Permisos: usuario con Docker ejecutable.
- **Costos**: 0 (todo local, sin cloud).

## 5. Instrucciones

Trabaja desde `/tmp/argo-09-01`. El `starter/` tiene stubs vacíos que debes completar.

### Paso 1 — Scratch dir y cluster

```bash
mkdir -p /tmp/argo-09-01 && cd /tmp/argo-09-01
cp -r <ruta>/starter/* .

kind create cluster --name argo09-01
kubectl create ns external-secrets
kubectl create ns capstone
```

### Paso 2 — Instalar ESO

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --set installCRDs=true --wait
kubectl -n external-secrets wait --for=condition=Available deploy/external-secrets --timeout=120s
```

### Paso 3 — Completar `cluster-secret-store.yaml`

El stub tiene las claves pero sin valores. Añade dos entradas en `provider.fake.data`:

- key `prod/capstone/db` con value JSON `{"username":"capstone","password":"s3cr3t-v1"}`
- key `prod/capstone/api` con value `api-token-v1`

Aplica:

```bash
kubectl apply -f cluster-secret-store.yaml
```

### Paso 4 — Completar `external-secret.yaml`

Debe producir un `Secret` nativo llamado `capstone-db` en el namespace `capstone` con dos keys: `username` y `password`, ambas leídas del JSON de `prod/capstone/db`. `refreshInterval: 30s`, `creationPolicy: Owner`.

```bash
kubectl apply -f external-secret.yaml
kubectl -n capstone wait --for=condition=Ready externalsecret/capstone-db --timeout=60s
```

### Paso 5 — Verificar materialización

```bash
kubectl -n capstone get secret capstone-db -o jsonpath='{.data.password}' | base64 -d
# -> s3cr3t-v1
```

### Paso 6 — Rotar

Edita `cluster-secret-store.yaml` cambiando `s3cr3t-v1` → `s3cr3t-v2`, reaplica, espera 35 s y verifica que el `Secret` nativo tiene el valor nuevo.

### Paso 7 — Verificar higiene de los manifiestos

Ningún archivo del `starter` final debe contener la cadena `s3cr3t-v2` **salvo** `cluster-secret-store.yaml` (que en producción no cargaría valores — es la simulación del provider). Esto lo valida `tests/validate.sh`.

### Paso 8 — Ejecutar validador

```bash
bash tests/validate.sh
```

## 6. Resultado esperado

- `kubectl -n capstone get externalsecret capstone-db` reporta `Ready=True`, `SecretSynced=True`.
- `kubectl -n capstone get secret capstone-db` existe con 2 keys.
- Rotar el valor en el store se propaga en ≤ 60 s.
- `tests/validate.sh` imprime `All checks passed`.

## 7. Criterios de aceptación

- **Funcionalidad**: `Secret` materializado y rotado.
- **Seguridad**: ningún valor en claro fuera del `ClusterSecretStore` simulado; `creationPolicy: Owner` para que ESO sea el único dueño del `Secret`.
- **Reproducibilidad**: `kind delete cluster --name argo09-01 && reset` deja todo en 0.
- **Mantenibilidad**: `refreshInterval` razonable; nombres consistentes con el capstone.

## 8. Validación

```bash
bash tests/validate.sh
```

El script revisa: CRDs presentes, controller `external-secrets` Available, `ClusterSecretStore` Ready, `ExternalSecret` Ready, `Secret` nativo con 2 keys, y rotación funcional.

## 9. Preguntas de reflexión

1. ¿Dónde queda exactamente el valor en producción (con AWS SM)? ¿Y en etcd?
2. ¿Qué pasa si el `refreshInterval` es muy bajo (10 s)? ¿Y muy alto (24 h)?
3. ¿Qué debería compromiterse para fugar el valor? Compara contra Sealed Secrets.
4. Si cambias el provider a AWS SM, ¿qué partes del manifiesto cambian y cuáles no?
5. ¿Por qué `creationPolicy: Owner` y no `Merge`?

## 10. Extensiones

1. Añadir un segundo `ExternalSecret` para `prod/capstone/api` y consumirlo desde un `Deployment` como env var.
2. Montar el `Secret` como volumen y verificar hot-reload cuando ESO lo actualiza.
3. Rotar vía `kubectl patch` del `ClusterSecretStore` y medir tiempo de propagación con `-w`.
4. Instalar Argo CD, poner los manifiestos en un repo (puede ser `file://` local) y gestionar el `ExternalSecret` desde una `Application`.

## 11. Limpieza

```bash
kind delete cluster --name argo09-01
rm -rf /tmp/argo-09-01
```
