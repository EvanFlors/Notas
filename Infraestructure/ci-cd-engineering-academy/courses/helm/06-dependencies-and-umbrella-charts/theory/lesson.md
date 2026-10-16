# helm-06 — Dependencias y umbrella charts (lección)

> 12 secciones. Lee la lección entera antes de tocar los ejemplos.

## 1. Por qué un chart puede depender de otro

Una aplicación real casi nunca es "un solo manifiesto". Un servicio web típico necesita, además de su `Deployment` y `Service`:

- Una base de datos (Postgres, MySQL, Mongo).
- Un sistema de cache o cola (Redis, RabbitMQ, Kafka).
- A veces un ingress controller o cert-manager específico.

Cada uno de esos componentes ya existe como chart maduro (ingress-nginx, bitnami/postgresql, bitnami/redis, strimzi, etc.). Reempaquetarlos a mano es tiempo tirado y una fuente permanente de drift respecto al upstream.

Helm permite declarar que tu chart **depende** de otros charts. En tiempo de empaquetado/instalación, Helm:

1. Resuelve las dependencias contra sus repositorios.
2. Las descarga como `.tgz` dentro de `charts/`.
3. Las renderiza como *subcharts* del chart raíz.

El resultado es **una sola release** que gestiona el ciclo de todos los componentes a la vez. Esa es, al mismo tiempo, la ventaja (dev local trivial) y el riesgo (lifecycles acoplados en producción).

## 2. Declarar dependencias en `Chart.yaml`

En `apiVersion: v2` las dependencias viven en el propio `Chart.yaml`:

```yaml
apiVersion: v2
name: myapp
version: 0.1.0
appVersion: "1.0.0"
type: application

dependencies:
  - name: postgresql
    version: "18.12.4"
    repository: https://charts.bitnami.com/bitnami
    alias: db
    condition: db.enabled
    tags:
      - datastore
    import-values:
      - child: auth
        parent: dbAuth
```

Campos relevantes:

| Campo | Qué significa |
|-------|---------------|
| `name` | Nombre del chart en el repo. |
| `version` | **Versión exacta o rango SemVer** (`"18.12.4"`, `"~18.12.0"`, `"^18.0.0"`). |
| `repository` | URL del repo HTTP o `oci://...` para OCI. Puede ser `file://../local-chart` para un chart hermano. |
| `alias` | Nombre bajo el que se "monta" el subchart (p. ej. llamar `db` a `postgresql`). Permite montar el mismo chart dos veces (primary/replica). |
| `condition` | Clave en `values` que, si es `false`, desactiva el subchart por completo. |
| `tags` | Grupos para activar/desactivar varios subcharts a la vez. |
| `import-values` | "Eleva" valores de un subchart al namespace del padre (ver §7). |

Tras editar `Chart.yaml` hay que ejecutar `helm dependency update` para que Helm resuelva, descargue a `charts/` y actualice `Chart.lock`.

## 3. `helm dependency update` vs `helm dependency build`

Son dos comandos parecidos con una diferencia crítica:

- **`helm dependency update`** — consulta los repositorios, resuelve rangos SemVer **frescos** y **(re)escribe** `Chart.lock`. Es el equivalente a `npm install` sin lockfile o `cargo update`: puede traerte una versión más nueva si tu rango lo permite.
- **`helm dependency build`** — lee `Chart.lock` y descarga **exactamente** esas versiones. Si no hay lock, falla. Es el equivalente a `npm ci`: 100% reproducible.

Regla operativa:

- En desarrollo, cuando añades/subes una dep: `helm dependency update`, revisas el diff de `Chart.lock`, lo commiteas.
- En CI y en imágenes productivas: `helm dependency build`. Nunca `update`.

Si confundes los dos, dos checkouts del mismo repo en instantes distintos pueden traer `.tgz` distintos, con los problemas de "funciona en mi máquina" clásicos.

## 4. `Chart.lock` — el lockfile de Helm

`Chart.lock` es un YAML autogenerado que fija versiones **efectivas** resueltas y un digest del conjunto. Ejemplo:

```yaml
dependencies:
- name: postgresql
  repository: https://charts.bitnami.com/bitnami
  version: 18.12.4
digest: sha256:880bd01ac69e0449924c3a201f7e6022b725b5b269180e537d56e4ec6a0f32fb
generated: "2026-10-15T13:37:53Z"
```

Tres observaciones importantes:

1. El `digest` cubre **el conjunto completo** de versiones resueltas. Un cambio mínimo en cualquiera lo invalida.
2. `Chart.lock` **debe commitearse** al repo de código. Es parte del contrato de reproducibilidad del chart.
3. Si `Chart.yaml` y `Chart.lock` divergen, `helm dependency build` falla con un mensaje tipo `Chart.lock is out of sync with Chart.yaml`. La solución es `helm dependency update` y commitear el nuevo lock.

Igual que con `package-lock.json` o `go.sum`, el lockfile es la frontera entre "mi `Chart.yaml` dice qué quiero" y "mi `Chart.lock` dice qué conseguí".

## 5. `charts/` — dónde viven las dependencias resueltas

Después de `dependency update`, los `.tgz` quedan bajo `charts/`:

```
myapp/
├── Chart.yaml
├── Chart.lock
├── values.yaml
├── charts/
│   └── postgresql-18.12.4.tgz
└── templates/
    └── deployment.yaml
```

Alternativa totalmente offline: en lugar de un repo remoto puedes meter el chart hijo expandido directamente en `charts/mysubchart/`. Helm lo detecta sin necesidad de `dependency update`. Es útil para:

- Charts internos de un monorepo (sin publicar).
- Entornos air-gapped.
- Fijar completamente la versión sin depender de un remoto.

Mezcla no recomendada: no pongas a mano `.tgz` descargados en `charts/` sin actualizar `Chart.lock`; romperás la invariante del lockfile.

## 6. Alias — montar el mismo chart dos veces

Un ejemplo típico: necesitas dos instancias del mismo chart con configuraciones distintas (una DB primaria y una de reporting). `alias:` lo permite:

```yaml
dependencies:
  - name: postgresql
    alias: primary
    version: "18.12.4"
    repository: https://charts.bitnami.com/bitnami
  - name: postgresql
    alias: reporting
    version: "18.12.4"
    repository: https://charts.bitnami.com/bitnami
```

Luego en `values.yaml`:

```yaml
primary:
  auth:
    database: appdb
reporting:
  auth:
    database: reportingdb
  primary:
    enabled: true
```

Dentro del chart raíz, cada subchart recibe sus valores desde su propia clave (`primary.*` o `reporting.*`). El alias se vuelve el *namespace de values* del subchart.

## 7. Compartir valores entre padre e hijos

Dos mecanismos:

- **`global:`** — cualquier cosa bajo `.Values.global` es visible por *todos* los subcharts. Útil para `imageRegistry`, `storageClass`, `imagePullSecrets` o políticas transversales.
- **`import-values`** — "eleva" ciertos valores del hijo al namespace del padre. Útil cuando el padre necesita leer la contraseña generada por el subchart (p. ej. el nombre del Secret de la DB) sin duplicar la estructura.

```yaml
dependencies:
  - name: postgresql
    version: "18.12.4"
    repository: https://charts.bitnami.com/bitnami
    import-values:
      - child: auth           # desde el subchart: .Values.auth
        parent: dbAuth        # en el padre: .Values.dbAuth
```

Regla de higiene: usar `global` para lo verdaderamente transversal (una decisión de la plataforma). Para datos que el padre consume de un hijo específico, `import-values`. Nada más.

## 8. Condicionales — `condition` y `tags`

Dos formas de activar/desactivar subcharts:

```yaml
dependencies:
  - name: postgresql
    version: "18.12.4"
    repository: https://charts.bitnami.com/bitnami
    condition: db.enabled
    tags:
      - datastore
  - name: redis
    version: "20.0.0"
    repository: https://charts.bitnami.com/bitnami
    condition: cache.enabled
    tags:
      - datastore
```

- **`condition`** apunta a una clave de `values`. Si `db.enabled=false`, el subchart no se renderiza ni se instala.
- **`tags`** permite activar/desactivar grupos vía `.Values.tags.datastore=false` (todos los subcharts marcados con ese tag).

Caso canónico: en dev se levanta la DB como subchart; en prod la DB es un servicio gestionado (RDS, Cloud SQL) y `db.enabled=false` apaga el subchart. El `values.yaml` por defecto suele poner `enabled: false` (producción = default seguro) y el entorno de dev lo activa con `-f values-dev.yaml`.

Importante: `condition` **no** sustituye a `if` en los templates propios del padre. Si tu padre tiene recursos que *también* deberían desaparecer cuando la DB está apagada (p. ej. un `ServiceMonitor` para la DB), tienes que envolverlos tú en un `{{- if .Values.db.enabled }}`.

## 9. Umbrella chart vs chart per app

Un **umbrella chart** es un chart cuyo "producto" es la composición: declara varios subcharts, los parametriza y los libera como una sola release. Normalmente el propio umbrella casi no tiene `templates/` propios; es orquestación.

**Umbrella — bueno cuando**:

- Dev local: `helm install dev-stack ./umbrella` levanta app + DB + Redis en un comando.
- Entornos de prueba efímeros (preview environments en CI).
- "Soluciones" cerradas que un cliente despliega de una sola pieza (p. ej. tu propio producto embebido on-prem).
- Un único equipo es dueño de todos los componentes.

**Chart per app — bueno cuando**:

- Equipos distintos operan componentes distintos (SRE opera Postgres; equipo de producto opera la app).
- Cadencia de upgrade distinta por componente (actualizas la app diariamente; la DB una vez al trimestre).
- Blast radius importa: un rollback de la app no debería tocar la DB.
- GitOps con Argo CD/Flux donde cada componente es un `Application`/`HelmRelease` separado.

**El error típico** es replicar en prod lo que funcionó en dev. En dev, una release monolítica es cómoda. En prod, acopla el lifecycle de todo el stack a cada `helm upgrade`, y una ventana de rollback que debería ser quirúrgica se vuelve nuclear.

## 10. Cuándo *no* usar umbrella

Resumen operativo. **No** uses umbrella si cualquiera de estos es cierto:

- El ownership operacional está dividido entre equipos (DB ≠ app).
- Las ventanas de mantenimiento difieren por componente.
- Alguna dependencia es un **servicio gestionado** del cloud (no vive en el cluster).
- Un fallo de upgrade en el componente X no debería forzar rollback de Y.
- El operador manual de prod no tiene permisos sobre todos los componentes.
- Tienes GitOps y cada componente ya está versionado como un `Application` separado.

En esos casos, mantén el umbrella **solo para dev local** (una sola release, cero fricción) y en prod despliega cada componente por separado. El propio chart puede estar diseñado para funcionar en los dos modos: la app por separado, el umbrella como "envoltorio" que la monta junto a sus deps *solo* para dev.

## 11. Versionado de dependencias como código

Las dependencias de un chart se gestionan con el mismo rigor que las dependencias de código:

- **SemVer explícito**: pinea versiones exactas o rangos conservadores (`~18.12.0`, no `^18.0.0`). Un salto de minor en Bitnami puede introducir cambios de template de calado.
- **Lockfile commiteado**: `Chart.lock` siempre en git.
- **Renovación controlada**: usa Renovate/Dependabot para abrir PRs de upgrade de deps; nunca `dependency update` suelto en main.
- **CI reproducible**: en CI siempre `dependency build`, no `update`.
- **Pruebas**: cada bump de dep debe pasar al menos `helm lint` + `helm template` + idealmente `helm install` en un `kind` efímero (`chart-testing`).
- **Changelog**: mantener un CHANGELOG del chart propio que anote cuándo subiste una dep y por qué (igual que un `requirements.txt` con contexto).

Equivale a tratar `Chart.yaml` + `Chart.lock` como el `package.json` + `package-lock.json` del cluster.

## 12. Patrones comunes y antipatrones

**Patrones**:

- **"Dual-mode chart"**: tu chart principal (app) tiene subchart opcional de DB con `condition: db.enabled`. Default `false`. Un `values-dev.yaml` lo activa.
- **Subchart local en `charts/`** para charts internos del monorepo (sin publicar).
- **Umbrella de desarrollo** separado del chart de aplicación: `apps/myapp/chart/` + `apps/myapp/dev-umbrella/` (umbrella que depende del chart propio y de la DB).
- **Un repo OCI interno** (GHCR, ECR) donde publicas tus charts internos y los demás proyectos los consumen con versiones pinneadas.

**Antipatrones**:

- **Umbrella gigante** que incluye la plataforma entera (ingress + cert-manager + DB + apps). Blast radius inmanejable.
- **No commitear `Chart.lock`**. Equivale a no tener lockfile.
- **Rangos SemVer amplios** (`^18.0.0`) sin cultura de renovación controlada. Un día tu CI trae `18.99.0` y rompe prod.
- **Usar `condition` para parchar diseño**: si la app necesita saber si la DB existe o no en runtime (no en render), eso ya no es asunto de Helm, es de la aplicación.
- **Mezclar lifecycles de equipos** vía umbrella sin que los equipos lo acuerden explícitamente. Es la vía rápida al "quién rompió prod" sin respuesta clara.

---

## Preguntas de evaluación

Responde sin consultar la lección:

1. ¿Qué diferencia hay entre `helm dependency update` y `helm dependency build`? ¿Cuál usarías en CI y por qué?
2. ¿Qué pasa si `Chart.lock` y `Chart.yaml` divergen? ¿Cómo se resuelve?
3. Diseña el `dependencies:` de un chart "app + Postgres" donde la DB **solo** se levanta como subchart en dev. ¿Qué defaults pondrías en `values.yaml` y por qué?
4. Dos equipos: el de producto opera `myapp`, el de datos opera Postgres. ¿Umbrella o separados? Argumenta en términos de lifecycle y blast radius.
5. ¿Cuándo *sí* tiene sentido un umbrella chart en producción?
6. ¿Qué problema resuelve `import-values` que no resuelve `global:`?
7. ¿Qué efecto tiene `alias:` sobre el namespace de values de un subchart? Da un ejemplo donde sea imprescindible.
8. Rangos SemVer amplios (`^18.0.0`) en `dependencies:` — ¿cuándo son aceptables y qué disciplina de equipo asumen?
