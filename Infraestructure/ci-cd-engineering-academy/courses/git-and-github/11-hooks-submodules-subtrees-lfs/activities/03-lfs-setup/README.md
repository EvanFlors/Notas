# Actividad 03 — Configurar Git LFS para un archivo binario

## 1. Identificación

- **ID:** `gh-11-03-lfs-setup`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-11-hooks-submodules-subtrees-lfs`
- **Dificultad:** intermediate
- **Duración estimada:** 30 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a configurar **Git LFS** desde cero en un repo nuevo, trackear un patrón de archivo binario (`*.bin`), añadir un archivo de 2 MB y verificar que lo committed **no son los bytes del binario** sino un **puntero LFS** (~130 bytes de texto). Es el flujo canónico que todo repo con binarios debería seguir desde el día 1.

## 3. Objetivos

Al terminar:
- Inicializas LFS en el repo (`git lfs install` global + `git lfs track` en el repo).
- Confirmas que `.gitattributes` recibió la línea con `filter=lfs diff=lfs merge=lfs -text`.
- Añades un archivo `*.bin` y lo committeas.
- Verificas con `git cat-file -p HEAD:<archivo>` que el blob committed es un **puntero** (texto empezando por `version https://git-lfs.github.com/spec/v1`).
- Confirmas que `git lfs ls-files` lista el archivo.

## 4. Prerrequisitos

- Git ≥ 2.30.
- `git-lfs` instalado. Si no lo tienes:
  - macOS: `brew install git-lfs`
  - Debian/Ubuntu: `sudo apt install git-lfs`
  - Windows: incluido en Git for Windows ≥ 2.33 o `choco install git-lfs`
- Una vez instalado: `git lfs install` (una sola vez por usuario; registra los filtros smudge/clean globalmente).

**Si `git-lfs` no está disponible en esta máquina**, el validador lo detectará y hará **skip graceful** indicando qué chequear manualmente. La actividad siempre puede completarse creando el `.gitattributes` correcto a mano, pero el bit más interesante (puntero vs blob) requiere `git-lfs`.

**Costos**: ninguno (local). Nota: en GitHub real, LFS tiene cuotas de storage/bandwidth facturadas.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-starter-repo.sh /tmp/lfs-lab
cd /tmp/lfs-lab
```

El starter crea un repo vacío con un `README.md` committed. No hay `.gitattributes` ni `*.bin` aún.

### 5.2 Instalar LFS globalmente (una vez por máquina)

```bash
git lfs install
```

Esto registra los filtros `smudge` y `clean` en tu `~/.gitconfig`. Puedes verificar:

```bash
git config --global --get-all filter.lfs.clean
git config --global --get-all filter.lfs.smudge
git config --global --get-all filter.lfs.process
```

### 5.3 Trackear `*.bin` en el repo

```bash
cd /tmp/lfs-lab
git lfs track "*.bin"
cat .gitattributes
# → *.bin filter=lfs diff=lfs merge=lfs -text
```

### 5.4 Añadir un binario y commitear

```bash
mkdir -p assets
dd if=/dev/urandom of=assets/data.bin bs=1024 count=2048 2>/dev/null   # 2 MB

git add .gitattributes assets/data.bin
git commit -m "feat: add binary data (tracked by LFS)"
```

### 5.5 Verificar que el objeto committed es un **puntero** LFS

```bash
# El blob committed debe ser texto plano del tipo:
#   version https://git-lfs.github.com/spec/v1
#   oid sha256:<hash>
#   size 2097152
git cat-file -p HEAD:assets/data.bin

# Confirma lista LFS
git lfs ls-files
# → <oid-abrev> * assets/data.bin
```

### 5.6 Validar

```bash
bash tests/validate.sh /tmp/lfs-lab
```

Si `git-lfs` no está instalado, el validador falla el chequeo de puntero pero valida el `.gitattributes` y marca el resto como SKIPPED con instrucciones.

## 6. Resultado esperado

- `.gitattributes` committed, con la línea `*.bin filter=lfs diff=lfs merge=lfs -text`.
- `assets/data.bin` committed, pero el **blob real en Git** es un puntero LFS (~130 bytes de texto plano).
- `git lfs ls-files` muestra `assets/data.bin`.
- `git log --oneline` muestra ≥ 2 commits (init + binary).

## 7. Criterios de aceptación

- [ ] Funcionalidad: `.gitattributes` con filter=lfs, binario commiteado como puntero.
- [ ] Calidad: patrón `*.bin` correcto; `.gitattributes` versionado.
- [ ] Reproducibilidad: `tests/validate.sh` pasa (o explica skip si `git-lfs` falta).
- [ ] Comprensión: puedes explicar la diferencia entre el puntero y el blob real.

## 8. Validación

```bash
bash tests/validate.sh /tmp/lfs-lab
```

Chequea:
- Repo existe.
- `.gitattributes` committed y contiene la línea `*.bin filter=lfs diff=lfs merge=lfs -text`.
- `assets/data.bin` committed.
- (Si `git-lfs` está instalado): el blob de `assets/data.bin` en HEAD empieza por `version https://git-lfs.github.com/spec/v1` (es decir, es un puntero), y `git lfs ls-files` lo lista.
- (Si `git-lfs` no está instalado): el validador marca esos chequeos como SKIPPED con mensaje claro.

## 9. Preguntas de reflexión

1. Si olvidas correr `git lfs install` *antes* de commitear, ¿qué pasa con `assets/data.bin`? ¿Cómo lo arreglas?
2. ¿Qué pasa si trackeas `*.bin` **después** de haber commiteado `foo.bin`? ¿El blob se convierte retroactivamente?
3. ¿Por qué el puntero LFS incluye `size`? ¿Para qué sirve a Git?
4. En GitHub, ¿cómo se refleja el billing de LFS? ¿Qué dimensiones cobran?
5. ¿Cuándo preferirías un artifact store externo (S3) en lugar de LFS? Da 2 criterios.

## 10. Extensiones (opcional)

- **E1** — Añade `*.psd` y `*.zip` al tracking. Verifica que `.gitattributes` crece.
- **E2** — Simula una migración: añade un `legacy.bin` **sin** LFS, commiteáloló, luego usa `git lfs migrate import --include="*.bin"` para moverlo. Observa cómo cambia el hash del commit.
- **E3** — Investiga `.lfsconfig` para apuntar a un servidor LFS alternativo (self-hosted) sin cambiar el `.gitattributes`.
- **E4** — Usa `git lfs clone <url> --exclude="*"` + `git lfs pull --include="path"` para clonar un repo con LFS sin bajar binarios.

## 11. Limpieza

```bash
rm -rf /tmp/lfs-lab
# El cache de LFS vive en .git/lfs/ (dentro del repo). Si borras el repo, se va.
# A nivel global no hay nada que limpiar (git lfs install solo edita gitconfig).
```
