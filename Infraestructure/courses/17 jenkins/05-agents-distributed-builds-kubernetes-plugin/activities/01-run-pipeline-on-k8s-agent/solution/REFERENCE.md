# REFERENCE — jk-05-01-run-pipeline-on-k8s-agent

> Una **referencia** razonada. No es la única respuesta correcta.

## Archivos

- `podTemplate.yaml`: Pod con `jnlp` + `build` (Maven) + `kaniko`. `restartPolicy: Never`, `runAsNonRoot: true`, requests/limits en todos los contenedores.
- `Jenkinsfile`: declarative; `agent { kubernetes { yamlFile 'podTemplate.yaml' } }`; una stage por contenedor; `defaultContainer 'jnlp'` para evitar comandos accidentales en el agent.

## Justificaciones clave

1. **`restartPolicy: Never`**. Un fallo del Pod no se reintenta a nivel K8s; Jenkins gestiona el retry a nivel pipeline. Si fuera `OnFailure`, el controller vería un Pod "vivo" aun habiendo fallado y el build quedaría colgado.
2. **`sleep infinity`**. El plugin mantiene el Pod corriendo y ejecuta comandos con `exec` en cada contenedor. Si el contenedor termina, el `container('name') { sh '...' }` falla con "Container ... not running".
3. **`runAsNonRoot: true`**. Baseline de seguridad: ningún contenedor del Pod corre como root. Compatible con PSS `restricted`.
4. **Requests y limits presentes en todos**. Sin requests, el scheduler adivina; sin limits, un `mvn` puede comerse el nodo.
5. **`defaultContainer 'jnlp'`**. Fija el default a `jnlp`; cualquier `sh` fuera de `container(...)` se dirige al agent y no contamina los contenedores de build.
6. **`timeout`** en `options`. Evita que un Pod *Pending* indefinidamente consuma un executor.

## Lab vivo opcional (kind)

```bash
# 1. Crear cluster
kind create cluster --name jk05

# 2. Namespaces
kubectl create namespace jenkins
kubectl create namespace jenkins-agents

# 3. Service account del agent (minimo privilegio)
kubectl -n jenkins-agents create sa jenkins-agent

# 4. Instalar Jenkins (helm chart) con el kubernetes plugin preconfigurado
#    y apuntando a 'jenkins-agents' como podNamespace.
# 5. Crear un pipeline en Jenkins que apunte al Jenkinsfile anterior
#    (SCM o pasted script); al correrlo, kubectl -n jenkins-agents get pods
#    debe mostrar el Pod efimero vivo y luego eliminado.
```

El validador detecta la ausencia de `kind` y salta esta parte con `SKIP`.

## Preguntas de reflexión — respuestas rápidas

1. Sin `sleep infinity`, el contenedor sale al segundo y el `container()` falla.
2. `OnFailure` reintentaría; romperia el modelo de Jenkins que ya reintenta a su nivel.
3. Si `jnlp` queda desfasado respecto al controller, la conexión JNLP se rompe. Fija por canal (p.ej. mantener misma minor que el LTS).
4. Un label descriptivo: `maven-kaniko-build`, nunca `agent-15`.
5. El `serviceAccountName` del Pod debe tener permisos mínimos (p.ej. solo `pods/exec` o solo acceso al namespace de destino). Nunca `cluster-admin`.
