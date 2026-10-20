# Actividad 02 — Publicar el primer release (`v0.1.0`)

## 1. Identificación

- **ID:** `gh-05-02-publish-first-release`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-05-github-first-contact`
- **Dificultad:** beginner
- **Duración estimada:** 30–45 min
- **Tipo:** guided-lab

## 2. Contexto

Marcar el final de un ciclo con un **tag anotado SemVer** y promoverlo a **Release** con un artefacto `.tar.gz`. Esta actividad consolida la diferencia conceptual entre *tag* (Git) y *release* (GitHub).

Modos:

- **`MODE=live`**: crea el release en GitHub con `gh release create`.
- **`MODE=local`**: simula el release con un directorio `releases/<tag>/` que contiene las notas y el asset.

## 3. Objetivos

Al terminar:
- Creas un tag anotado con mensaje decente.
- Pusheas el tag al remoto (`origin`).
- Generas un asset `.tar.gz` reproducible (sin `.git/` dentro).
- Publicas el release con notas (modo `live`) o lo simulas localmente (modo `local`).
- Verificas con `gh release view` (live) o inspección de archivos (local).

## 4. Prerrequisitos

- `gh-05-01-create-repo-and-push` completada (necesitas un repo con remote).
- Git ≥ 2.30.
- Modo `live`: `gh auth status` OK. Costo: $0.
- Modo `local`: nada extra.

## 5. Instrucciones

### 5.1 Preparar

El starter crea un **repo listo para release**: tiene base commit, `hello.sh`, README, `.gitignore` y, en `MODE=local`, un bare `origin` ya conectado.

```bash
# Modo local (default aquí):
MODE=local bash starter/bootstrap.sh /tmp/publish-first-release

# Modo live:
MODE=live bash starter/bootstrap.sh /tmp/publish-first-release
```

### 5.2 Pasos (comunes)

```bash
cd /tmp/publish-first-release/local

# 1. Haz un commit "release-ready" si quieres cambiar algo. En el starter ya
#    tienes commit base; opcionalmente añade CHANGELOG.md o similar.

# 2. Tag ANOTADO (no ligero).
git tag -a v0.1.0 -m "Release v0.1.0

First release:
- hello.sh script
- README
"

# 3. Push del tag al remote
git push origin v0.1.0

# 4. Genera el asset (fuera del repo, para no ensuciar el working tree)
tar -czf ../v0.1.0.tar.gz --exclude='.git' --exclude='releases' -C .. local
ls -lh ../v0.1.0.tar.gz
```

### 5.3 Publicar

#### Modo `live`

```bash
gh release create v0.1.0 \
  --title "v0.1.0 — First release" \
  --notes "First public release. See README." \
  ../v0.1.0.tar.gz

gh release view v0.1.0
```

#### Modo `local`

Como no hay API de GitHub, **simulamos** el release con un directorio `releases/<tag>/` dentro del bare origin (o en `$BASE/releases/<tag>/`):

```bash
BASE=/tmp/publish-first-release
mkdir -p "$BASE/releases/v0.1.0"
cat > "$BASE/releases/v0.1.0/NOTES.md" <<'EOF'
# v0.1.0 — First release

First public release. See README.
EOF
cp ../v0.1.0.tar.gz "$BASE/releases/v0.1.0/"
ls -R "$BASE/releases"
```

### 5.4 Validar

```bash
# Local (CI-friendly):
MODE=local bash tests/validate.sh /tmp/publish-first-release

# Live (si creaste release en GitHub):
MODE=live  bash tests/validate.sh /tmp/publish-first-release
```

## 6. Resultado esperado

- Tag `v0.1.0` **anotado** en el repo local y en `origin`.
- Asset `.tar.gz` que:
  - Tiene nombre con el tag (`v0.1.0`).
  - Es extraíble (`tar -tzf` lista contenido).
  - **No contiene** `.git/`.
- Modo `local`: `releases/v0.1.0/NOTES.md` + asset bajo `releases/v0.1.0/`.
- Modo `live`: `gh release view v0.1.0` muestra el release con al menos 1 asset.

## 7. Criterios de aceptación

- [ ] Tag `v0.1.0` existe y es **anotado** (`git cat-file -t v0.1.0` → `tag`, no `commit`).
- [ ] Tag presente en el remote (`origin`).
- [ ] Asset `.tar.gz` existe y es válido.
- [ ] Asset **no incluye** `.git/`.
- [ ] Notas de release presentes (locales o en GitHub).
- [ ] Working tree limpio.

## 8. Validación

El validador acepta `MODE=live` o `MODE=local` vía env var.

```bash
MODE=local bash tests/validate.sh /tmp/publish-first-release
```

## 9. Preguntas de reflexión

1. ¿Por qué **anotado** y no ligero para un release? Da dos razones.
2. ¿Qué pasaría si re-pusheas el tag `v0.1.0` apuntando a otro commit, luego de que un usuario ya descargó el asset?
3. En modo `local`, ¿qué parte **sí** es Git puro y qué parte es simulación?
4. ¿Qué información añade `--generate-notes` que no tendría una nota manual? ¿Qué requiere para funcionar bien?
5. ¿En qué casos no te molestarías en adjuntar un asset y dejarías el release "solo tag + notas"?

## 10. Extensiones (opcional)

- **E1** — Marca el release como `--prerelease` con tag `v0.2.0-rc.1`.
- **E2** — Firma el tag: `git tag -s v0.1.0 -m "..."` (requiere key GPG o SSH signing — ver `gh-13`).
- **E3** — Automatiza con GitHub Actions: workflow que al hacer push de un tag `v*` cree el release automáticamente.
- **E4** — Añade un segundo asset (checksum): `shasum -a 256 v0.1.0.tar.gz > v0.1.0.tar.gz.sha256` y súbelo.

## 11. Limpieza

```bash
# Local
rm -rf /tmp/publish-first-release

# Live (si procede):
gh release delete v0.1.0 --yes
git tag -d v0.1.0
git push origin :refs/tags/v0.1.0
```
