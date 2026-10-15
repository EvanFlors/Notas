# Actividad 02 — fsck a un repo roto (recovery con alternates)

## 1. Identificación

- **ID:** `gh-09-02-fsck-a-broken-repo`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-09-git-internals`
- **Dificultad:** advanced
- **Duración estimada:** 45–75 min
- **Tipo:** independent

## 2. Contexto

Son las 2 AM. El runner de CI tiró un error extraño: `fatal: unable to read ...`. El equipo revisa el repo y encuentra que **falta un objeto** en `.git/objects/`. Nadie recuerda haberlo borrado. Tienes dos opciones: restaurar de backup (lenta, se pierde trabajo de las últimas horas) o **reparar in-place** usando el clon sano de otro desarrollador.

Vas a practicar la segunda. Es el patrón real para recuperarte sin perder trabajo cuando parte del object store se pierde: añadir el clon sano como `alternate` y consolidar.

## 3. Objetivos

Al terminar deberías poder:

- Correr `git fsck --full` y **leer** su salida (`missing`, `broken link`, `dangling`).
- Añadir un repo externo como **alternate** editando `.git/objects/info/alternates`.
- Consolidar los objetos recuperados con `git repack -ad` (para dejar de depender del alternate).
- Verificar la salud con `git fsck` **sin** el alternate.

## 4. Prerrequisitos

- `gh-09-01-commit-from-scratch-plumbing` completada.
- Haber leído el módulo entero.
- Git ≥ 2.30.

**Costos**: ninguno (local).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-broken-repo.sh /tmp/fsck-lab
cd /tmp/fsck-lab
ls
# backup/   broken/   MISSING_HASH.txt   README.md
```

Tienes dos repos:

- `broken/` — el repo "de producción" **con un objeto faltante**.
- `backup/` — el clon sano de un colega.

Y un archivo `MISSING_HASH.txt` que te dice qué hash falta (no deberías necesitarlo — `fsck` te lo dirá).

### 5.2 Diagnóstico

```bash
cd /tmp/fsck-lab
git -C broken fsck --full
```

Observa la salida: debería listar al menos un `missing blob <hash>` y uno o más `broken link from commit <X> to blob <hash>`.

Preguntas que debes contestarte **antes** de intentar recuperar:

- ¿Qué commit referencia el blob faltante?
- ¿Qué archivo del tree de ese commit es el que corresponde al blob?
- ¿Está el blob presente en `backup/`? (`git -C backup cat-file -e <hash> && echo YES || echo NO`)

### 5.3 Recuperación

**No se te da la receta exacta.** Las pistas están en orden de "no me rindo".

### 5.4 Pistas

**Pista 1 — Dónde vive la info del alternate.**
Git lee la lista de object stores alternativos desde `.git/objects/info/alternates`. Es un archivo de texto plano: una ruta absoluta por línea.

**Pista 2 — Cómo apuntar al backup.**
```bash
echo "/tmp/fsck-lab/backup/.git/objects" > /tmp/fsck-lab/broken/.git/objects/info/alternates
```
Con eso, cualquier `git -C broken ...` que necesite un objeto que **no** esté en `broken/.git/objects/` lo buscará también en `backup/.git/objects/`.

**Pista 3 — Verifica que el alternate funciona.**
```bash
git -C broken fsck --full
# → debería estar limpio ahora (0 missing).
git -C broken log --oneline
# → debería recorrer la historia completa sin errores.
```

**Pista 4 — Consolidar.**
No quieres depender del backup para siempre (si el backup se mueve, se rompe de nuevo). Opciones:

- Opción A (recomendada, "copia todo lo que necesito"):
  ```bash
  git -C broken repack -ad
  ```
  `repack -ad` empaqueta todos los objetos **alcanzables** desde las refs en un pack nuevo dentro de `broken/.git/objects/pack/`. Lee del alternate si hace falta. Después, los objetos están **físicamente** en `broken/`.

- Opción B (manual, solo si quieres entender el detalle):
  Copia el objeto suelto desde `backup/.git/objects/<primeros-2>/<resto>` al mismo path en `broken/.git/objects/`.

**Pista 5 — Desactivar el alternate.**
```bash
rm /tmp/fsck-lab/broken/.git/objects/info/alternates
```

**Pista 6 — Verificar que ya no depende del backup.**
```bash
git -C broken fsck --full
# → debe seguir siendo clean sin el alternate.

# Prueba más agresiva: mueve temporalmente el backup y revisa:
mv /tmp/fsck-lab/backup /tmp/fsck-lab/backup.hidden
git -C broken fsck --full          # debe seguir OK
git -C broken log --all --oneline  # debe seguir recorriendo
mv /tmp/fsck-lab/backup.hidden /tmp/fsck-lab/backup
```

### 5.5 Validar

```bash
bash tests/validate.sh /tmp/fsck-lab
```

El validador va a:

1. Chequear que `broken/.git/objects/info/alternates` **no exista**.
2. Mover temporalmente `backup/` a un path escondido.
3. Correr `git fsck --full` sobre `broken/` — debe pasar sin missing/broken.
4. Verificar que el blob que faltaba originalmente **ahora esté** en `broken/.git/objects/` (sea loose o en un pack).
5. Restaurar `backup/`.

Debe terminar con `RESULT: OK`.

## 6. Resultado esperado

- `broken/` ya no tiene objetos faltantes (`fsck --full` → 0 missing / 0 broken link).
- `broken/.git/objects/info/alternates` fue eliminado (ya no depende del backup).
- El objeto faltante **fue físicamente consolidado** dentro de `broken/.git/objects/` (loose o pack).
- `backup/` sigue intacto (no tocaste nada ahí).

## 7. Criterios de aceptación

- [ ] `git -C broken fsck --full` sale `0` sin reporte de missing ni broken link.
- [ ] `broken/.git/objects/info/alternates` no existe.
- [ ] Si se renombra `backup/` → `broken` sigue funcionando perfectamente.
- [ ] No modificaste `backup/`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/fsck-lab
```

## 9. Preguntas de reflexión

1. **Antes de la recuperación**, ¿qué commits de `broken/` se pueden hacer `checkout` y cuáles no? ¿Por qué?
2. ¿Qué habría pasado si **nadie** tuviera un clon sano? ¿Podrías reconstruir el blob desde el reflog local? ¿Desde un remoto?
3. ¿Por qué `git repack -ad` consolida los objetos del alternate pero `git gc` solo (sin `-a`) **no** necesariamente? (Pista: `-a` = *all reachable, including from alternate when needed*.)
4. ¿Qué pasa con el `backup` si olvidas quitar el alternate y en una semana haces `rm -rf /tmp/fsck-lab/backup`? ¿Cómo lo detectarías?
5. Diseña un **procedimiento de 5 pasos** para que un equipo responda a `fsck: missing object` en producción. Incluye quién, qué, en qué orden, y cómo comunican.
6. ¿Qué diferencia práctica hay entre que el objeto perdido sea un `blob` vs un `tree` vs un `commit`? ¿Cuál sería peor?

## 10. Extensiones (opcional)

- **E1** — Corrompe un objeto en lugar de borrarlo (p. ej. `echo garbage > .git/objects/ab/cdef...`) y observa cómo `fsck` lo reporta de forma distinta. ¿Cuál es más grave?
- **E2** — Haz el ejercicio sin alternate: usa `git -C backup cat-file blob <hash> | git -C broken hash-object --stdin -w` para transferir el blob manualmente, uno a uno. Cuando el missing es un `tree` el flujo cambia (necesitas `-t tree`); investígalo.
- **E3** — Simula el escenario en que ni el backup lo tiene. ¿Qué le dirías al equipo? ¿Qué commits se pueden salvar y cuáles no?
- **E4** — Investiga `git maintenance` y configura una tarea periódica de `git fsck` para detectar corrupción temprano en tu máquina. ¿En qué cadencia tendría sentido?

## 11. Limpieza

```bash
rm -rf /tmp/fsck-lab
```
