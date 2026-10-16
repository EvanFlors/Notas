# Actividad 01 — Añadir SAST al capstone

## 1. Identificación

- **ID:** `sec-06-01-add-sast-to-capstone`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-06-sast-with-semgrep-and-codeql`
- **Dificultad:** intermediate
- **Duración estimada:** 60–75 min
- **Tipo:** guided-lab (independiente de la actividad 02)

## 2. Contexto

Tienes un capstone (o un repo de ejemplo, da igual) y necesitas meter SAST a nivel pipeline:

- Semgrep en el job rápido.
- Bandit como refuerzo Python.
- CodeQL via GitHub Code Scanning — como el runner local **no es GitHub Actions**, el entregable de CodeQL es **doc-only**: un `codeql.yml` escrito y revisado.
- Un documento TRIAGE.md con al menos 10 findings clasificados.

Esta actividad produce **archivos**, no corre un cluster. Si no tienes `semgrep` o `bandit` instalados, el validador lo detecta y marca el chequeo como SKIPPED en vez de FAIL.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Instalar Semgrep + Bandit, ejecutar un scan y leer la salida.
- Escribir un `.github/workflows/codeql.yml` razonable para Python.
- Clasificar un finding en fix / suppress-con-razón / FP.
- Argumentar por qué CodeQL va en nightly y Semgrep en PR.

## 4. Prerrequisitos

- `bash`, `python3` (≥ 3.9), `pip`.
- Opcional pero recomendado: `semgrep` (`pip install semgrep`) y `bandit` (`pip install bandit`). Sin ellos, los chequeos de ejecución se marcan SKIPPED.
- Costos: ninguno. Todo local y en `/tmp/sec-06-01-capstone`.

## 5. Instrucciones

### 5.1 Preparar el scratch dir

```bash
rm -rf /tmp/sec-06-01-capstone
mkdir -p /tmp/sec-06-01-capstone
cd /tmp/sec-06-01-capstone
```

### 5.2 Crear un repo Python de prueba

Crea `src/app.py` con **tres vulnerabilidades plantadas** (toma como referencia la solución):

- Una llamada `requests.get(url)` sin `timeout=`.
- Un uso de `hashlib.md5` para integridad.
- Un `subprocess.run(cmd, shell=True)` con una variable concatenada.

Y un `src/safe.py` con cosas correctas (para generar al menos un "no match").

### 5.3 Correr Semgrep y Bandit

```bash
semgrep scan --config auto --sarif --output semgrep.sarif src/   || true
bandit -r src/ -f json -o bandit.json                             || true
```

(El `|| true` es para no abortar el script si exit != 0; vas a leer los JSON/SARIF de todas formas.)

### 5.4 Crear el workflow Semgrep

Escribe `.github/workflows/semgrep.yml` siguiendo el patrón de `../../examples/01-semgrep-ci/`. Mínimos requeridos: `on: pull_request`, step de `semgrep scan`, step de `upload-sarif`.

### 5.5 Escribir el workflow CodeQL

Escribe `.github/workflows/codeql.yml` siguiendo `../../examples/02-codeql-github-advanced-security/`. Mínimos: `languages: [python]`, `queries: security-and-quality`, pasos `init` + `autobuild` + `analyze`.

**No** se ejecuta en esta actividad — es doc-only.

### 5.6 Clasificar 10 findings → `TRIAGE.md`

Crea `TRIAGE.md` listando **al menos 10 findings** (de Semgrep + Bandit combinados; si son menos, inventa 2–3 más del repo). Para cada uno:

- ID de la regla.
- Archivo + línea.
- Decisión: `fix` | `suppress` | `false-positive`.
- Justificación en 1 línea.

### 5.7 Validar

```bash
bash <ruta-repo>/courses/devsecops/06-sast-with-semgrep-and-codeql/activities/01-add-sast-to-capstone/tests/validate.sh /tmp/sec-06-01-capstone
```

### 5.8 Autoevaluar

Compara `TRIAGE.md` con `solution/REFERENCE.md`.

### 5.9 Limpieza

```bash
rm -rf /tmp/sec-06-01-capstone
```

## 6. Criterios de evaluación

| # | Criterio |
|---|----------|
| 1 | `src/app.py` existe y contiene las 3 vulnerabilidades. |
| 2 | `.github/workflows/semgrep.yml` presente, con `upload-sarif` y `on: pull_request`. |
| 3 | `.github/workflows/codeql.yml` presente, con `languages: python`, pasos init/analyze. |
| 4 | `TRIAGE.md` tiene al menos 10 entradas y usa las tres categorías. |
| 5 | Semgrep/Bandit ejecutados si están instalados; sino, SKIPPED. |

## 7. Costos y riesgos

- Costos: ninguno.
- Riesgos: dejar `/tmp/sec-06-01-capstone` sin limpiar. El validador no limpia; limpia tú.
