# Actividad 01 — Portar una matriz de GHA a GitLab `parallel: matrix:`

## 1. Identificación

- **ID:** `gl-04-01-port-matrix-from-gha`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-04-rules-workflow-needs-dag-parallel-matrix`
- **Dificultad:** intermediate
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab (independiente respecto a la actividad 02)

## 2. Contexto

Tu equipo mantiene una librería Python que soporta **Python 3.11 / 3.12 / 3.13** sobre **linux-x64 / linux-arm64**. Tenéis un workflow de GitHub Actions que corre la matriz y añade **una** combinación extra con `include` (`py=3.13 + os=macos`) y **excluye** una combinación problemática (`py=3.11 + os=linux-arm64`, por un bug viejo de wheels).

La organización ha decidido migrar a GitLab. Te toca portar **ese workflow concreto**, respetando:

1. Mismas combinaciones de tests, ni una más ni una menos.
2. `workflow:` top-level que **no** cree pipeline duplicado cuando hay MR abierto.
3. `rules:` por job equivalente al `if:` del workflow de GHA (correr solo en MR o en `main`).

El workflow origen es este:

```yaml
# .github/workflows/test.yml (origen)
name: tests
on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'tests/**'
      - 'pyproject.toml'
  pull_request:

jobs:
  test:
    if: github.event_name == 'pull_request' || github.ref == 'refs/heads/main'
    strategy:
      fail-fast: false
      matrix:
        py: ["3.11", "3.12", "3.13"]
        os: [linux-x64, linux-arm64]
        include:
          - py: "3.13"
            os: macos
        exclude:
          - py: "3.11"
            os: linux-arm64
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.py }}
      - run: pip install -e .[test]
      - run: pytest -q
```

Combinaciones **efectivas** (6 jobs):

```
(3.11, linux-x64)
(3.12, linux-x64) (3.12, linux-arm64)
(3.13, linux-x64) (3.13, linux-arm64) (3.13, macos)
```

Nota: `(3.11, linux-arm64)` queda **excluida**.

## 3. Objetivos

Al terminar deberías poder, sin consultar la lección:

- Expresar un `strategy.matrix` con `include/exclude` como `parallel: matrix:` **con entradas múltiples** (porque GitLab no tiene `exclude:` nativo).
- Escribir un `workflow:` top-level que resuelva el "doble pipeline" en MR.
- Escribir un `rules:` por job que combine `if:` y `changes:` (equivalente al `paths:` filter de GHA).
- Validar el YAML con `python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))"` antes del commit.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (en particular §2 workflow, §3 rules y §5 parallel matrix).
- Haber recorrido los tres `examples/` del módulo.
- Haber completado `gl-02` (`.gitlab-ci.yml` básico).
- Herramientas: `bash`, `python3` con **PyYAML** instalado (`pip install pyyaml`).

**Costos**: ninguno. Todo local contra archivos YAML.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gl-04-01
cd /tmp/gl-04-01
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `.gitlab-ci.yml`

Debe contener:

1. **`workflow:` top-level** con reglas que:
   - Dejen correr pipelines de MR (`merge_request_event`).
   - Dejen correr push a `main`.
   - **No** creen pipeline duplicado cuando una branch tiene MR abierto.

2. **Un job `test:`** con:
   - `parallel: matrix:` que expanda exactamente las **6 combinaciones** efectivas (no 7, no 5).
   - `tags:` interpolando la variable de la matriz (p. ej. `$OS_TAG`).
   - `image:` interpolando la versión de Python (p. ej. `python:$PY_VERSION`).
   - Un `script:` que ejecute `pytest`.
   - Un bloque `rules:` que combine `if:` (correr en MR o en `main`) y `changes:` para `src/**/*`, `tests/**/*`, `pyproject.toml` (equivalente al `paths:` filter).

### 5.3 Entregable

Un archivo:

```
/tmp/gl-04-01/.gitlab-ci.yml
```

válido YAML, con la estructura descrita.

### 5.4 Validación local rápida

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('/tmp/gl-04-01/.gitlab-ci.yml'))"
bash <ruta-repo>/courses/gitlab-cicd/04-rules-workflow-needs-dag-parallel-matrix/activities/01-port-matrix-from-gha/tests/validate.sh /tmp/gl-04-01
```

## 6. Resultado esperado

- `.gitlab-ci.yml` parsea limpio con PyYAML.
- Expande a **exactamente 6 jobs** cuando se renderiza mentalmente el `parallel: matrix:`.
- `workflow:` contiene al menos las 3 reglas descritas.
- `test:` tiene `rules:` con `if:` y `changes:`.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa (`0 issue(s)`).
- **Equivalencia**: las 6 combinaciones corresponden al `strategy.matrix` origen minus la combinación excluida.
- **Explicitud**: la exclusión se expresa como entradas separadas en `matrix:`, **no** con `rules:` por combinación.
- **Mantenibilidad**: alguien que lea el YAML entiende qué combinaciones corren sin ejecutar nada.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-04-01
```

El validador comprueba **estructura** (claves presentes, 6 combinaciones expandidas, `workflow:` con las reglas pedidas, `rules:` con `if:` y `changes:`), no semántica. Compara tu YAML con `solution/.gitlab-ci.yml` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué GitLab no tiene `exclude:` nativo y GHA sí? ¿Qué trade-off eligió cada uno?
2. Si mañana añades `python 3.14`, ¿qué cambia en tu YAML? ¿Y si quieres quitar `linux-arm64` para todas las versiones?
3. ¿Qué pasaría si en vez de usar `parallel: matrix:` escribieses 6 jobs a mano? ¿Cuándo preferirías cada enfoque?
4. ¿Qué variable de GitLab (`$CI_PIPELINE_SOURCE`, `$CI_COMMIT_BRANCH`, …) usas en `rules:` para que el job sólo corra en MR o en `main`?
5. Si el equipo decide que los tests de `macos` deben correr sólo cuando se toque `src/platform/mac/**/*`, ¿cómo lo expresas sin romper el resto?

## 10. Extensiones

- Añade un segundo job `lint:` con `needs: []` para que arranque sin esperar.
- Añade un `allow_failure: true` sólo para la combinación `macos` (requiere separarla en su propia entrada de `matrix:` con `rules:`).
- Factoriza el `workflow:` como `include:` desde un archivo aparte.

## 11. Limpieza

```bash
rm -rf /tmp/gl-04-01
```

No hay procesos ni infraestructura que detener.
