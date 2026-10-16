# Actividad 01 — Umbrella chart para dev local (app + Postgres)

## 1. Identificación

- **ID:** `helm-06-01-umbrella-for-dev-stack`
- **Tecnología:** `helm`
- **Módulo:** `helm-06-dependencies-and-umbrella-charts`
- **Dificultad:** intermediate
- **Duración estimada:** 50–70 min
- **Tipo:** guided-lab

## 2. Contexto

El equipo quiere que **un solo `helm install`** levante la app + la DB para desarrollo local. En producción la DB es RDS, así que el chart debe funcionar **también** sin Postgres como subchart.

Vas a convertir el chart `fastapi-app` del starter en un umbrella *dual-mode*: con `db.enabled=true` levanta Postgres como subchart; con `db.enabled=false` (default) deja la conexión a cargo de un servicio externo.

## 3. Objetivos

- Añadir `bitnami/postgresql` como dependencia condicional.
- Generar y commitear `Chart.lock` con versión pinneada exacta (`18.12.4`).
- Diseñar `values-dev.yaml` y `values-prod.yaml` que activen/desactiven el subchart.
- Verificar vía `helm template` que el render con dev incluye `StatefulSet` y con prod no.

## 4. Prerrequisitos

- Helm ≥ 3.14 (probado con 4.3.1).
- **Internet** para resolver `bitnami/postgresql` la primera vez.
- `bash` moderno, `awk`.
- **Costos**: ninguno (solo render local; no se instala en cluster).

## 5. Instrucciones

### 5.1 Preparar el entorno

```bash
cd /tmp
rm -rf helm06-act01
mkdir helm06-act01 && cd helm06-act01
cp -R <ruta-al-starter>/fastapi-app .
cd fastapi-app
```

El starter contiene:

```
fastapi-app/
├── Chart.yaml          # SIN dependencies aún
├── values.yaml         # defaults, sin bloque db
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    └── _helpers.tpl
```

### 5.2 Añadir la dependencia

Edita `Chart.yaml` y añade un bloque `dependencies:` con:

- `name: postgresql`
- `version: "18.12.4"` (versión exacta, no rango).
- `repository: https://charts.bitnami.com/bitnami`
- `alias: db` (queremos consumir los valores bajo `.Values.db.*`).
- `condition: db.enabled`

### 5.3 Resolver y commitear el lock

```bash
helm dependency update
```

Esto crea `charts/postgresql-18.12.4.tgz` y escribe `Chart.lock`. Ambos ficheros deberían commitearse normalmente (en esta actividad solo nos interesa que `Chart.lock` exista con la versión correcta).

### 5.4 Diseñar `values.yaml` (default = seguro)

Al final de `values.yaml`, añade:

```yaml
db:
  enabled: false
  auth:
    username: appuser
    password: dev-only-not-a-real-secret
    database: appdb
  primary:
    persistence:
      enabled: false
```

Default `false` porque **producción es el default** y en producción no queremos levantar un Postgres en el cluster.

### 5.5 Crear `values-dev.yaml`

```yaml
# dev: levantamos la DB como subchart
db:
  enabled: true
```

### 5.6 Crear `values-prod.yaml`

```yaml
# prod: la DB es externa (RDS). No instalamos subchart.
db:
  enabled: false
```

### 5.7 Validar manualmente

```bash
# Debe aparecer StatefulSet (postgres):
helm template demo . -f values-dev.yaml  | awk '/^kind:/{print $2}' | sort -u

# NO debe aparecer StatefulSet:
helm template demo . -f values-prod.yaml | awk '/^kind:/{print $2}' | sort -u
```

### 5.8 Ejecutar los tests

```bash
bash <ruta-a-la-actividad>/tests/validate.sh /tmp/helm06-act01/fastapi-app
```

## 6. Resultado esperado

- `Chart.yaml` declara una dependencia a `postgresql` versión exacta `18.12.4`, con `alias: db` y `condition: db.enabled`.
- `Chart.lock` existe y pinnea `18.12.4`.
- `values.yaml` tiene `db.enabled: false` por defecto.
- `values-dev.yaml` activa `db.enabled: true`.
- `values-prod.yaml` deja `db.enabled: false`.
- `helm template -f values-dev.yaml` genera `StatefulSet`.
- `helm template -f values-prod.yaml` **no** genera `StatefulSet`.
- `tests/validate.sh` termina con `RESULT: 6/6 checks OK`.

## 7. Criterios de aceptación

- **Funcional**: los dos renders se comportan como se describe.
- **Reproducibilidad**: `Chart.lock` fija versión exacta; sin él la actividad no se considera entregada.
- **Seguridad**: `password` en `values.yaml` es un placeholder visible y claramente dummy. No reusar en entornos reales.
- **Mantenibilidad**: el chart sigue siendo instalable sin la DB (prod default); no se introducen `templates/` que asuman la DB sin un `{{- if .Values.db.enabled }}`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/helm06-act01/fastapi-app
```

Comprueba:

1. `Chart.yaml` tiene `dependencies:` con `postgresql`.
2. La versión declarada es `18.12.4` exacta (sin `^` ni `~`).
3. `Chart.lock` existe y contiene `version: 18.12.4`.
4. `values.yaml` tiene `db.enabled: false` por defecto.
5. `helm template -f values-dev.yaml` genera al menos un `StatefulSet`.
6. `helm template -f values-prod.yaml` **no** genera `StatefulSet`.

## 9. Preguntas de reflexión

1. ¿Por qué `db.enabled: false` como **default**, y no `true`?
2. Si cambias `version: "18.12.4"` por `"^18.0.0"` y vuelves a hacer `helm dependency update` dentro de 6 meses, ¿qué puede pasar?
3. ¿Qué le añadirías a `values-prod.yaml` para apuntar la app a una DB externa? ¿Dónde iría ese dato (en `values` o en un `Secret` del cluster)?
4. Si el equipo de datos opera Postgres por separado, ¿seguirías usando este umbrella para prod? Justifica.

## 10. Extensiones

- Añade `redis` como segunda dependencia con `condition: cache.enabled`.
- Usa `global.imageRegistry` para forzar un mirror interno en todos los subcharts.
- Importa `auth.existingSecret` del subchart al padre con `import-values`.

## 11. Limpieza

```bash
rm -rf /tmp/helm06-act01
```
