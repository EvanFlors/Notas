# Actividad 01 — Configurar el framework `pre-commit` con 3 hooks

## 1. Identificación

- **ID:** `gh-11-01-pre-commit-framework`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-11-hooks-submodules-subtrees-lfs`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Recibes un repo Python con un `.pre-commit-config.yaml` vacío (comentado). Tu tarea: configurar **al menos 3 hooks** del framework `pre-commit` y lograr que `pre-commit run --all-files` pase en verde sobre el starter.

El starter incluye código Python intencionalmente "casi correcto": sin trailing whitespace peligroso, sin archivos gigantes, mensajes de commit limpios — para que los hooks pasen tras configurarlos. Si rompes algo tendrás feedback claro.

## 3. Objetivos

Al terminar:
- Instalas `pre-commit` (framework) y corres `pre-commit install` sobre el repo.
- Configuras ≥ 3 hooks declarativos (algunos de `pre-commit-hooks`, uno de un repo externo tipo `ruff`).
- Pinneas versiones (`rev: v...`) correctamente.
- `pre-commit run --all-files` sale `0` en el repo.
- Entiendes que el shim en `.git/hooks/pre-commit` es creado por `pre-commit install`.

## 4. Prerrequisitos

- Git ≥ 2.30.
- Python 3.8+ con `pip` disponible.
- Conexión a internet para que `pre-commit` descargue los repos de los hooks a `~/.cache/pre-commit/`.
- `pre-commit` instalado. Opciones:
  - `pip install --user pre-commit`
  - `pipx install pre-commit`
  - `brew install pre-commit`
  - o se usará `python3 -m pre_commit` si el binario no está en PATH.

**Costos**: ninguno (todo local).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-starter-repo.sh /tmp/pre-commit-lab
cd /tmp/pre-commit-lab
cat .pre-commit-config.yaml           # starter: casi vacío, con TODO
```

### 5.2 Configurar `.pre-commit-config.yaml`

Debes añadir **al menos 3 hooks**. Lista recomendada (basta elegir 3; puedes añadir más):

- `trailing-whitespace` (de `pre-commit/pre-commit-hooks`)
- `end-of-file-fixer` (del mismo repo)
- `check-added-large-files` con `args: ['--maxkb=500']`
- `check-yaml`, `check-json`, `check-merge-conflict`, `detect-private-key` (del mismo repo)
- Opcional avanzado: `ruff` o `ruff-format` de `https://github.com/astral-sh/ruff-pre-commit`

**Pinnea versiones**: usa `rev: v4.6.0` para `pre-commit-hooks` (o la que prefieras; evita `HEAD`).

**Importante**: para que esta actividad corra sin red fiable y sin que un auto-fixer modifique el repo "post facto", los 3 hooks requeridos para el validador son los que **no modifican archivos** y usan solo repos stock:

Hooks mínimos requeridos por el validador (puedes añadir más):
1. `trailing-whitespace`
2. `end-of-file-fixer`
3. `check-added-large-files` con `--maxkb=500`

Todos del repo `https://github.com/pre-commit/pre-commit-hooks` a `rev: v4.6.0` (o versión mayor).

### 5.3 Instalar y correr

```bash
# instala el shim en .git/hooks/pre-commit
pre-commit install
# o si no está en PATH:
python3 -m pre_commit install

# primera corrida (descarga los repos a ~/.cache/pre-commit/)
pre-commit run --all-files
# o:
python3 -m pre_commit run --all-files
```

Si el starter ya está limpio, los 3 hooks deberían salir en `Passed`. Si alguno falla con `Failed`, lee el output: te dirá qué línea arreglar.

### 5.4 Commitear el config

```bash
git add .pre-commit-config.yaml
git commit -m "chore: enable pre-commit framework with 3 hooks"
```

Observa: tu propio commit disparó el hook. Si el config está mal, el commit es rechazado.

### 5.5 Validar

```bash
bash tests/validate.sh /tmp/pre-commit-lab
```

Debe salir con `OK`.

## 6. Resultado esperado

- `.pre-commit-config.yaml` versionado con ≥ 3 hooks del repo `pre-commit/pre-commit-hooks` (incluyendo los 3 requeridos arriba).
- `rev:` apunta a una versión pinneada (no `HEAD`, no `main`).
- `pre-commit run --all-files` sale `0`.
- `.git/hooks/pre-commit` existe y contiene el shim de `pre-commit install`.
- Un commit extra en el log: `chore: enable pre-commit framework...`.

## 7. Criterios de aceptación

- [ ] Funcionalidad: `pre-commit run --all-files` pasa.
- [ ] Calidad: versiones pinneadas, YAML válido.
- [ ] Reproducibilidad: `tests/validate.sh` pasa en el repo del alumno.
- [ ] Comprensión: puedes explicar qué hace cada hook y por qué pinneaste la versión.

## 8. Validación

```bash
bash tests/validate.sh /tmp/pre-commit-lab
```

Chequea:
- `.pre-commit-config.yaml` existe y es YAML válido.
- Contiene **al menos 3 hooks** (contando por `id:`).
- Los 3 hooks requeridos (`trailing-whitespace`, `end-of-file-fixer`, `check-added-large-files`) están presentes.
- Ningún `rev:` es `HEAD` ni rama (`main`, `master`).
- `.git/hooks/pre-commit` existe, es ejecutable y contiene la cadena `pre-commit` (shim del framework).
- `pre-commit run --all-files` (o `python3 -m pre_commit run --all-files`) sale `0`.
- Si no se encuentra el binario `pre-commit` ni el módulo Python, el validador falla con mensaje claro.

## 9. Preguntas de reflexión

1. ¿Por qué `pre-commit install` modifica `.git/hooks/pre-commit` pero el archivo real que define los chequeos (`.pre-commit-config.yaml`) está versionado? ¿Qué problema resuelve esta separación?
2. Si usas `rev: HEAD`, el día que el mantenedor del hook rompa compatibilidad, tu commit local fallará sin que tú tocaste nada. ¿Cómo evitas esto?
3. ¿Por qué un hook que **modifica archivos** (`end-of-file-fixer`, `ruff --fix`) puede "pasar en segunda corrida" aunque falló en la primera? ¿Es seguro en CI?
4. ¿Qué hooks moverías a `pre-push` o CI en lugar de `pre-commit` para no frustrar a los devs?
5. En un repo con 20 devs, ¿cómo garantizas que **todos** tengan los hooks instalados sin excepción? (Pista: `pre-commit run --all-files` en CI).

## 10. Extensiones (opcional)

- **E1** — Añade el hook `ruff` de `astral-sh/ruff-pre-commit`. Introduce un error de estilo en un `.py` y observa cómo el hook lo detecta/arregla.
- **E2** — Añade `trufflehog` (requiere `go` instalado o imagen Docker; lee la doc). Mete una llave privada falsa y observa el bloqueo.
- **E3** — Añade `conventional-pre-commit` como hook `commit-msg` (`stages: [commit-msg]`). Intenta committear con mensaje `"stuff"` y observa el rechazo.
- **E4** — Escribe un hook **local** inline en el YAML (`repo: local`) que corra `pytest -q` en modo rápido.

## 11. Limpieza

```bash
rm -rf /tmp/pre-commit-lab
# El cache de pre-commit vive en ~/.cache/pre-commit/
# Si quieres también limpiarlo:
# pre-commit clean
```
