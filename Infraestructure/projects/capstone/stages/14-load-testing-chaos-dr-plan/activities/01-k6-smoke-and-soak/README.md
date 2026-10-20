# Actividad 01 — k6 smoke + ramp contra la app capstone

## 1. Identificacion

- **ID:** `cap-14-01-k6-smoke-and-soak`
- **Tecnologia:** `capstone`
- **Modulo:** `14-load-testing-chaos-dr-plan`
- **Tipo:** guided-lab

## 2. Contexto

Hasta ahora medimos la app con metricas de produccion (RED, SLOs). Falta medirla bajo **carga controlada** para conocer su techo antes de que un pico real lo descubra por nosotros.

## 3. Objetivos

- Correr k6 (smoke y ramp) contra la URL de la app.
- Interpretar los thresholds del script y la salida del summary.
- Registrar un baseline en `baseline.md` que el equipo pueda comparar en el futuro.

## 4. Prerrequisitos

- App FastAPI accesible (p. ej. `kubectl port-forward svc/fastapi 8000:80`).
- `k6` instalado (si no, el runner hace SKIP y la actividad se cierra con auto-reflexion).

## 5. Instrucciones

1. Levantar la app o el port-forward.
2. Correr `BASE_URL=http://localhost:8000 bash ../../load/run-k6.sh`.
3. Capturar el `summary.json` que queda en `../../load/results/`.
4. Escribir `baseline.md` con: p95 observado (smoke + ramp), error rate, fecha, URL, version del commit.
5. (Opcional) Correr `SOAK=1 bash ../../load/run-k6.sh` durante 15 min contra un cluster descartable.

### 5.5 Pistas

- `k6 run` admite `--vus` y `--duration` para overrides rapidos cuando iteras.
- Si los thresholds fallan, no "sube el threshold". Diagnostica (CPU, DB connections, GC pauses).

## 6. Resultado esperado

- `baseline.md` creado con las secciones minimas (ver validator).
- Summary json guardado y referenciado.

## 7. Criterios de aceptacion

- [ ] Existe `baseline.md` con secciones `## p95`, `## Error rate`, `## Fecha`.
- [ ] `baseline.md` referencia al menos un archivo de resultado real.
- [ ] `validate.sh` termina con `RESULT: 0 issue(s)`.

## 8. Validacion

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexion

1. ¿Por que el soak corre con un escenario separado y no con mas VUs del ramp?
2. ¿Que decision tomarias si el p95 cumple pero el error rate es 0.9% (muy cerca del limite)?
3. ¿Como integrarias este baseline con el scorecard de Backstage (etapa 13)?

## 10. Limpieza

```bash
rm -rf ../../load/results/
```
