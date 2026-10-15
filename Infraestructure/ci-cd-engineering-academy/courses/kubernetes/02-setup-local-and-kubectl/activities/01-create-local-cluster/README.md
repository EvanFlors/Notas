# k8s-02-01 — Crear un cluster local kind

## 1. Identificación

- **ID:** `k8s-02-01-create-local-cluster`
- **Tecnología:** kubernetes
- **Módulo:** `02-setup-local-and-kubectl`
- **Dificultad:** beginner
- **Duración estimada:** 40 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a crear un cluster kind desde cero, apuntar `kubectl` a él, cambiar el namespace por default del contexto, y aplicar tu primer manifiesto declarativo (un ConfigMap). El objetivo no es "ejecutar comandos" sino **ver qué hace cada paso en el kubeconfig y en el apiserver**.

El validador comprueba el estado final: cluster vivo, contexto apuntando a él, namespace cambiado, ConfigMap presente con los campos correctos.

## 3. Objetivos

Al terminar deberías poder:

- Crear un cluster kind con nombre explícito y verlo en `kubectl config get-contexts`.
- Cambiar el namespace por default del contexto actual sin alterar el kubeconfig a mano.
- Aplicar un YAML con `kubectl apply` y entender el ciclo create/update.
- Extraer campos con `jsonpath` y `custom-columns`.

## 4. Prerrequisitos

- Docker corriendo (`docker info` responde).
- `kind` ≥ 0.20 instalado (`kind version`).
- `kubectl` ≥ 1.28 instalado (`kubectl version --client`).
- Puertos efímeros libres (kind los elige solo).
- Sin costo monetario (todo local).

Si falta `kind` o `kubectl`, el validador imprime un `SKIP` con instrucciones de instalación (`brew install kind kubectl` en macOS; ver el `validate.sh`).

## 5. Instrucciones

Trabaja en `/tmp/k8s-02-01/`. Crea el directorio:

```bash
mkdir -p /tmp/k8s-02-01 && cd /tmp/k8s-02-01
```

### Paso 1 — crear el cluster

1. Crea un cluster con **estos requisitos exactos** (el validador los verifica):
   - nombre: `academy`
   - imagen de nodo: default de tu versión de kind (no la fijes salvo necesidad).
2. Verifica:

   ```bash
   kind get clusters                      # debe listar "academy"
   kubectl config current-context         # debe decir "kind-academy"
   kubectl get nodes                      # el nodo "academy-control-plane" en Ready
   ```

### Paso 2 — cambiar el namespace por default del contexto

El namespace por default del contexto `kind-academy` debe pasar de `default` a `k8s-02-lab`. Pasos:

1. Crea el namespace: `kubectl create namespace k8s-02-lab`.
2. Cambia el default del contexto actual: `kubectl config set-context --current --namespace=k8s-02-lab`.
3. Verifica: `kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}'` debe imprimir `k8s-02-lab`.

### Paso 3 — primer `apply` declarativo

Crea `/tmp/k8s-02-01/configmap.yaml` con **exactamente** este contenido:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: lab-config
  labels:
    module: k8s-02
    owner: academy
data:
  greeting: "hola k8s"
  module: "k8s-02"
```

Aplícalo:

```bash
kubectl apply -f configmap.yaml
```

Verifica:

```bash
kubectl get configmap lab-config
kubectl get configmap lab-config -o jsonpath='{.data.greeting}{"\n"}'
kubectl get configmap lab-config -o custom-columns=NAME:.metadata.name,KEYS:.data
```

### Paso 4 — guardar un snapshot

Guarda en `/tmp/k8s-02-01/snapshot.md` lo siguiente (puedes copiar el formato):

```markdown
# snapshot k8s-02-01

## current-context
<salida de: kubectl config current-context>

## namespace del contexto
<salida de: kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}'>

## nodo
<salida de: kubectl get node -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type>

## ConfigMap
<salida de: kubectl get cm lab-config -o jsonpath='{.data}'>
```

### Paso 5 — validar

```bash
bash <ruta-al-repo>/courses/kubernetes/02-setup-local-and-kubectl/activities/01-create-local-cluster/tests/validate.sh
```

**IMPORTANTE**: el validador verifica el **estado del lab** en ese momento. Si limpiaste antes de validar, fallará.

## 6. Resultado esperado

- `kind get clusters` lista `academy`.
- `kubectl config current-context` = `kind-academy`.
- El namespace del contexto actual es `k8s-02-lab`.
- `kubectl get cm lab-config -n k8s-02-lab` existe con `data.greeting == "hola k8s"`.
- `/tmp/k8s-02-01/snapshot.md` existe con las cuatro secciones.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- No creas recursos fuera de `k8s-02-lab` para el ConfigMap.
- El snapshot tiene las cuatro secciones (no basta con el título).

## 8. Validación

```bash
bash courses/kubernetes/02-setup-local-and-kubectl/activities/01-create-local-cluster/tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Qué pasa si corres `kind create cluster --name academy` dos veces seguidas? ¿Y si cambias el nombre?
2. `kubectl config set-context --current --namespace=X` — ¿qué archivo modifica? Mira el diff con `git diff` si tienes `~/.kube/config` versionado localmente (no deberías).
3. Si borras el ConfigMap con `kubectl delete -f configmap.yaml` y luego vuelves a hacer `apply`, ¿qué pasa? ¿Y si cambias un valor en `data` y aplicas?
4. Si corres `kubectl apply --server-side -f configmap.yaml`, ¿qué cambia en la salida? Mira `kubectl get cm lab-config -o yaml | grep -A5 managedFields`.

## 10. Extensiones

- Crea un cluster kind con 1 control-plane + 2 workers usando `--config` (ver docs oficiales de kind).
- Compara el output de `kubectl explain configmap` con `kubectl explain configmap.data` — explica por qué uno es un map y el otro no.
- Aplica el mismo ConfigMap con `kubectl apply --server-side` y mira el annotation `managedFields`. ¿Quién es el `fieldManager`?

## 11. Limpieza

```bash
kubectl delete namespace k8s-02-lab --ignore-not-found
kind delete cluster --name academy
rm -rf /tmp/k8s-02-01
```
