# Ejemplo 02 — Primer release: tag anotado + `gh release create`

## Concepto que demuestra

Cómo:
1. Crear un **tag anotado** siguiendo *SemVer*.
2. Pushearlo.
3. Promoverlo a **Release** con `gh`, con notas y un artefacto `.tar.gz`.
4. Inspeccionarlo con `gh release view` y `gh release download`.

También muestra el equivalente **local** (sin GitHub) para entender qué partes son Git puro y cuáles son GitHub API.

## Contexto

Marca el final de un ciclo: "esta versión del código es consumible". El tag es Git. El release es GitHub.

## Objetivo

Al terminar:
- Distingues qué hace `git tag -a` vs `gh release create`.
- Puedes publicar un release con assets desde la CLI en 3 comandos.
- Entiendes que un release *vive* sobre un tag (y que borrar uno no borra el otro).

## Prerrequisitos

- Un repo propio en GitHub (puede ser uno vacío creado para la demo).
- `gh` autenticado (`gh auth status` → OK).

**Costos**: ninguno (releases y assets son gratis en public y private).

## Ejecución — modo `live` (con GitHub real)

### 1. Preparar un repo demo

```bash
mkdir -p /tmp/release-demo && cd /tmp/release-demo
git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

cat > README.md <<'EOF'
# release-demo

Trivial package used to showcase `gh release create`.

## Install

Download the `.tar.gz` from the Releases page.
EOF
cat > hello.sh <<'EOF'
#!/usr/bin/env bash
echo "hello from release-demo"
EOF
chmod +x hello.sh

git add .
git commit -q -m "feat: initial release-demo package"

# Crear repo en GitHub y pushear
gh repo create release-demo --public --source=. --remote=origin --push
```

### 2. Crear tag anotado

```bash
git tag -a v0.1.0 -m "Release v0.1.0

First release:
- hello.sh script
- README with install hint
"
git push origin v0.1.0
```

Inspecciona:

```bash
git show v0.1.0 | head -20
# tag v0.1.0
# Tagger: Student <student@example.com>
# Date: ...
# Release v0.1.0 ...
# commit <hash>
```

### 3. Empaquetar artefacto

```bash
# Crear fuera del repo para no contaminar el working tree
tar -czf /tmp/release-demo-0.1.0.tar.gz --exclude='.git' -C /tmp release-demo
ls -lh /tmp/release-demo-0.1.0.tar.gz
```

### 4. Crear el Release en GitHub

```bash
gh release create v0.1.0 \
  --title "v0.1.0 — First release" \
  --notes "First public release. Includes hello.sh and README." \
  /tmp/release-demo-0.1.0.tar.gz
# → sube el asset y devuelve la URL del release
```

### 5. Verificar

```bash
gh release list
gh release view v0.1.0
gh release view v0.1.0 --web          # abre en navegador

# Descargar los assets (como lo haría un usuario)
mkdir -p /tmp/release-demo-dl
gh release download v0.1.0 --dir /tmp/release-demo-dl
ls -lh /tmp/release-demo-dl
```

### 6. Variantes útiles

```bash
# Prerelease (no se marca "Latest")
gh release create v0.2.0-rc.1 --prerelease ...

# Draft (invisible al público hasta publicar)
gh release create v0.2.0 --draft ...

# Notas desde archivo
gh release create v0.2.0 --notes-file CHANGELOG.md

# Auto-generar notas desde PRs/commits desde el último release
gh release create v0.2.0 --generate-notes
```

## Ejecución — modo `local` (sin GitHub)

El tag en sí es Git puro. Lo "release" es GitHub, pero podemos **simularlo** con un fichero de notas y un directorio `releases/` local que haga de "bucket de assets":

```bash
mkdir -p /tmp/release-demo-local && cd /tmp/release-demo-local
git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"
cat > hello.sh <<'EOF'
#!/usr/bin/env bash
echo "hello from release-demo-local"
EOF
chmod +x hello.sh
git add .
git commit -q -m "feat: initial"

# Tag anotado
git tag -a v0.1.0 -m "Release v0.1.0"

# "Release" simulado: notas + asset en releases/<tag>/
mkdir -p releases/v0.1.0
cat > releases/v0.1.0/NOTES.md <<'EOF'
# v0.1.0 — First release

- hello.sh script
EOF
tar -czf releases/v0.1.0/release-demo-local-0.1.0.tar.gz --exclude='.git' --exclude='releases' .
ls -R releases/
```

Comparación mental:

| GitHub real | Local simulado |
|-------------|----------------|
| Tag en remoto | Tag en `.git/refs/tags/` (no se pushea, no hay remoto) |
| Metadata del release en API GitHub | `releases/<tag>/NOTES.md` |
| Asset en bucket de GitHub | `releases/<tag>/*.tar.gz` |
| URL pública de descarga | Ruta local del archivo |

## Limpieza

```bash
# Modo live:
gh release delete v0.1.0 --yes
git tag -d v0.1.0
git push origin :refs/tags/v0.1.0
# Opcional: borrar el repo
gh repo delete release-demo --yes

rm -rf /tmp/release-demo /tmp/release-demo-dl /tmp/release-demo-0.1.0.tar.gz

# Modo local:
rm -rf /tmp/release-demo-local
```

## Preguntas de reflexión

1. ¿Qué pasa si borras el release en GitHub pero no borras el tag?
2. ¿Qué pasa si borras el tag pero no el release?
3. ¿Por qué el asset va fuera del repo y no `git add dist/`?
4. ¿Qué información aporta `--generate-notes` que no tendría un release manual? ¿Qué requiere para funcionar bien (hint: PRs merged)?
