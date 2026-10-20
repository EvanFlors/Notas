# Ejemplo 02 — Grafana provisioning (datasource + dashboard declarativos)

## Concepto que demuestra

En producción nadie configura Grafana "a mano" por la UI. **Datasources y dashboards se declaran como YAML/JSON en Git** y Grafana los materializa al arrancar leyendo `/etc/grafana/provisioning/`.

Este ejemplo levanta el mismo stack del ejemplo 01, pero:

- El **datasource Prometheus** ya está creado al primer login (y marcado como `editable: false`).
- Un **dashboard** `obs-02 — Targets overview` ya aparece en la lista, mostrando el estado de los targets (`up`) y uso de CPU, sin ningún clic.

## Archivos

```
02-grafana-provisioning/
├── README.md
├── compose.yaml
├── prometheus/
│   └── prometheus.yml
└── grafana/
    ├── provisioning/
    │   ├── datasources/
    │   │   └── datasource.yml
    │   └── dashboards/
    │       └── dashboards.yml       # provider que lee JSON desde /var/lib/grafana/dashboards
    └── dashboards/
        └── targets-overview.json    # el dashboard en sí
```

## Puntos clave de la configuración

### `provisioning/datasources/datasource.yml`

- `uid: prometheus` — importante: el JSON del dashboard referencia *este* UID, no el nombre.
- `editable: false` — bloquea la edición desde la UI.
- `isDefault: true` — ahorra tener que seleccionar el DS en cada panel nuevo.

### `provisioning/dashboards/dashboards.yml`

- Es un **provider** `type: file`: le dice a Grafana "lee cada JSON que haya en `/var/lib/grafana/dashboards`".
- `disableDeletion: true` + `allowUiUpdates: false` → la UI no puede sobreescribir estos dashboards: ante un intento de Save, Grafana ofrece *Save as copy*.
- `updateIntervalSeconds: 30` → Grafana re-lee los JSON cada 30s; si editas el archivo con `vim`, lo verás reflejado en el navegador casi al instante.

### `dashboards/targets-overview.json`

- `uid: obs02-targets-overview` — URL estable (`/d/obs02-targets-overview`).
- Panel 1 (`stat`): `up` con value mappings (0 → DOWN rojo, 1 → UP verde).
- Panel 2 (`timeseries`): CPU usage derivado de `1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m]))`.

## Cómo correrlo

```
cd examples/02-grafana-provisioning
docker compose up -d
curl -fsS http://localhost:9090/-/healthy
curl -fsS http://localhost:3000/api/health

# Verifica que el datasource existe sin tocarlo:
curl -fsS -u admin:admin http://localhost:3000/api/datasources
```

En el navegador:

- `http://localhost:3000/datasources` — "Prometheus" aparece con etiqueta *provisioned*.
- `http://localhost:3000/d/obs02-targets-overview` — el dashboard, con datos reales.

## Qué observar

1. El dashboard aparece sin que hayas tocado la UI. Si editas `targets-overview.json` con un editor y guardas, se refresca solo (hasta 30s).
2. En la UI, intentar editar y guardar el dashboard muestra el aviso "This dashboard is provisioned". Es la señal de que la fuente de verdad vive en el repo.
3. `docker compose down -v` + `up -d` deja todo exactamente igual (datasource + dashboard presentes). **Es la prueba de reproducibilidad**.

## Limpieza

```
docker compose down -v
```
