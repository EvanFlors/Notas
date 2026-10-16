# obs-12-02 — Añadir SLO rules via CRDs

## 1. Identificación
- **ID:** `obs-12-02-add-slo-rules-via-crds`
- **Tecnología:** prometheus-grafana
- **Módulo:** `12-prometheus-operator-and-kube-prometheus-stack`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

En la actividad anterior montaste el stack. Ahora, como SRE del equipo *payments*, te piden instrumentar la observabilidad de su API en términos de SLO en vez de métricas crudas:

- **SLI** definido: fracción de requests HTTP con status < 500.
- **SLO**: 99.5% en ventana de 30 días (error budget = 0.5%).
- **Routing**: alertas `severity=critical` → PagerDuty (webhook), `severity=warning` → Slack.
- Quieren todo como código, aplicable por Argo CD, con los labels requeridos por el Operator.

No vas a instalar nada: solo escribirás los CRDs y los validarás.

## 3. Objetivos

- Escribir **un** `PrometheusRule` con:
  - Al menos **1 recording rule** (p. ej. `job:payments_requests:rate5m`).
  - Al menos **2 alerting rules** con severidades distintas (`critical` y `warning`).
  - `annotations.summary`, `annotations.description`, `annotations.runbook_url` en cada alerta.
  - La label `release: kps` en el metadata (requisito del Operator por default).
- Escribir **un** `AlertmanagerConfig` que rute por `severity` a receivers distintos y que haga `groupBy` razonable.
- Referenciar la clave del webhook por `Secret`, **no** hardcodearla.
- Validar con `promtool check rules` si está disponible.

## 4. Prerrequisitos

- Haber hecho obs-12-01.
- Opcional: `promtool` (viene en la imagen oficial de Prometheus o instalable por paquete).
- No requiere cluster vivo para esta actividad (los tests son estructurales).

## 5. Instrucciones

Trabaja dentro de `starter/`:

```
starter/
├── payments-rules.yaml       # ← rellenar
├── payments-amconfig.yaml    # ← rellenar
└── payments-secret.yaml      # ← rellenar (ejemplo seguro)
```

### 5.1 `payments-rules.yaml`

- Un `PrometheusRule` llamado `payments-slo` en namespace `payments`.
- Labels requeridos: `release: kps`, `tenant: payments`.
- Un `group` con nombre `payments.slo.rules`.
- Define al menos:
  - Record `job:payments_requests:rate5m = sum by (job) (rate(http_requests_total{job="payments"}[5m]))`.
  - Record `job:payments_errors:ratio5m` para el ratio de errores 5xx.
  - Alerta `PaymentsErrorBudgetBurnFast` (crítica, condición de burn rápido).
  - Alerta `PaymentsErrorBudgetBurnSlow` (warning, condición de burn lento sostenido).

### 5.2 `payments-amconfig.yaml`

- Un `AlertmanagerConfig` llamado `payments` en namespace `payments`.
- Labels: `release: kps`.
- `route.receiver` = `payments-slack` (default).
- Subrutas:
  - `severity=critical` → `payments-pager`.
  - `severity=warning` → `payments-slack`.
- `groupBy: [alertname, namespace]`, `groupWait`, `groupInterval`, `repeatInterval` razonables.
- Dos `receivers`:
  - `payments-pager` con `pagerdutyConfigs` referenciando el Secret `pd-integration` key `routingKey`.
  - `payments-slack` con `slackConfigs` referenciando el Secret `slack-webhook` key `url`.

### 5.3 `payments-secret.yaml`

Un ejemplo de cómo *modelar* los secrets (los valores reales nunca van al repo). Comentar en el fichero cómo se crearían en producción (External Secrets, SealedSecrets, Vault, etc.).

## 6. Resultado esperado

- Los tres YAMLs son válidos (`kubectl apply --dry-run=client -f` pasa).
- `promtool check rules` sobre el extracto de reglas no reporta errores (si `promtool` está instalado).
- El validator estructural de la actividad pasa.

## 7. Criterios de aceptación

- **Funcional**: cada alerta tiene las 3 annotations.
- **Seguridad**: ningún secreto en claro — todo por `secret.name` / `secret.key`.
- **Calidad**: nombres consistentes, condiciones no triviales (nada de `up == 0 for 1m` como SLO).
- **Operator-friendly**: labels `release: kps` + `tenant: payments` en ambos CRs.

## 8. Validación

```bash
bash tests/validate.sh
```

Checks:

1. Los tres ficheros existen.
2. `payments-rules.yaml` contiene `kind: PrometheusRule`, `release: kps`, al menos un `record:` y dos `alert:`, y `runbook_url` aparece.
3. `payments-amconfig.yaml` contiene `kind: AlertmanagerConfig`, al menos dos receivers y rutas por `severity`.
4. Ningún fichero contiene un token obvio (`xoxb-`, `AKIA`, `-----BEGIN`).
5. Si `promtool` está disponible, valida las reglas.

## 9. Preguntas de reflexión

1. ¿Por qué la alerta rápida de burn-rate necesita una ventana corta *y* otra larga en el mismo PromQL?
2. ¿Qué ocurre si olvidas `release: kps` en el `PrometheusRule`? ¿Cómo lo detectas?
3. ¿Por qué `AlertmanagerConfig` es un CRD "por namespace" en vez de un alertmanager.yml global?
4. Si un tenant añade un receiver mal configurado, ¿puede tumbar las alertas de otro tenant? Argumenta.
5. ¿Dónde pondrías el `runbook_url` real para que exista versionado y accesible 24/7?

## 10. Extensiones

1. Añade una tercera alerta `PaymentsNoTraffic` que dispare si `rate(http_requests_total[10m]) == 0 for 15m`.
2. Modela el escenario multi-tenant: duplica para `search` con sus propios Secrets y verifica que las rutas no se mezclan.
3. Integra `sloth` o `OpenSLO` para generar las reglas desde una spec declarativa de SLO.
4. Añade `inhibit_rules` para que `PaymentsDown` silencie las de latencia.

## 11. Limpieza

```bash
# nada que limpiar: no se aplica al cluster
rm -rf /tmp/obs12-02-* 2>/dev/null || true
```
