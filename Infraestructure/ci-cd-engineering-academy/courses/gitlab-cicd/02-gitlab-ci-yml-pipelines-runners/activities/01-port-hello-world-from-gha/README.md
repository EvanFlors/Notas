# Actividad 01 — Portar `hello.yml` de GHA a `.gitlab-ci.yml`

## 1. Identificación

- **ID:** `gl-02-01-port-hello-world-from-gha`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-02-gitlab-ci-yml-pipelines-runners`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** guided-lab

## 2. Contexto

Tu equipo mantiene un workflow trivial en GitHub Actions llamado `hello.yml` que hace tres cosas en orden: **lint** (shellcheck), **test** (pytest), **build** (empacar un tarball). La empresa está evaluando migrar a GitLab y te piden como primer paso **portar ese workflow** a `.gitlab-ci.yml` para medir el *mapping* real.

El workflow origen (en `starter/.github/workflows/hello.yml`) usa:

- Trigger: push a `main` y pull_request.
- 3 jobs secuenciales: `lint`, `test`, `build`.
- `runs-on: ubuntu-latest`.
- `python:3.12` para el job `test`.

Tu tarea: producir un `.gitlab-ci.yml` **equivalente** en `/tmp/gl-02-01/.gitlab-ci.yml` que respete el modelo `pipeline → stages → jobs` de GitLab y use `rules:` moderno (no `only/except`).

**Importante**: no hace falta ejecutarlo en `gitlab.com`. La validación es estructural (Python + `yaml`).

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Traducir `on:` → `workflow:rules:` (y/o `rules:` por job) sin ambigüedad.
- Decidir qué va en `default:` vs qué va job por job.
- Declarar `stages:` explícito y asignar cada job a su stage.
- Usar `image:` para el job que lo requiere y dejar el resto sin `image:`.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo.
- Haber recorrido los tres `examples/` del módulo.
- Haber completado el curso **github-actions** o tener fluidez en `on:`, `jobs:`, `runs-on:`, `steps:`.
- Herramientas: `bash`, `python3` con módulo `yaml` (`python3 -c 'import yaml'` debe no fallar). Si falta:
  ```bash
  python3 -m pip install --user pyyaml
  ```

**Costos**: ninguno. Local, sin cuenta GitLab.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/gl-02-01
cd /tmp/gl-02-01
```

Puedes usar otro directorio, pero entonces pásalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Lee el origen

```bash
cat starter/.github/workflows/hello.yml
```

### 5.3 Escribe tu `.gitlab-ci.yml`

En `/tmp/gl-02-01/.gitlab-ci.yml`. Requisitos **obligatorios** (los chequea el validador):

1. YAML válido (parsea con `yaml.safe_load`).
2. Declara `stages:` con **al menos** `lint`, `test`, `build` (en ese orden).
3. Define **≥ 3 jobs** no reservados. Cada uno con `stage:` apuntando a uno de esos stages.
4. **Al menos un job** tiene `image:` (el que usa `python:3.12` tiene sentido).
5. Todos los `script:` son **listas**, no escalares.
6. **No** uses `only:` ni `except:` (deprecados). Si quieres filtrar, usa `rules:` o `workflow:rules:`.
7. Incluye **`workflow:`** o `rules:` que haga el equivalente a "push a main o merge request" (los validadores aceptan ambos).

### 5.4 Valida tu trabajo

```bash
bash tests/validate.sh /tmp/gl-02-01
```

Debe terminar con `OK:` y exit code 0.

## 6. Resultado esperado

- `/tmp/gl-02-01/.gitlab-ci.yml` existe y parsea.
- 3 stages, 3+ jobs, 1+ con `image:`, 0 ocurrencias de `only:`/`except:`.
- `workflow:` o `rules:` presente mencionando `main` o `merge_request`.

## 7. Criterios de aceptación

- **Funcionalidad**: validador en verde.
- **Calidad**: los nombres de job son descriptivos (`lint-shell`, `pytest`, `build-tarball`), no `job1`/`job2`.
- **Reproducibilidad**: un ingeniero del equipo puede copiar tu `.gitlab-ci.yml` a un proyecto GitLab y ejecutarlo sin más cambios (más allá de instalar dependencias reales).

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-02-01
```

Opcional — si tienes `gitlab-ci-lint` instalado:

```bash
gitlab-ci-lint /tmp/gl-02-01/.gitlab-ci.yml
```

Si no lo tienes, el validador estructural + los `python3 -c 'import yaml; yaml.safe_load(...)'` cubren el 90% de los errores.

## 9. Preguntas de reflexión

1. ¿Dónde pondrías `tags: [docker, linux]`: en `default:` o en cada job? Justifica.
2. En GHA cada `step` es su propio bloque. En GitLab todo el `script:` es un bloque. ¿Qué pierdes y qué ganas?
3. Si quisieras cachear `pip install`, ¿cómo lo harías en GitLab? (Pista: `cache:` — se profundiza en módulos posteriores.)
4. ¿Qué pasa si un `script:` tiene 20 comandos y el comando 7 falla? Compara con GHA.

## 10. Extensiones

- Añade un cuarto job `smoke` en un nuevo stage `deploy` que corra solo en `main` (`rules:` con `$CI_COMMIT_BRANCH == "main"`).
- Añade `default: image: python:3.12-slim` y elimina `image:` de los jobs que lo repitan.
- Añade un job `lint-yaml` paralelo a `lint-shell` en el stage `lint`.

## 11. Limpieza

```bash
rm -rf /tmp/gl-02-01
```

Nada más que limpiar.
