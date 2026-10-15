# Lección: Colaboración vía Pull Requests y revisiones

> **ID:** `gh-07-collaboration-prs-and-review` · **Nivel:** intermedio · **Duración:** 4 h
> **Prerrequisitos:** `gh-05` (GitHub), `gh-06` (rebase y limpieza de historia).

---

## 1. Introducción intuitiva

Imagina que trabajas en un repo con otras diez personas. Haces un cambio en tu rama local. Lo pusheas. ¿Y ahora qué? Si pudieras escribir directo en `main`, el repo sería un campo de minas: nadie habría leído tu cambio, ningún test habría corrido con el estado futuro de main, y una regresión costaría horas de bisect.

El **Pull Request** (PR) resuelve este problema. Es, literalmente, una petición: "por favor, consideren traer *mis commits de esta rama* a *esa rama*". Mientras la petición existe, hay un espacio donde:

- Un bot (CI) corre tests contra una simulación del merge.
- Humanos comentan en líneas específicas, proponen cambios con *suggestions*, aprueban o piden ajustes.
- Políticas del repo (`CODEOWNERS`, required reviewers, status checks) *bloquean* el merge hasta que se cumplen.
- Cuando se cierra, GitHub crea el commit de merge con la **estrategia** que elijas.

Un PR no es un email de "¿puedo?". Es un **objeto versionado**, con su propia página, sus propias refs, su propio hilo de conversación. Y lo más importante: **la mitad del valor de un PR está en la descripción y la revisión, no en el código**.

---

## 2. Fundamentos

### 2.1 Qué es técnicamente un PR

Un PR en GitHub referencia dos puntos del DAG:

- **Base**: la rama de destino (típicamente `main`).
- **Head**: la rama de origen (tu rama de trabajo, en el mismo repo o en un fork).

GitHub, en el momento en que se abre o actualiza el PR, crea **dos refs** en el repo base:

```
refs/pull/<N>/head    ← el tip de la rama head del PR
refs/pull/<N>/merge   ← un merge test: base + head mergeados en un commit efímero
```

Puedes verlas con:

```bash
git ls-remote origin 'refs/pull/*/head' 'refs/pull/*/merge'
```

Y **traer** una PR local con:

```bash
git fetch origin refs/pull/42/head:pr-42
git switch pr-42
```

Esto no requiere permisos de escritura en el fork del contribuidor. Es el truco por el que un maintainer puede probar una PR aun cuando el autor es un externo.

### 2.2 Fork vs. branch-based

Hay dos topologías principales:

- **Branch-based (shared-repo)**: todos los contribuidores tienen permiso de `push` al repo. Cada quien crea una rama (`feat/x`) y abre PR dentro del mismo repo. Es el modelo de la mayoría de equipos internos.
- **Fork-based**: contribuidor sin permiso de push al repo original. Hace *fork* a su cuenta, pushea a su fork, y abre un PR cross-repo. Es el modelo de open source y de contratistas sin acceso.

En **ambos** modelos el objeto PR es el mismo; cambia dónde vive la rama head.

### 2.3 Draft vs. ready for review

Un PR puede abrirse en modo **draft**: anuncia la intención, dispara CI, pero **no notifica reviewers ni permite merge**. Es la señal cultural correcta de "trabajo en curso, feedback bienvenido, no mergear". Pasar a *Ready for review* es el acto deliberado de pedir revisión.

### 2.4 Review tools

GitHub ofrece tres niveles de interacción:

- **Comment**: hilo normal (general del PR, o anclado a una línea).
- **Suggestion**: un bloque ```` ```suggestion ```` dentro de un comment; el autor puede *commitear* la sugerencia con un click. Es el formato correcto para "este nombre mejor así" o "falta un `return`".
- **Review decision**: *Comment* (sin decisión), *Approve* (verde), *Request changes* (rojo, bloquea merge si hay required reviewers).

Un *review* agrupa comments individuales en una entrega atómica. Sin esto, cada observación llegaría como notificación suelta.

### 2.5 Linked issues

GitHub cierra automáticamente issues cuando se mergea un PR cuyo cuerpo contiene uno de los *closing keywords*:

```
Fixes #123
Closes org/repo#456
Resolves #789
```

El issue cerrado queda enlazado al PR. Esto crea un rastro bidireccional "qué cambio resolvió qué requisito". Un PR sin `Fixes #` es un PR cuyo *por qué* es implícito, y los implícitos envejecen mal.

### 2.6 `CODEOWNERS`

Un archivo que mapea *patterns* a *owners*. Vive en una de tres rutas (GitHub busca en orden):

```
.github/CODEOWNERS
CODEOWNERS
docs/CODEOWNERS
```

Sintaxis mínima (una regla por línea; **la última regla que matchea gana**):

```
# default owner (fallback)
*                              @alice @bob

# path (directorio con trailing slash)
/docs/                         @docs-team

# glob por extensión
*.py                           @python-maintainers

# archivo específico
/.github/workflows/            @devops-team @alice
```

Cuando se abre un PR, GitHub inspecciona los archivos tocados, aplica las reglas y añade los owners como **reviewers sugeridos**. Si combinas `CODEOWNERS` con la opción *Require review from Code Owners* (en branch protection o Ruleset), esos reviewers pasan a ser **obligatorios**: el merge se bloquea sin su aprobación.

### 2.7 Required reviewers y auto-merge

- **Required reviewers**: política del repo, "mínimo N aprobaciones antes de mergear", opcionalmente "al menos una de un CODEOWNER", y "dismiss stale approvals cuando se hace push nuevo".
- **Auto-merge**: dejas el PR configurado para que se mergee *automáticamente* cuando todas las checks requeridas pasen y las aprobaciones estén presentes. Es la herramienta correcta para no estar "sentado esperando el verde".

### 2.8 Las tres estrategias de merge

GitHub permite tres (configurables por repo; puedes habilitar las que quieras):

- **Create a merge commit**: produce un commit de merge con dos padres (base y head). Conserva **todos** los commits originales y la **forma** de la rama en el DAG.
- **Squash and merge**: colapsa todos los commits del PR en **un solo** commit nuevo sobre base. Historia lineal, un commit por PR.
- **Rebase and merge**: aplica los commits del PR *uno a uno* sobre el tip de base (fast-forward si es posible). Historia lineal, conserva cada commit individual (pero con **hashes nuevos**).

Cada una produce un commit (o varios) distinto; lo exploramos en §4.3 y §8.

---

## 3. Contexto histórico

El concepto de **Pull Request** nació con GitHub en 2008. Antes, el flujo en open source era *patches por email* a una lista de correo: `git format-patch` + `git send-email`, el maintainer aplicaba con `git am`. Linux kernel sigue usando este modelo hoy; es más eficiente para proyectos con cientos de contribuidores por día, pero tiene una curva brutal para quien llega de la UI web.

GitHub popularizó la idea de que una rama *remota* podía ser **una conversación**: el PR fusiona el DAG (código) con un hilo de comentarios (contexto social). Esto cambió para siempre cómo se contribuye a open source: pasó de ser un ritual técnico a un acto de UX.

GitLab (2011) y Bitbucket (2008) adoptaron el mismo modelo con otros nombres (*Merge Request*). Hoy el PR/MR es *la* interfaz universal de colaboración en Git. Si trabajas con Git en producción, trabajas con PRs.

Dato relevante: el **PR template** y `CODEOWNERS` llegaron relativamente tarde (GitHub introdujo PR templates en 2016 y CODEOWNERS en 2017). Antes se improvisaban convenciones en el README. Hoy un repo profesional *tiene* los dos.

---

## 4. Funcionamiento interno

### 4.1 Refs de un PR

Al abrir el PR número `N`, GitHub crea en el repo base:

```
refs/pull/N/head     → el commit tip de la rama head en el momento actual
refs/pull/N/merge    → un commit efímero (dos padres: base_tip, head_tip)
                       que representa "cómo quedaría si mergeáramos ahora"
```

`refs/pull/N/merge` se **recomputa** cada vez que cambia la base o el head. Si hay conflicto, GitHub lo omite y marca la PR como "no mergeable".

Verificación práctica (en un repo que haya tenido PRs):

```bash
git ls-remote origin 'refs/pull/*/head' 'refs/pull/*/merge' | head
```

Por eso puedes hacer `git fetch origin refs/pull/42/head:pr-42` aun si el fork del autor es privado — GitHub expone la ref desde el repo *base*.

### 4.2 Qué pasa al abrir, actualizar, cerrar

- **Open**: GitHub crea `refs/pull/N/head` y `.../merge`, dispara workflows con `pull_request` como evento, aplica `CODEOWNERS` para sugerir reviewers.
- **Push a la rama head**: `refs/pull/N/head` avanza, `.../merge` se recomputa, se **reset** de aprobaciones si la política lo exige, se re-dispara CI.
- **Close**: las refs no se borran de inmediato (quedan accesibles para auditoría). El merge no ocurre.
- **Merge**: GitHub crea el commit según la estrategia elegida (§4.3), pushea a base, y marca el PR como *Merged*.

### 4.3 Qué commit crea cada estrategia

Supongamos base tip = `B`, head tiene commits `C1 → C2 → C3`.

**Merge commit (`--no-ff`)**:
```
... ─ A ─ B ─────────── M            ← nuevo commit M, 2 padres
                \      /
                 C1 ─ C2 ─ C3
```
`M.parents = [B, C3]`. `C1..C3` preservan autor, fecha, hash. `M` es nuevo (committer: GitHub, autor: quien pulsó el botón).

**Squash and merge**:
```
... ─ A ─ B ─ S                      ← nuevo commit S, 1 padre
```
`S.parent = [B]`. Contiene el *diff* combinado de `C1+C2+C3`, con un mensaje nuevo (por default: título del PR + concatenación de bullets). Los commits originales **no se referencian** desde base; viven solo en `refs/pull/N/head`.

**Rebase and merge**:
```
... ─ A ─ B ─ C1' ─ C2' ─ C3'        ← commits "nuevos" con hashes distintos
```
Cada `Ci'.parent = Ci-1'` (o `B` para el primero). Preserva el autor y mensaje, **pero cambia el hash** porque el committer o el parent cambia. No crea un merge commit; es fast-forward (no hay bifurcación en el DAG).

> **Consecuencia:** si tu CI firma attestations con el hash del commit, un *squash* o *rebase* en GitHub producen hashes distintos a los que probaste localmente. Lo cubrimos en `gh-13`.

### 4.4 Qué pasa en el repo del contribuidor tras merge

En **ninguna** estrategia GitHub borra la rama head por default (puedes activarlo con "Automatically delete head branches"). Y aun si la borra, los commits originales viven en `refs/pull/N/head` para siempre (según política de retención del repo). Puedes rescatarlos con `git fetch origin refs/pull/N/head`.

---

## 5. Ejemplo mínimo

Simulemos un PR *sin GitHub*, con un **bare repo local** como "remoto". Esto hace tangible lo que GitHub hace al abrir y mergear.

```bash
# 1. Preparar un "remoto" y un "clon"
rm -rf /tmp/pr-demo && mkdir -p /tmp/pr-demo && cd /tmp/pr-demo

git init --bare remote.git
git clone remote.git work
cd work
git -c user.name=Dev -c user.email=dev@example.com commit --allow-empty -m "chore: init"
git push -u origin main

# 2. Rama de feature (equivalente a "head" del PR)
git switch -c feat/greeting
echo 'print("hola, PR")' > greet.py
git add greet.py
git -c user.name=Dev -c user.email=dev@example.com commit -m "feat: add greet.py"
git push -u origin feat/greeting

# 3. "Abrir el PR" localmente = describir intención
mkdir -p .pr
cat > .pr/PR-1.md <<'EOF'
# PR-1: feat: add greet.py

## Summary
Añade un script de saludo mínimo.

## Changes
- greet.py: imprime "hola, PR".

## Linked issues
Fixes #1

## Test plan
- [x] python greet.py imprime "hola, PR".
EOF
git add .pr/PR-1.md
git -c user.name=Dev -c user.email=dev@example.com commit -m "docs(pr): describe PR-1"
git push

# 4. "Review" = otro clon aprueba
cd ..
git clone remote.git reviewer
cd reviewer
git fetch origin feat/greeting:feat/greeting
git switch feat/greeting
cat greet.py                 # revisa el código
mkdir -p .pr && echo "approved-by: @reviewer" > .pr/PR-1.approvals
git add .pr/PR-1.approvals
git -c user.name=Rev -c user.email=rev@example.com commit -m "chore(pr): approve PR-1"
git push

# 5. Merge con estrategia "squash" (equivalente a "Squash and merge")
cd ../work
git fetch
git switch main
git merge --squash feat/greeting
git -c user.name=Dev -c user.email=dev@example.com commit -m "feat: add greet.py (#1)

Fixes #1"
git push
git log --oneline --graph --all
```

Dos observaciones clave:
- **El PR no "existe" como entidad propia** en Git; existe como un acuerdo humano sobre qué rama trae qué, documentado en `.pr/PR-1.md` y las aprobaciones. GitHub lo hace primera clase; Git puro no.
- **`merge --squash` + `commit` manual** es el equivalente local del botón "Squash and merge". El commit resultante tiene **un solo padre** (`main` previo).

---

## 6. Implementación progresiva

Partimos del PR anterior y añadimos:

1. **PR template** reutilizable.
2. **CODEOWNERS**.
3. Cambio en `rebase and merge` como alternativa.

### 6.1 PR template reutilizable

```bash
cd /tmp/pr-demo/work
mkdir -p .github
cat > .github/PULL_REQUEST_TEMPLATE.md <<'EOF'
## Summary
<!-- ¿Qué problema resuelve este PR? 2–4 líneas. -->

## Changes
<!-- Lista de cambios de alto nivel. -->

## Linked issues
<!-- Fixes #N / Closes #N -->

## Test plan
- [ ] <describe cómo verificaste>

## Risk / rollback
<!-- ¿Qué podría romperse? ¿Cómo revertir? -->
EOF
git add .github/PULL_REQUEST_TEMPLATE.md
git -c user.name=Dev -c user.email=dev@example.com commit -m "chore(.github): add PR template"
git push
```

Al abrir una PR nueva en GitHub, el cuerpo se prellena con esto.

### 6.2 CODEOWNERS

```bash
cat > .github/CODEOWNERS <<'EOF'
# Default: todo el repo
*                               @alice @bob

# Docs
/docs/                          @docs-team

# Python
*.py                            @python-maintainers

# Workflows y configuración de CI
/.github/workflows/             @devops-team @alice
EOF
git add .github/CODEOWNERS
git -c user.name=Dev -c user.email=dev@example.com commit -m "chore(.github): add CODEOWNERS"
git push
```

Al abrir un PR que toque `greet.py`, GitHub asignaría a `@python-maintainers` como reviewer. Si tocara también `docs/README.md`, añadiría a `@docs-team`. Si fuera un cambio en `.github/workflows/ci.yml`, invocaría a `@devops-team @alice`.

### 6.3 Rebase and merge local

Equivalente local de "Rebase and merge":

```bash
git switch main
git fetch
git rebase origin/main          # ya estamos actualizados
# Trae los commits de la rama uno a uno, sin merge commit
git switch -c probe
git merge --ff-only feat/greeting
```

Si no es fast-forward posible, primero rebaseas la rama feature sobre main (`git rebase origin/main` desde `feat/greeting`) y luego `merge --ff-only`. Resultado: historia lineal, cada commit visible.

---

## 7. Aplicación profesional

### 7.1 Un PR bueno

Un PR revisable en 90 segundos tiene:

1. **Título imperativo, imperativo, conciso.** `fix(parser): handle empty input` → sí. `Changes` → no.
2. **Summary de 2–4 líneas** respondiendo *qué* y *por qué*. El *qué* se puede leer del diff; el *por qué* no.
3. **Changes bulleted** de alto nivel. No describas línea por línea; eso es el diff.
4. **Linked issues** con closing keyword. `Fixes #123`.
5. **Test plan**. Cómo verificaste. Un checkbox que diga "corrió la suite" **no es** test plan.
6. **Riesgo / rollback** cuando el cambio toca algo delicado.
7. **Diff pequeño**. 400 líneas o menos. Más que eso, divide en varios PRs.
8. **Un solo tema**. Si el título necesita "y", divide.

### 7.2 Una review buena

- **Primera pasada**: lee la descripción. Si no entiendes el *por qué*, pide clarificación antes de mirar el código.
- **Segunda pasada**: lee los tests. Si entiendes qué debe pasar, entenderás el código.
- **Tercera pasada**: el código. Marca:
  - **Must**: incorrecto, bug, security, breaking contract. Usa *Request changes*.
  - **Should**: mejora clara. Usa *suggestion* para bajarle el costo al autor.
  - **Nit** o **optional**: estética. Marca que es opcional. No bloquees por nits.
- **Terminar con una pregunta útil**, no con "LGTM" vacío. "¿Por qué elegiste X sobre Y?" vale más que 10 "ok".
- **Approve** cuando harías *tú* el merge sin dudar. Un approve con dudas es ruido.

### 7.3 Scope creep

El error más común de un contribuidor es ampliar el PR durante la revisión: "ya que estoy aquí, limpio esto otro". Mala idea:

- La revisión se re-dispara desde cero.
- El riesgo del PR crece sin que crezca la discusión original.
- El cambio queda invisible dentro de otro cambio.

Regla: si descubres algo que *no* es el objetivo del PR, **abre un issue** y referencialo. Nunca lo metas en el mismo PR.

### 7.4 Elegir estrategia de merge

| Estrategia | Historia resultante | Cuándo elegirla |
|------------|---------------------|-----------------|
| **Merge commit** | DAG con bifurcaciones; cada PR es visible como una "burbuja". | Equipos que valoran contexto (quién mergeó qué agrupamiento). Cuando los commits internos del PR *importan* para debug (p. ej. bisect por fases). |
| **Squash and merge** | Lineal, 1 commit por PR. | Repos donde el PR es la unidad de verdad; el ruido intermedio ("fix typo", "wip") no aporta. Default razonable para la mayoría. |
| **Rebase and merge** | Lineal, 1 commit **por commit** del PR. | Equipos con disciplina estricta de "cada commit atómico, pasa tests por sí mismo". Facilita `git bisect` fino. Requiere que los autores limpien historia antes de pedir merge. |

Un repo serio **elige una** y la aplica consistentemente. Mezclar las tres degrada la utilidad de la historia.

### 7.5 Auto-merge en la práctica

Habilitar auto-merge requiere:
- Branch protection / Ruleset con **required status checks**.
- Required reviewers (al menos 1 CODEOWNER si procede).
- `gh pr merge --auto --squash` (o UI). GitHub lo mergea cuando *todo* pase.

Esto cierra el loop: subes la PR, pides review, te vas, GitHub mergea cuando esté listo.

---

## 8. Trade-offs

### 8.1 Fork vs. branch-based

| Dimensión | Branch-based | Fork-based |
|-----------|--------------|------------|
| Permisos | Todos los contribs tienen push al repo | Solo maintainers; externos pushean a su fork |
| Fricción contribuidor | Baja | Media (hay que forkear, mantener fork sincronizado) |
| Protección natural | Depende solo de branch protection | El fork protege de "push accidental a main" |
| Uso típico | Equipos internos | Open source, consultoría |

### 8.2 Squash vs. merge commit vs. rebase (en profundidad)

- **Merge commit**: `git log --oneline` lee ruidoso; `git log --graph` lee bien. Facilita entender "qué agrupamiento de cambios entró". Dificulta `git revert` si el commit a revertir es intermedio.
- **Squash**: `git log --oneline` lee lineal y claro. `git revert <sha>` revierte el PR entero con un comando. Pierde los commits atómicos originales (viven en `refs/pull/N/head`, no en la rama).
- **Rebase**: lineal **y** granular. `git bisect` encuentra bugs con precisión fina. Exige que el autor haga *rebase interactivo* antes de pedir merge; equipos sin disciplina generan historia sucia igual.

### 8.3 CODEOWNERS vs. required reviewers "a mano"

- `CODEOWNERS` **sugiere** por default; **obliga** cuando se activa "Require review from Code Owners". Es declarativo y versionado — vive en el repo, revisable como código.
- Required reviewers configurados a mano en la UI son un cambio *fuera del repo*; no auditables desde `git log`.
- Recomendación: usa CODEOWNERS + "Require review from CODEOWNERS" + N aprobaciones mínimas. Evita listas de reviewers en la UI.

### 8.4 PR template único vs. múltiple

- `.github/PULL_REQUEST_TEMPLATE.md` (único): se usa en todos los PRs. Simple, suficiente para la mayoría.
- `.github/PULL_REQUEST_TEMPLATE/<name>.md` (múltiple): se eligen vía query param `?template=<name>.md`. Útil cuando hay flujos muy distintos (bugfix vs. release vs. docs). Más fricción (hay que recordar el link).

### 8.5 Draft PR vs. no abrir todavía

Abrir *draft* temprano cuesta ~0 y:
- Dispara CI (feedback inmediato de rotura).
- Hace tu trabajo visible (evita duplicados).
- Permite feedback en diseño antes de haber escrito 2 días de código.

No hay razón defendible para "esperar a tenerlo todo antes de abrir el PR" si tu plataforma soporta drafts.

---

## 9. Errores frecuentes

### 9.1 PR gigante ("let me know what you think")

Diff de 2.000 líneas tocando 40 archivos. Nadie lo revisa de verdad. Se aprueba por cansancio. Fix: divide. Si no puedes dividir, divide igual.

### 9.2 Descripción vacía o copiada del template

Un PR con "see commits for details" no es revisable. El reviewer tiene que reconstruir la intención a partir del diff; eso es trabajo del autor, no del reviewer.

### 9.3 Scope creep mid-review

Durante la revisión, el autor empuja "ya que estoy, arreglé esta otra cosa". La review tiene que empezar de cero. Fix: nuevo PR o nuevo issue.

### 9.4 `request changes` por nits

Usar el botón rojo para "este nombre podría ser más corto" congela el PR por horas o días. Fix: comment o suggestion, no request changes.

### 9.5 "Fixes #" en el commit en vez del cuerpo del PR

GitHub cierra el issue si el keyword está en **el cuerpo del PR o en el commit del merge**. Si lo pones solo en el commit *de la rama* y luego eliges *squash*, el commit real que se mergea es nuevo y puede no incluirlo. Mejor en el **cuerpo del PR**.

### 9.6 Mergear con la estrategia equivocada

Repo configurado como "squash only", autor pide "rebase and merge" para preservar los commits atómicos. O al revés. Fix: configurar el repo con **una sola** estrategia habilitada; evita el error.

### 9.7 `CODEOWNERS` con usuarios/teams que ya no existen

GitHub ignora silenciosamente los owners inválidos. El PR queda sin reviewers y nadie se entera. Fix: validar con `gh api repos/{owner}/{repo}/codeowners/errors` cuando se cambia el archivo.

### 9.8 Approve propio

El autor del PR **no puede** aprobarlo. Suena obvio; aun así es la causa más común de "estoy esperando aprobación de alguien".

---

## 10. Buenas prácticas

- **Draft desde el minuto 1** si el trabajo tomará más de un día.
- **Un PR = un tema = un issue linkeado.** Si no cabe en una frase, divide.
- **≤ 400 líneas de diff.** Rara vez una excepción se justifica.
- **PR template con *Risk / rollback*.** La pregunta correcta no es "¿funciona?" sino "¿cómo lo deshago?".
- **CODEOWNERS versionado y validado.** Audita trimestralmente: gente que se fue, teams renombrados.
- **Required reviewers = 1 CODEOWNER + 1 approval.** Más que eso es ritual.
- **Auto-merge activo** una vez que confías en CI. Es tiempo que recuperas.
- **Suggestions en vez de "please change X".** Baja el costo del cambio a un click.
- **Una estrategia de merge por repo.** Decide, documenta, cumple.
- **Nunca mergees tu propio PR si hay reviewers requeridos.** Aunque *técnicamente* puedas tras aprobación.
- **Branch protection + Rulesets** son el único "no" real. La disciplina humana no basta.

---

## 11. Ejercicios recomendados

1. **`activities/01-open-review-merge-pr/`** — simula (o abre) un PR, lo revisa, lo mergea con estrategia justificada. Guided-lab, con `MODE=local` por default y `MODE=live` opcional.
2. **`activities/02-codeowners-and-required-reviews/`** — redacta `CODEOWNERS` y PR template para un repo multi-equipo. Guided-lab.

---

## 12. Evaluación

Responde sin consultar la lección. Si tienes que buscar, re-lee la sección correspondiente.

**P1.** ¿Qué refs crea GitHub al abrir el PR número 42? (marca todas las correctas)
   - [ ] `refs/heads/pr-42`
   - [ ] `refs/pull/42/head`
   - [ ] `refs/pull/42/merge`
   - [ ] `refs/remotes/origin/pr-42`

**P2.** Describe en 2–3 frases **qué commit** crea GitHub en cada una de las tres estrategias de merge, en términos de **padres** y **hashes**.

**P3.** Un contribuidor externo (sin permiso de push) abre PR desde su fork a tu repo. Tras la review quieres probar su rama local. ¿Qué comando `git fetch` usas y por qué funciona aun si el fork es privado?

**P4.** Verdadero / falso:
   - [ ] `CODEOWNERS` por sí solo bloquea el merge si falta aprobación del owner.
   - [ ] Un PR en *draft* dispara CI pero no notifica reviewers.
   - [ ] `Fixes #123` en el cuerpo del PR cierra el issue al mergear, incluso con estrategia *squash*.
   - [ ] "Rebase and merge" en GitHub preserva los hashes originales de los commits.

**P5.** Un reviewer pulsa *Request changes* para pedir que renombres una variable (de `x` a `data`). ¿Qué hiciste mal en el proceso y cómo deberías haberlo hecho? (razona ambos lados.)

**P6.** Tu equipo discute entre *squash and merge* y *merge commit*. El repo es una API con release mensual y necesitan `git bisect` para hunting de regresiones ocasional. ¿Qué estrategia recomendarías y por qué? ¿Y si en vez de API fuera una librería con contributors ocasionales y PRs de 1–5 commits bien atómicos?

**P7.** Un `CODEOWNERS` tiene estas dos reglas, en este orden:
```
*.py           @python-team
/src/api/      @api-team
```
Un PR toca `src/api/handlers.py`. ¿Quién es owner asignado? Justifica.

**P8.** Diseño: un repo nuevo de 8 personas, con 2 seniors y 6 juniors, va a aplicar branch protection. Define: estrategia de merge habilitada, políticas de reviewers, uso de CODEOWNERS, cuándo usar draft, uso de auto-merge. Justifica cada elección en 1–2 frases.

---

## Referencias

Documentación oficial (consultada 2026-10):

- **About pull requests** — <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests>
- **About pull request merges (merge strategies)** — <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/about-pull-request-merges>
- **About code owners (`CODEOWNERS`)** — <https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners>
- **Creating a pull request template for your repository** — <https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/creating-a-pull-request-template-for-your-repository>
- **Linking a pull request to an issue** (closing keywords) — <https://docs.github.com/en/issues/tracking-your-work-with-issues/linking-a-pull-request-to-an-issue>
- **Automatically merging a pull request (auto-merge)** — <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/automatically-merging-a-pull-request>
- **`gh pr` CLI reference** — <https://cli.github.com/manual/gh_pr>
- **About protected branches / Rulesets** — <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches>

Lectura complementaria:

- Chacon/Straub, *Pro Git* cap. 6 "GitHub".
- *How to write a Git commit message*, Chris Beams — <https://cbea.ms/git-commit/> (aplicable al título del PR).
- *The art of code review*, varios autores en engineering blogs (Google, Microsoft, ThoughtBot) — buscar "code review guidelines".
