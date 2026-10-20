# Actividad 02 — Instalar Argo CD y registrar el chart como Application

## 1. Identificacion

- **ID:** `cap-09-02-register-argocd-app`
- **Tecnologia:** capstone
- **Modulo:** `09-helm-chart-argocd`
- **Dificultad:** intermediate
- **Duracion estimada:** 50 min
- **Tipo:** independent

## 2. Contexto

Instalas Argo CD en el cluster `kind` creado en la etapa 8, registras el chart
`fastapi-app` como una `Application` CR con policy automated + selfHeal, y
demuestras que GitOps esta cerrando el loop: si borras un pod a mano, Argo CD
lo trae de vuelta sin que corras ningun comando.

## 3. Objetivos

- Correr `./scripts/install-argocd.sh` y entender que hace.
- Aplicar `argocd/applications/fastapi-dev.yaml`.
- Verificar `Synced + Healthy` desde CLI y desde UI.
- Probar selfHeal borrando un pod y observando reconciliacion.
- Aplicar `argocd/app-of-apps.yaml` para que futuras Applications aparezcan solas.

## 4. Prerrequisitos

- Cluster `kind` levantado (`kind get clusters` muestra `capstone`).
- `kubectl` apuntando al cluster correcto.
- `helm` v3.14+ (lo usamos para `helm test`).
- Internet para descargar manifests de Argo CD (`v2.12.3`).
- Si falta `kubectl` o el cluster no esta, el validador reporta `SKIP`.

## 5. Instrucciones

### Paso 1 — Instalar Argo CD

```bash
cd projects/capstone/stages/09-helm-chart-argocd
./scripts/install-argocd.sh
```

El script es idempotente. Al final imprime el comando para obtener la
password inicial y para hacer `port-forward`.

### Paso 2 — Apuntar la Application al chart local

En un escenario real `spec.source.repoURL` apunta a tu repo publico (git o
OCI). Para la demo local, puedes:

- Opcion A (git): empujar este repo a un remote accesible y actualizar
  `repoURL` en `argocd/applications/fastapi-dev.yaml`.
- Opcion B (local kind): instalar directamente con Helm y usar Argo CD solo
  para una Application vacia que apunte a `charts/fastapi-app/` montado en
  el nodo kind. (Avanzado; en etapa 10 lo cerramos con un registry OCI).

Para la actividad, lo mas simple es Opcion A con tu fork.

### Paso 3 — Aplicar la Application

```bash
kubectl apply -f argocd/applications/fastapi-dev.yaml
kubectl -n argocd get applications fastapi-dev -w
```

Espera a que reporte `SYNC STATUS: Synced` y `HEALTH STATUS: Healthy`.

### Paso 4 — Probar selfHeal

```bash
POD=$(kubectl -n fastapi-dev get pod -l app.kubernetes.io/instance=fastapi -o name | head -1)
kubectl -n fastapi-dev delete "$POD"
# En < 30s Argo CD + ReplicaSet recrean el pod
kubectl -n fastapi-dev get pods -w
```

### Paso 5 — Smoke test del chart

```bash
helm test fastapi -n fastapi-dev
```

Debe salir en 0 (el hook `test-connection` hace wget al `/healthz`).

### Paso 6 — App-of-apps

```bash
kubectl apply -f argocd/app-of-apps.yaml
kubectl -n argocd get applications
```

Deberias ver `capstone-root` ademas de `fastapi-dev`.

### Paso 7 — Validador

```bash
bash activities/02-register-argocd-app/tests/validate.sh
```

## 6. Entregables

- Captura de `kubectl -n argocd get applications` con `Synced + Healthy`.
- Log de `kubectl -n fastapi-dev get pods -w` mostrando el pod recreado.
- Log de `helm test fastapi -n fastapi-dev` exitoso.
- Validador en verde (o `SKIP` justificado).

## 7. Pistas

1. Si la Application queda `OutOfSync` con error de `ComparisonError`,
   casi siempre es `repoURL` o `path` apuntando a algo que no existe.
2. Si `helm test` nunca termina, revisa que el pod wget tenga acceso al
   Service (NetworkPolicies, nombre de servicio, puerto).
3. Si `install-argocd.sh` imprime `SKIP`, revisa `kubectl cluster-info`.
