# helm-05-01 — Env overrides (dev / stg / prod)

## 1. Identificación
- **ID:** `helm-05-01-env-overrides-dev-stg-prod`
- **Tecnología:** helm
- **Módulo:** 05-values-precedence-and-child-charts
- **Dificultad:** intermediate
- **Duración estimada:** 50 min
- **Tipo:** guided-lab

## 2. Contexto
Un equipo despliega el mismo chart `mychart` en tres entornos: `dev`, `stg`, `prod`. Los defaults son dev-ish (1 replica, `debug`), prod necesita 5 replicas, `info`, y recursos reales, y staging está "entre" los dos. El reto es diseñar `values-{dev,stg,prod}.yaml` **simétricos y mínimos** (ninguno reescribe lo que no cambia).

## 3. Objetivos
- Separar los defaults seguros en `values.yaml`.
- Escribir tres archivos de override, uno por entorno, cada uno **solo** con las claves que difieren.
- Verificar que `helm template` produce el ConfigMap esperado para cada entorno.
- Demostrar que `--set` sobre un pipeline (p. ej. `image.tag`) **gana** al override de entorno.

## 4. Prerrequisitos
- Conocimientos: módulos `helm-03` y `helm-04` completados; lectura de `theory/lesson.md` secciones §2–§5.
- Software: `helm` v3.12+ o v4.x.
- Dependencias: ninguna (todo local, sin cluster).
- Variables de entorno: ninguna.
- Permisos / cuentas: ninguno.
- Infraestructura: ninguna.
- **Costos potenciales:** 0 USD.

## 5. Instrucciones

1. Copiar `starter/mychart/` a tu workspace y examinar `templates/configmap.yaml`. Verás que renderiza las claves `replicas`, `logLevel`, `image.repository`, `image.tag`, `resources.requests.memory`.
2. Completar `starter/mychart/values.yaml` como defaults razonables (dev-ish): `replicas: 1`, `logLevel: debug`, `image.repository: ghcr.io/acme/myapp`, `image.tag: 0.0.0-dev`, `resources.requests.memory: 64Mi`.
3. Crear `values-dev.yaml` — **mínimo**: solo debería contener lo que NO sea igual al default. Si todo coincide, el archivo puede quedar prácticamente vacío (con un comentario explicando que es intencional).
4. Crear `values-stg.yaml` con: `replicas: 2`, `logLevel: info`, `resources.requests.memory: 128Mi`. (No tocar la imagen.)
5. Crear `values-prod.yaml` con: `replicas: 5`, `logLevel: info`, `image.tag: 1.0.0`, `resources.requests.memory: 256Mi`.
6. Validar cada entorno:
   ```bash
   helm template demo ./mychart -f mychart/values-dev.yaml
   helm template demo ./mychart -f mychart/values-stg.yaml
   helm template demo ./mychart -f mychart/values-prod.yaml
   ```
7. Simular un pipeline que fija `image.tag`:
   ```bash
   helm template demo ./mychart -f mychart/values-prod.yaml --set image.tag=1.2.3
   ```
   Observar que `image.tag` ganó al override de prod.
8. Ejecutar `bash tests/validate.sh` desde el directorio de la actividad. Debe reportar `All 4 scenarios OK`.

## 6. Resultado esperado
- `mychart/values.yaml` con defaults completos.
- `mychart/values-dev.yaml`, `values-stg.yaml`, `values-prod.yaml` **mínimos**.
- `helm template` para cada entorno produce un ConfigMap con los valores esperados (ver §8).
- `tests/validate.sh` termina con exit code 0.

## 7. Criterios de aceptación
- **Funcionalidad:** los 4 escenarios del validador pasan.
- **Calidad:** `values-dev.yaml` NO tiene más de 3 claves (dev == defaults). Si tiene más, el contrato está mal diseñado.
- **Seguridad:** ningún secret en los values.
- **Reproducibilidad:** `helm template` sin acceso a cluster es suficiente para validar.
- **Mantenibilidad:** los overrides pueden leerse de un vistazo y entender qué cambia por entorno.

## 8. Validación
```bash
bash tests/validate.sh
```

Internamente ejecuta cuatro `helm template` (defaults, dev, stg, prod) y verifica:
- defaults → `replicas: "1"`, `logLevel: "debug"`
- dev     → `replicas: "1"`, `logLevel: "debug"`
- stg     → `replicas: "2"`, `logLevel: "info"`, `memory: "128Mi"`
- prod    → `replicas: "5"`, `image.tag: "1.0.0"`, `memory: "256Mi"`
- Y adicionalmente que `--set image.tag=1.2.3` gane sobre prod.

El validador apunta a `starter/mychart` **por default** (donde el estudiante trabaja). Para apuntar al `solution/`, exportar `CHART_DIR`:
```bash
CHART_DIR=solution/mychart bash tests/validate.sh
```

## 9. Preguntas de reflexión
- ¿Por qué `values-dev.yaml` queda casi vacío? ¿Qué pasaría si el equipo decide "cambiar los defaults a prod-ish"?
- ¿Qué fallaría si en `values-prod.yaml` se olvida la clave `image.tag` y el pipeline tampoco la pasa?
- ¿En qué situaciones es mejor tener `values-prod-us.yaml` y `values-prod-eu.yaml` adicionales en vez de un solo prod?
- Si `resources.requests.memory` fuera una lista en vez de un escalar, ¿qué cambiaría en el merge?

## 10. Extensiones
1. Añadir un `values.schema.json` que exija `logLevel` ∈ {`debug`,`info`,`warn`,`error`}. Probar que un valor inválido falla el `helm template`.
2. Añadir un override `--set` por línea de comando que fuerce `logLevel=warn` en prod y confirmar que gana.
3. Agregar una lista `env:` al ConfigMap y observar qué pasa cuando un override "añade" un elemento (spoiler: lo *reemplaza*).

## 11. Limpieza
Esta actividad no toca ningún cluster. Para limpiar los temporales del validador:
```bash
rm -rf /tmp/helm-05-01-*
```
