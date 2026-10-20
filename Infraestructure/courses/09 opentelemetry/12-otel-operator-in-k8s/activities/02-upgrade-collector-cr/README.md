# otel-12-02 — Upgrade de un `OpenTelemetryCollector` CR

## 1. Identificación
- **ID:** `otel-12-02-upgrade-collector-cr`
- **Tecnología:** opentelemetry
- **Módulo:** `12-otel-operator-in-k8s`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

En producción los Collectors viven años; se *upgradan* decenas de veces. Hay dos vectores de cambio:

- **Imagen** del binario (`otel/opentelemetry-collector-contrib:X.Y.Z`).
- **Configuración** (`spec.config`: receivers/processors/exporters).

Y hay dos **modos** de upgrade de imagen con el Operator:

- **Pin explícito** (`spec.image: ...`) — el upgrade es controlado por quien edita el CR.
- **Default del Operator** (`spec.image` omitido) — el Operator elige la imagen según su versión; actualizar el Operator mueve *todos* los Collectors a la vez.

Esta actividad te hace ejercitar ambos casos y producir un ADR corto comparando con Helm.

## 3. Objetivos

- Pinear `spec.image` y upgradar la minor (p. ej. `0.111.0 → 0.112.0`), observar el rolling update.
- Cambiar `spec.config` (añadir un processor `attributes`) y observar que el ConfigMap renderizado tiene un `hash` nuevo y el Pod reinicia.
- Simular el fallo del "default-image" sin pinear: entender por qué upgradar el Operator sin `spec.image` es arriesgado.
- Escribir `OPERATOR_VS_HELM.md` con la decisión justificada para un contexto dado.

## 4. Prerrequisitos

- Haber completado `otel-12-01` (el cluster `otel-12-lab` sirve; alternativamente, el starter re-crea un cluster mínimo).
- `kind`, `kubectl`.
- Internet para pulls.

**Si falta kind/kubectl**, la actividad acepta el **modo documentación**: edita `starter/OPERATOR_VS_HELM.md` únicamente, sin disparar los rollouts.

## 5. Instrucciones

> No se te dará la secuencia exacta. Debes razonar las operaciones.

### Setup

```bash
cd starter/
bash setup.sh    # usa el cluster otel-12-lab si existe, si no lo crea
```

Esto deja aplicado un `OpenTelemetryCollector/upgradable` en `observability` con `spec.image: otel/opentelemetry-collector-contrib:0.110.0` (versión *vieja* a propósito).

### Ejercicios

1. **Upgrade de imagen pineada**:
   - Modifica el CR para pasar a `0.111.0`.
   - Verifica que aparece un **nuevo ReplicaSet** y que el viejo queda a 0.
   - Captura la salida de `kubectl -n observability get rs -l app.kubernetes.io/managed-by=opentelemetry-operator` antes y después.
2. **Cambio de config**:
   - Añade al CR un processor `attributes` que inserte `deployment.environment=lab` para todos los spans.
   - Verifica que el **ConfigMap** generado tiene nombre con hash distinto al anterior.
   - Verifica que el Pod re-rolla (nuevo `pod.metadata.name`).
3. **Caso "sin pin"**:
   - Edita el CR para **quitar** `spec.image`.
   - Observa qué imagen aplica el Operator (`kubectl describe pod | grep Image:`).
   - Documenta en tu ADR qué pasaría si upgradás el Operator ahora.
4. **Comparación con Helm**:
   - Documenta en `starter/OPERATOR_VS_HELM.md`:
     - Para un contexto dado (`N instancias`, `auto-inject sí/no`, `GitOps sí/no`), ¿Operator o Helm?
     - Qué comandos equivaldrían al rollout del ejercicio 1 bajo Helm.
     - 3 red flags que te harían **no** adoptar el Operator en un contexto específico.

### Validar

```bash
bash tests/validate.sh
```

El validador acepta dos modos:
- **Modo A** (ejecutaste los pasos en cluster): verifica imagen final = `0.111.0`, presencia del processor `attributes`, y que `OPERATOR_VS_HELM.md` tiene las secciones.
- **Modo B** (documentación): verifica que `OPERATOR_VS_HELM.md` tiene las 4 secciones completas.

## 6. Resultado esperado

- **Modo A**: `OpenTelemetryCollector/upgradable` en `0.111.0` con processor `attributes/env`, ADR escrito.
- **Modo B**: ADR escrito con las 4 secciones y ejemplos de comandos.

## 7. Criterios de aceptación

- La imagen final está **pineada** (no vacía).
- La config incluye un processor nuevo introducido en la actividad.
- El ADR cita al menos 3 criterios concretos (no "depende") y recomienda explícitamente para un contexto.
- No se usa `--force` ni `kubectl patch` sobre objetos generados — todo via el CR.

## 8. Validación

```bash
bash tests/validate.sh
```

Salidas posibles:
- `RESULT: OK (mode: A)`
- `RESULT: OK (mode: B)`
- `RESULT: FAIL — ...`
- `SKIP: ...` (sin kubectl y sin ADR).

## 9. Preguntas de reflexión

1. ¿Por qué el Operator cambia el **nombre** del ConfigMap (añade un hash) en vez de editarlo in-place?
2. Si dos CRs comparten el mismo nombre en namespaces distintos, ¿pueden colisionar los Deployments generados? ¿Y los Services?
3. ¿Qué información necesitarías para decidir, en una org real, si pinear `spec.image` o confiar en el default del Operator?
4. En GitOps (Argo CD), ¿quién gana si Argo re-aplica el CR y el Operator ha reconciliado cambios implícitos? ¿Hay drift?
5. ¿Cómo harías un **rollback** de un upgrade de config que rompió el pipeline?

## 10. Extensiones

- Añade un `PodDisruptionBudget` indirectamente (via `spec.podDisruptionBudget` del CR si tu versión lo soporta) y verifica que el rollout respeta el PDB.
- Pasa el `mode` de `deployment` a `statefulset` sin perder config — razona por qué el Operator *no* lo migra in-place (reconstruye).
- Añade `spec.upgradeStrategy: none` y comprueba que el default-image del Operator deja de moverse en upgrade del Operator.

## 11. Limpieza

```bash
bash starter/teardown.sh
```
