# obs-09-01 — Escribir alertas con tests `promtool` (guided-lab)

## 1. Identificacion
- **ID:** `obs-09-01-write-alerts-with-promtool-tests`
- **Tecnologia:** prometheus-grafana
- **Modulo:** 09-alertmanager-and-alert-design
- **Dificultad:** intermediate
- **Duracion estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto
Tu equipo tiene una API HTTP con metricas RED expuestas en `/metrics`. Debes entregar **tres alertas** con tests unitarios que pasen en CI: `HighErrorRate`, `HighLatencyP95`, `AbsentTarget`. Sin tests, nadie confia en que la alerta disparara cuando toque.

## 3. Objetivos
- Escribir reglas Prometheus con `for`, labels y annotations correctos.
- Escribir tests `promtool test rules` que cubran: disparo esperado, no-disparo con trafico sano y disparo por target ausente.
- Validar con `promtool check rules` y `promtool test rules` sin errores.

## 4. Prerrequisitos
- Haber leido `theory/lesson.md` secciones 1–3.
- Docker instalado (para correr `promtool` sin instalarlo) **o** `promtool` nativo.
- Shell bash. Sin cuentas, sin costos.

## 5. Instrucciones

### Paso 1 — Copia el starter
```bash
cp -r starter /tmp/obs-09-01
cd /tmp/obs-09-01
```

### Paso 2 — Completa `alerts.yaml`
Edita el fichero. Hay tres `TODO:` que completar:
1. `HighErrorRate` — error 5xx > 5% durante 10m.
2. `HighLatencyP95` — p95 de `http_request_duration_seconds` > 0.5s durante 5m.
3. `AbsentTarget` — `up{job="api"} == 0` o `absent(up{job="api"})` durante 2m.

Reglas obligatorias para cada alerta:
- `for:` presente.
- `labels:` con `severity` y `team`.
- `annotations:` con `summary`, `description` y `runbook_url`.

### Paso 3 — Completa `tests.yaml`
Hay un `TODO:` por alerta. Debes agregar:
- Un caso que **dispare** y verifique labels/annotations.
- Un caso **sano** que no dispare.

### Paso 4 — Valida
```bash
# Con promtool nativo
promtool check rules alerts.yaml
promtool test rules tests.yaml

# O con docker
docker run --rm --entrypoint promtool -v "$PWD":/w -w /w prom/prometheus:latest check rules alerts.yaml
docker run --rm --entrypoint promtool -v "$PWD":/w -w /w prom/prometheus:latest test rules tests.yaml
```

### Paso 5 — Ejecuta el validador
```bash
bash tests/validate.sh /tmp/obs-09-01
```

## 6. Resultado esperado
- `promtool check rules` → `SUCCESS: 3 rules found`.
- `promtool test rules` → `SUCCESS`.
- `tests/validate.sh` → `== PASS ==`.

## 7. Criterios de aceptacion
- Las 3 alertas tienen `for`, `severity`, `team`, `summary`, `description`, `runbook_url`.
- `promtool test rules` pasa.
- `AbsentTarget` dispara en el test cuando `up` queda ausente.

## 8. Validacion
```bash
bash tests/validate.sh /tmp/obs-09-01
```

## 9. Preguntas de reflexion
- Por que `for: 2m` es razonable para `AbsentTarget` y no `for: 10m`?
- Que pasa si quito el `for` de `HighErrorRate` y hay un pico de 1 min?
- Como testearias que la alerta **se resuelve** cuando el trafico vuelve a la normalidad?

## 10. Extensiones
- Anade una recording rule `job:http_errors:ratio5m` y reescribe la alerta usandola.
- Anade una cuarta alerta `BurnRateHigh1h` (SLO-based) y su test.

## 11. Limpieza
```bash
rm -rf /tmp/obs-09-01
```

## Si no tienes Docker ni promtool
El modulo degrada **gracefully**: `tests/validate.sh` detecta la ausencia y marca los pasos de ejecucion como `SKIP` (reporta el motivo). La validacion estructural (ficheros presentes, campos obligatorios) sigue corriendo.
