# Actividad 02 — `kube-bench` y plan de remediación top-3

## 1. Identificación

- **ID:** `k8s-16-02-run-kube-bench-and-fix`
- **Tecnología:** `kubernetes`
- **Módulo:** `16-security-hardening-and-supply-chain`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

Tomas un cluster activo (idealmente el mismo de la Actividad 01) y le corres **kube-bench** como Job in-cluster. Parseas la salida, eliges los **3 hallazgos `FAIL`** más críticos y documentas la remediación en un `REMEDIATIONS.md` que el validador comprueba por estructura.

Esta es una actividad **independent**: no te damos la solución mientras escribes. El `tests/validate.sh` evalúa solo la estructura del documento, no el contenido técnico — el contenido se evalúa por revisión manual (lección §10 y §12 son tu referencia).

## 3. Objetivos

Al terminar:

- Habrás ejecutado `kube-bench` como Job y guardado la salida en `/tmp/k8s-16-02/work/kube-bench.out`.
- `REMEDIATIONS.md` contendrá:
  - Resumen cuantitativo (PASS / FAIL / WARN totales).
  - 3 secciones `### H1`, `### H2`, `### H3`, cada una con los sub-encabezados **Hallazgo**, **Mecanismo**, **Impacto**, **Remediación**.
  - Al menos 2 líneas de prosa real por subsección.
  - Sin placeholders (`TODO:`, `<rellena>`).
  - Mínimo 60 líneas no vacías en total.

## 4. Prerrequisitos

- Cluster activo (kind recomendado).
- `kubectl` funcional.
- La Actividad 01 completada (opcional pero recomendado — así tienes contraste con/sin PSA).

## 5. Instrucciones

### 5.1 Bootstrap

```bash
bash courses/kubernetes/16-security-hardening-and-supply-chain/activities/02-run-kube-bench-and-fix/starter/bootstrap.sh /tmp/k8s-16-02
cd /tmp/k8s-16-02/work
```

Esto crea:
- `kube-bench-job.yaml` — Job que corre `aquasec/kube-bench` sobre el nodo (targets=node por default; para kind esto es suficiente).
- `REMEDIATIONS.md` — plantilla con placeholders.

### 5.2 Correr kube-bench

```bash
kubectl apply -f kube-bench-job.yaml

# Espera a que el Job termine (unos segundos)
kubectl wait --for=condition=complete job/kube-bench --timeout=120s

# Captura la salida
kubectl logs job/kube-bench > kube-bench.out
head -50 kube-bench.out
```

Si el Job falla porque el nodo kind no soporta ciertos checks de control plane, puedes ejecutar `kube-bench` directamente con `targets=node`:

```bash
# Variante alternativa (si el Job original falla):
kubectl delete job/kube-bench --ignore-not-found
sed -i.bak 's/kube-bench run/kube-bench run --targets=node/' kube-bench-job.yaml
kubectl apply -f kube-bench-job.yaml
kubectl wait --for=condition=complete job/kube-bench --timeout=120s
kubectl logs job/kube-bench > kube-bench.out
```

### 5.3 Analizar la salida

```bash
# Totales por estado:
grep -E "^== Summary|checks PASS|checks FAIL|checks WARN|checks INFO" kube-bench.out

# Listado de FAILs con su id:
grep -E "^\[FAIL\]" kube-bench.out | head -20
```

Elige **3 FAILs** priorizando por:

1. **Impacto en superficie de ataque** (p. ej., `--anonymous-auth=true`, `--authorization-mode=AlwaysAllow`, `encryption-provider-config` ausente, kubelet readonly port abierto).
2. **Facilidad de explotación** (público en Internet > local al cluster > requiere credencial previa).
3. **Costo de remediación** (bajo coste primero: cambiar un flag suele ser trivial).

### 5.4 Escribir `REMEDIATIONS.md`

Edita el archivo. Estructura obligatoria por hallazgo:

```markdown
### H1 — <id CIS> <titulo corto>

**Hallazgo**
2+ lineas describiendo que detecto kube-bench, con el ID exacto del benchmark
(p.ej. "1.2.19 Ensure --anonymous-auth is set to false").

**Mecanismo**
Que primitiva de K8s/Linux esta involucrada. Por que el default es inseguro.

**Impacto**
Que puede hacer un atacante si no se remedia. Severidad (ALTA/MEDIA/BAJA)
con justificacion.

**Remediacion**
Pasos concretos, incluyendo flag/manifiesto/comando exacto. Como verificar.
```

Repite para H2 y H3.

### 5.5 Validar

```bash
bash courses/kubernetes/16-security-hardening-and-supply-chain/activities/02-run-kube-bench-and-fix/tests/validate.sh
```

Debe terminar con `RESULT: N/N controles OK`.

## 6. Resultado esperado

- `/tmp/k8s-16-02/work/kube-bench.out` existe y tiene salida real de kube-bench.
- `REMEDIATIONS.md` con 3 hallazgos estructurados y sin placeholders.
- `validate.sh` pasa.

## 7. Criterios de aceptación

- **Estructura**: validada automáticamente (encabezados, subsecciones, longitud).
- **Contenido** (revisión manual):
  - Cada hallazgo tiene el ID CIS exacto citado desde `kube-bench.out`.
  - La "Remediación" es ejecutable: incluye flag, archivo, comando, no "configurar correctamente".
  - La severidad está justificada por mecanismo, no por intuición.

## 8. Validación

Automatizada: `bash tests/validate.sh`.

## 9. Preguntas de reflexión

- ¿Por qué `--anonymous-auth=true` es un hallazgo con *mucho* más retorno de hardening que, digamos, `--profiling=true`?
- ¿Qué controles del CIS Benchmark son competencia del operador (self-hosted) y cuáles vienen cerrados en un cluster managed (EKS/GKE)?
- Si tu cluster corre bajo un provider managed, ¿tiene sentido correr `kube-bench --targets=master`? ¿Qué devolvería?
- ¿Qué hallazgos deberían gestionarse como *drift detection* continuo y no como auditoría one-shot?

## 10. Extensiones

- Instala el **Trivy Operator** y compara sus `ConfigAuditReport` con los FAILs de `kube-bench`.
- Corre `kube-hunter` (modo *remote*) desde fuera del cluster y añade sus hallazgos.
- Automatiza `kube-bench` como `CronJob` + envío de resultados a Prometheus (hay chart oficial de Aqua).

## 11. Limpieza

```bash
kubectl delete job/kube-bench --ignore-not-found
rm -rf /tmp/k8s-16-02
```
