# Actividad 02 — Escribir una regla Semgrep custom

## 1. Identificación

- **ID:** `sec-06-02-write-custom-rule`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-06-sast-with-semgrep-and-codeql`
- **Dificultad:** intermediate
- **Duración estimada:** 45–60 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Los findings del registry son útiles para empezar, pero cada organización tiene **patrones propios** que ningún registry público va a cubrir. Esta actividad entrena el ciclo completo:

1. Diseñar la regla.
2. Escribir casos **ok** y **ruleid** (fixtures).
3. Correr `semgrep --test` y hacer que todos los casos pasen.
4. Documentar la decisión (TEMPLATE.md) para que un futuro contribuidor pueda editar la regla sin introducir regresiones.

El patrón canónico de este módulo es `no-requests-without-timeout`.

## 3. Objetivos

Al terminar deberías poder:

- Explicar qué hacen `pattern-either` y `pattern-not`.
- Diseñar una regla que capture todos los verbos HTTP (`get`, `post`, `put`, `delete`, `patch`, `head`, `options`, `request`).
- Dejar un fixture con al menos 3 líneas `ruleid:` y 3 líneas `ok:`.
- Entender por qué un fixture sin `ok` casos es tan malo como no tener fixture.

## 4. Prerrequisitos

- `bash`, `python3`.
- Opcional: `semgrep` (`pip install semgrep`). Sin él, el chequeo de `semgrep --test` se marca SKIPPED.
- Costos: ninguno.

## 5. Instrucciones

### 5.1 Preparar

```bash
rm -rf /tmp/sec-06-02-custom-rule
mkdir -p /tmp/sec-06-02-custom-rule/.semgrep
cd /tmp/sec-06-02-custom-rule
```

### 5.2 Escribir la regla

Crea `.semgrep/no-requests-without-timeout.yml`. Mínimos requeridos:

- `rules[].id` igual a `no-requests-without-timeout`.
- `languages: [python]`.
- `severity: ERROR` (o `WARNING`).
- `message` útil (menciona `timeout`).
- `metadata.owner` presente.
- Un patrón que capture `requests.<METHOD>(...)` SIN `timeout=`.

### 5.3 Escribir el fixture

Crea `.semgrep/no-requests-without-timeout.test.py` con:

- Al menos **3 líneas marcadas con `# ruleid: no-requests-without-timeout`** que deben disparar la regla.
- Al menos **3 líneas marcadas con `# ok: no-requests-without-timeout`** que **no** deben disparar la regla.
- Cubrir al menos 3 verbos distintos (`get`, `post`, `request`).

### 5.4 Correr tests

```bash
semgrep --test .semgrep/
```

Debe salir `6/6 cases passed` (o más).

### 5.5 TEMPLATE.md

Crea `TEMPLATE.md` en el root del scratch dir con secciones:

- **Qué detecta** — en 2 líneas.
- **Cuándo suprimir** — con qué comentario `# nosemgrep: ... — razón: ...`.
- **Cuándo migrar al wrapper** — si existe `platform.http`, qué hacer en su lugar.
- **Dueño** — equipo responsable.

### 5.6 Validar

```bash
bash <ruta-repo>/courses/devsecops/06-sast-with-semgrep-and-codeql/activities/02-write-custom-rule/tests/validate.sh /tmp/sec-06-02-custom-rule
```

### 5.7 Autoevaluar

Compara `TEMPLATE.md` + la regla con `solution/REFERENCE.md` + `solution/TEMPLATE.md`.

### 5.8 Limpieza

```bash
rm -rf /tmp/sec-06-02-custom-rule
```

## 6. Criterios de evaluación

| # | Criterio |
|---|----------|
| 1 | `.semgrep/no-requests-without-timeout.yml` presente y con `id` + `languages` + `severity` + `message` + metadata.owner. |
| 2 | Fixture con ≥3 `ruleid:` y ≥3 `ok:`. |
| 3 | `semgrep --test` pasa (si semgrep instalado). |
| 4 | `TEMPLATE.md` con las 4 secciones. |

## 7. Costos y riesgos

- Costos: ninguno.
- Riesgo: dejar `/tmp/sec-06-02-custom-rule` sin limpiar.
