# Lección: Marketplace actions y bases de reutilización

> **ID:** `gha-04-marketplace-actions-and-basics-of-reuse` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** `gha-01-model-and-first-workflow`.

---

## 1. Introducción intuitiva

En `gha-01` escribiste tu primer workflow. Casi seguro empezó así:

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-python@v5
```

Eso **funciona**. Y a la vez, eso **es** una decisión de seguridad que probablemente no tomaste de forma consciente. En este módulo vamos a desarmarla.

Un `uses:` no es "importar una librería inocente". Es decir: *"ejecuta este código de un tercero dentro de mi runner, con acceso a mi workspace, a mis variables de entorno, a `GITHUB_TOKEN`, y potencialmente al secreto que vas a usar dos steps más abajo"*. Y a diferencia de `pip install cryptography==42.0.5` donde la versión está pinneada por hash en `poetry.lock`/`Pipfile.lock`, un `uses: owner/action@v4` por default **no está pinneado por hash**. Depende de un tag Git, y los tags Git son **mutables**.

El escenario que vamos a dominar:

```
┌──────────────────────────────────────────────────────────┐
│  tu workflow .github/workflows/ci.yml                    │
│                                                          │
│    uses: actions/checkout@v4   ◄──── ¿qué commit?        │
│    uses: tj-actions/x@v3       ◄──── ¿quién lo mantiene? │
│    uses: badguy/helper@main    ◄──── ¡puede cambiar hoy! │
└───────────────────────┬──────────────────────────────────┘
                        │ resuelve ref → SHA → clona → corre
                        ▼
                 ┌─────────────────┐
                 │  GitHub runner  │   TOKEN, SECRETS,
                 │  (tu VM)        │   WORKSPACE, NET
                 └─────────────────┘
```

El objetivo de esta lección: que al final puedas mirar cualquier `uses:` de cualquier workflow y, en 30 segundos, decir **si es seguro, si no lo es, y qué habría que cambiar**.

---

## 2. Fundamentos

### 2.1 Qué es exactamente una "action"

Una **action** es una unidad reutilizable que vive en un repositorio Git (típicamente GitHub) y que un workflow invoca con la keyword `uses:`. Técnicamente son tres cosas distintas empaquetadas bajo la misma interfaz:

| Tipo | Qué contiene | Cómo corre | Ejemplo oficial |
|------|--------------|------------|-----------------|
| **JavaScript** | `action.yml` + código JS (Node 20 por default) | El runner ejecuta `node main.js` directamente en el host | `actions/checkout`, `actions/setup-python`, `actions/cache` |
| **Docker container** | `action.yml` + `Dockerfile` o imagen prebuilt | El runner hace `docker build` (o `docker pull`) y `docker run` | `hashicorp/setup-terraform` (en algunas versiones), muchas de linting |
| **Composite** | `action.yml` con `runs.using: composite` y una lista de `steps:` (shell o `uses:`) | El runner expande los steps **in-place** en el job que la invoca | `actions/setup-node` con cache integrada; cualquier action propia que agrupe pasos |

Diferencias con impacto real:

- **JS actions** son las más rápidas (sin overhead de contenedor). Dependen del Node del runner.
- **Docker actions** solo corren en runners Linux x86_64 por default. Añaden latencia de build/pull. Pero son el único tipo que te permite empaquetar un binario arbitrario (ej. una CLI escrita en Go).
- **Composite actions** no son un lenguaje nuevo: son una forma de agrupar steps YAML. **Se expanden en el mismo runner y comparten su entorno**: variables, PATH, workspace. Esto importa cuando se habla de permisos.

Todas tres se referencian igual: `uses: owner/repo@<ref>`.

### 2.2 Anatomía de `uses:` — `owner/repo@ref` (+ opcional subpath)

```yaml
uses: actions/checkout@v4
#     └─────┬─────┘ └┬┘
#           │        └── ref: tag | branch | commit SHA
#           └── owner/repo (en GitHub)
```

Variantes:

```yaml
# a) tag de major (lo que la mayoría del Marketplace recomienda)
uses: actions/checkout@v4

# b) tag exacto (semver completo)
uses: actions/checkout@v4.2.2

# c) branch
uses: actions/checkout@main

# d) commit SHA (40 chars) — ESTA es la forma segura
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

# e) subpath dentro de un repo (ej. monorepo de actions de una org)
uses: my-org/actions/.github/actions/setup@abc...  # v1.0.0

# f) action local al propio repo
uses: ./.github/actions/my-composite

# g) action en un contenedor Docker directamente
uses: docker://alpine:3.19
```

De todas, la única que te garantiza **inmutabilidad** es la (d). Las razones vienen en §2.4.

### 2.3 Los tres grupos de confianza

Antes de pinnear, decide **si quieres esa action en tu pipeline**. Taxonomía útil:

| Grupo | Qué es | Política razonable |
|-------|--------|---------------------|
| **1. Oficiales de GitHub** (`actions/*`, `github/*`) | Mantenidas por GitHub. Auditadas, firmadas por GitHub Verified. | `@v4` o similar aceptable en repos privados; **SHA siempre** en public/producción. |
| **2. Trusted vendors** | Vendor con marca y responsabilidad: `hashicorp/*`, `docker/*`, `aws-actions/*`, `google-github-actions/*`, `azure/*`, `pulumi/*`. | **SHA + Dependabot**. Tratarlas como una lib externa seria. |
| **3. Terceros desconocidos** | Un usuario personal con 200 estrellas. | **SHA siempre** y fork del repo si vas a depender fuerte. Idealmente, re-escribirla como composite propia. |

El incidente real que ancla esto en memoria: en **marzo de 2025**, la action popular `tj-actions/changed-files` fue comprometida: alguien reescribió sus tags para apuntar a un commit malicioso que exfiltraba secretos a través de logs. Miles de workflows que la usaban como `@v45` ejecutaron el payload **sin cambiar una línea de código propio**. Los que la usaban con pin a SHA no se vieron afectados. Esta no es una historia hipotética — es la razón concreta por la que este módulo existe.

### 2.4 Por qué los tags de Git son mutables

Un tag en Git es un **ref** — un archivo en `.git/refs/tags/vX.Y.Z` que contiene un hash de commit (ligero) o apunta a un objeto *tag* (anotado). Reescribirlo es trivial:

```bash
git tag -d v1.0.0                 # borra el tag local
git push origin :refs/tags/v1.0.0 # borra el tag remoto
git tag v1.0.0 <otro-commit>      # vuelve a crearlo
git push origin v1.0.0            # subelo
```

Nada en el protocolo lo impide. La `v4` de una action puede apuntar hoy al commit `abc123` y mañana al commit `def456`, sin que tú lo veas. Peor: muchas actions oficiales *intencionalmente* mueven el tag mayor (`v4`) hacia adelante cuando sacan una nueva minor (`v4.2.3`), para que `@v4` siempre te traiga "la última v4 compatible". Es cómodo. Es también la superficie de ataque.

GitHub tampoco firma los tags por default (eso cambia con `attest-build-provenance`, pero es `gha-14`). El único string que **sí** es inmutable en Git es un **commit SHA de 40 caracteres**: cambiar un bit del commit cambia el SHA, por diseño. Un pin a SHA es equivalente a un `requirements.txt` con hashes.

Diagrama mental:

```
    tag  v4  ─────► commit abc123   (hoy)
                        │
                        │ el maintainer re-apunta v4
                        ▼
    tag  v4  ─────► commit def456   (mañana)

    SHA abc123 ──► commit abc123   (hoy, mañana, siempre;
                                     cambiarlo requeriría romper SHA-1)
```

### 2.5 El patrón canónico: SHA + comentario de versión

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

Dos piezas:

1. **El SHA**: lo que el runner realmente usa. Es la ancla de inmutabilidad.
2. **El comentario con la versión semver**: para humanos y para **Dependabot**. Sin él, nadie sabe si estás 3 majors atrás.

Dependabot (ver §5) lee el comentario, mira si hay una versión más nueva, y abre un PR con el nuevo SHA + comentario actualizado. Es el workflow que hace sostenible el pinning: "pinneo todo a SHA, pero una vez por semana reviso PRs de Dependabot y acepto los que pintan bien".

Si omites el comentario, pierdes la actualización semi-automática. Si omites el SHA, pierdes la seguridad. Los dos juntos son la práctica.

### 2.6 Cómo resolver un tag a su SHA

Tres maneras equivalentes:

```bash
# 1) Con gh (lo más común si ya estás auth)
gh api repos/actions/checkout/git/refs/tags/v4.2.2 --jq '.object.sha'
# -> 11bd71901bbe5b1630ceea73d27597364c9af683

# 2) Con git ls-remote (no requiere auth)
git ls-remote https://github.com/actions/checkout.git refs/tags/v4.2.2
# -> 11bd71901bbe5b1630ceea73d27597364c9af683  refs/tags/v4.2.2

# 3) Mirando el commit en la UI: github.com/actions/checkout/releases/tag/v4.2.2
```

**Precaución con tags anotados**: `gh api .../git/refs/tags/<v>` te devuelve el SHA del **objeto tag**, no del commit. Para muchas actions el objeto *es* el commit (tag ligero) y da igual. Para tags anotados debes dereferenciar con `^{}` o pedir el peeled ref:

```bash
git ls-remote https://github.com/actions/checkout.git 'refs/tags/v4.2.2^{}'
```

El SHA que corre es el del **commit**. Si pinneas al SHA del *tag object*, GitHub Actions igual lo resuelve (lo dereferencia), pero el patrón limpio es usar el SHA del commit.

---

## 3. Entidades y relaciones

Entidades que viven en este módulo:

- **Workflow** — archivo YAML en `.github/workflows/`.
- **Step** — una entrada en `steps:`, que ejecuta `run:` o `uses:`.
- **Action** — repo externo (o local) referenciado por `uses:`.
- **Ref** — el string después del `@`: tag, branch o SHA.
- **Marketplace entry** — página de GitHub Marketplace que lista actions "publicadas", pero *todas* las actions son solo repos públicos; el Marketplace es índice, no es garantía.
- **Verified creator** — badge de GitHub que indica que la org publicadora pasó verificación; no implica auditoría del código.
- **Dependabot config** — `.github/dependabot.yml` con `package-ecosystem: github-actions` que vigila los pins.

Flujo:

```
          workflow.yml
                │
                │ uses: owner/repo@<ref>
                ▼
    GitHub Actions service resuelve <ref>
      - si es SHA de 40 hex: lo usa directo
      - si es tag/branch: consulta refs del repo → SHA
                │
                │ clona el repo de la action al runner (o pull si es docker)
                ▼
    Runner ejecuta la action
       - lee action.yml → runs.using (node20 | docker | composite)
       - le pasa `with:` como inputs
```

---

## 4. Modelo mental

Tres ejes para mirar un `uses:` ajeno:

1. **¿De quién es?** → first-party / trusted / terceros desconocidos.
2. **¿Cómo se referencia?** → SHA / tag exacto / tag mayor / branch.
3. **¿Qué puede hacer?** → ¿este step corre antes o después de que algún secreto esté expuesto en el runner? ¿puede leer el workspace del repo? ¿tiene `permissions:` sobre el `GITHUB_TOKEN`?

Combinando ejes, la decisión práctica es casi siempre la misma:

```
                   first-party        trusted vendor       tercero desconocido
   repo privado    @v4 OK             @SHA+comment         @SHA, considera fork
   repo público    @SHA+comment       @SHA+comment         @SHA, considera fork
   producción      @SHA+comment       @SHA+comment         ⚠ auditar primero
```

Un pin a SHA no te libra de pensar — un maintainer puede sacar una `v4.9.9` maliciosa y Dependabot proponerte el PR. **El pin congela el pasado; la revisión humana cuida el futuro**. Las dos son necesarias.

---

## 5. Mecanismos internos

### 5.1 Qué pasa cuando el runner ve `uses:`

Pseudo-código del comportamiento del runner:

```
for step in job.steps:
    if step.uses:
        owner, repo, ref = parse(step.uses)
        if is_sha40(ref):
            commit = ref
        else:
            commit = github_api.resolve_ref(owner, repo, ref)   # ← aquí entra la mutabilidad

        clone(owner, repo, commit) into _actions/<owner>/<repo>/<commit>/
        action_yml = read("_actions/.../action.yml")

        match action_yml.runs.using:
            case "node20": exec node _actions/.../main.js
            case "docker": docker build/pull + docker run
            case "composite": inline-expand action_yml.runs.steps
```

Observa la línea del `resolve_ref`: ocurre **cada vez** que se dispara el workflow. Si el maintainer cambia el tag entre runs, el run siguiente trae otro commit. Un pin a SHA salta esa línea.

### 5.2 Qué garantiza Dependabot

Dependabot es un servicio managed de GitHub que:

1. Lee tu `.github/dependabot.yml`.
2. Para `package-ecosystem: github-actions` escanea tus workflows en busca de `uses:`.
3. Compara el **comentario** (`# v4.2.2`) o el tag inferido con el último release del repo origen.
4. Abre un PR que reescribe la línea con el nuevo SHA + el nuevo comentario.

Config mínima:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

Lo que **no** hace: no audita el código del nuevo commit. Confía en que si tú (o Renovate, u otra herramienta) decides mergear el PR, aceptas lo que trae. Dependabot sí marca con security advisories (GHSA) PRs de versiones con CVE conocida.

### 5.3 Cómo se expande una composite action

Tomemos una composite action simple:

```yaml
# .github/actions/setup-python-poetry/action.yml
name: Setup Python + Poetry
runs:
  using: composite
  steps:
    - uses: actions/setup-python@0b93645e9fea7318ecaed2b359559ac225c90a2b  # v5.3.0
      with:
        python-version: ${{ inputs.python-version }}
    - run: pipx install poetry
      shell: bash
```

En el job que la invoca:

```yaml
steps:
  - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
  - uses: ./.github/actions/setup-python-poetry
    with: { python-version: '3.12' }
  - run: poetry install
```

El runner **no** salta a otro job: expande los steps de la composite in-place. Resultado efectivo (lo que ejecuta):

```
step 1: checkout
step 2a: setup-python   (venía de la composite)
step 2b: pipx install poetry   (venía de la composite)
step 3: poetry install
```

Implicación: una composite action **hereda** el `GITHUB_TOKEN`, los secretos, el workspace y las env vars del job llamador. Esto es diferente de un **reusable workflow** (`workflow_call`), que define jobs separados con sus propios runners y permisos — eso va en `gha-08`.

---

## 6. Operación básica (comandos y uso)

### 6.1 Resolver un tag a SHA (sin tocar nada)

```bash
# Elige la action y la versión que quieras usar
OWNER=actions; REPO=setup-python; TAG=v5.3.0

# Con gh
gh api "repos/$OWNER/$REPO/git/refs/tags/$TAG" --jq '.object.sha'

# Sin auth
git ls-remote "https://github.com/$OWNER/$REPO.git" "refs/tags/$TAG"
# o para el commit real (dereferenciando tags anotados):
git ls-remote "https://github.com/$OWNER/$REPO.git" "refs/tags/$TAG^{}"
```

### 6.2 Reescribir un workflow para pinnear todo

Script esqueleto (lo rehacemos en el ejemplo 02):

```bash
# Para cada `uses: owner/repo@tag`, deja esto:
#   uses: owner/repo@<SHA>  # <tag>
# El reemplazo manual es seguro y pedagógico la primera vez.
# Para repos grandes existen tools: pin-github-action, ratchet, frizbee.
```

### 6.3 Habilitar Dependabot para actions

```bash
mkdir -p .github
cat > .github/dependabot.yml <<'EOF'
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule: { interval: "weekly" }
    groups:
      actions:
        patterns: ["*"]   # agrupa todas las actions en un PR por semana
EOF
git add .github/dependabot.yml
git commit -m "chore: enable Dependabot for GitHub Actions"
```

### 6.4 Lintear localmente

```bash
# actionlint cubre sintaxis, expresiones y algunas prácticas de seguridad
brew install actionlint      # macOS
# o: curl -L ... (ver docs)
actionlint .github/workflows/*.yml
```

`actionlint` **no** falla por falta de pin a SHA por default — pero sí hay reglas custom (ej. [`pinact`](https://github.com/suzuki-shunsuke/pinact), [`zizmor`](https://github.com/woodruffw/zizmor)) que sí.

---

## 7. Errores comunes y antipatrones

| Antipatrón | Qué pasa | Cómo arreglarlo |
|-----------|----------|-----------------|
| `uses: owner/action@main` | Cada run trae el HEAD de main. Un push al repo origen cambia tu pipeline **sin PR**. | Pin a SHA de un release. |
| `uses: owner/action@master` | Igual que anterior, además señal de que el repo origen es viejo / sin mantenimiento. | Pin a SHA + evalúa alternativa. |
| `uses: owner/action@v4` sin comentario | Vulnerable a reescritura del tag mayor. Dependabot no puede proponerte la actualización porque no sabe de qué versión vienes. | Pin a SHA **con** comentario `# v4.x.y`. |
| Pinnear a SHA **sin** comentario | Seguro pero inmantenible: nadie sabe de qué versión vienes. | Añadir el comentario con el tag equivalente. |
| Copiar actions de blogs sin verificar el autor | Puedes importar una action de un usuario con 2 estrellas y 0 CI. | Mirar: estrellas, commits recientes, issues abiertos, `verified creator`, código del `action.yml`. |
| Pinnear al SHA del **tag object** anotado (no del commit) | Funciona, pero confunde a Dependabot y a humanos. | Usar siempre el SHA del commit (`refs/tags/<tag>^{}`). |
| `pull_request_target` + action de tercero sin pin | Cocktail de ataque documentado: el fork puede inyectar código que corre con tus secretos. Ver `gha-03`. | SHA pin + revisar permisos + preferir `pull_request`. |
| "Es solo un repo privado, da igual" | Un repo privado también tiene secretos (deploy keys, cloud creds). | Mismas reglas; concesión: `@v4` tolerable para actions **first-party de GitHub**. |

---

## 8. Riesgos y seguridad

Tres riesgos reales:

### 8.1 Supply chain de actions

Documentado por GitHub ("Security hardening for GitHub Actions"): una action de tercero es código ejecutado con los permisos del job. Mitigaciones:

- Pin a SHA.
- `permissions:` restrictivo (default `contents: read`, escalada selectiva por job). Esto se trabaja a fondo en `gha-05`.
- `GITHUB_TOKEN` scope mínimo.
- No pasar secretos a actions sin verificar que los necesitan.

### 8.2 Script injection vía inputs

No es tema estricto de este módulo (va en `gha-02`), pero es cercano: si una action acepta un `with:` que luego interpola en un shell sin cuidado, un PR malicioso puede ejecutar código. Pin a SHA no te salva de esto si la action en sí es vulnerable.

### 8.3 Falsa sensación de seguridad del Marketplace

El badge **Verified** del Marketplace significa que GitHub verificó la **identidad del publisher** (dominio, pago). **No** significa que GitHub auditó el código. Tratar `verified` como garantía de calidad es un error común.

Caso práctico: una action verificada puede pasar a un maintainer malicioso vía transferencia o compromiso de cuenta. El historial de la industria ya tiene ejemplos.

---

## 9. Observabilidad y verificación

Qué mirar y cómo:

- **Qué commit corrió realmente**: en los logs de la UI de Actions, GitHub muestra `Download action repository 'owner/repo@<ref>'` y el commit resuelto. Si pinneas a SHA, verás ese SHA tal cual.
- **Diff entre dos ejecuciones**: `gh run view <id> --log | grep "Download action"`.
- **Qué actions usa un repo entero**: `grep -rhE '^\s*uses:' .github/workflows/`.
- **Cuáles no están pinneadas** (grep básico):

  ```bash
  # imprime las líneas que probablemente no están pinneadas a SHA
  grep -rhE '^\s*uses:\s+[^@]+@[^0-9a-f]' .github/workflows/ \
    || grep -rhE '^\s*uses:\s+[^@]+@[0-9a-f]{1,39}([^0-9a-f]|$)' .github/workflows/
  ```

- **Auditoría formal**: herramientas como [`zizmor`](https://github.com/woodruffw/zizmor), [`pinact`](https://github.com/suzuki-shunsuke/pinact) o la propia regla `shellcheck`-like de actionlint.

Ejemplo de lo que debería leerse "limpio":

```
.github/workflows/ci.yml:
  uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2   ✓
  uses: actions/setup-python@0b93645e9fea7318ecaed2b359559ac225c90a2b  # v5.3.0  ✓
  uses: actions/cache@6849a6489940f00c2f30c0fb92c6274307ccb58a  # v4.1.2  ✓
```

---

## 10. Alternativas y comparación

| Opción | Cuándo tiene sentido |
|--------|----------------------|
| **Pin a SHA + Dependabot** | Default moderno. Lo que enseñamos acá. |
| **Pin a tag exacto `@v4.2.2`** | Mejor que `@v4`, peor que SHA. Un tag exacto *también* es reescribible aunque sea más raro. Útil solo como compromiso de legibilidad en orgs con auditoría estricta de PRs. |
| **Fork propio + pin a SHA** | Cuando dependes fuerte de una action de un tercero y quieres soberanía: forkeas el repo a tu org y pinneas al SHA de tu fork. Añade mantenimiento. |
| **Reescribir como composite propia** | Si la action externa es simple (5 líneas de bash), copiarla a `.github/actions/foo/` es un *trade* bueno: una dependencia menos. |
| **Reusable workflow (`workflow_call`)** | Para reutilizar *jobs enteros* a nivel org, no solo pasos. Es `gha-08`. |
| **Runners self-hosted con imagen sellada** | Mitigación paralela, no sustitutiva. Es `gha-10`. |
| **No usar actions en absoluto** | Sí existe: workflows 100% `run:` con shell. Pierdes reutilización pero reduces superficie a cero. Práctico en orgs con compliance alto. |

Comparación con otras plataformas:

- **GitLab CI/CD**: los `include:` también pueden pinnearse a SHA. Mismo problema con tags.
- **CircleCI orbs**: tienen versionado semver, también pinneable, con menos cultura de SHA pin.
- **Jenkins Shared Libraries**: pueden pinnearse al commit; depende de cómo el `Jenkinsfile` resuelva la lib.

El tema de fondo es universal: ejecutar código de terceros en tu pipeline sin congelar la versión por hash es una decisión de riesgo que se repite en toda la industria.

---

## 11. Casos de uso prácticos

- **Repo público OSS con contributors externos**: política de org "todo pin a SHA + Dependabot". Previene que un PR malicioso te meta un `uses: @main` nuevo.
- **Repo empresarial de alto blast radius (deploys a prod)**: pin a SHA + revisión manual de PRs de Dependabot + `permissions:` mínimo + environment con approval.
- **Repo interno de bajo riesgo (docs, utilidades)**: `@v4` para `actions/*` oficiales está bien; el resto a SHA.
- **Monorepo con muchos workflows**: Dependabot con `groups:` para no ahogarte en PRs, y un script `scripts/pin-actions.sh` que corre en pre-commit.

---

## 12. Síntesis y cierre

Lo que te llevas:

1. **Tres tipos de actions**: JS, Docker, composite. Mismo `uses:`, costos y portabilidad distintos.
2. **El `@ref` es la decisión que importa**: tag mayor es cómodo e inseguro; tag exacto es intermedio; **SHA es inmutable**.
3. **Patrón canónico**: `owner/repo@<SHA40>  # v<SEMVER>`.
4. **Dependabot** hace sostenible el pinning (sin él, el pin se vuelve deuda).
5. **Taxonomía de confianza**: first-party / trusted vendor / tercero. Reglas distintas por grupo.
6. **Auditar un workflow ajeno** es una habilidad concreta: `grep -rhE '^\s*uses:'` + mirar cada línea con los tres ejes del §4.

Pregunta de evaluación — explica, con un ejemplo concreto (puede ser el incidente `tj-actions/changed-files` de 2025 o uno de tu invención), **cómo un tag reescrito compromete un pipeline que depende de él**, y qué tres cambios aplicarías tras el incidente para que no se repita.

Siguiente lección: `gha-05-secrets-variables-and-environments-basics` — qué puede ver y hacer una action con `GITHUB_TOKEN` + variables + secrets, y cómo acotarlo con `permissions:`.
