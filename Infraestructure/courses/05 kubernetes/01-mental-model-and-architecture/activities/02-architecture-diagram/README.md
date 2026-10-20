# Actividad 02 — Mapa anotado: control plane, data plane y reconciliation loop

## 1. Identificación

- **ID:** `k8s-01-02-architecture-diagram`
- **Tecnología:** `kubernetes`
- **Módulo:** `k8s-01-mental-model-and-architecture`
- **Dificultad:** beginner
- **Duración estimada:** 45–60 min
- **Tipo:** independent

## 2. Contexto

Esta es la actividad **conceptual** central del módulo. No requiere cluster, ni `kubectl`, ni cloud: se puede completar en cualquier editor de texto.

Produces un **mapa anotado** del cluster: control plane, data plane, el camino de un `kubectl apply` y la cadena de controllers que gestiona un Deployment. Si no puedes dibujarlo con tus palabras, no entiendes la arquitectura todavía.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Dibujar los **5 componentes** del control plane (`kube-apiserver`, `etcd`, `kube-scheduler`, `kube-controller-manager`, `cloud-controller-manager`) y qué hace cada uno.
- Dibujar los componentes del **nodo** (`kubelet`, `kube-proxy`, container runtime, CNI, CSI).
- Explicar por qué el `kube-apiserver` es la **única** puerta a `etcd`.
- Dibujar y explicar la cadena **Deployment → ReplicaSet → Pods** como reconciliation loop.
- Trazar el camino de un `kubectl apply -f deployment.yaml` desde tu laptop hasta que un `kubelet` arranca el primer contenedor.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` completo (al menos §4 y §5).
- Haber recorrido `examples/01-draw-control-plane/`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/k8s-01-arch
cd /tmp/k8s-01-arch
```

(Puedes usar otro directorio si pasas la ruta a `validate.sh`; el default es `/tmp/k8s-01-arch`.)

### 5.2 Entregable: `MAP.md`

Produce un archivo `MAP.md` con **cuatro secciones** explícitas:

#### A. Control plane

Dibuja (ASCII) el control plane. Para **cada uno** de los 5 componentes, una frase con su responsabilidad:

- `kube-apiserver`
- `etcd`
- `kube-scheduler`
- `kube-controller-manager`
- `cloud-controller-manager`

Al final de la sección, **explica en 2–3 frases** por qué el API server es la **única** puerta a `etcd` (razones de consistencia, autorización, admission y auditoría).

#### B. Data plane (nodo)

Dibuja (ASCII) un nodo. Para **cada uno** de estos componentes, una frase con su responsabilidad:

- `kubelet`
- `kube-proxy`
- container runtime (containerd / CRI-O)
- CNI plugin
- CSI driver

Indica explícitamente **con quién habla el kubelet** (el API server) y **con quién NO habla** (`etcd`).

#### C. Reconciliation loop: Deployment → ReplicaSet → Pods

Dibuja (ASCII) la cadena **Deployment → ReplicaSet → Pods** con flechas de "gestionado por" indicando qué controller interviene en cada eslabón. Para cada eslabón, nombra:

- Qué controller lo gestiona.
- Qué objeto gestiona ese controller.
- Qué pasa si borras un Pod directamente.

Al final de la sección, en 3–5 frases, define **reconciliation loop** con tus palabras.

#### D. `kubectl apply` end-to-end

Dibuja (ASCII, numerado por pasos) qué pasa cuando ejecutas `kubectl apply -f deployment.yaml` desde tu laptop hasta que un `kubelet` arranca el primer contenedor. Debe incluir, en orden:

1. `kubectl` construye y envía la request al **API server**.
2. API server: **authn → authz → admission (mutating → validating) → validación de esquema → persistencia en `etcd`**.
3. **Deployment controller** reacciona (WATCH) y crea un **ReplicaSet**.
4. **ReplicaSet controller** reacciona y crea los **Pods**.
5. **Scheduler** asigna `spec.nodeName` a cada Pod.
6. **kubelet** del nodo elegido llama al **runtime (CRI)**; **CNI** configura red; **CSI** monta volúmenes si hay; el contenedor arranca.
7. **kubelet** escribe `status.*` vía el API server.
8. **Endpoints/EndpointSlice controller** actualiza el Service si corresponde; **kube-proxy** reprograma reglas.

### 5.3 Preguntas obligatorias (al final de `MAP.md`)

Numera las respuestas **del 1 al 7**:

1. ¿Por qué `kube-apiserver` es la única puerta a `etcd`? Da **tres** razones distintas de las obvias ("por consistencia").
2. Si el `kube-scheduler` se cae, ¿qué pasa con los Pods **ya corriendo**? ¿Y con los **nuevos** que se declaren? Justifica.
3. ¿Cuál es la diferencia funcional entre el **`kube-controller-manager`** y el **`cloud-controller-manager`**? ¿Por qué se separaron?
4. En un Deployment con `replicas: 3`, borras **manualmente** un Pod con `kubectl delete pod web-xxxxx`. Describe **paso a paso** qué controller reacciona, qué objeto escribe, y por qué al final tienes 3 Pods otra vez.
5. ¿Por qué un Pod **no es** "un contenedor con metadata"? Nombra al menos **tres cosas** que comparten los contenedores de un mismo Pod y una que **no** comparten por default.
6. Un `kubectl apply` falla con `403 Forbidden`. ¿En qué fase del pipeline del API server se produjo el fallo? ¿Qué significa en términos de autenticación vs autorización?
7. Si pierdes **todos los nodos** del cluster pero conservas `etcd` y el control plane, ¿sigue existiendo el cluster? ¿Qué podrías hacer para "recuperarlo"? Argumenta con el modelo mental "cluster = API con controllers".

### 5.4 Validar estructura

```bash
bash tests/validate.sh /tmp/k8s-01-arch
```

Chequea que `MAP.md` exista y contenga las cuatro secciones mínimas (A, B, C, D), los componentes del control plane y del nodo nombrados, los conceptos clave (`spec`/`status`, `reconciliation`, `WATCH`), la cadena Deployment → ReplicaSet → Pods, y las 7 respuestas numeradas. **No valida contenido semántico** — eso lo verificas contra `solution/MAP-reference.md`.

## 6. Resultado esperado

- Archivo `MAP.md` en `/tmp/k8s-01-arch/` con secciones A, B, C, D y 7 respuestas numeradas.
- `tests/validate.sh` pasa.
- Autocomparas con `solution/MAP-reference.md` para calibrar.

## 7. Criterios de aceptación

- [ ] Los 5 componentes del control plane aparecen nombrados.
- [ ] Al menos 4 componentes del nodo aparecen nombrados (kubelet, kube-proxy, runtime, CNI o CSI).
- [ ] Se identifica a `kube-apiserver` como única puerta a `etcd`.
- [ ] La cadena `Deployment → ReplicaSet → Pods` aparece con sus controllers.
- [ ] `spec`, `status`, `reconciliation` y `WATCH` aparecen con una definición propia.
- [ ] Las 7 preguntas respondidas (como `1.`, `2.`, ... al inicio de línea).

## 8. Validación

```bash
bash tests/validate.sh /tmp/k8s-01-arch
```

Estructural. **Semántica** la calibras tú con `solution/MAP-reference.md`.

## 9. Preguntas de reflexión

Más allá de las obligatorias:

1. Si quisieras **sustituir `etcd`** por otra base de datos (p. ej. `kine` sobre PostgreSQL, como hace k3s), ¿qué parte del sistema **no cambia** y por qué?
2. ¿Por qué el `kubelet` tiene permisos muy acotados (puede escribir `status` de **sus** Pods, no de otros)? ¿Qué pasaría si todos los kubelets fueran "admin del API"?
3. Si un operador propio (CRD + controller) sigue el patrón `WATCH + reconcile`, ¿qué pide eso del API server y de `etcd` cuando hay **cientos** de operadores corriendo? ¿Dónde está el límite?

## 10. Extensiones (opcional)

- **E1** — Añade un diagrama de qué pasa cuando `kube-apiserver` se cae temporalmente: ¿los nodos siguen corriendo Pods? ¿los Services siguen enrutando? ¿los controllers siguen reconciliando?
- **E2** — Dibuja la variante **managed** (EKS/GKE/AKS): qué cambia conceptualmente respecto a tu diagrama (el control plane lo opera el proveedor, no lo ves como procesos). Añade qué **sí** sigues operando tú.
- **E3** — Investiga qué es el **"informer / lister"** en client-go y añade a tu `MAP.md` una nota sobre cómo los controllers evitan hammering al API server (hint: cache local poblado por `WATCH`).

## 11. Limpieza

```bash
rm -rf /tmp/k8s-01-arch
```
