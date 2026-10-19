# Actividad 02 — Pipeline lineal → DAG con `needs:` y medir wall clock

## 1. Identificación

- **ID:** `gl-04-02-cut-wall-clock-with-needs`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-04-rules-workflow-needs-dag-parallel-matrix`
- **Dificultad:** intermediate
- **Duración estimada:** 75–100 min
- **Tipo:** independent (independiente respecto a la actividad 01)

## 2. Contexto

Tu pipeline actual tiene **6 jobs en 3 stages** y nadie ha mirado si eso es óptimo. Las duraciones son medidas reales de la última semana:

| Job | Stage | Duración | Depende realmente de |
|-----|-------|----------|----------------------|
| `build-amd64` | `build` | 3 min | — |
| `build-arm64` | `build` | 3 min | — |
| `lint` | `test` | 1 min | nada (sólo lee el repo) |
| `unit-tests` | `test` | 5 min | `build-amd64` |
| `integration-tests` | `test` | 4 min | `build-amd64`, `build-arm64` |
| `deploy-stg` | `deploy` | 2 min | `unit-tests` |

Hoy, **sin `needs:`**, el wall clock es:

```
max(build) + max(test) + max(deploy) = 3 + 5 + 2 = 10 min
```

Pero `lint` sigue bloqueado dentro de `test` (1 min esperando 4 min más) y `deploy-stg` espera también a `integration-tests` sin necesitarlo.

Tu encargo: **reescribir el pipeline con `needs:`** respetando las dependencias reales y **justificar la ganancia** de wall clock en un documento corto.

**Importante**: no hay runner real. No se ejecuta nada. El entregable es el YAML + un Markdown con el cálculo.

## 3. Objetivos

Al terminar deberías poder, sin consultar la lección:

- Dibujar en tu cabeza el DAG a partir de la tabla "depende realmente de".
- Reescribir el `.gitlab-ci.yml` con `needs:` en al menos 4 jobs (los que tienen dependencia distinta a "stage anterior entero").
- Usar `needs: []` explícito en el linter.
- Calcular el wall clock del DAG (camino crítico) y compararlo con el lineal.
- Justificar la decisión en un `WALL-CLOCK.md` que un ingeniero externo pueda leer.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (en particular §4 `needs:` y §7 patrones).
- Haber recorrido el `examples/02-dag-with-needs/`.
- Haber completado `gl-02`.
- Herramientas: `bash`, `python3` con **PyYAML**.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gl-04-02
cd /tmp/gl-04-02
```

### 5.2 Escribe `.gitlab-ci.yml`

Debe incluir **exactamente estos 6 jobs** con sus `stage:` originales:

- `build-amd64` (`build`)
- `build-arm64` (`build`)
- `lint` (`test`) — con `needs: []` explícito.
- `unit-tests` (`test`) — con `needs: ["build-amd64"]`.
- `integration-tests` (`test`) — con `needs: ["build-amd64", "build-arm64"]`.
- `deploy-stg` (`deploy`) — con `needs:` apuntando sólo a sus deps reales.

Cada job puede tener un `script:` dummy (`echo` o `sleep` simbólico; no se ejecuta).

### 5.3 Escribe `WALL-CLOCK.md`

Documento corto que debe contener:

1. **Tabla de duraciones** (las de la tabla del enunciado — puedes copiarla).
2. **Wall clock lineal** calculado paso a paso: `max(build) + max(test) + max(deploy)` con las cifras explícitas.
3. **Wall clock DAG** calculado como el **camino crítico** (`build-amd64` → `unit-tests` → `deploy-stg` = 3 + 5 + 2 = 10 min; pero `integration-tests` ya no bloquea a `deploy-stg`, y `lint` ya no bloquea a nada).
4. **Ganancia esperada** si una de las duraciones empeora (p. ej. si `integration-tests` sube a 7 min, el DAG sigue en 10 min; el lineal subiría).
5. Al menos **una decisión** justificada: por qué `deploy-stg` depende sólo de `unit-tests` y no de `integration-tests` (asumiendo que `integration-tests` corre en staging post-deploy, por ejemplo — o justificando lo contrario).

### 5.4 Entregables

```
/tmp/gl-04-02/.gitlab-ci.yml
/tmp/gl-04-02/WALL-CLOCK.md
```

### 5.5 Validación local rápida

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('/tmp/gl-04-02/.gitlab-ci.yml'))"
bash <ruta-repo>/courses/gitlab-cicd/04-rules-workflow-needs-dag-parallel-matrix/activities/02-cut-wall-clock-with-needs/tests/validate.sh /tmp/gl-04-02
```

## 6. Resultado esperado

- `.gitlab-ci.yml` parsea limpio.
- Al menos **4 jobs** tienen `needs:` declarado (incluyendo `needs: []` del linter).
- `WALL-CLOCK.md` compara explícitamente lineal vs DAG con números.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa (`0 issue(s)`).
- **Fidelidad**: los `needs:` reflejan la tabla "depende realmente de". No añadas dependencias falsas.
- **Explicación**: `WALL-CLOCK.md` justifica la ganancia, no sólo la lista.
- **Legibilidad**: alguien que lea el YAML y el Markdown entiende por qué el DAG es mejor **sin** mirar la UI de GitLab.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-04-02
```

El validador comprueba estructura: 6 jobs presentes, al menos 4 con `needs:`, `needs: []` en `lint`, `WALL-CLOCK.md` menciona wall clock y las cifras clave. No ejecuta el pipeline.

## 9. Preguntas de reflexión

1. Si mañana añades un job `security-scan` que depende sólo del repo, ¿con qué `needs:` lo configurarías?
2. ¿Qué pasa si `build-arm64` falla? ¿Qué jobs se saltan? ¿Y si falla `lint`?
3. Si el equipo quiere que `deploy-stg` también espere a `integration-tests`, ¿cuánto subiría el wall clock? ¿Vale la pena?
4. En qué escenario preferirías **no** usar `needs:` aunque el pipeline sea grande?
5. ¿Cómo le explicarías a tu jefe no técnico la diferencia entre "wall clock" y "suma de duraciones de todos los jobs"?

## 10. Extensiones

- Añade una `parallel: matrix:` a `unit-tests` para 2 versiones de Python y recalcula el wall clock.
- Convierte `integration-tests` en un `trigger:` a un child pipeline y discute el impacto.
- Añade `needs:` con `artifacts: true` para pasar el binario de `build-amd64` a `unit-tests`.

## 11. Limpieza

```bash
rm -rf /tmp/gl-04-02
```
