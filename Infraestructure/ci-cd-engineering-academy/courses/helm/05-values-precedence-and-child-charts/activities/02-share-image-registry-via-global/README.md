# helm-05-02 — Share image registry via `global`

## 1. Identificación
- **ID:** `helm-05-02-share-image-registry-via-global`
- **Tecnología:** helm
- **Módulo:** 05-values-precedence-and-child-charts
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto
Una plataforma interna empaqueta dos servicios (`web` y `worker`) como subcharts bajo un chart padre `platform`. Toda la plataforma debe tirar imágenes del **mismo registry** (p. ej. `ghcr.io/acme` por default, `registry.internal` en ambientes air-gapped). Replicar el nombre del registry en el `values.yaml` de cada subchart es un antipatrón: un cambio obliga a tocar N archivos.

La solución correcta es `global.imageRegistry`, el patrón que usan Bitnami, Grafana y la mayoría de los charts maduros.

## 3. Objetivos
- Crear un chart padre `platform` con dos subcharts locales `web` y `worker`.
- Hacer que ambos subcharts resuelvan la imagen final como `{{ .Values.global.imageRegistry }}/<name>:<tag>`.
- Demostrar que un único override `--set global.imageRegistry=...` cambia **ambos** subcharts.
- Entregar un `values-airgapped.yaml` que sobreescriba el registry en una sola clave.

## 4. Prerrequisitos
- Conocimientos: módulos `helm-03` y `helm-04`; teoría §6, §7 del módulo actual.
- Software: `helm` v3.12+ o v4.x.
- Dependencias: ninguna.
- Variables de entorno: ninguna.
- Permisos / cuentas: ninguno.
- Infraestructura: ninguna.
- **Costos potenciales:** 0 USD.

## 5. Instrucciones
Esta actividad es **independiente**: no hay starter con esqueleto completo. Debes diseñar la estructura a partir de la especificación.

Requisitos del entregable:

1. Crear `platform/` con `Chart.yaml` apuntando a dos dependencias locales (`web` y `worker`) en `platform/charts/`.
2. `platform/values.yaml` debe declarar:
   ```yaml
   global:
     imageRegistry: ghcr.io/acme
   ```
   y nada más (ningún default redundante para los subcharts).
3. Cada subchart (`web`, `worker`) debe:
   - Tener su propio `Chart.yaml` y `values.yaml` con `image.name` e `image.tag` locales (por ejemplo `name: web`, `tag: 1.0.0`).
   - Renderizar un `ConfigMap` con una clave `image: "{{ .Values.global.imageRegistry }}/{{ .Values.image.name }}:{{ .Values.image.tag }}"`.
4. Crear `platform/values-airgapped.yaml` que sobreescriba `global.imageRegistry: registry.internal`.
5. Verificar manualmente:
   ```bash
   helm template demo ./platform
   helm template demo ./platform -f platform/values-airgapped.yaml
   helm template demo ./platform --set global.imageRegistry=some.other.io
   ```
   El cambio debe propagarse a los dos subcharts simultáneamente.
6. Ejecutar `bash tests/validate.sh` desde el directorio de la actividad. Por defecto apunta a `./platform` relativo al cwd del test (es decir, el directorio donde está `platform/`). Puedes trabajar en `./platform/` o apuntarlo con `CHART_DIR=/ruta/platform bash tests/validate.sh`.

## 6. Resultado esperado
- Chart padre `platform/` con dos subcharts locales `web` y `worker`.
- `helm template` sin flags produce dos ConfigMaps:
  - `demo-web` con `image: "ghcr.io/acme/web:1.0.0"`.
  - `demo-worker` con `image: "ghcr.io/acme/worker:1.0.0"`.
- `-f platform/values-airgapped.yaml` cambia **ambos** a `registry.internal/...`.
- `--set global.imageRegistry=foo.io` cambia **ambos** a `foo.io/...`.

## 7. Criterios de aceptación
- **Funcionalidad:** los tres escenarios del validador pasan.
- **Calidad:** `platform/values.yaml` NO repite el registry por subchart (nada de `web.image.registry` + `worker.image.registry`).
- **Seguridad:** ningún secreto en los values.
- **Reproducibilidad:** `helm template` sin cluster.
- **Mantenibilidad:** cambiar el registry en todos los subcharts debe requerir editar **una sola línea** de `values.yaml`.

## 8. Validación
```bash
bash tests/validate.sh
```

Verifica:
- Scenario A (defaults): ambos ConfigMaps tienen `image: "ghcr.io/acme/web:1.0.0"` y `.../worker:1.0.0`.
- Scenario B (`values-airgapped.yaml`): ambos cambian a `registry.internal/...`.
- Scenario C (`--set global.imageRegistry=foo.io`): ambos cambian a `foo.io/...`.
- Antipatrón: busca `imageRegistry` repetido debajo de claves `web:` o `worker:` en `platform/values.yaml` y falla si lo encuentra.

Variable de entorno:
```bash
CHART_DIR=/ruta/absoluta/a/platform bash tests/validate.sh
```

## 9. Preguntas de reflexión
- ¿Por qué `global` es la zona correcta para `imageRegistry`? ¿Qué otros valores pondrías allí y cuáles **no**?
- Si un subchart de terceros espera `imageRegistry` en una clave propia (no bajo `global`), ¿cómo adaptarías el padre sin forkear al subchart?
- ¿Qué pasa si el chart padre pone un valor por default pero el subchart también define su propio `global.imageRegistry` en su `values.yaml`? ¿Quién gana?
- Si mañana añades un tercer subchart `scheduler`, ¿cuántos archivos tienes que tocar para que use el mismo registry?

## 10. Extensiones
1. Añadir una condición en cada subchart: si `.Values.global.imageRegistry` es vacío, usar `.Values.image.registry` local como fallback.
2. Añadir `global.imagePullSecrets` y propagarlo a los `imagePullSecrets:` del Pod spec en ambos subcharts.
3. Convertir `platform` en un umbrella real con `helm dependency build` (requiere empaquetar los subcharts a `.tgz` o referenciarlos como `file://`).

## 11. Limpieza
```bash
rm -rf /tmp/helm-05-02-*
```
