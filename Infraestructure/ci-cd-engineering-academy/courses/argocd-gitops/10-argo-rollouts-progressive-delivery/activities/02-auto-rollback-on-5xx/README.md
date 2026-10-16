# argo-10-02 — Auto-rollback por 5xx con AnalysisTemplate Prometheus

## 1. Identificación

- **ID:** `argo-10-02-auto-rollback-on-5xx`
- **Tecnología:** argocd-gitops
- **Módulo:** `10-argo-rollouts-progressive-delivery`
- **Dificultad:** advanced
- **Duración estimada:** 120 min
- **Tipo:** independent

## 2. Contexto

Tienes el `Rollout` canary de la actividad 01. Ahora debes añadirle un **gate automático** que consulte Prometheus durante el canary y revierta al estable si la tasa de respuestas 5xx del servicio canary supera un umbral.

Esta actividad es **independiente**: el README describe el *qué*, no el *cómo* paso-a-paso. Diseña tú el `AnalysisTemplate`, los umbrales, la ventana, y el punto del canary donde se inserta.

## 3. Objetivos

- Diseñar un `AnalysisTemplate` que mida la razón de 5xx del canary.
- Decidir y defender los parámetros `interval`, `count`, `failureLimit`, `successCondition`.
- Integrarlo en el `Rollout` como step `analysis`.
- Garantizar que un fallo del analysis **gatilla rollback automático** (sin intervención humana).

## 4. Prerrequisitos

- Actividad 01 completada (o su solución).
- Lección del módulo, secciones 6, 8, 11.
- (Opcional, para probar en caliente) Prometheus accesible y el servicio capstone emitiendo `http_requests_total{code="5xx"}` — p.ej. mediante un sidecar nginx-exporter o un microservicio instrumentado.

## 5. Instrucciones

Trabaja en `/tmp/argo-10-02/`:

```bash
mkdir -p /tmp/argo-10-02
cp starter/* /tmp/argo-10-02/
cd /tmp/argo-10-02
```

Produce **dos archivos**:

1. `analysistemplate.yaml` — un `AnalysisTemplate` llamado `error-rate-5xx` con:
   - `spec.args` para parametrizar al menos `service-name` y `prometheus-address`.
   - Exactamente **una** `metric` que mida la razón `rate(5xx) / rate(total)` sobre una ventana corta (sugerencia 2m).
   - `interval`, `count`, `failureLimit`, `successCondition` y `failureCondition` numéricas.
   - Provider `prometheus` con `address` y `query` que usen la interpolación `{{args.NAME}}`.

2. `rollout.yaml` — el `Rollout` `capstone` canary con **al menos un step `analysis`** que referencie `templateName: error-rate-5xx` y pase los `args` requeridos. El resto de la estructura puede partir de tu actividad 01.

### Decisiones que debes documentar en comentarios dentro de los YAML

- Umbral exacto (`<= 0.01`? `<= baseline + 0.005`?) y por qué.
- `interval`/`count`/`failureLimit` elegidos y por qué (evitar flapping).
- Posición del step `analysis` dentro de los steps y justificación.

### Valida

```bash
bash tests/validate.sh /tmp/argo-10-02
```

### (Opcional) Prueba en caliente

Si tienes Argo Rollouts + Prometheus y un servicio canary instrumentado:

1. Aplica el `AnalysisTemplate` y el `Rollout`.
2. Dispara un cambio de imagen.
3. Fuerza 5xx (p.ej. imagen rota) y observa que:
   - `AnalysisRun` termina en `Failed`.
   - `Rollout` entra en `Degraded`.
   - El `canary` escala a 0 y el `stable` vuelve a servir el 100%.
   - **Sin intervención humana**.

## 6. Resultado esperado

- `tests/validate.sh` sale con exit 0.
- Opcionalmente, un `AnalysisRun` con fase `Failed` tras forzar 5xx y Rollout en `Degraded` con revert automático.

## 7. Criterios de aceptación

- `kind: AnalysisTemplate` con `metadata.name: error-rate-5xx`.
- `spec.args` con al menos los dos nombres requeridos.
- Una `metric` con `successCondition` numérica, `failureCondition` numérica, `failureLimit >= 1`, `count >= 1`, `interval` definido.
- Provider `prometheus` con `address` y `query` conteniendo `5..` y `{{args.service-name}}`.
- `rollout.yaml` referencia `templateName: error-rate-5xx` dentro de un step `analysis`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/argo-10-02
```

## 9. Preguntas de reflexión

1. ¿Por qué `failureLimit >= 2` evita rollbacks por puntos espurios?
2. ¿Qué pasa si tu Prometheus está caído durante el analysis? ¿Qué fase da el `AnalysisRun` y por qué eso **no** gatilla rollback?
3. ¿Cómo compararías canary vs stable para que un pico global no dispare el rollback? Escribe la query.
4. ¿Por qué `count` finito es mejor que infinito si el canary tiene varios pasos de analysis?

## 10. Extensiones

- Añade una segunda `metric` para latencia p95 con `histogram_quantile`.
- Convierte el `AnalysisTemplate` en `ClusterAnalysisTemplate` para reutilizarlo entre namespaces.
- Añade un `prePromotionAnalysis` versión blue/green y compara DX con canary.

## 11. Limpieza

```bash
rm -rf /tmp/argo-10-02
# Si aplicaste en cluster:
# kubectl delete analysistemplate error-rate-5xx --ignore-not-found
# kubectl delete rollout capstone --ignore-not-found
```
