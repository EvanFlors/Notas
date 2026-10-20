# Ejemplo 02 — `run` vs `uses`: dos jobs equivalentes

## Concepto que demuestra

La diferencia operacional entre ejecutar shell con `run:` y invocar una **action** reutilizable con `uses:`. Los dos jobs del archivo hacen lo mismo (checkout + poner Python 3.12 disponible + imprimir versión), pero uno lo resuelve "a mano" con `run:` y el otro delega en actions.

## Contexto

Es la decisión más común al escribir un workflow: ¿me armo yo los comandos o reutilizo una action? Hay reglas para elegir; este ejemplo las ilustra.

## Objetivo

Al terminar, podrás:
- Diferenciar los dos modelos en código.
- Argumentar por qué `actions/setup-python` es *mejor* que `apt-get install python3`.
- Reconocer cuándo `run:` directo es la respuesta correcta.

## Prerrequisitos

- Haber leído la lección y el ejemplo `01-hello-world/`.

## Archivo del ejemplo

Está en `files/run-vs-uses.yml`. Léelo:

```yaml
# .github/workflows/run-vs-uses.yml
name: run-vs-uses

on:
  push:
  pull_request:

jobs:

  # Opción A: todo a mano con `run:`
  manual:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Instalar Python 3.12 "a mano"
        run: |
          # ubuntu-latest trae Python preinstalado, pero fijemos la versión
          sudo apt-get update -qq
          sudo apt-get install -y python3.12
          python3.12 --version

  # Opción B: delegar en una action oficial
  via_action:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - name: Verificar
        run: |
          python --version   # 3.12.x
```

### Qué ganas con `uses:` (versión B)

- **Portabilidad entre SO**: `apt-get` no existe en macOS ni Windows. `actions/setup-python` conoce los tres.
- **Caché gestionado**: la action descarga de un *tool cache* precomputado por GitHub; evita apt mirrors lentos.
- **Compatibilidad con `matrix`**: cambiar la versión es un parámetro, no un `if` sobre `runs-on`.
- **Correcciones de bugs sin tocar tu YAML**: GitHub libera `v5.1`, `v5.2`, etc.; tú sigues en `@v5`.

### Cuándo `run:` directo gana (versión A)

- Comandos triviales del proyecto (`pytest`, `make build`, `./scripts/release.sh`).
- Herramientas no soportadas por ninguna action.
- Debugging: imprimir variables, listar archivos, inspeccionar el runner.
- Cuando *añadir una dependencia de terceros* no se justifica.

Regla práctica: **si existe una action oficial o de vendor que haga lo que necesitas, úsala**. Para tus propios comandos de proyecto, `run:`.

## Ejecución

### Modo lectura

Lee los dos jobs y, para cada paso, pregúntate:
- ¿Qué comando real está detrás?
- ¿Cuánto tarda?
- ¿Qué pasa si cambia la versión de Ubuntu de GitHub?

### Modo real (en un repo de prueba)

```bash
cd /tmp
rm -rf gha-run-vs-uses-demo
mkdir gha-run-vs-uses-demo && cd gha-run-vs-uses-demo
git init -b main
mkdir -p .github/workflows
cp /path/to/examples/02-run-vs-uses/files/run-vs-uses.yml .github/workflows/
git add .
git commit -m "ci: run vs uses demo"

gh repo create gha-run-vs-uses-demo --private --source=. --remote=origin --push

gh run watch
```

Observa en la UI que los dos jobs corren **en paralelo** (no hay `needs:` entre ellos) y en runners distintos.

## Resultado esperado

- Dos jobs verdes: `manual` y `via_action`.
- El job `via_action` suele ser **más rápido** (el tool cache ya tiene Python 3.12).
- Ambos imprimen `Python 3.12.x`.

## Interpretación

- `uses:` descargó una action compuesta por un `action.yml` + código JS/Node (en el caso de `actions/setup-python`), la corrió aislada, y expuso Python en el `PATH` del runner para los siguientes steps.
- `run:` en el job `manual` ejecutó `apt-get` directamente — con las limitaciones y lentitud correspondientes.
- Los dos jobs no se ven entre sí: distinta VM, distinto filesystem.

## Errores frecuentes

- **"Mejor hago todo con `run:`, así no dependo de nadie"**: ignora el valor del tool cache, de la compatibilidad multi-SO, y de las correcciones gratis.
- **"Mejor hago todo con `uses:`, hay actions para todo"**: aumenta la superficie de confianza del pipeline. Cada action de terceros es código que corre con tu `GITHUB_TOKEN`. Audita y pin a SHA cuando no sea action oficial (`gha-04`).
- **Esperar que el PATH se mantenga entre jobs**: no. Cada job es una VM. Si quieres Python en los dos jobs, haces setup en los dos.

## Relación con escenarios reales

- Un pipeline típico mezcla ambos: `uses:` para setup (checkout, Python, Node, Go, Docker Buildx) y `run:` para los comandos específicos del proyecto.
- Cuando una action falla y el log es críptico, el reflejo "lo bajo a `run:` para debuggear qué comando real está corriendo" es útil — pero la mayoría de actions oficiales publican su source y puedes leerlo.

## Limpieza

```bash
gh repo delete gha-run-vs-uses-demo --yes
rm -rf /tmp/gha-run-vs-uses-demo
```
