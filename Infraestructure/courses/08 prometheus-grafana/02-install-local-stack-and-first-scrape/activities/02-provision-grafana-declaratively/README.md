# obs-02-02 — Provision Grafana declaratively

## 1. Identificación
- **ID:** `obs-02-02-provision-grafana-declaratively`
- **Tecnología:** prometheus-grafana
- **Módulo:** 02-install-local-stack-and-first-scrape
- **Dificultad:** beginner
- **Duración estimada:** 75 min
- **Tipo:** independent

## 2. Contexto

En el laboratorio anterior configuraste Grafana a mano (o lo dejaste tal cual). Al primer `docker compose down -v` todo eso se pierde. En proyectos reales, datasources y dashboards se **declaran como código** y Grafana los materializa al arrancar.

Tu misión: completar el starter para que al primer `up -d`, Grafana ya tenga:

1. El datasource **Prometheus** apuntando a `http://prometheus:9090`, con `uid: prometheus` y marcado como `isDefault: true, editable: false`.
2. Un **provider de dashboards** `type: file` que lee JSON desde `/var/lib/grafana/dashboards`.
3. Un **dashboard JSON** con `uid: obs02-overview` y al menos un panel que grafica `up` (indicando qué targets están UP).

No vas a tocar la UI de Grafana para configurar nada: solo para *ver* que apareció.

## 3. Objetivos
- Declarar el datasource Prometheus vía provisioning YAML.
- Declarar un provider file-based y versionar un dashboard JSON.
- Verificar vía API que ambos aparecen marcados como *provisioned*.
- Comprobar reproducibilidad: `down -v && up -d` → mismo estado, sin clics.

## 4. Prerrequisitos
- `obs-02-01` completado.
- Docker Desktop o Engine con `docker compose` v2.
- Puertos libres: `9090`, `3000`.
- `curl` y `bash`.
- Costos: ninguno (todo local).

## 5. Instrucciones (no revelan la solución)

El starter contiene:

```
starter/
├── compose.yaml                    # ya monta ./grafana/provisioning y ./grafana/dashboards (lee-only)
├── prometheus/
│   └── prometheus.yml              # correcto
└── grafana/
    ├── provisioning/
    │   ├── datasources/            # VACIO — ponga aqui el YAML del datasource
    │   └── dashboards/             # VACIO — ponga aqui el YAML del provider
    └── dashboards/                 # VACIO — ponga aqui el JSON del dashboard
```

Pasos sugeridos:

1. Copia el starter a `/tmp`:
   ```
   rm -rf /tmp/obs-02-02 && mkdir -p /tmp/obs-02-02
   cp -R starter/. /tmp/obs-02-02/
   cd /tmp/obs-02-02
   ```
2. Crea `grafana/provisioning/datasources/datasource.yml` con `apiVersion: 1` y una entrada que registre el datasource Prometheus. Pistas:
   - La URL correcta es la del servicio en la red de Compose, no `localhost`.
   - `uid` fija: `prometheus`. El dashboard lo referenciará por ese UID.
   - `editable: false` evita que la UI reescriba la fuente de verdad.
3. Crea `grafana/provisioning/dashboards/dashboards.yml` con un provider `type: file` que apunte a `/var/lib/grafana/dashboards` (ese es el *path dentro del contenedor*, el host monta `./grafana/dashboards` ahí).
4. Crea un dashboard JSON en `grafana/dashboards/` con:
   - `uid: obs02-overview`
   - `title: obs-02 — Overview`
   - Al menos un panel con la query `up` y un valor por target.
   
   Puedes partir de uno que armaste manualmente en Grafana (exportar en *Dashboard settings → JSON Model*). Asegúrate de que `datasource.uid` dentro del panel sea `prometheus`.
5. Levanta el stack:
   ```
   docker compose up -d
   ```
6. Verifica manualmente:
   ```
   curl -fsS -u admin:admin http://localhost:3000/api/datasources | grep -o '"uid":"prometheus"'
   curl -fsS -u admin:admin http://localhost:3000/api/search?query=obs-02
   ```
7. Prueba de reproducibilidad:
   ```
   docker compose down -v && docker compose up -d
   ```
   Y vuelve a correr los curls del paso 6. Deberían dar el mismo resultado sin que hayas hecho ningún clic.
8. Corre el validador:
   ```
   bash activities/02-provision-grafana-declaratively/tests/validate.sh
   ```

## 6. Resultado esperado

- `GET /api/datasources` lista una entrada con `uid: prometheus` y `type: prometheus`.
- `GET /api/search?query=obs-02` lista al menos un dashboard con `uid: obs02-overview`.
- `GET /api/datasources/uid/prometheus` responde `200` y confirma el datasource.
- `down -v && up -d` deja el estado idéntico.

## 7. Criterios de aceptación

- **Funcionalidad:** validador verde.
- **Calidad:** `editable: false` en el datasource; `allowUiUpdates: false` en el provider.
- **Seguridad:** no commiteaste nunca passwords de Grafana más allá del `admin/admin` de demo (explícito como tal). El starter tampoco.
- **Reproducibilidad:** `down -v && up -d` lleva al mismo estado.
- **Mantenibilidad:** cada archivo tiene un propósito único y claro; nada mágico.

## 8. Validación

```
bash activities/02-provision-grafana-declaratively/tests/validate.sh
```

Variables:
- `BASE_DIR` (default `/tmp/obs-02-02`).
- `USE_SOLUTION=1`: el validador levanta `solution/` en un project aislado y lo tumba al terminar.

## 9. Preguntas de reflexión
- ¿Qué pasaría si cambias `uid: prometheus` del datasource pero el dashboard sigue referenciando `prometheus`? ¿Cómo lo detectarías?
- Si editaras un panel en la UI y pulsaras *Save*, ¿qué ofrece Grafana? ¿Por qué?
- ¿Qué cambios serían necesarios para versionar también una **alerta** desde `provisioning/alerting/`?

## 10. Extensiones
- Añade un segundo dashboard en una **carpeta** separada (`foldersFromFilesStructure: true` y mete el JSON en `grafana/dashboards/infra/`).
- Añade un segundo datasource de prueba (p. ej. `TestData DB`) y haz que el dashboard lo use en un panel adicional.
- Mete los dashboards en un **ConfigMap** generado desde los mismos JSON (anticipo de obs-12).

## 11. Limpieza

```
cd /tmp/obs-02-02
docker compose down -v
cd -
rm -rf /tmp/obs-02-02
```
