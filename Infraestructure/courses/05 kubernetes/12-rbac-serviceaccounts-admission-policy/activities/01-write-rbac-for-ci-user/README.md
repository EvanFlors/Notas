# Actividad 01 — RBAC mínimo para un usuario de CI (guided-lab)

## 1. Identificación

- **ID:** `k8s-12-01-write-rbac-for-ci-user`
- **Tecnología:** `kubernetes`
- **Módulo:** `k8s-12-rbac-serviceaccounts-admission-policy`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** **guided-lab** (se te indica el objetivo exacto, no la solución)

## 2. Contexto

Una pipeline de CI/CD debe desplegar la aplicación `payments` en el namespace `apps`. Hoy el equipo usa el `ServiceAccount` `default` del namespace con un `ClusterRoleBinding` a `cluster-admin` (porque "funcionaba"). Tu misión: eliminar ese antipatrón creando un `ServiceAccount` dedicado con **solo** los permisos que la pipeline necesita, y demostrarlo con `kubectl auth can-i`.

Permisos requeridos para la pipeline:

- Listar y leer Pods, ReplicaSets y Deployments en `apps`.
- Crear, actualizar y hacer patch de Deployments y Services en `apps`.
- Leer logs de Pods en `apps` (`pods/log`).

Permisos que **no** debe tener:

- Leer Secrets (ni en `apps` ni en ningún namespace).
- Modificar Nodes.
- Nada en otros namespaces (`default`, `kube-system`).
- Crear o modificar RBAC (`roles`, `rolebindings`, `clusterroles`, `clusterrolebindings`).

## 3. Objetivos

- Crear un `Namespace` `apps`, un `ServiceAccount` `ci-deployer` y los objetos RBAC mínimos para los permisos listados.
- Pasar el validator automático que verifica permisos positivos **y** negativos.
- Documentar en el ADR corto `apps-rbac.md` las decisiones (ver §5.4).

## 4. Prerrequisitos

- `kubectl` ≥ 1.28
- `kind` ≥ 0.22
- `bash`, `python3`

**Costos:** USD 0, 100% local.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/k8s-12-01
cd /tmp/k8s-12-01
```

Esto crea un cluster `kind` llamado `k8s-12-01` y la carpeta `/tmp/k8s-12-01/manifests/` donde debes dejar tus YAMLs. Si ya existe, el bootstrap es idempotente.

### 5.2 Fase 1 — Diseño

Lee la lista de permisos requeridos y prohibidos en §2 y escribe en `manifests/apps-rbac.yaml` (debes crearlo tú):

- `Namespace` `apps`.
- `ServiceAccount` `ci-deployer` en `apps` con `automountServiceAccountToken: false`.
- `Role` en `apps` con las reglas mínimas.
- `RoleBinding` que asocia el `Role` al `ServiceAccount`.

Pistas:

- Deployments y ReplicaSets están en el apiGroup `apps`. Services en el core (`""`).
- `pods/log` es un subresource; verbos típicos: `get`, `list`.
- No crees `ClusterRole` ni `ClusterRoleBinding` para esta actividad.

### 5.3 Fase 2 — Aplicar

```bash
kubectl --context kind-k8s-12-01 apply -f manifests/apps-rbac.yaml
```

### 5.4 Fase 3 — ADR corto

Crea `manifests/apps-rbac.md` con el formato:

```markdown
# ADR — RBAC para ci-deployer

## Status
Accepted — <fecha>

## Context
<Antipatrón previo: default SA con cluster-admin. Riesgo materializado.>

## Decision
<Reglas elegidas y por qué.>

## Consequences
<Positivas y negativas.>
```

### 5.5 Validar

```bash
bash tests/validate.sh /tmp/k8s-12-01
```

Debe reportar `RESULT: ALL CHECKS PASS`.

## 6. Resultado esperado

- Cluster `kind-k8s-12-01` con namespace `apps`, SA `ci-deployer` y RBAC aplicado.
- `kubectl auth can-i` devuelve `yes` para los verbos permitidos y `no` para los prohibidos.
- `apps-rbac.md` con las 4 secciones.

## 7. Criterios de aceptación

- [ ] `ServiceAccount` `ci-deployer` existe en `apps` con `automountServiceAccountToken: false`.
- [ ] `Role` en `apps` sin `*` en verbs ni resources.
- [ ] `RoleBinding` liga el `Role` al `ServiceAccount`.
- [ ] No existe ningún `ClusterRoleBinding` que ligue `ci-deployer` a `cluster-admin`.
- [ ] `kubectl auth can-i get secrets -n apps --as=system:serviceaccount:apps:ci-deployer` devuelve `no`.
- [ ] ADR con `## Status`, `## Context`, `## Decision`, `## Consequences`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/k8s-12-01
```

## 9. Preguntas de reflexión

1. ¿Qué pasa si la pipeline, en un sprint futuro, necesita leer un `Secret` concreto (p. ej. una API key)? ¿Cómo lo añadirías sin ampliar el `Role` entero?
2. Si otra app en `apps` necesita permisos distintos, ¿por qué conviene **otro SA** en vez de ampliar `ci-deployer`?
3. ¿Qué diferencia práctica hay entre un `Role` + `RoleBinding` y un `ClusterRole` + `RoleBinding` (reutilizando `ClusterRole` en un namespace)?

## 10. Extensiones

- **E1** — Añade `resourceNames: ["payments"]` para restringir el `Role` a un solo Deployment.
- **E2** — Añade `audit` label al namespace con `pod-security.kubernetes.io/audit=restricted` y comenta el impacto en los Pods existentes.

## 11. Limpieza

```bash
kind delete cluster --name k8s-12-01
rm -rf /tmp/k8s-12-01
```
