# Lección: Recovery and forensics

> **ID:** `gh-10-recovery-and-forensics` · **Nivel:** avanzado · **Duración:** 4 h
> **Prerrequisitos:** `gh-09-git-internals`.

---

## 1. Introducción intuitiva

Escena 1 — viernes 18:30. Ejecutas `git reset --hard origin/main` en la rama equivocada. Dos horas de trabajo "desaparecen". No las has pusheado. ¿Las perdiste?

Escena 2 — lunes 10:00. Un test que ayer pasaba hoy falla. Entre ayer y hoy entraron 42 commits (merges de otros equipos, cherry-picks, rebases). Nadie recuerda qué tocó esa parte. ¿Vas a leer 42 diffs?

Escena 3 — martes. Alguien escribió `password = ""` en producción. ¿Quién fue, cuándo, en qué PR?

Este módulo es la caja de herramientas para los tres escenarios. La idea central: **Git casi nunca borra. Lo que parece perdido suele estar a un comando de distancia**. Y lo que no, suele poderse acotar a O(log n) con `bisect`.

El precio: hay que entender el modelo (que ya viste en `gh-09`) y conocer tres o cuatro comandos que casi nunca se usan en el día a día pero valen oro cuando hacen falta.

---

## 2. Fundamentos

### 2.1 Reachability y por qué "borrar" no borra

Un objeto Git (blob, tree, commit, tag) vive en `.git/objects/` identificado por su hash. Un objeto es **reachable** (alcanzable) si lo apunta alguna **ref** (`refs/heads/*`, `refs/tags/*`, `refs/remotes/*`, `HEAD`, `refs/stash`, reflogs). Reachable = *protegido*.

`git reset --hard HEAD~3`:
1. Mueve la ref `main` tres commits atrás.
2. Los tres commits que quedaron fuera **ya no son reachable por refs normales**.
3. Pero **sí** son reachable por el **reflog** de `main` y de `HEAD`.
4. Mientras lo sean, `git gc` no los toca.

Resumen: `reset --hard` cambia *refs*, no toca *objects*. El working tree sí se sobreescribe (ahí perdemos cambios no committeados — esos sí son irrecuperables salvo que estuvieran en el index, veremos).

### 2.2 El reflog: un diario de HEAD y de cada rama local

Cada vez que una ref local cambia, Git añade una línea al reflog correspondiente:

```
.git/logs/HEAD                 ← cada movimiento de HEAD
.git/logs/refs/heads/main      ← cada movimiento de main
.git/logs/refs/heads/feature   ← cada movimiento de feature
```

Formato de línea:
```
<old-sha> <new-sha> <author> <timestamp> <tz>\t<operation>: <message>
```

Visualización:
```bash
git reflog                        # HEAD
git reflog show main              # por rama
git reflog show --date=iso        # fechas legibles
```

Sintaxis `@{N}` para referirse a un estado histórico:
```bash
git show HEAD@{2}                 # HEAD dos movimientos atrás
git show main@{yesterday}         # main como estaba ayer
git diff HEAD@{1} HEAD            # qué cambió respecto al estado anterior de HEAD
```

**Clave**: el reflog es **local y por clon**. No se transfiere con `push`/`fetch`. Si clonas un repo, tu reflog empieza vacío.

### 2.3 Expiración del reflog y de los objetos

Entradas antiguas del reflog expiran según `gc.reflogExpire` y `gc.reflogExpireUnreachable`:

| Variable | Default | Qué controla |
|---|---|---|
| `gc.reflogExpire` | 90 días | Entradas de reflog aún alcanzables por su ref viva |
| `gc.reflogExpireUnreachable` | 30 días | Entradas que apuntan a commits ya no alcanzables |

Un objeto es candidato a eliminación por `git gc` cuando:
1. No es reachable por ninguna ref viva.
2. No es reachable por ningún reflog no expirado.
3. Tiene más de `gc.pruneExpire` (default 2 semanas).

Hasta entonces, está en `.git/objects/` como **loose object** o dentro de un packfile. `git gc --prune=now` fuerza la limpieza inmediata (destructivo).

### 2.4 Cuando el reflog ya no te salva: `fsck --lost-found`

Si borraste una rama, pasaron semanas, o alguien hizo `git gc --prune=now`, el reflog ya no apunta a nada útil. Pero mientras el **objeto** siga en `.git/objects/`, `git fsck` lo encuentra:

```bash
git fsck --lost-found
# dangling commit abc123...
# dangling blob  def456...
```

Los objetos dangling (sin referencia pero aún presentes) quedan listados en `.git/lost-found/{commit,other}/`. Puedes:
```bash
git show abc123
git branch rescue-branch abc123     # vuelve a hacerlo reachable
```

Si pasó `gc --prune` y el objeto ya no está en `.git/objects/`: ahí sí murió.

### 2.5 `bisect`: búsqueda binaria sobre la historia

Dado un commit `good` donde el bug *no* existe y uno `bad` donde *sí*, `bisect` encuentra el commit culpable en **O(log₂ N)** pasos. 1000 commits → ~10 pruebas.

Modelo mental: Git marca el commit del medio del rango, te pide que lo pruebes, y según respondas (`good`/`bad`) descarta la mitad opuesta.

Dos modos:
- **Manual**: tú ejecutas el test y respondes `git bisect good` o `git bisect bad`.
- **Automático**: `git bisect run <script>`. El script sale con:
  - `0` → good
  - `1..124, 126..127` → bad
  - `125` → skip (commit no testeable: no compila, dependencias rotas)
  - `>=128` → abort (error grave)

Asume **monotonicidad**: una vez malo, siempre malo. Si el bug es intermitente o si hay commits que no compilan intercalados, usa `skip`.

### 2.6 Pickaxe: `git log -S` y `git log -G`

- `git log -S"foo"` — commits donde el **número de ocurrencias** de la cadena `foo` cambió. Ideal para "¿cuándo apareció/desapareció esta constante?".
- `git log -G"regex"` — commits donde el **diff contiene** líneas que casan con la regex (más amplio, incluye reformats).

Combinable con `--all` para buscar en todas las refs, con `-- <path>` para acotar a un archivo o directorio.

### 2.7 `blame` y `log --follow`

- `git blame -L 20,40 file` — autor y commit de cada línea en el rango 20–40.
- `git blame -w` — ignora cambios de whitespace (más útil).
- `git blame -C -C` — sigue copias dentro del commit (más caro).
- `git log --follow file` — sigue el archivo a través de renombres (`log` solo no lo hace).

Combinación letal: `blame` para localizar la línea → tomar el hash → `git show <hash>` y `git log <hash>^..<hash>` para contexto.

### 2.8 `worktree`: múltiples checkouts, un solo `.git/`

```bash
git worktree add ../repo-investigate <commit-or-branch>
```

Crea un segundo working tree que comparte `.git/`. Útil para:
- Investigar un commit viejo sin perder tu estado actual.
- Correr `bisect` en una copia mientras sigues desarrollando en otra.
- Comparar dos ramas en IDEs distintos.

Cuando terminas: `git worktree remove ../repo-investigate`.

### 2.9 `stash` y por qué no abusarlo

`git stash push` crea **dos commits** (uno con el index, otro con el working tree) y los apunta desde `refs/stash` (un reflog). `git stash pop` los aplica y descarta la entrada.

Problemas prácticos:
- Es "memoria efímera que se olvida sola". Un `stash` de hace 3 meses nunca se recupera.
- `refs/stash` es un **reflog**: entradas viejas expiran igual que cualquier reflog.
- No se pushea.

**Mejor alternativa 90% de las veces**: un commit WIP en una rama. `git commit -m "WIP: refactor"` + luego `git reset --soft HEAD~` cuando vuelves. O un `worktree`.

Si debes usar `stash`: nómbralo (`git stash push -m "mensaje descriptivo"`) y lístalo (`git stash list`).

---

## 3. Contexto histórico

- **2005** — Git nace con la noción de reflog desde el inicio: era necesario para que `rebase` y `reset` fueran "seguros".
- **~2007** — `git bisect` se añade (basado en ideas de Linus sobre búsqueda binaria sobre historia); la variante `run` llega poco después.
- **2007** — Primer soporte sólido de `git stash` (Nanako Shiraishi).
- **2015** — `git worktree` añadido (Git 2.5) tras años de pedirlo (antes se abusaba de `GIT_DIR` + clones duplicados).
- **2019** — Git 2.23 introduce `restore`/`switch`, reduciendo la carga semántica de `checkout`/`reset`.
- **~2020+** — `git maintenance` (Git 2.29) automatiza `gc`, `fetch`, `commit-graph`, etc. en background.

El patrón: cada feature forense llegó como respuesta a casos reales donde "me rompí el repo" o "no sé qué introdujo este bug".

---

## 4. Modelo interno

### 4.1 Qué guarda un reflog físicamente

```
$ cat .git/logs/HEAD
0000...  abc1  Student <s@e> 1700000000 +0000  commit (initial): init
abc1     def2  Student <s@e> 1700000001 +0000  commit: WIP
def2     abc1  Student <s@e> 1700000002 +0000  reset: moving to HEAD~1
```

Un archivo de texto, append-only, por ref. Si lo borras, pierdes la historia local. Si borras una ref (`git branch -D foo`), `.git/logs/refs/heads/foo` queda huérfano brevemente y luego también se borra en el próximo `gc`.

### 4.2 Qué objetos quedan dangling tras `reset --hard HEAD~3`

```
antes:                        después:
main → C5                     main → C2
HEAD → main                   HEAD → main
   C5 ─ C4 ─ C3 ─ C2 ─ C1        C5 ─ C4 ─ C3 (dangling)
                                              │
                                              C2 ─ C1
```

C3, C4, C5 **no son reachable por refs vivas**. Sí lo son por el reflog de `main` y `HEAD` (entradas que anotan "pre-reset"). Mientras no expiren, `gc` no los toca.

Si corres `git reflog expire --expire=now --all && git gc --prune=now`: adiós. Prueba sintética en una copia antes de hacerlo "en serio".

### 4.3 Cómo recorre `bisect` el DAG

`bisect` no asume historia lineal. En un DAG con merges, elige el commit cuyo "ancho" (número de commits del rango) está más cerca de la mitad. Esto puede dar varios candidatos equivalentes; `bisect` elige uno. Al terminar, imprime "first bad commit is <hash>".

En presencia de merges, el commit culpable puede ser un merge que trajo cambios malos de otra rama; `bisect` sí lo detecta.

---

## 5. Ejemplo mínimo

```bash
mkdir /tmp/reflog-min && cd /tmp/reflog-min
git init -q -b main
git config user.email "s@e" && git config user.name "s"

echo a > f && git add . && git commit -q -m "a"
echo b > f && git add . && git commit -q -m "b"
echo c > f && git add . && git commit -q -m "c"

git reset --hard HEAD~2       # "perdemos" b y c
git log --oneline             # solo 'a'
git reflog                    # vemos b y c como HEAD@{1}, HEAD@{2}
git reset --hard HEAD@{2}     # restaurado
cat f                         # c
```

Dos movimientos: perder y recuperar. El objeto nunca se tocó.

---

## 6. Ejemplo progresivo

Escenario: tienes un repo con historia de 50 commits. Un test `tests/sanity.sh` que ayer pasaba hoy falla. No sabes en qué commit se rompió.

```bash
cd ~/myrepo

# 1. marcas el actual como malo
git bisect start
git bisect bad HEAD

# 2. marcas uno conocido bueno (hace una semana)
git bisect good HEAD~50

# 3. Git te deja en el commit del medio. Pruebas:
bash tests/sanity.sh
# si pasa:
git bisect good
# si falla:
git bisect bad

# ... repites log₂(50) ≈ 6 veces.

# cuando termina:
# "abc1234 is the first bad commit"

git bisect reset             # vuelve a tu rama original
```

Automatizado:
```bash
git bisect start HEAD HEAD~50
git bisect run bash tests/sanity.sh
# Git recorre todo solo. Resultado en pantalla.
```

El test debe salir `0` cuando good, `1` cuando bad, y `125` para skip.

---

## 7. Variante profesional

### 7.1 Un `bisect run` útil en CI

Un script típico:

```bash
#!/usr/bin/env bash
# bisect-probe.sh
set -u

# 1. Prepara: a veces un commit viejo no compila por culpa de dependencias.
#    Si eso pasa, 'skip' en lugar de 'bad'.
if ! make build >/dev/null 2>&1; then
  exit 125
fi

# 2. Corre solo el test afectado, con timeout.
if ! timeout 60 ./tests/run_only_regression.sh; then
  exit 1    # bad
fi

exit 0      # good
```

Características:
- **Timeout**: un commit puede loopear infinitamente.
- **Skip builds rotos**: no son "malos", son "no testeables".
- **Test enfocado**: no todo el suite — mientras más rápido, más commits bisectados por hora.

### 7.2 Reflog con TTL extendido para humanos

```bash
# Para repos personales, extiende el reflog a 1 año.
git config gc.reflogExpire 365.days.ago
git config gc.reflogExpireUnreachable 180.days.ago
```

Trade-off: `.git/` crece más. En equipos, estándar es el default.

### 7.3 `blame` + pickaxe para una auditoría real

"Cuándo apareció este secreto hardcoded":

```bash
git log --all -S"sk_live_" -- config/
# commits donde la cadena 'sk_live_' cambió de conteo

git log --all -G"api_key\s*=\s*\"" -- src/
# commits donde el diff tocó la asignación

git blame -w -L 40,60 config/prod.py
# quién tocó cada línea del rango
```

Luego `git show <hash>` sobre el candidato y listo. Combina con `git log --follow` si el archivo fue renombrado.

### 7.4 `worktree` para investigar sin perder estado

```bash
git worktree add /tmp/investigate abc1234
cd /tmp/investigate
# todo tu stack, en el commit viejo, sin tocar el working tree original
cd -
git worktree remove /tmp/investigate
```

---

## 8. Trade-offs y decisiones

| Dilema | Opción A | Opción B | Cuándo A, cuándo B |
|---|---|---|---|
| Rescatar commit perdido | `git reset --hard <sha>` | `git cherry-pick <sha>` | A si quieres volver *toda* tu rama a ese estado. B si quieres traerte *solo* ese commit a tu rama actual |
| Investigar sin cambiar estado | `git stash` + checkout | `git worktree add` | `stash` para < 30 min; `worktree` para cualquier cosa más larga o si vas a necesitar correr builds |
| Buscar origen de línea | `git blame` | `git log -S` | `blame` si la línea existe hoy; `-S` si quieres saber cuándo apareció y desapareció a lo largo del tiempo |
| Encontrar bug en N commits | Leer diffs | `git bisect run` | Si N ≥ 10 **y** hay un test determinista: `bisect run` siempre gana |
| Limpiar historia local | `git reflog expire --expire=now --all && git gc --prune=now` | No hacer nada | Casi nunca lo primero. Solo si realmente necesitas purgar un secreto *local*. |

---

## 9. Errores frecuentes

1. **"Perdí el trabajo, ya no está en `git log`"** — casi siempre está en `git reflog`. Siempre revisar antes de llorar.
2. **Confundir `log` con `reflog`** — `log` camina el DAG hacia atrás desde una ref. `reflog` recorre los movimientos *de esa ref en tu clon*. Son cosas distintas.
3. **Correr `git gc --prune=now` "para limpiar"** — borra objetos dangling. Si recién hiciste un reset o un rebase, mataste tu red de seguridad.
4. **`bisect` con test lento** — si tu test dura 20 min, bisectar 1000 commits son 200 min. Reduce el test al mínimo.
5. **`bisect` sin `skip` para commits que no compilan** — devuelve "bad" falso y te apunta al commit equivocado.
6. **Confundir `stash` con "guardar para después"** — se olvida en semanas. Prefiere un commit WIP en rama.
7. **`blame` sin `-w`** — reformats de whitespace muestran al autor equivocado.
8. **Olvidar que el reflog es local** — recién clonaste, no hay reflog. Nada que recuperar vía reflog en ese clon.
9. **Pushear después de un rebase en una rama compartida** — reescribes historia pública; el reflog ajeno no te salva. Regla de `gh-06`.
10. **`git bisect reset` olvidado** — te quedas en detached HEAD y confundes todo lo siguiente.

---

## 10. Buenas prácticas

- Antes de `reset --hard`: `git log --oneline -5` y `git stash list` para saber qué estás "cerrando".
- Después de cualquier operación destructiva local: *no cierres la terminal* hasta verificar que nada esencial falta. El reflog está, pero tu memoria también importa.
- Scripts para `bisect run` siempre con `set -u` y `timeout`.
- Nombra tus `stash`: `git stash push -m "refactor router mid-way"`.
- Si tu repo personal es importante: `gc.reflogExpire = 365.days.ago`.
- Haz un `git fetch` antes de bisectar: necesitas rango completo si tu `good` está upstream.
- Para debug de history-rewrite: `git log --oneline --graph --all --reflog` muestra incluso lo que ya no es reachable.
- Prefiere `worktree` sobre clones duplicados: comparten objetos.

---

## 11. Ejercicios guiados

### 11.1 — Recuperar un commit tras `reset --hard`

```bash
mkdir /tmp/ex1 && cd /tmp/ex1
git init -q -b main
git config user.email s@e && git config user.name s
for i in 1 2 3; do echo $i > f; git add .; git commit -q -m "c$i"; done
git reset --hard HEAD~2
# recupera c3 en main sin consultar notas
```

### 11.2 — Encontrar el commit que renombró e introdujo un bug

```bash
mkdir /tmp/ex2 && cd /tmp/ex2
git init -q -b main
git config user.email s@e && git config user.name s
echo "def ok(): return True" > a.py
git add . && git commit -q -m "add a.py"
git mv a.py b.py
git commit -q -m "rename"
sed -i.bak 's/True/False/' b.py && rm b.py.bak
git add . && git commit -q -m "oops"
# usa git log --follow + blame para encontrar quién puso 'False'
```

### 11.3 — `bisect run` con un script

Crea un repo de 10 commits donde el commit 6 introduce `rm -rf` en un script. Escribe un test que detecte "rm -rf" en el script y usa `git bisect run bash test.sh` para encontrarlo.

---

## 12. Evaluación

Responde sin consultar notas:

1. Después de `git reset --hard HEAD~5`, ¿qué objetos quedan huérfanos y en qué momento exacto los borra `git gc`? ¿Qué variables controlan el plazo?
2. ¿Por qué el reflog **no** te sirve si acabas de `git clone` un repo?
3. Diferencias prácticas entre `git reflog show main` y `git log main`.
4. ¿Qué códigos de salida espera `git bisect run` y qué significa cada uno?
5. En un `bisect` con 1024 commits entre `good` y `bad`, ¿cuántos ejecutaciones del test necesitas en el peor caso?
6. Un archivo fue renombrado tres veces. ¿Qué comando usas para seguir su historia completa? ¿Qué diferencia hay con `git log` normal?
7. Diseña un script `bisect-probe.sh` que: compile, ejecute `tests/regression.sh` con timeout de 2 minutos, salga 125 si no compila, 1 si falla, 0 si pasa. Escríbelo.
8. ¿Cuándo preferirías `git worktree add` sobre `git stash`? Da dos escenarios.

---

## Referencias

Ver `resources/links.md`.
