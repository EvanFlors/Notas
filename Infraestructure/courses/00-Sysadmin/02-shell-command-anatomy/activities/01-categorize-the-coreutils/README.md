# Actividad 01 — Clasifica 40 coreutils

## 1. Identificación

- **ID:** `sys-02-01-categorize-the-coreutils`
- **Módulo:** `sys-02-shell-command-anatomy`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** independent

## 2. Contexto

Hasta ahora leíste la **tabla de categorías canónicas** (lección, sección 6). Esta actividad invierte el flujo: se te da una lista de 40 comandos reales y tú produces la tabla.

Es la actividad que valida si realmente *interiorizaste* el modelo mental — no si recuerdas los nombres.

## 3. Objetivos

Al terminar deberías poder:

- Asignar cualquier comando Unix conocido a una de las 14 categorías canónicas.
- Escribir una línea de uso típica sin consultar `man` (si no la sabes, aprende primero y luego escribe).
- Argumentar por qué un comando "frontera" (p. ej. `find`) pertenece a una categoría y no a otra.
- Usar `whatis`, `apropos`, `tldr`, `type -a` para investigar comandos desconocidos.

## 4. Prerrequisitos

- Lección `theory/lesson.md` leída, especialmente la sección 6.
- `whatis` funcional (`sudo mandb` si acaba de instalar `man-db`).
- `tldr` opcional pero recomendado (`pip install --user tldr` o `apt install tldr`).

## 5. Instrucciones

### 5.1 Copia el starter

```bash
cd /tmp
rm -rf categorize-coreutils
mkdir categorize-coreutils && cd categorize-coreutils
cp <ruta-de-la-actividad>/starter/commands.txt .
```

### 5.2 Produce `classification.md`

En el mismo directorio, crea `classification.md` con:

- Un título.
- Una **tabla Markdown** con exactamente 40 filas (una por comando) y las columnas:

```markdown
| Comando | Categoría | Uso típico (una línea) |
|---------|-----------|-------------------------|
| ls      | Navegación / FS | `ls -la` lista el cwd con detalles. |
| ...     | ...       | ...                     |
```

- Las categorías permitidas son **exactamente** las de la lección (sección 6). Nombres aceptados por el validador: `Navegación`, `Manipulación`, `Lectura`, `Edición`, `Búsqueda`, `Procesos`, `Red`, `Usuarios`, `Paquetes`, `Servicios`, `Disco`, `Archivadores`, `Checksums`, `Meta`. Puedes añadir sufijos (`Navegación / FS`), el validador acepta substring.

### 5.3 Preguntas obligatorias

Al final de `classification.md`, añade una sección `## Preguntas` con tus respuestas:

1. `find` ¿pertenece a Búsqueda o a Navegación/FS? Argumenta en 2-3 líneas.
2. ¿Por qué `sudo` no está en Usuarios aunque gestiona privilegios? (Pista: ¿qué categoría de la tabla encajaría mejor desde el punto de vista de lo que *hace*?)
3. Un comando que no está en la lista: `rsync`. ¿Dónde lo pondrías y por qué?
4. Da **dos** comandos de Meta de shell que **no** son externos (son builtins). Verifícalo con `type -a`.
5. Para los 5 comandos cuyo nombre no reconocías, lista cuál fue tu fuente de verdad (`man`, `tldr`, `apropos`, otro) y qué pregunta hiciste.

### 5.4 Validar

```bash
bash <ruta-de-la-actividad>/tests/validate.sh /tmp/categorize-coreutils
```

El validador comprueba estructura (40 filas, categorías válidas, sección de preguntas). **No valida semántica fina** — para eso compara con `solution/README.md`.

## 6. Resultado esperado

- `/tmp/categorize-coreutils/classification.md` con tabla de 40 filas + 5 preguntas respondidas.
- `tests/validate.sh` sale con código 0.

## 7. Criterios de aceptación

- [ ] 40 filas, una por comando, en el orden de `commands.txt` o reordenadas por categoría.
- [ ] Cada fila usa una categoría de la lista canónica.
- [ ] Cada "uso típico" es una línea autoexplicativa (`ls -la ~/`, no `displays files`).
- [ ] 5 preguntas respondidas, con argumento (no sólo sí/no).
- [ ] Fronteras tratadas con criterio (ver pregunta 1 y 2).

## 8. Validación

```bash
bash tests/validate.sh /tmp/categorize-coreutils
```

Estructural. Semántica = compara con `solution/README.md`.

## 9. Preguntas de reflexión

- Si tuvieras que **añadir** una categoría a la tabla canónica para cubrir mejor Linux moderno, ¿cuál sería y por qué? (Pista: contenedores, orquestación, observabilidad.)
- ¿Qué comandos de la lista son **builtin** de Bash y no externos? ¿Cómo lo averiguaste?

## 10. Extensiones (opcional)

- **E1** — Añade 10 comandos más de tu uso cotidiano a la clasificación.
- **E2** — Marca con `(POSIX)` los que son POSIX puros y con `(GNU)` los que son extensiones GNU.
- **E3** — Para cada categoría, añade *un* comando "moderno" sustituto (`fd` por `find`, `rg` por `grep`, `bat` por `cat`, `exa`/`eza` por `ls`, `btop` por `top`).

## 11. Limpieza

```bash
rm -rf /tmp/categorize-coreutils
```
