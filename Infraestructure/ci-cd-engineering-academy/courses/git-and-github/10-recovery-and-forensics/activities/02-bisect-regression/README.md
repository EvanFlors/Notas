# Actividad 02 — Bisect a regression (automated)

## 1. Identificación

- **ID:** `gh-10-02-bisect-regression`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-10-recovery-and-forensics`
- **Dificultad:** advanced
- **Duración estimada:** 40–55 min
- **Tipo:** guided-lab

## 2. Contexto

Se te entrega un repo con **~20 commits** sobre un script `calc.sh`. Uno (y solo uno) de ellos introduce una regresión que un test determinístico detecta. Tu tarea: localizarlo con `git bisect`, idealmente con `git bisect run` para automatizar la búsqueda.

## 3. Objetivos

Al terminar deberías poder:

- Iniciar un `bisect` con los `good` y `bad` correctos.
- Escribir (o reutilizar) un script-probe con códigos de salida convenidos (`0`/`1`/`125`).
- Automatizar la búsqueda con `git bisect run`.
- Reportar el hash del "first bad commit" y entender qué hizo mal ese commit.

## 4. Prerrequisitos

- `gh-10` lección leída.
- Haber hecho `examples/02-bisect-with-script/`.
- `bash`, `grep`, `awk`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-regression-repo.sh /tmp/bisect-lab
```

Esto crea `/tmp/bisect-lab/repo` con ~20 commits sobre `main`. También crea `/tmp/bisect-lab/probe.sh` (el test que detecta la regresión) y un `/tmp/bisect-lab/README.md` con el escenario.

### 5.2 Entender el escenario

El repo contiene un script `calc.sh` que recibe dos números y debe imprimir su suma:

```bash
cd /tmp/bisect-lab/repo
./calc.sh 2 3     # debe imprimir 5
```

- En `HEAD` (hoy): **imprime un valor incorrecto**.
- Hace 20 commits (`HEAD~20`): **correcto**.
- Entre medias, un commit introdujo la regresión.

El probe:

```bash
cat /tmp/bisect-lab/probe.sh
```

Hace `./calc.sh 2 3` y compara contra `5`. Sale `0` si bien, `1` si mal, `125` si el script no existe.

### 5.3 Tu tarea

1. Verifica el escenario:

   ```bash
   cd /tmp/bisect-lab/repo
   bash /tmp/bisect-lab/probe.sh; echo "exit=$?"   # 1 (bad)
   git checkout HEAD~20 -- calc.sh                  # trae la versión vieja de calc.sh
   bash /tmp/bisect-lab/probe.sh; echo "exit=$?"   # 0 (good)
   git restore --source=HEAD --staged --worktree calc.sh   # vuelve a HEAD
   ```

2. Ejecuta `git bisect` **automatizado**:

   ```bash
   git bisect start HEAD HEAD~20
   git bisect run bash /tmp/bisect-lab/probe.sh
   ```

   Git recorre log₂(20) ≈ 5 commits y reporta `<hash> is the first bad commit`.

3. Anota el hash. Luego inspecciona el commit:

   ```bash
   git show <hash>
   ```

4. Antes de terminar, deja constancia del resultado para que el validador pueda verificarlo. **Dos formas aceptadas**, elige una:

   - **Forma A (automática):** deja activo el estado post-`bisect`. En algunas versiones de Git queda `refs/bisect/bad` o un archivo `BISECT_LOG` con el resultado. Si tu versión limpia esto al reportar, usa Forma B.
   - **Forma B (manual):** escribe el hash en un archivo `/tmp/bisect-lab/answer.txt`:

     ```bash
     echo "<hash>" > /tmp/bisect-lab/answer.txt
     ```

   Después puedes limpiar: `git bisect reset`.

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/bisect-lab
```

El validador acepta ambas formas (A o B).

## 6. Resultado esperado

- El hash reportado por `bisect run` corresponde al commit cuyo subject es **`refactor: swap operator (regression)`**.
- `tests/validate.sh` reporta `RESULT: OK`.

## 7. Criterios de aceptación

- [ ] Ejecutaste `bisect start` con los extremos correctos.
- [ ] Usaste `bisect run` con un probe funcional.
- [ ] Identificaste el hash del commit culpable.
- [ ] El hash o estado quedó registrado donde el validador lo puede leer.

## 8. Validación

```bash
bash tests/validate.sh /tmp/bisect-lab
```

El validador comprueba que `answer.txt` (si existe) contenga el hash del commit culpable **o** que `BISECT_LOG`/`refs/bisect/bad` apunten a él.

## 9. Preguntas de reflexión

1. ¿Cuántos commits probó `bisect` para encontrar la regresión en 20 commits? ¿Y cuántos probaría en 2000?
2. ¿Qué pasa si tu probe sale con `0` en todos los commits (bug: olvidaste comparar correctamente)? ¿Qué devuelve `bisect run`?
3. ¿Por qué el probe vive en `/tmp/` y no en el repo?
4. Si un commit intermedio **no compilara** (p. ej. test suite rota por otra razón), ¿qué código de salida debería devolver tu probe? ¿Qué sucedería si devolviera `1`?
5. Diseña un probe que, además, imprima a `stderr` qué está haciendo en cada iteración, para que puedas debuggear si bisect te lleva al commit equivocado.

## 10. Extensiones (opcional)

- **E1** — Modifica `starter/build-regression-repo.sh` para hacer una historia de **100 commits** y mide el tiempo de `bisect run`.
- **E2** — Introduce **dos regresiones** en commits distintos; usa `bisect` para encontrar la primera, haz un revert local, y repite para encontrar la segunda.
- **E3** — Repite todo pero sobre una historia con **merges** (no lineal). Observa qué commit elige bisect en cada iteración.

## 11. Limpieza

```bash
cd /tmp/bisect-lab/repo && git bisect reset 2>/dev/null || true
rm -rf /tmp/bisect-lab
```
