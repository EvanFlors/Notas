# Actividad 02 — Primeros commits observando objetos

## 1. Identificación

- **ID:** `gh-01-02-first-commits`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-01-setup-and-mental-model`
- **Dificultad:** beginner
- **Duración estimada:** 30–40 min
- **Tipo:** guided-lab

## 2. Contexto

Convertir el modelo mental en reflejo: ejecutar un ciclo real `init → status → add → commit` observando los objetos aparecer y las refs moverse. Si entiendes esto en profundidad, los módulos siguientes son más fáciles.

## 3. Objetivos

Al terminar deberías poder:

- Crear un repo y hacer 5+ commits atómicos.
- Interpretar la salida de `git status` en cada estado (untracked / staged / unmodified / modified).
- Leer `.git/refs/heads/main` y entender qué apunta.
- Usar `git cat-file` para inspeccionar un blob, un tree y un commit propios.
- Usar `git log` con filtros útiles.

## 4. Prerrequisitos

- Actividad `01-config-personal` completada.
- Git ≥ 2.30.
- `jq` opcional (para explorar índice).

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el entorno

```bash
cd /tmp
rm -rf first-commits
mkdir first-commits && cd first-commits
```

### 5.2 Inicializar

```bash
git init
git status
```

Observa que `git status` dice "On branch main. No commits yet.".

### 5.3 Primer commit — un archivo

Crea `README.md`:

```bash
cat > README.md <<'EOF'
# Mi proyecto

Primer commit — solo este archivo.
EOF
```

```bash
git status           # Untracked files: README.md
git add README.md
git status           # Changes to be committed: new file: README.md
git commit -m "init: README mínimo"
git log --oneline
```

Después del commit, inspecciona:

```bash
# Hash del último commit
git rev-parse HEAD

# Qué hay en el commit
git cat-file -p HEAD

# Qué hay en el tree del commit
git cat-file -p HEAD^{tree}

# ¿Qué es `main`?
cat .git/refs/heads/main
```

### 5.4 Segundo commit — modificar un archivo

```bash
echo "Línea extra." >> README.md
git status           # modified: README.md
git diff             # ver qué cambió
git add README.md
git commit -m "docs: amplía README"
```

Observa:
```bash
git log --oneline
cat .git/refs/heads/main    # ← cambió al nuevo hash
```

### 5.5 Tercer commit — crear carpetas y múltiples archivos

```bash
mkdir -p src tests
cat > src/hello.py <<'EOF'
def hello(name: str) -> str:
    return f"Hola, {name}!"
EOF

cat > tests/test_hello.py <<'EOF'
from src.hello import hello

def test_greets():
    assert hello("Git") == "Hola, Git!"
EOF

git add .
git status
git commit -m "feat: hello function + test"
```

Inspecciona el tree ahora:

```bash
git cat-file -p HEAD^{tree}
# Verás 3 entries: README.md (blob), src/ (tree), tests/ (tree)

# Entra al subtree de src
TREE_SRC=$(git ls-tree HEAD | awk '$4=="src"{print $3}')
git cat-file -p $TREE_SRC
```

### 5.6 Cuarto commit — un cambio que no debería ser un commit

Haz un cambio trivial *sin* intención semántica — y haz un commit mal.

```bash
echo "" >> README.md
git add README.md
git commit -m "update"
```

Lee tu `git log --oneline`. Pregúntate: ¿este commit tiene valor comunicativo? Lo arreglaremos en la Actividad siguiente del curso (`gh-02-recording-changes`).

### 5.7 Quinto commit — un cambio con mensaje bueno

```bash
cat >> src/hello.py <<'EOF'

def goodbye(name: str) -> str:
    return f"Adiós, {name}!"
EOF

git add src/hello.py
git commit -m "feat: añade goodbye()"
```

### 5.8 Explorar

```bash
# Log con formato
git log --oneline --graph --decorate --all

# Número de commits
git rev-list --count HEAD

# Autor
git log --format='%an <%ae>' -n1

# Objetos sueltos en objects/
find .git/objects -type f | grep -v pack | wc -l

# Verificar integridad
git fsck
```

### 5.9 Validar

```bash
bash tests/validate.sh
```

Debe pasar con `OK`.

## 6. Resultado esperado

- Repo con **≥ 5 commits** en `main`.
- `git log --oneline` muestra la historia lineal.
- `git cat-file -p HEAD` muestra el último commit con sus metadatos.
- `git cat-file -p HEAD^{tree}` muestra el árbol con 3 entries (`README.md`, `src/`, `tests/`).
- `cat .git/refs/heads/main` imprime el hash del último commit.
- `tests/validate.sh` pasa.

## 7. Criterios de aceptación

- [ ] Funcionalidad: 5+ commits en main, DAG lineal.
- [ ] Calidad: al menos 4 de 5 mensajes son significativos (uno "update" permitido para la lección).
- [ ] Reproducibilidad: `tests/validate.sh` pasa.
- [ ] Comprensión: puedes responder las preguntas de reflexión sin consultar.

## 8. Validación

```bash
bash tests/validate.sh
```

Chequea: directorio es repo, HEAD en `main`, ≥5 commits, tree del HEAD contiene `README.md`, `src/`, `tests/`, autor configurado, `fsck` limpio.

## 9. Preguntas de reflexión

1. Entre el *segundo* commit (modificar README) y el *tercero* (crear carpetas), ¿cuántos objetos nuevos se crearon y de qué tipo cada uno?
2. ¿Por qué el blob del `README.md` cambió de hash cuando añadiste "Línea extra."? ¿El blob viejo sigue existiendo en `.git/objects/`?
3. Después de **5 commits**, ¿cuántas copias del README hay en `.git/objects/`? (pista: una por cada versión distinta).
4. Mira `git log --format='%H %T'` — qué significa cada columna, y por qué dos commits consecutivos pueden tener *el mismo* valor en la 2a si no hubo cambios de contenido.
5. ¿Qué pasa si ejecutas `git commit --allow-empty -m "no change"`? ¿Es útil alguna vez?

## 10. Extensiones (opcional)

- **E1** — Repite el ejercicio usando `git commit -am` (atajo). ¿Qué archivos *no* se agregan automáticamente?
- **E2** — Haz un commit sobre un archivo binario (`dd if=/dev/urandom of=random.bin bs=1k count=10`). Inspecciona el blob (`git cat-file -p` no es legible — ¿por qué? ¿cómo verías el tamaño?).
- **E3** — Introduce un error en el commit (p. ej. mensaje con typo). Investiga `git commit --amend` (se detalla en `gh-02`, aquí solo exploración).
- **E4** — Ejecuta `git gc` tras tus 5 commits. Observa cómo `.git/objects/` cambia (muchos sueltos → packfile).

## 11. Limpieza

```bash
rm -rf /tmp/first-commits
```
