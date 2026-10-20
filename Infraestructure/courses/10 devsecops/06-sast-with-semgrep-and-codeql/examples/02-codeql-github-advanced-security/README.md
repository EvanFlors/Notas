# Ejemplo 02 — CodeQL vía GitHub Code Scanning

> Lectura. **No** se ejecuta localmente — CodeQL en este módulo se consume como workflow de GitHub, no como CLI.

## Objetivo

Entender el workflow oficial `codeql.yml`, qué hace cada paso y cuándo tocar `autobuild` por `build manual`.

## Cómo se habilita

1. Push al repo (público, o privado con **GitHub Advanced Security**).
2. `Settings → Code security and analysis → Code scanning → Set up → Default` genera un `codeql.yml` razonable.
3. O se crea a mano (abajo).

## Workflow oficial anotado

```yaml
# .github/workflows/codeql.yml
name: CodeQL

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '23 4 * * 1'       # weekly refresh — queries evolucionan

jobs:
  analyze:
    name: Analyze (${{ matrix.language }})
    runs-on: ubuntu-latest
    timeout-minutes: 360
    permissions:
      actions: read            # leer el workflow para context
      contents: read           # checkout
      security-events: write   # subir SARIF a Code Scanning

    strategy:
      fail-fast: false         # un lenguaje fallando no cancela los otros
      matrix:
        language: [python, javascript-typescript]
        # Lenguajes soportados: cpp, csharp, go, java-kotlin,
        # javascript-typescript, python, ruby, swift.

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: ${{ matrix.language }}
          # security-extended = más queries con FP ligeramente mayor
          # security-and-quality = security-extended + maintainability
          queries: security-and-quality

      # --- Build phase ---------------------------------------------------
      # Para lenguajes interpretados (python, js, ruby) autobuild es NO-OP.
      # Para compilados (java, c++, go, c#, swift) autobuild intenta
      # detectar y correr Maven/Gradle/make/go build/dotnet.
      - name: Autobuild
        uses: github/codeql-action/autobuild@v3

      # Si autobuild falla, reemplazar el paso anterior por:
      # - name: Manual build
      #   run: |
      #     ./scripts/build.sh
      # -------------------------------------------------------------------

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
        with:
          category: "/language:${{ matrix.language }}"
```

### Decisiones de diseño del workflow

| Decisión | Por qué |
|----------|---------|
| `fail-fast: false` | Un parser roto en un lenguaje no debe cancelar el otro. |
| `cron: weekly` | Las queries de CodeQL se actualizan; un push viejo puede tener findings nuevos. |
| `security-and-quality` | Cubre security + bugs comunes (null-deref, resource-leak). |
| `category` por lenguaje | Separar findings por "idioma" en la UI de Code Scanning. |
| `timeout-minutes: 360` | CodeQL en repos grandes puede tardar >1 h; el default de 6 h lo cubre. |

## Autobuild vs build manual — cuándo

- **Autobuild funciona** si el repo tiene un sistema de build estándar:
  - Java/Kotlin: `pom.xml`, `build.gradle(.kts)`.
  - C/C++: `Makefile`, `CMakeLists.txt`, `configure`.
  - C#: `.sln`, `.csproj`.
  - Go: `go.mod`.
- **Autobuild falla típicamente** cuando:
  - Hay varios módulos y faltan deps privadas.
  - Se requiere setup previo (DB, submódulos, env vars).
  - El build es custom (bazel con remote cache, scripts internos).

Reemplazo manual típico:

```yaml
      - name: Manual build
        run: |
          sudo apt-get install -y libxml2-dev
          ./configure --with-ssl
          make -j"$(nproc)"
```

CodeQL solo necesita **que la compilación termine** para observar las invocaciones del compilador.

## Lectura de un Alert

Al disparar una query, el alert tiene:

- **Rule**: `py/sql-injection` por ejemplo.
- **Severity** (Critical/High/Medium/Low) + **Security severity** (CVSS-like).
- **Dataflow path**: UI muestra source → steps → sink. Clave para distinguir FP.
- **Dismiss reasons**: `False positive`, `Won't fix`, `Used in tests`. Cada dismiss queda en el audit log.

## Qué NO hacer

- **No** dismissear sin razón.
- **No** correr CodeQL solo en `main` — pierdes el filtro por PR.
- **No** usar `security-extended` sin triar primero el ruido adicional.
- **No** confundir "Autobuild OK, 0 findings" con "código seguro" — puede que CodeQL **no haya observado** el código importante (p. ej. módulo no linkeado).
