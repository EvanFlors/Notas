# Actividad 03 — Mapear `.git/` y explicar cada entrada

## 1. Identificación

- **ID:** `gh-01-03-explore-dot-git`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-01-setup-and-mental-model`
- **Dificultad:** intermediate
- **Duración estimada:** 40–60 min
- **Tipo:** independent

## 2. Contexto

Hasta ahora has sido guiado paso a paso. Esta actividad invierte el rol: **se te da un repo con cosas ya pasadas** y debes mapear `.git/` y explicar cada entrada por tu cuenta.

Es la actividad que valida si realmente comprendiste el modelo de objetos — no si recuerdas los comandos.

## 3. Objetivos

Al terminar deberías poder:

- Describir el **propósito** y el **contenido** de cada entrada relevante de `.git/`.
- Identificar los objetos nuevos creados por un `commit` dado, y de qué tipo.
- Correlacionar `.git/refs/heads/<branch>` con el commit al que apunta.
- Explicar la relación `HEAD → ref → commit → tree → blob/tree`.
- Diferenciar `.git/objects/` sueltos vs `.git/objects/pack/` empaquetados.

## 4. Prerrequisitos

- Actividades `01` y `02` del módulo completadas.
- `bash`, `jq` opcional.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Generar el repo de referencia

```bash
cd /tmp
rm -rf explore-dot-git
bash <ruta-de-la-actividad>/starter/build-sample-repo.sh /tmp/explore-dot-git
cd /tmp/explore-dot-git
```

Esto crea un repo con:
- 3 commits en `main`.
- 1 rama adicional `feature/x` apuntando a un commit distinto.
- 1 tag `v0.1`.
- Al menos un archivo en `.git/info/exclude`.

**No ejecutes `git gc` aún** — queremos ver objetos sueltos primero.

### 5.2 Entregable principal: `MAP.md`

Produce un archivo `MAP.md` en el directorio raíz del repo con:

#### A. Mapa anotado completo de `.git/`

Para cada archivo y directorio que encuentres, una línea con:

```
<path dentro de .git/>  — <qué es> — <por qué existe en este repo>
```

Debes **mirar el archivo**, no inventar. Si no sabes qué es algo, dilo ("función desconocida, pendiente de investigar").

#### B. Diagrama de los objetos

Dibuja (ASCII o Mermaid) **todos los objetos** del repo y sus relaciones, para los 3 commits y la rama adicional:

```
HEAD → refs/heads/main → commit3 → tree_root3 → ...
                             ↑
                           parent
                             │
                         commit2 → tree_root2 → ...
                             ↑
                           parent
                             │
                         commit1 → tree_root1 → blob(README)

refs/heads/feature/x → commitX → tree_X → ...
refs/tags/v0.1 → ...   (lightweight o annotated)
```

Para cada commit, lista:
- Hash abreviado (7 caracteres).
- Hash de su tree.
- Mensaje.
- Padre(s).

### 5.3 Preguntas obligatorias en `MAP.md`

Al final de `MAP.md`, responde:

1. ¿Cuántos **blobs** únicos hay en el repo? ¿Por qué ese número?
2. ¿Cuántos **trees** únicos? ¿Por qué?
3. ¿Cuántos **commits**? ¿Y cuántos **tags**?
4. Verifica tu respuesta con un comando (hint: `find .git/objects -type f` y filtrar por tipo con `git cat-file -t`).
5. ¿La ref `refs/tags/v0.1` apunta directamente a un commit (lightweight) o a un objeto tag (annotated)? ¿Cómo lo distingues?
6. Si borras `.git/refs/heads/feature/x` **sin** borrar los objetos: ¿los commits de esa rama se pierden inmediatamente? ¿Dónde quedan rastros?
7. Ejecuta `git gc` ahora. ¿Qué cambió en `.git/objects/`? ¿Siguen los commits accesibles?

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/explore-dot-git
```

Chequea que `MAP.md` exista y que incluya las secciones mínimas (A, B, 7 respuestas). **No** valida el contenido semántico — eso lo verifica un instructor o te lo autoevaluas con la solución (ver `solution/`).

## 6. Resultado esperado

- Archivo `MAP.md` en `/tmp/explore-dot-git/` con las secciones A, B y las 7 respuestas.
- `tests/validate.sh` pasa (presencia de secciones).
- Opcionalmente: comparas con `solution/MAP-reference.md` tras completar.

## 7. Criterios de aceptación

- [ ] Mapa de `.git/` cubre al menos: `HEAD`, `config`, `index`, `logs/`, `objects/`, `refs/heads/*`, `refs/tags/*`, `info/exclude`.
- [ ] Diagrama de objetos muestra la cadena commit → tree → blobs para los 3 commits de `main` y la rama feature.
- [ ] Las 7 respuestas están presentes y fundamentadas con comandos verificables.
- [ ] Diferencias entre lightweight tag y annotated tag identificadas correctamente.
- [ ] Observación post-`git gc`: packfile presente y objetos sueltos reducidos.

## 8. Validación

```bash
bash tests/validate.sh /tmp/explore-dot-git
```

Validación estructural (presencia de secciones y archivos). **Validación semántica** la haces tú contra `solution/MAP-reference.md`.

## 9. Preguntas de reflexión

Más allá de las obligatorias de la 5.3:

1. Si clonas este repo (`git clone /tmp/explore-dot-git /tmp/clone`), ¿qué entradas de `.git/` **no** se copian? ¿Por qué?
2. Si editas `.git/HEAD` manualmente a `ref: refs/heads/no-existe`, ¿qué pasa en `git status`?
3. ¿Qué consecuencia tiene borrar `.git/index` (sin tocar `.git/objects/`)? Prueba y reporta.

## 10. Extensiones (opcional)

- **E1** — Reconstruye un commit **a mano** usando `git hash-object -w`, `git mktree`, `git commit-tree`. Útil para interiorizar los niveles plumbing / porcelain.
- **E2** — Crea un segundo repo y configura `.git/objects/info/alternates` para apuntar al primero. Observa cómo el segundo repo "ve" objetos del primero sin duplicar.
- **E3** — Usa `git fsck --dangling` para ver objetos no alcanzables desde ninguna ref. Explica por qué podrían existir.

## 11. Limpieza

```bash
rm -rf /tmp/explore-dot-git
```
