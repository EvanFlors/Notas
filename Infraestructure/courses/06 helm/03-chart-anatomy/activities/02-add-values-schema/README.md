# helm-03-02 — Añadir `values.schema.json` al chart FastAPI

## 1. Identificación

- **ID:** `helm-03-02-add-values-schema`
- **Tecnología:** helm
- **Módulo:** `03-chart-anatomy`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

Tienes el chart `fastapi-app` de la actividad anterior. `values.yaml` documenta
el contrato en prosa, pero no lo *valida*: un typo (`replicas:` en vez de
`replicaCount:`), un `service.type` inválido, o un `port` fuera de rango se
colarían al render y aparecerían como error oscuro del API server.

En esta actividad **independiente** debes diseñar un `values.schema.json` que
cierre ese hueco. No se te da el schema completo; se te dan los **requisitos**
que debe cumplir y los **casos de prueba** que debe aprobar/rechazar.

## 3. Objetivos

- Añadir `values.schema.json` draft-07 al chart.
- Lograr que todos los casos "felices" sigan pasando `helm template`.
- Lograr que todos los casos "negativos" fallen con mensaje claro.
- Justificar la elección de dónde aplicar `additionalProperties: false`.

## 4. Prerrequisitos

- Haber completado `helm-03-01-chart-for-fastapi` (o reproducir con
  `../01-chart-for-fastapi/solution/run-solution.sh`).
- `helm` ≥ v3.14.
- Sin cluster real; todo con `helm template`.

## 5. Instrucciones

Trabaja en el **mismo chart** generado por la actividad anterior
(`/tmp/helm-03-01/fastapi-app/`). Crea `values.schema.json` en la raíz del chart.

### Requisitos del schema

El schema debe:

1. Ser JSON Schema **draft-07** (`"$schema": "https://json-schema.org/draft-07/schema#"`).
2. Declarar `type: object` en el root.
3. Marcar como **requeridos** en root: `image`, `service`.
4. Para `image`:
   - `type: object`, requerido: `repository`.
   - `repository`: string, `minLength: 1`.
   - `tag`: string (opcional).
   - `pullPolicy`: string, `enum: [Always, IfNotPresent, Never]`.
   - `additionalProperties: false`.
5. Para `service`:
   - `type: object`, requerido: `port`.
   - `type`: string, `enum: [ClusterIP, NodePort, LoadBalancer]`.
   - `port`: integer, `minimum: 1`, `maximum: 65535`.
   - `targetPort`: integer, `minimum: 1`, `maximum: 65535`.
   - `additionalProperties: false`.
6. Para `replicaCount`: integer, `minimum: 1`, `maximum: 50`.
7. Para `resources`: `type: object` (sin restricciones estrictas por ahora;
   `requests` y `limits` libres).
8. Para `probes`: `type: object` con `path: string` (empieza por `/`) y
   `port: integer` (1..65535).
9. En root puedes elegir si poner `additionalProperties: false` o no — ten en
   cuenta que si lo activas, cualquier clave fuera del schema (p. ej. una
   nueva que añadas luego) será rechazada hasta actualizar el schema.

### Casos de prueba

El validator ejecuta los siguientes casos con `helm template demo .`:

**Felices (deben PASAR):**

| # | Flags |
|---|-------|
| H1 | sin flags (defaults) |
| H2 | `--set replicaCount=10` |
| H3 | `--set image.pullPolicy=Always` |
| H4 | `--set service.type=NodePort,service.port=30080` |

**Negativos (deben FALLAR):**

| # | Flags | Debe fallar porque |
|---|-------|--------------------|
| N1 | `--set replicaCount=999` | fuera de rango (max 50) |
| N2 | `--set replicaCount=0` | fuera de rango (min 1) |
| N3 | `--set image.pullPolicy=Yolo` | enum violado |
| N4 | `--set service.type=Mesh` | enum violado |
| N5 | `--set service.port=99999` | fuera de rango (max 65535) |
| N6 | `--set image.repository=""` | minLength 1 |

Si tu schema deja pasar un N o rechaza un H, debes ajustarlo.

### Validar manualmente

```bash
cd /tmp/helm-03-01/fastapi-app
helm template demo .                                         # H1
helm template demo . --set replicaCount=10                   # H2
helm template demo . --set replicaCount=999 2>&1 | tail -3   # N1
```

### Correr el validator

```bash
bash <REPO>/courses/helm/03-chart-anatomy/activities/02-add-values-schema/tests/validate.sh
```

## 6. Resultado esperado

- `values.schema.json` existe en la raíz del chart.
- Los 4 casos felices renderizan sin errores.
- Los 6 casos negativos fallan con mensajes que mencionan la clave inválida.

## 7. Criterios de aceptación

- Schema válido JSON (parseable).
- Root `type: object`.
- `required: ["image", "service"]` en root.
- `image.pullPolicy` restringido por enum.
- `service.type` restringido por enum.
- `replicaCount` acotado 1..50.
- `service.port` acotado 1..65535.

## 8. Validación

```bash
bash tests/validate.sh
# o:
CHART_DIR=/path/to/fastapi-app bash tests/validate.sh
```

Si `helm` no está instalado, el validator solo verifica forma del schema y
hace SKIP de los casos de render (exit 0 con nota).

## 9. Preguntas de reflexión

1. ¿Qué pasa si pones `additionalProperties: false` en el **root** del schema y
   luego Argo CD inyecta un `global:` para subcharts?
2. ¿Dónde no te atreverías a poner `additionalProperties: false` y por qué?
3. ¿Qué información recibe el usuario de un error de schema vs un error de
   render? ¿Cuál es más útil para debugging?
4. ¿Cómo mantendrías sincronizados `values.yaml` y `values.schema.json` cuando
   el chart crece? (adelanto de `helm-05`).

## 10. Extensiones

- Añade `description` a cada propiedad del schema — tu IDE mostrará ayuda.
- Añade `default` a propiedades para documentar valores por default.
- Añade `oneOf` para permitir `image.tag: string` **o** `image.digest: string`
  (uno u otro, no ambos).
- Reemplaza `resources: {type: object}` por un sub-schema estricto que
  verifique `requests.cpu` y `requests.memory` como strings con unidades
  (`^[0-9]+(m|Mi|Gi)?$`).

## 11. Limpieza

```bash
rm -rf /tmp/helm-03-01
```
