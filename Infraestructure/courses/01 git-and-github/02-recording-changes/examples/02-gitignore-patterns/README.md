# Ejemplo 02 — `.gitignore` y `.gitattributes` en la práctica

## Concepto que demuestra

Patrones comunes de `.gitignore`, pitfalls típicos (archivo ya tracked, negación, scope), y uso complementario de `.gitattributes` para line endings y binary diff.

## Objetivo

Al terminar:
- Sabes qué patrones aplicar por lenguaje/entorno.
- Entiendes por qué poner algo en `.gitignore` **no basta** si ya fue committed.
- Usas `.gitattributes` para normalización de line endings y marcado de binarios.

## Prerrequisitos

- Git ≥ 2.30. Haber completado `gh-01` y leído la lección de `gh-02`.

## `.gitignore` canónico para Python + Node + genérico

Ver `files/gitignore-template` como punto de partida. Secciones:

- **Python**: `__pycache__/`, `*.py[cod]`, `.venv/`, `.pytest_cache/`, `.coverage`, `htmlcov/`.
- **Node** (si aplica): `node_modules/`, `dist/`, `.next/`.
- **IDE / OS**: `.idea/`, `.vscode/*`, `.DS_Store`, `Thumbs.db`, `*.swp`.
- **Secrets** (defensa en profundidad): `.env`, `.env.*`, `*.pem`, `*.key`.
- **Build**: `dist/`, `build/`, `*.log`.

## Pitfall 1 — Archivo ya tracked no se "desya"

```bash
cd /tmp && rm -rf gi-demo && mkdir gi-demo && cd gi-demo
git init -q -b main
git config user.name Demo && git config user.email d@e.com

echo "SECRET=abc" > .env
git add .env && git commit -q -m "oops: commit env"

# Ahora creas .gitignore
echo ".env" > .gitignore
git add .gitignore && git commit -q -m "add gitignore"

# ¿Está .env ignorado?
echo "SECRET=xyz" > .env
git status
# → "nothing to commit, working tree clean"  <-- parece OK
# PERO: el archivo .env sigue tracked
git ls-files | grep .env
# → .env

# Si lo modificas, git lo verá como modified (NO está ignorado):
echo "SECRET=lmn" > .env
git status
# modified: .env     ← ¡seguía tracked!
```

**Fix correcto:**
```bash
git rm --cached .env
echo ".env" >> .gitignore
git add .gitignore
git commit -m "chore: untrack .env"

# AHORA sí
echo "SECRET=xyz" > .env
git status    # clean
```

Y **asumir que el secret está leaked** (vive en la historia). Rotar.

## Pitfall 2 — Negación con `!`

```gitignore
# Ignorar todos los .env
.env
.env.*

# Excepto el ejemplo:
!.env.example
```

**No funciona** si el directorio padre está ignorado:

```gitignore
# NO funciona
config/
!config/public.yaml      # IGNORADO: config/ ya está ignorado
```

**Sí funciona** siendo específicos:

```gitignore
config/*
!config/public.yaml
```

## Pitfall 3 — Scope de un `.gitignore`

Un `.gitignore` dentro de `src/` solo aplica a `src/`. Para el repo entero, va en la raíz.

## `.gitattributes` básico

```gitattributes
# Normalizar line endings
* text=auto

# Forzar LF en scripts
*.sh    text eol=lf
*.py    text eol=lf

# Forzar CRLF en PowerShell
*.ps1   text eol=crlf

# Binarios
*.png   binary
*.jpg   binary
*.pdf   binary
*.zip   binary

# Jupyter: usar driver si está instalado (opcional)
*.ipynb diff=jupyternotebook

# Exportar sin ciertos archivos (git archive)
.github/       export-ignore
tests/         export-ignore
.gitattributes export-ignore
```

Reglas:
- `text=auto` deja que Git detecte texto vs binario y aplique `core.autocrlf` del cliente al checkout.
- `text eol=lf`/`eol=crlf` **fuerza** el line ending al checkout, independientemente del cliente.
- `binary` desactiva normalización y marca el archivo para diff "binario" (sin texto).

## Resultado esperado

- `.gitignore` del capstone cubre Python + IDE + OS + secretos.
- `.gitattributes` normaliza line endings y marca binarios comunes.
- Entiendes y evitas los pitfalls documentados.

## Verificar que un patrón se aplica

```bash
# ¿Está este archivo ignorado por qué regla?
git check-ignore -v config/public.yaml
# → .gitignore:3:!config/public.yaml      config/public.yaml

# Ver si un archivo sería tracked en el próximo add
git status --ignored
```

## Relación con escenarios reales

- Un repo con `node_modules/` committed accidentalmente: 100 MB extra en cada clon por siempre, incluso tras removerlo (está en la historia).
- Un `.env` con creds de prod en la historia: catastrófico; rotar inmediatamente.
- Un equipo con devs Linux + Windows sin `.gitattributes`: PRs con "cambios de línea en todo el archivo" que son solo CRLF↔LF.

## Limpieza

```bash
rm -rf /tmp/gi-demo
```
