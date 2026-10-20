# Teoria — obs-09: Alertmanager y diseno de alertas

> Modulo intermedio del curso Prometheus + Grafana. 4 horas. Spanish prose, English code.

Esta leccion asume PromQL fluido (`obs-04`). Se divide en **12 secciones**: desde la mecanica de una regla de alerta hasta criterios de diseno SLO-based y antidotos para alert fatigue.

---

## 1. De la query al disparo: anatomia de una regla

Una **alerting rule** vive en un fichero YAML cargado por Prometheus (via `rule_files:` en `prometheus.yml`). Prometheus evalua cada regla en cada `evaluation_interval` (default 1 min) y, si la `expr` devuelve series no vacias, inicia una alerta.

```yaml
groups:
  - name: api.rules
    interval: 30s                 # opcional; default es evaluation_interval global
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{job="api",status=~"5.."}[5m]))
            /
          sum(rate(http_requests_total{job="api"}[5m]))
            > 0.05
        for: 10m
        labels:
          severity: page
          team: platform
        annotations:
          summary: "API 5xx rate >5% (10m)"
          description: "La tasa de errores 5xx de {{ $labels.job }} supera 5% durante 10m."
          runbook_url: "https://runbooks.example.com/api/high-error-rate"
```

Campos clave:

- `expr`: una PromQL **booleana** (devuelve series cuando la condicion es cierta).
- `for`: cuanto tiempo debe mantenerse cierta para pasar de `pending` a `firing`. Evita flaps por un unico scrape anomalo.
- `labels`: adjuntas a la alerta; **el routing en Alertmanager se decide sobre estas labels**.
- `annotations`: texto libre (templates Go) para humanos: `summary`, `description`, `runbook_url`.

**Estados de una alerta**: `inactive` → `pending` (`expr` true pero `for` sin cumplirse) → `firing` (notificable). Si `expr` deja de ser true, vuelve a `inactive` y Prometheus envia **resolved** a Alertmanager (que lo propaga segun receiver).

---

## 2. Reglas de alerta vs recording rules

Mismo contenedor (`groups`/`rules`) pero semanticas distintas:

| | Recording rule | Alerting rule |
|---|---|---|
| Clave | `record:` | `alert:` |
| Resultado | nueva serie en TSDB | eventos a Alertmanager |
| Costo | storage extra | sin storage; evaluacion |
| Uso | pre-computo para dashboards/alertas | notificar humanos |

Patron habitual: la expresion compleja se **pre-calcula** como recording rule (`job:http_errors:ratio5m`) y la regla de alerta queda legible:

```yaml
- alert: HighErrorRate
  expr: job:http_errors:ratio5m{job="api"} > 0.05
  for: 10m
```

Se tratan a fondo en `obs-10`.

---

## 3. `promtool test rules`: tests unitarios para alertas

`promtool` (parte de la distribucion Prometheus) permite escribir **series sinteticas** y afirmar que una alerta dispara en el momento esperado. Es la unica forma seria de evitar que una regla "funcione en mi laptop" y luego no dispare en prod.

Formato del fichero de test:

```yaml
# tests.yaml
rule_files:
  - alerts.yaml

evaluation_interval: 1m

tests:
  - interval: 1m
    input_series:
      - series: 'http_requests_total{job="api",status="500"}'
        values: '0 60 120 180 240 300 360 420 480 540 600 660'
      - series: 'http_requests_total{job="api",status="200"}'
        values: '0 10 20 30 40 50 60 70 80 90 100 110'

    alert_rule_test:
      - eval_time: 11m
        alertname: HighErrorRate
        exp_alerts:
          - exp_labels:
              severity: page
              team: platform
              job: api
            exp_annotations:
              summary: "API 5xx rate >5% (10m)"
```

Ejecucion:

```bash
promtool test rules tests.yaml
```

Devuelve `SUCCESS` o un diff claro. Es el equivalente a `pytest` para reglas de alerta.

Notas:

- `values:` acepta notacion expandida (`'0+60x11'` = 0, 60, 120 ...).
- `eval_time` debe ser `>=` tiempo cuando se cumple `for`.
- Se puede testear que una alerta **no** dispare: `exp_alerts: []`.

---

## 4. Alertmanager: por que existe y que hace

Prometheus **no** envia emails. Al disparar una alerta, hace `POST /api/v2/alerts` a uno o varios Alertmanagers. Alertmanager asume toda la logica de notificacion:

1. **Deduplicacion**: multiples Prometheus (HA) mandan la misma alerta; Alertmanager dedup por labels.
2. **Grouping**: agrupa alertas relacionadas en una notificacion.
3. **Inhibition**: suprime alertas B cuando A esta activa.
4. **Silences**: silencia manualmente (ventanas de mantenimiento).
5. **Routing**: enruta cada alerta al receiver correcto.
6. **Notify**: entrega a email/slack/pagerduty/webhook/...

Vive separado de Prometheus porque: (a) debe ser HA independiente, (b) sobrevive a reinicios de Prometheus, (c) una sola instancia agrega alertas de varios Prometheus.

---

## 5. Route tree: enrutamiento por labels

El `route:` de `alertmanager.yml` es un **arbol**. La raiz es el default; los `routes:` hijos son filtrados por `matchers:` y pueden anidar mas rutas.

```yaml
route:
  receiver: default-slack
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - matchers:
        - severity="page"
      receiver: pagerduty-oncall
      continue: true          # tambien evalua rutas siguientes
    - matchers:
        - team="platform"
      receiver: platform-slack
    - matchers:
        - team="payments"
      receiver: payments-slack
      routes:
        - matchers: [severity="page"]
          receiver: payments-pagerduty
```

Reglas:

- La **primera coincidencia** gana (DFS). `continue: true` permite seguir evaluando hermanos para fan-out.
- Los hijos **heredan** `group_by`, `group_wait`, etc. salvo override explicito.
- `matchers:` acepta `=`, `!=`, `=~`, `!~` (regex con anchoring implicito).

Diseno practico: una ruta por **equipo**, sub-ruta por **severidad**. Evitar arboles profundos (>3 niveles).

---

## 6. Grouping: `group_by`, `group_wait`, `group_interval`, `repeat_interval`

Grouping es el mecanismo que evita que una incidencia en 50 pods genere 50 mensajes.

- `group_by: ['alertname', 'cluster']` — colapsa en una sola notificacion las alertas que comparten estos labels. Un grupo distinto por combinacion.
- `group_wait: 30s` — tras **la primera** alerta de un grupo nuevo, espera N segundos antes de notificar (permite que lleguen las otras).
- `group_interval: 5m` — minimo entre notificaciones **de updates** al mismo grupo (nueva alerta en el grupo, o resolved).
- `repeat_interval: 4h` — si el grupo sigue firing, re-envia cada N (recordatorio).

Elegir numeros razonables:

| Severidad | `group_wait` | `group_interval` | `repeat_interval` |
|-----------|--------------|------------------|-------------------|
| page      | 10–30s       | 5m               | 1–4h              |
| ticket    | 1m           | 10m              | 12h               |
| info      | 2m           | 30m              | 24h               |

`group_by: ['...']` incluir **siempre** `alertname` y los labels de scope (cluster, namespace, service). **Nunca** incluir labels de alta cardinalidad (`instance`, `pod`) porque fragmenta en N grupos.

Caso especial: `group_by: [...]` + `'...'` como string unico `'...'` desactiva agrupacion y envia uno por alerta — usar solo para pruebas.

---

## 7. Inhibition: silenciar efectos cuando la causa es conocida

Patron: cuando un nodo cae, caen tambien N targets de ese nodo. Queremos **una** pagina (NodeDown), no N+1.

```yaml
inhibit_rules:
  - source_matchers:
      - alertname="NodeDown"
    target_matchers:
      - alertname="TargetDown"
    equal: ['node']           # misma label 'node' en source y target
```

Lectura: *si existe una alerta activa `NodeDown` con cierto `node=X`, suprime cualquier `TargetDown` con `node=X`*.

Reglas:

- `equal:` **debe** compartirse entre source y target; de otro modo nunca empareja.
- La inhibicion solo aplica mientras la source siga **firing** en Alertmanager (incluyendo tiempo de notificacion). Si se resuelve, los targets vuelven a notificar.
- No cambia estado en Prometheus — las alertas target siguen `firing` en el UI de Prometheus; Alertmanager solo decide **no notificarlas**.

Casos tipicos:

- `ClusterDown` inhibe `KubeNodeNotReady`, `KubePodNotReady`, etc.
- `DatabaseDown` inhibe `AppHighErrorRate` en apps que dependen de esa DB.
- Severidad: `severity="critical"` inhibe `severity="warning"` del mismo `alertname`+`service`.

---

## 8. Silences: ventanas temporales

Silence = suprimir **manualmente** notificaciones durante una ventana. Se crea via UI de Alertmanager o `amtool`:

```bash
amtool silence add alertname=HighErrorRate team=payments \
  --duration=2h \
  --author="ana" \
  --comment="Deploy ventana, 10:00-12:00"
```

- Matchers con la misma gramatica que el route tree.
- Scope temporal estricto; expiran solas.
- Visibles para toda la organizacion (auditables).

Anti-patron: silences perpetuos ("silence this for 10 years"). Si una alerta no debe disparar nunca, borrarla o cambiar su `expr`.

---

## 9. Receivers: email, slack, webhook, pagerduty, msteams, opsgenie

Cada receiver se define una vez en `receivers:` y se referencia desde `route:`.

```yaml
receivers:
  - name: default-slack
    slack_configs:
      - api_url_file: /etc/alertmanager/secrets/slack_webhook
        channel: '#alerts-default'
        send_resolved: true
        title: '{{ template "slack.title" . }}'
        text: '{{ template "slack.text" . }}'

  - name: pagerduty-oncall
    pagerduty_configs:
      - routing_key_file: /etc/alertmanager/secrets/pagerduty_key
        severity: '{{ .CommonLabels.severity }}'

  - name: team-webhook
    webhook_configs:
      - url: http://ticket-bot:8080/alert
        send_resolved: true
```

Buenas practicas:

- **Secretos fuera del YAML**: usar `*_file` (soportado para `api_url`, `routing_key`, `bearer_token`, etc.) y montar como secret.
- `send_resolved: true` para que el receiver sepa cuando dejar de preocuparse.
- Plantillas custom en `templates:` para formatear mensajes consistentes (titulo con `[severity]`, link al runbook y al dashboard).
- Validar con `amtool check-config alertmanager.yml`.

---

## 10. Diseno sobre sintomas, no causas (SLO/user-impact)

**Google SRE** lo resume: *paginar solo cuando un humano debe actuar ya, para proteger a los usuarios*.

- **Sintoma** = algo que el usuario nota: error rate, latencia, disponibilidad del endpoint.
- **Causa** = algo interno: CPU alta, cola de 1000 mensajes, un pod en `CrashLoopBackOff`.

Alertar sobre sintomas:

- Pros: menos alertas, mejor senial/ruido, mapea 1:1 con SLO.
- Contras: a veces menos accionable sin contexto; mitigar con buenos runbooks y dashboards vinculados.

Alertar sobre causas:

- Solo cuando (a) la causa predice un sintoma inminente (**disco lleno en 1h**) y (b) requiere accion humana.
- Nunca alertar CPU alta por si misma. Alta CPU + latencia OK = no es un problema.

**SLO-based alerts (burn-rate)**: multi-window multi-burn-rate reduce drasticamente el ruido. Pagina solo si se quema **mucho** error budget **rapido** (ventanas 1h/5m y 6h/30m combinadas). Se tratan a fondo en `obs-14`; aqui basta con conocer el concepto y preferirlo sobre thresholds planos.

---

## 11. Alert fatigue y antidotos

**Sintomas de fatigue**:

- Mas de ~5 pages/semana por on-call.
- Alertas que se silencian con `amtool silence` cada semana.
- "No la mires, siempre dispara en los deploys".
- Alertas sin runbook o con runbook "si pasa, llamar a Juan".

**Antidotos** aplicables en orden:

1. **Borrar** las no accionables. Si nadie actua, no es alerta — es grafana.
2. **Agrupar** con mejor `group_by` y `group_wait` adecuado.
3. **Inhibir** cascadas con `inhibit_rules`.
4. **Subir el `for`** para absorber flaps breves.
5. **Reescribir sobre sintomas** (SLO/burn-rate) en vez de causas.
6. **Reducir severidad** a `ticket`/`info` si no requiere accion inmediata.
7. **Postmortems** cada alerta despertando: si no deberia haber despertado, cambiar la alerta.

Checklist antes de hacer merge de una alerta nueva:

- [ ] Tiene `for` > 0 (salvo criticos tipo "down").
- [ ] Tiene `severity`, `team`.
- [ ] Tiene `summary`, `description`, `runbook_url`.
- [ ] El runbook existe y describe que hacer **ahora**.
- [ ] Esta cubierta por un test `promtool test rules`.
- [ ] Si es causa, se justifica por que es un predictor fiable.

---

## 12. Operacion y troubleshooting

- **Reload**: `kill -HUP $(pidof alertmanager)` o `curl -X POST localhost:9093/-/reload`. Prometheus igual: `/-/reload`. Config invalida → log + mantiene la anterior.
- **Validacion offline**: `amtool check-config alertmanager.yml`, `promtool check rules alerts.yaml`.
- **Test de routing**: `amtool config routes test severity=page team=platform` imprime a que receiver iria sin notificar.
- **Observabilidad del propio Alertmanager**: scrapear `alertmanager:9093/metrics`. Series utiles:
  - `alertmanager_notifications_total{integration,status}` — exito/fallo por canal.
  - `alertmanager_notifications_failed_total` — para alertar sobre el que alerta (meta-alerting).
  - `alertmanager_alerts{state="active"|"suppressed"}` — tamanio del backlog.
- **HA**: Alertmanager soporta cluster gossip (`--cluster.peer=...`); garantiza una sola notificacion aun con 2–3 Alertmanagers.
- **Troubleshooting flujo end-to-end**:
  1. Prometheus `/alerts` muestra `firing`? Si no, la regla no dispara (query, `for`).
  2. Prometheus `/status/runtimeinfo` → `Alertmanagers` listados y healthy?
  3. Alertmanager `/#/alerts` muestra la alerta?
  4. `amtool config routes test ...` dice a que receiver va?
  5. Receiver recibe? Mirar `alertmanager_notifications_failed_total`.

---

## Cierre

En este modulo pasas de **saber escribir una query** a **tener un sistema de alertas que la organizacion puede sostener**. Las dos actividades hacen esto concreto: la primera (guided-lab) te lleva de 0 a una regla con tests `promtool`; la segunda (independent) te obliga a tomar decisiones duras — tirar alertas, agrupar, inhibir — hasta llegar a un set de 5 alertas SLO-based con justificacion escrita.
