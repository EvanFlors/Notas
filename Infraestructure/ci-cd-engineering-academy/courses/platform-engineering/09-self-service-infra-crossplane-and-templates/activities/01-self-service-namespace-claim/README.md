# Actividad 01 — Self-service NamespaceProduct via Crossplane

## 1. Identificación

- **ID:** `plat-09-01-self-service-namespace-claim`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-09-self-service-infra-crossplane-and-templates`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a jugar el papel del **platform engineer** que publica un *producto de plataforma*: el `NamespaceProduct`. Un developer puede pedirlo con 3 inputs (`name`, `tier`, `env`) y recibir un namespace con quota y network policy, sin necesitar permisos de administrador en el cluster.

Para evitar costos y credenciales, usamos el **provider `kubernetes`** de Crossplane: los *managed resources* se materializan como recursos K8s nativos en el mismo cluster. El patrón se traslada 1:1 a un provider cloud en producción.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Explicar el ciclo `claim → XR → Composition → Managed Resources` observando sus statuses.
- Modificar el XRD/Composition propios y re-aplicar sin romper el claim existente.
- Debuggear "no se materializó" con la cadena `kubectl describe claim → XR → MR → provider logs`.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (al menos §3 a §7).
- Haber recorrido `examples/01-crossplane-install-in-kind/` y `examples/02-xrd-namespace-product/`.
- Herramientas locales: `docker`, `kind`, `kubectl`, `helm`. Si falta alguna, el validador saldrá en modo `SKIP`.

**Costos**: ninguno (todo corre en kind local).

## 5. Instrucciones

### 5.1 Trabajar sobre el starter

El `starter/` contiene **esqueletos con `REPLACE_ME`** que debes completar:

- `starter/xrd.yaml` — faltan los `enum` del `tier` y el `pattern` del `name`.
- `starter/composition.yaml` — falta el patch que mapea `tier` → `requests.cpu` y `requests.memory`.
- `starter/claim.yaml` — faltan los valores del developer (name/tier/env).

Compara con `../../examples/02-xrd-namespace-product/` para orientarte. **No copies ciegamente**: ajusta nombres (el claim debe llamarse `student-claim` para que el validador lo encuentre; el nombre del namespace resultante debe ser `student-ns`).

### 5.2 Setup del cluster y Crossplane

```bash
cd activities/01-self-service-namespace-claim
bash tests/setup.sh
```

El script:

1. Crea cluster kind `plat-09-01` si no existe.
2. Instala Crossplane via helm.
3. Instala `provider-kubernetes` + `ProviderConfig` default.
4. Aplica tu `starter/xrd.yaml` y `starter/composition.yaml`.
5. Crea el namespace `team-student` y aplica `starter/claim.yaml`.

Si tu starter tiene `REPLACE_ME` sin completar, `setup.sh` **falla** con un mensaje claro.

### 5.3 Observar la materialización

```bash
kubectl -n team-student get namespaceproductclaim student-claim -o yaml
kubectl get xnamespaceproduct
kubectl get object
kubectl get ns student-ns --show-labels
kubectl -n student-ns get resourcequota,networkpolicy
```

### 5.4 Validar

```bash
bash tests/validate.sh
```

### 5.5 Limpiar

```bash
bash tests/cleanup.sh
```

Borra el cluster kind y el scratch `/tmp/plat-09-01-*`.

## 6. Resultado esperado

- El claim `student-claim` en el namespace `team-student` está `Ready=True`.
- El composite `XNamespaceProduct` correspondiente existe.
- El namespace `student-ns` existe con labels `managed-by=crossplane` y `env`.
- `ResourceQuota student-ns-quota` existe en `student-ns` con los valores derivados de `tier`.
- `NetworkPolicy student-ns-deny-all` existe en `student-ns` y es default-deny.
- `bash tests/validate.sh` sale en verde (5/5 checks).

## 7. Criterios de aceptación

- **Funcionalidad**: 5/5 checks del validador.
- **Calidad**: XRD con `enum` y `pattern` activos (no se puede crear un claim con `tier=xxl`).
- **Reproducibilidad**: borrar el cluster y repetir `setup.sh` + `validate.sh` da el mismo resultado.

## 8. Validación

```bash
bash tests/validate.sh
```

El validador hace **5 checks**:

1. XRD `xnamespaceproducts.platform.io` existe y está `Established=True`.
2. Composition `xnamespaceproducts.k8s-native` existe.
3. Claim `student-claim` en `team-student` está `Ready=True`.
4. Namespace `student-ns` existe con label `managed-by=crossplane`.
5. `ResourceQuota student-ns-quota` + `NetworkPolicy student-ns-deny-all` existen.

**Modo SKIP**: si falta `docker` / `kind` / `kubectl` / el apiserver no responde, el validador sale con `SKIP` y exit 0. No requiere red más allá del `helm repo add`.

## 9. Preguntas de reflexión

1. ¿Por qué el claim vive en `team-student` y no en `crossplane-system`? ¿Qué pasaría si estuviera en `crossplane-system`?
2. ¿Qué garantiza que un developer con permisos en `team-student` no pueda crear un namespace `student-ns` directamente sin pasar por el claim? ¿Es Crossplane el que lo garantiza?
3. Si borras el claim, ¿se borra el namespace materializado? ¿Y si usaras `deletionPolicy: Orphan` en los MRs?
4. ¿Cómo haría el platform team para **versionar** este XRD a `v1beta1` sin romper los claims existentes?
5. ¿Qué 2 cosas cambiarían si en vez de `provider-kubernetes` usaras `provider-aws` para materializar un bucket S3?

## 10. Extensiones

- Añade un cuarto recurso a la Composition: un `LimitRange` default para pods del namespace.
- Añade un patch que ponga labels de FinOps (`cost-center`, `team`) derivados del `spec.parameters`.
- Rechaza con Kyverno (si lo tienes) claims cuyo `name` empiece por `test-` en el namespace `team-student`.
- Escribe un segundo Claim (`student-claim-2`) con `tier=medium` y comprueba que su ResourceQuota tiene `requests.cpu=8`.

## 11. Limpieza

```bash
bash tests/cleanup.sh
```
