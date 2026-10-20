# `cap-11-01-wire-slo-burn-rate-alerts`

> Tipo: **independent** · Tiempo estimado: 70 min · Nivel: advanced
> Prerrequisito: `cap-10-01-gitops-rollouts-canary` (GitOps + Argo Rollouts corriendo).

## Objetivo

Dejar las 4 alertas MWMBR del SLO 99.9 % funcionando end-to-end y demostrar, con un fault injection controlado, que `HighErrorBudgetBurnFast` entra en `firing` en menos de 5 min. No se te da el `expr` ya mascado: parte de los recording rules de `prometheusrule-slo.yaml` y razona.

## Qué entregas

1. Un pequeño log (`notes.md`) con:
   - Qué burn-rate (14.4x, 6x, 3x, 1x) te parece el *floor* mínimo razonable para el capstone y por qué.
   - Un `promtool query instant` ejemplo que calculaste a mano antes de aplicar.
2. Capturas (o export) de Grafana mostrando el panel "Errors (5xx ratio)" subiendo por encima de `0.001` y el "Error budget remaining" cayendo.
3. Un screenshot (o export JSON) del `Alertmanager` con la alerta `HighErrorBudgetBurnFast` en `firing`, luego en `resolved` tras parar la inyección.
4. `tests/validate.sh` en verde.

## Pasos sugeridos (no un script a copiar)

1. Lee `observability/prometheusrule-slo.yaml` y escribe en tus notas, antes de ejecutar nada, cuál es la razón de que el *fast burn* use `5m AND 1h` en lugar de uno solo.
2. Ejecuta `bash tests/validate.sh` tal cual. Debe salir verde porque sólo valida estructura, no runtime.
3. Despliega la stage siguiendo la Sección 4 del `README.md` del stage.
4. Con la app en pie, inyecta errores:

   ```bash
   kubectl -n capstone exec deploy/capstone-api -- \
     sh -c 'for i in $(seq 1 2000); do wget -q -O- http://localhost:8000/boom || true; done'
   ```

   Si el endpoint `/boom` no existe, añade un router minúsculo que haga `raise HTTPException(status_code=500)`. Documenta el cambio en tus notas.
5. Observa en Prometheus (`port-forward svc/kps-prometheus 9090:9090`) la métrica `slo:http_requests_error_ratio:rate5m`.
6. Confirma el `firing` en Alertmanager (`port-forward svc/kps-alertmanager 9093:9093`).
7. Para la inyección y espera a que resuelva.

## Criterios de aceptación

- [ ] `bash tests/validate.sh` sale 0.
- [ ] Las 4 alertas aparecen listadas en `GET /api/v2/alerts` de Alertmanager (al menos como `inactive`).
- [ ] En la ventana de la inyección, `HighErrorBudgetBurnFast` pasa a `firing`.
- [ ] Tras parar la inyección y transcurrir >5 min, pasa a `resolved`.
- [ ] `notes.md` contiene las decisiones y la razón de cada burn-rate elegido.
