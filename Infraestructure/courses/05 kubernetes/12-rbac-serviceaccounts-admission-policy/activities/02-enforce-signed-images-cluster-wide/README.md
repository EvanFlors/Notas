# Actividad 02 — Enforce de firmas de imagen cluster-wide (independent)

## 1. Identificación

- **ID:** `k8s-12-02-enforce-signed-images-cluster-wide`
- **Tecnología:** `kubernetes`
- **Módulo:** `k8s-12-rbac-serviceaccounts-admission-policy`
- **Dificultad:** advanced
- **Duración estimada:** 90–120 min
- **Tipo:** **independent** (se te da el objetivo, no la solución)

## 2. Contexto

El equipo de seguridad decidió que ninguna imagen puede ejecutarse en producción sin pasar por el pipeline oficial (que firma con cosign/sigstore keyless). Hoy el cluster acepta cualquier imagen de Docker Hub. Tu misión es **instalar Kyverno** en el cluster `kind` y escribir una `ClusterPolicy` que **rechace** cualquier Pod cuya imagen no esté firmada por el flujo autorizado.

Para que el ejercicio sea reproducible 100% local y sin dependencias externas de red para la verificación (no todos los clusters tienen acceso a `rekor.sigstore.dev` siempre disponible), diseñaremos la policy de forma que, al no poder validar la firma, **el Pod se rechace**. Es decir: la validación de firma falla → admission deniega → ese es el comportamiento que probamos.

> **Nota:** en producción, usarías `cosign sign --keyless` desde tu pipeline y la
> policy aceptaría imágenes firmadas por un workflow concreto. Aquí probamos la
> contrapartida (la denegación), que es el control real que te interesa auditar.

## 3. Objetivos

- Instalar Kyverno en el cluster `kind` creado por el starter.
- Crear una `ClusterPolicy` con una regla `verifyImages` que matchee un patrón de imagen muy amplio (p. ej. `docker.io/library/*` o `ghcr.io/*`).
- Verificar que un Pod con una imagen que matchea el patrón es rechazado al crear.
- Verificar que la policy aparece con `validationFailureAction: Enforce`.
- Pasar el validator automático.

## 4. Prerrequisitos

- `kubectl` ≥ 1.28
- `kind` ≥ 0.22
- `bash`, `python3`
- Acceso a internet para descargar la instalación de Kyverno (se usa el manifest oficial `install.yaml` de una release; el starter lo intenta y falla con mensaje claro si no hay red).

**Costos:** USD 0, 100% local.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/k8s-12-02
cd /tmp/k8s-12-02
```

Esto:

1. Crea el cluster `kind-k8s-12-02`.
2. Deja la carpeta `policies/` donde debes escribir tu `ClusterPolicy`.
3. **No instala Kyverno**: lo instalas tú (parte del ejercicio).

### 5.2 Fase 1 — Instalar Kyverno

Instala Kyverno con el manifest oficial de una release estable:

```bash
kubectl --context kind-k8s-12-02 create -f \
  https://github.com/kyverno/kyverno/releases/download/v1.12.5/install.yaml
```

Espera a que los pods estén `Ready`:

```bash
kubectl --context kind-k8s-12-02 -n kyverno wait --for=condition=Ready pod --all --timeout=180s
```

Verifica los CRDs:

```bash
kubectl --context kind-k8s-12-02 api-resources | grep kyverno
```

Debes ver al menos `clusterpolicies` y `policies`.

### 5.3 Fase 2 — Escribir la ClusterPolicy

En `/tmp/k8s-12-02/policies/require-signed-images.yaml` escribe una `ClusterPolicy` que:

- Se llame `require-signed-images`.
- Tenga `spec.validationFailureAction: Enforce`.
- Tenga una regla con `verifyImages`.
- `imageReferences` debe matchear al menos `docker.io/library/*` (así cualquier `nginx`, `busybox`, etc. activa la verificación).
- Use `attestors.entries[0].keyless` con un `subject` y un `issuer` que **no** vayan a matchear la imagen de prueba (así la verificación falla y la imagen es rechazada — exactamente lo que queremos demostrar).

Aplica:

```bash
kubectl --context kind-k8s-12-02 apply -f /tmp/k8s-12-02/policies/require-signed-images.yaml
```

Verifica que esté `Ready`:

```bash
kubectl --context kind-k8s-12-02 get clusterpolicy require-signed-images
```

### 5.4 Fase 3 — Probar el rechazo

Intenta crear un Pod con una imagen pública:

```bash
kubectl --context kind-k8s-12-02 run test-unsigned \
  --image=docker.io/library/nginx:1.27-alpine
```

Debería ser **rechazado** por el webhook de Kyverno (mensaje con `require-signed-images`). Si fuera aceptado, tu policy está en `Audit` o el `match` no cubre esa imagen.

### 5.5 Validar

```bash
bash tests/validate.sh /tmp/k8s-12-02
```

Debe reportar `RESULT: ALL CHECKS PASS`.

## 6. Resultado esperado

- Kyverno corriendo en `kyverno` namespace con pods `Ready`.
- `ClusterPolicy require-signed-images` presente, en `Enforce`, con una regla `verifyImages`.
- Creación de Pods con imagen `docker.io/library/*` es rechazada por admission.

## 7. Criterios de aceptación

- [ ] Namespace `kyverno` existe y tiene al menos 1 Pod `Running`.
- [ ] Existe la CRD `clusterpolicies.kyverno.io`.
- [ ] Existe un `ClusterPolicy` llamado `require-signed-images`.
- [ ] `spec.validationFailureAction == Enforce`.
- [ ] Al menos una regla tiene bloque `verifyImages`.
- [ ] `kubectl run` con una imagen que matchea el patrón es rechazado (código de salida ≠ 0 y mensaje contiene `require-signed-images` o `blocked`).

## 8. Validación

```bash
bash tests/validate.sh /tmp/k8s-12-02
```

El validator:

1. Comprueba contexto `kind-k8s-12-02`.
2. Verifica namespace `kyverno` y pods `Ready`.
3. Verifica CRD `clusterpolicies.kyverno.io`.
4. Lee la `ClusterPolicy require-signed-images` y valida acción y `verifyImages`.
5. Intenta `kubectl run` con una imagen pública y espera **rechazo** (no éxito).

El validator **SKIP graciosamente** la fase (5) si por algún motivo Kyverno no tiene el webhook listo todavía, con mensaje claro.

## 9. Preguntas de reflexión

1. ¿Qué diferencia operativa hay entre `validationFailureAction: Enforce` y `Audit`? ¿Cuándo migrarías de uno al otro en una organización real?
2. Si tu policy, por un bug, rechazara `kube-system/*` (p. ej. CoreDNS), ¿qué pasaría con el cluster? ¿Cómo lo previenes?
3. ¿Por qué `verifyImages` en Kyverno ocurre durante **mutating** admission y no solo validating?
4. ¿Cuál es el riesgo de `webhookTimeoutSeconds` alto en una policy `verifyImages`?
5. Compara `verifyImages` de Kyverno con hacerlo en el pipeline (p. ej. `cosign verify` antes de `kubectl apply`). ¿Qué garantiza admission que el pipeline no?

## 10. Extensiones

- **E1** — Añade una segunda regla en la misma policy que exija `runAsNonRoot: true` usando `pattern`.
- **E2** — Añade un `Policy` (namespace-scoped) que relaje la regla para un namespace `sandbox`.
- **E3** — Instala también una `ValidatingAdmissionPolicy` que haga el mismo check de `runAsNonRoot` y mide la diferencia de latencia (webhook vs in-API).
- **E4** — Firma una imagen propia con cosign keyless desde GitHub Actions y modifica la policy para aceptarla.

## 11. Limpieza

```bash
kind delete cluster --name k8s-12-02
rm -rf /tmp/k8s-12-02
```
