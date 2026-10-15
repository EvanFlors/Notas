# k8s-02-02 — Kubeconfig con dos contextos

## 1. Identificación

- **ID:** `k8s-02-02-kubeconfig-two-contexts`
- **Tecnología:** kubernetes
- **Módulo:** `02-setup-local-and-kubectl`
- **Dificultad:** beginner
- **Duración estimada:** 50 min
- **Tipo:** independent

## 2. Contexto

En la vida real **nunca** operas un solo cluster. Tienes `dev`, `staging`, `prod`, más clusters managed de dos clouds, más un kind local para experimentar. Equivocarte de cluster al correr `kubectl delete deployment` es una de las formas canónicas de romper producción.

En esta actividad vas a crear **dos** clusters kind, fusionar sus kubeconfigs en uno solo, y practicar alternar entre contextos con disciplina. No te daré los comandos exactos — solo los requisitos y el validador.

## 3. Objetivos

Al terminar deberías poder:

- Crear dos clusters kind con nombres distintos sin confundirlos.
- Fusionar múltiples kubeconfigs en un único archivo.
- Alternar entre contextos con `kubectl config use-context` y verificar en qué estás antes de ejecutar comandos destructivos.
- Diferenciar un contexto (tripleta) de un cluster (endpoint).

## 4. Prerrequisitos

- Docker corriendo.
- `kind` y `kubectl` instalados.
- 2 GB de RAM libres (dos clusters kind concurrentes).
- Sin costo.

Si falta algo, el validador imprime `SKIP` con instrucciones.

## 5. Instrucciones (independientes)

**No voy a darte los comandos.** Investiga en `kubectl config --help`, `kind create cluster --help`, y la documentación oficial.

### Requisitos del estado final

El validador comprueba:

1. **Dos clusters kind existen** con nombres:
   - `lab-dev`
   - `lab-stg`

2. **Dos contextos existen** en el kubeconfig actual (`$KUBECONFIG` o `~/.kube/config`):
   - `kind-lab-dev`
   - `kind-lab-stg`

3. **El contexto `kind-lab-dev` tiene namespace `apps-dev`** por default.
   - Debes crear el namespace `apps-dev` en el cluster `lab-dev`.
   - Y asignarlo como namespace por default del contexto.

4. **El contexto `kind-lab-stg` tiene namespace `apps-stg`** por default.
   - Igual pero en el otro cluster.

5. **Cada cluster tiene un ConfigMap distinto** que te permite saber en cuál estás:
   - En `lab-dev`, namespace `apps-dev`: ConfigMap `env-marker` con `data.env=dev`.
   - En `lab-stg`, namespace `apps-stg`: ConfigMap `env-marker` con `data.env=stg`.

6. **Un script tuyo en `/tmp/k8s-02-02/switch.sh`** que, dado un argumento (`dev` o `stg`):
   - Cambie a `kind-lab-$1` como current-context.
   - Imprima en qué context y namespace quedaste.
   - Imprima el valor de `data.env` del ConfigMap `env-marker`.
   - Debe ser `chmod +x` y usable como `./switch.sh dev`.

### Pistas (no soluciones)

- `kind create cluster --name <name>` crea el cluster y añade su contexto al kubeconfig actual.
- `KUBECONFIG=a:b kubectl config view --merge --flatten > merged.yaml` fusiona.
- `kubectl config set-context --current --namespace=X` cambia el default del contexto activo.
- `kubectl config use-context <name>` cambia de contexto.
- `kubectl config get-contexts` para auditar.
- Trabaja en `/tmp/k8s-02-02/`.

### Trampas que vas a encontrar

- Si creas los dos clusters en sesiones distintas de shell con `KUBECONFIG` apuntando a archivos diferentes, los dos contextos quedan en archivos distintos y "no se ven".
- `kubectl config set-context --current --namespace=X` solo cambia el **contexto actual**. Si quieres cambiar otro, hazlo explícito: `kubectl config set-context kind-lab-stg --namespace=apps-stg`.
- Si borras un namespace y recreas el ConfigMap antes de que termine la terminación, el `apply` queda en limbo.

## 6. Resultado esperado

- `kind get clusters` lista `lab-dev` y `lab-stg`.
- `kubectl config get-contexts` lista `kind-lab-dev` y `kind-lab-stg`.
- `kubectl --context kind-lab-dev -n apps-dev get cm env-marker -o jsonpath='{.data.env}'` imprime `dev`.
- `kubectl --context kind-lab-stg -n apps-stg get cm env-marker -o jsonpath='{.data.env}'` imprime `stg`.
- `/tmp/k8s-02-02/switch.sh dev` imprime algo como:

  ```
  context : kind-lab-dev
  ns      : apps-dev
  env     : dev
  ```

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- Puedes alternar entre contextos sin confundirte (regla operativa personal: antes de cualquier `delete` corres `kubectl config current-context`).
- `switch.sh` es idempotente y no asume que ya estás en un contexto concreto.

## 8. Validación

```bash
bash courses/kubernetes/02-setup-local-and-kubectl/activities/02-kubeconfig-two-contexts/tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Qué pasa si dos kubeconfigs tienen un contexto con el mismo nombre al fusionarlos? ¿Quién gana?
2. ¿Por qué un contexto es útil incluso si tienes un solo cluster? Pista: diferentes namespaces, diferentes usuarios.
3. Si un atacante consigue tu kubeconfig con `client-key-data` del cluster de staging, ¿qué puede hacer? ¿Y si fuera un token OIDC caducado?
4. ¿Cómo prevendrías operacionalmente ejecutar un comando destructivo en el cluster equivocado? Lista al menos tres técnicas (prompt del shell, naming convention, kube-ps1, kubectl-neat, etc.).

## 10. Extensiones

- Añade un tercer cluster `lab-prd` **sin** darle namespace por default. Observa qué namespace usa `kubectl` cuando no está definido.
- Fusiona el kubeconfig del lab con uno "real" (por ejemplo, el de un EKS temporal) usando `KUBECONFIG=a:b kubectl config view --merge --flatten > merged`.
- Instala `kubectx`/`kube-ps1` y configura tu prompt de shell para que SIEMPRE muestre el contexto y namespace actuales. Esto previene el 95 % de los "oops me equivoqué de cluster".

## 11. Limpieza

```bash
kind delete cluster --name lab-dev
kind delete cluster --name lab-stg
rm -rf /tmp/k8s-02-02
# Opcional: limpiar contextos huérfanos en ~/.kube/config si quedaron.
kubectl config delete-context kind-lab-dev 2>/dev/null || true
kubectl config delete-context kind-lab-stg 2>/dev/null || true
kubectl config delete-cluster kind-lab-dev 2>/dev/null || true
kubectl config delete-cluster kind-lab-stg 2>/dev/null || true
kubectl config delete-user    kind-lab-dev 2>/dev/null || true
kubectl config delete-user    kind-lab-stg 2>/dev/null || true
```
