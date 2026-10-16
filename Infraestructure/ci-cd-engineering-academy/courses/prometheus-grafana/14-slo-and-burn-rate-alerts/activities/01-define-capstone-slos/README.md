# obs-14-01 — Define los SLOs del capstone (guided lab)

## 1. Identificación
- **ID:** `obs-14-01-define-capstone-slos`
- **Tecnología:** prometheus-grafana
- **Módulo:** `14-slo-and-burn-rate-alerts`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto
Tu capstone expone una API `payments` instrumentada en módulos anteriores. Hoy no hay SLOs explícitos: cuando algo falla, las alertas se disparan sobre síntomas de recurso (CPU, memoria) y el on-call recibe páginas por falsos positivos. Vas a cerrar esa brecha definiendo un SLO formal, escribiendo los *ingredientes* (recording rules) y las alertas MWMBR a mano, y validándolas con `promtool`.

## 3. Objetivos
- Enunciar un SLO bien formado (SLI, objetivo, ventana, política).
- Escribir el `PrometheusRule` con 5 ingredientes + 4 alertas MWMBR (page y ticket).
- Validar las reglas con `promtool check rules`.
- Validar el comportamiento con `promtool test rules` cubriendo escenario calma y burn.

## 4. Prerrequisitos
- Conocimiento de los módulos `obs-09`, `obs-10`, `obs-12`.
- **Software:** Docker ≥ 20.10 (para correr `prom/prometheus:v2.54.1` sin instalar `promtool`).
- **No** se necesitan secrets ni cuentas cloud.
- **Costo:** 0 (todo local). Imagen Prometheus ~250 MB.

## 5. Instrucciones

### Paso 1 — Enunciar el SLO
Edita `starter/slo-draft.md` y responde:
- ¿Qué SLI eliges (availability, latency, ambos)?
- ¿Cuál es la query exacta de "good" y "total"?
- ¿Objetivo? ¿Ventana?
- ¿Qué pasa cuando el budget cae a 25 %, 10 %, 0 %?

### Paso 2 — Escribir ingredientes
En `starter/rules.yaml`, dentro del grupo `slo-ingredients-payments-availability`, añade:
- `sli:payments_requests:ratio_rate5m`
- `sli:payments_requests:ratio_rate30m`
- `sli:payments_requests:ratio_rate1h`
- `sli:payments_requests:ratio_rate2h`
- `sli:payments_requests:ratio_rate6h`

Convención: la ratio es `1 - error_rate` para que valores sanos estén cerca de 1.

### Paso 3 — Escribir alertas MWMBR
En el grupo `slo-alerts-payments-availability`, añade al menos:
- Una alerta `severity: page` con pares `(1h, 5m)` y burn-rate 14.4.
- Una alerta `severity: ticket` con pares `(6h, 1h)` y burn-rate 1.

Cada alerta debe tener `for:` razonable (≥ 2 min para page, ≥ 1 h para ticket) y annotations con `summary`, `description`, `runbook`.

### Paso 4 — Validar
```bash
bash tests/validate.sh
```

El script corre `promtool check rules` + `promtool test rules` dentro de Docker.
Si tu alerta `page` no dispara en el escenario burn, revisa:
- La fórmula es `(1 - sli_long) > burn_rate * 0.001 AND (1 - sli_short) > burn_rate * 0.001`.
- El `for:` no es más largo que la ventana del test.

## 6. Resultado esperado
- `starter/slo-draft.md` completo.
- `starter/rules.yaml` con 5 ingredientes y ≥ 2 alertas MWMBR válidas.
- `bash tests/validate.sh` termina con `OK` (o `SKIP` si Docker no está disponible).

## 7. Criterios de aceptación
- `promtool check rules` pasa.
- `promtool test rules` pasa con un fixture de calma (no alertas) y uno de burn (dispara al menos la alerta de page).
- Las alertas tienen `severity`, `slo`, y annotations con `runbook`.
- La política de error budget está documentada.

## 8. Validación
```bash
bash tests/validate.sh
```

Compara tu solución con `solution/rules.yaml` si te atascas (pero intenta primero).

## 9. Preguntas de reflexión
- ¿Por qué `1 - sli` y no `error_rate` directamente? ¿Qué pasa si cambias la convención?
- ¿Qué ocurre con la ventana corta si el error dura exactamente 2 min y luego cesa?
- Si tu servicio tiene 1 req/min, ¿sigue siendo útil `rate(X[5m])`? ¿Qué alternativa hay?
- ¿Cómo probarías manualmente la alerta sin esperar 1h real?

## 10. Extensiones
- Añade un SLO de **latency** (`fast / total` con bucket `le="0.3"`).
- Añade un panel Grafana que muestre budget restante en %.
- Convierte las reglas a un `PrometheusRule` CRD (Prometheus Operator).

## 11. Limpieza
```bash
# Las imágenes Docker descargadas pueden mantenerse o eliminarse:
docker image rm prom/prometheus:v2.54.1 || true
# Elimina scratch:
rm -rf /tmp/obs-14-01 || true
```
