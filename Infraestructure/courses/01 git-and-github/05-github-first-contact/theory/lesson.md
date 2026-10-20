# Lección: GitHub — first contact

> **ID:** `gh-05-github-first-contact` · **Nivel:** fundamentos · **Duración:** 2–3 h
> **Prerrequisitos:** `gh-04-remotes-and-collaboration-basics`.

---

## 1. Introducción intuitiva

Hasta aquí Git ha sido local. Clonaste un `--bare` en `/tmp/`, hiciste push, fetch, pull, y todo funcionó sin internet. Ahora llega el salto más común en la vida de cualquier desarrollador: **publicarlo en GitHub**.

El mensaje importante es que GitHub **no es Git**. Git es la base inmutable (snapshots, DAG, refs, objetos). GitHub es un *producto SaaS* que:

1. **Hospeda** repositorios Git (hace de "remote" vía SSH o HTTPS).
2. Añade una capa de **identidad y autenticación** (usuario, 2FA, tokens, SSH keys).
3. Añade una capa **social y de proceso** (PRs, issues, reviews, releases, discussions).
4. Añade una capa de **automatización y plataforma** (Actions, Packages, Pages, Apps).

Este módulo cubre **la parte 1 y 2 del lado 1**: hacer que tu máquina y GitHub se entiendan, crear un repo decente, y publicar un release. Lo *social* (PRs, reviews) viene en `gh-07`. La *gobernanza y seguridad* (rulesets, firma, OIDC) viene en `gh-12` y `gh-13`.

El escenario que vamos a dominar:

```
┌───────────────────┐   push    ┌──────────────────────┐
│  Tu máquina       │ ────────> │  GitHub (remote)     │
│  repo local       │           │  repo + metadata     │
│  identidad Git    │ <──────── │  releases, issues... │
└───────────────────┘   fetch   └──────────────────────┘
         ▲                                 ▲
         │ ssh key / PAT / gh auth         │ web UI / API / gh CLI
         │                                 │
         └─── autenticarte es el 1er paso ─┘
```

---

## 2. Fundamentos

### 2.1 Qué GitHub añade sobre Git puro

Git puro resuelve "versionar código". GitHub añade:

- **URL de clonado estable** (`git@github.com:user/repo.git` o `https://github.com/user/repo.git`).
- **Cuenta de usuario** con permisos (owner, collaborator, maintainer…).
- **Metadata del repo** fuera de los objetos Git: descripción, topics, visibilidad, license hint, README mostrado.
- **Objetos sociales**: Issues, Pull Requests, Discussions, Projects, Wiki.
- **Releases**: capa de "productos entregables" encima de los tags.
- **Automatización**: GitHub Actions (CI/CD), webhooks, Apps.
- **Seguridad**: 2FA, SSO, Dependabot, secret scanning, code scanning (CodeQL).

Todo esto es *valor agregado*. Nada de esto es Git. Puedes migrar tus commits y tags a GitLab, Gitea o Forgejo en 5 minutos; migrar PRs y Issues cuesta mucho más (lock-in social, no técnico).

### 2.2 Autenticación: tres caminos vigentes

GitHub dejó de aceptar **password** sobre HTTPS en agosto 2021. Hoy hay **tres** mecanismos vigentes para que tu CLI empuje y traiga código:

| Método | Protocolo | Bueno para | Mal para |
|--------|-----------|------------|----------|
| **SSH key** (ed25519) | SSH | tu máquina personal, servidores de larga vida | compartir entre máquinas (hay que generar por máquina) |
| **HTTPS + PAT** (classic o fine-grained) | HTTPS + Bearer token | redes que bloquean SSH, CI simple | tokens de larga vida son un riesgo si se filtran |
| **`gh auth login`** | HTTPS por debajo, con *credential helper* | dev humano moderno, laptops | servers / CI sin usuario interactivo |

En CI maduro añadimos un cuarto: **GitHub App / OIDC**, pero eso va en `gh-12`/`gh-13`.

### 2.3 Visibilidad del repo

Tres estados:

- **Public** — cualquiera lo lee; solo colaboradores pueden escribir.
- **Private** — solo quienes añades lo ven.
- **Internal** — solo miembros de tu *organization* (requiere plan de equipo/empresa). Pensado para "open source dentro de la empresa" (InnerSource).

En planes free puedes usar public y private sin límite para repos personales; algunas features avanzadas (environments con approval, SAML) requieren pagar.

### 2.4 Qué es exactamente un "release"

Punto que confunde: un **release** en GitHub **no es un commit nuevo**. Es:

```
release = tag Git + metadata GitHub + (opcional) assets

donde:
  tag Git     = puntero inmutable a un commit (ligero o anotado)
  metadata    = título, notas, flag draft/prerelease/latest, autor, timestamp
  assets      = archivos binarios adjuntos (tar.gz, zip, exe, deb, apk…)
                hosteados por GitHub, NO versionados en el repo
```

Es decir: `git tag v0.1.0 && git push --tags` crea el **tag**. GitHub lo *promueve* a Release cuando añades metadata (manual en la UI o con `gh release create`). Puedes borrar o editar el release sin tocar el tag, y viceversa.

Los assets viven en S3 (o equivalente) de GitHub y se sirven por URL estable. **Un repo con 10 GB de binarios en releases no infla el `.git/`** — por eso Releases es el canal correcto para distribuir binarios, no `git add release.tar.gz`.

---

## 3. Contexto histórico

- **2005** — Linus crea Git como VCS distribuido tras la ruptura con BitKeeper. Nada de GitHub todavía.
- **2008** — Chris Wanstrath, PJ Hyett y Tom Preston-Werner lanzan **GitHub** como hosting Git con una idea nueva: la **Pull Request** como primitiva social (antes se mandaban *patches* por mail, workflow del kernel). GitHub define el patrón "fork + PR" que domina OSS.
- **2013** — se añaden Releases como capa separada de tags.
- **2018** — Microsoft compra GitHub por 7.5 B USD. Mejora free tier (private repos ilimitados).
- **2019** — nace **GitHub Actions** (CI/CD nativo). GitHub CLI (`gh`) sale en beta ese mismo año.
- **2020** — GitHub Actions llega a GA. Codespaces anunciado.
- **2021** — **GitHub elimina password sobre HTTPS**. Fuerza a todos a PAT, SSH o `gh`.
- **2022** — se lanzan **fine-grained PATs** en beta (reemplazo recomendado del classic PAT).
- **2023** — **Rulesets** empiezan a reemplazar classic branch protection. 2FA obligatorio para contributors.
- **2024+** — Fine-grained PATs maduros, OIDC a cloud providers como estándar en Actions, attestations/SLSA.

Lectura: GitHub ha ido **cerrando mecanismos de larga vida** (password, PAT classic con *todo:write*) y empujando a mecanismos de **vida corta y permisos acotados** (fine-grained PAT, GitHub App installation tokens, OIDC). La dirección es clara.

---

## 4. Funcionamiento interno

### 4.1 Cómo se autentica SSH contra GitHub

1. Generas un par de claves: `ssh-keygen -t ed25519 -C "tu-email"` → crea `~/.ssh/id_ed25519` (privada) y `~/.ssh/id_ed25519.pub` (pública).
2. Subes la **pública** a GitHub (Settings → SSH and GPG keys → New).
3. Cuando haces `git push git@github.com:user/repo.git`, OpenSSH abre socket a `github.com:22` (o `ssh.github.com:443` si el 22 está bloqueado), presenta tu llave pública, firma un challenge con la privada, GitHub verifica contra las registradas y asocia la sesión a tu usuario. A partir de ahí Git fluye sobre esa tubería.
4. `ssh -T git@github.com` prueba la conexión sin hacer git. Debería responder: `Hi <user>! You've successfully authenticated...`.

Internamente: `~/.ssh/known_hosts` guarda la fingerprint del servidor (TOFU — Trust On First Use). GitHub publica sus fingerprints oficiales ([docs.github.com/.../github-s-ssh-key-fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)); verifícalas la primera vez.

### 4.2 Classic PAT vs fine-grained PAT

Un **Personal Access Token** es una cadena opaca que actúa como password para la API y para HTTPS git. Dos sabores:

| Dimensión | Classic PAT | Fine-grained PAT |
|-----------|-------------|------------------|
| Scopes | Grandes (`repo`, `workflow`, `admin:org`…) que suelen conceder más de lo necesario | **Permisos finos** por categoría (contents, issues, pull_requests, actions, metadata…) con niveles read/write |
| Alcance de repos | Todos tus repos (o repos públicos) | **Repos específicos** elegidos por token |
| Expiración | Opcional, hasta `no expiration` | **Obligatoria**, máximo 1 año |
| Auditoría | Básica | Detallada por repo y recurso |
| Autorización en orgs | No requiere approval explícito | **Requiere approval** del admin de la org |
| Prefijo del token | `ghp_...` | `github_pat_...` |

Regla práctica: **usa fine-grained siempre que puedas**. Classic PAT sigue existiendo por compatibilidad y porque algunos permisos (ej. ciertas APIs de GraphQL de apps) aún no están cubiertos por fine-grained.

### 4.3 Qué hace `gh auth login`

`gh` es la CLI oficial de GitHub. `gh auth login` ofrece dos flujos:

- **Web browser (device flow)** — te muestra un código, abres la URL, lo pegas, autorizas. `gh` recibe un OAuth token con los scopes que elegiste y lo guarda en el **credential store** del SO (Keychain en macOS, libsecret en Linux, Credential Manager en Windows).
- **Paste a token** — pegas un PAT.

Después, Git mismo puede usar `gh` como credential helper (`gh auth setup-git`) y así `git push https://github.com/...` funciona *sin* preguntar password nunca más, usando el token que `gh` administra. El token es un OAuth y se renueva/revoca sin manejarlo tú manualmente.

### 4.4 Qué es un tag Git y cómo se promueve a Release

Dos tipos de tags:

- **Ligero** (`git tag v1.0.0`): es una `ref` plana en `.git/refs/tags/v1.0.0` que apunta al commit. **Sin metadata**: sin autor, sin fecha, sin mensaje.
- **Anotado** (`git tag -a v1.0.0 -m "mensaje"`): crea un **objeto `tag` propio** en la base de objetos, con autor, timestamp, mensaje, y opcionalmente firma GPG/SSH. La ref apunta al objeto `tag`, el objeto `tag` apunta al commit.

```
Ligero:    refs/tags/v1.0.0 ──────────────> commit <abc123>

Anotado:   refs/tags/v1.0.0 ──> tag-obj ──> commit <abc123>
                               (author,
                                date, msg,
                                signature)
```

**Siempre usa anotados para releases**. Son los que sobreviven a `git describe`, los que puedes firmar, y los que GitHub trata como releases "serios".

Cuando haces `gh release create v1.0.0 ...`:

1. Si el tag no existe local, `gh` lo crea anotado en el commit actual.
2. Hace `git push --tags` del tag.
3. Llama a la API REST `POST /repos/{owner}/{repo}/releases` con `tag_name`, `name`, `body`, `draft`, `prerelease`.
4. Si pasas assets, hace `POST /repos/{owner}/{repo}/releases/{id}/assets?name=...` para cada archivo.

El resultado: en `https://github.com/user/repo/releases/tag/v1.0.0` aparece la página con las notas y los binarios descargables.

### 4.5 Cómo GitHub decide el lenguaje del repo (Linguist)

El badge "Python 73% / Shell 20% / HTML 7%" lo calcula **GitHub Linguist**, una gem Ruby open source. Linguist mira extensiones, shebangs, heurísticas, y a veces se equivoca (clasifica un repo Terraform como HCL del 95% o un repo con muchos fixtures JSON como "JSON 60%").

Se corrige con `.gitattributes`:

```gitattributes
# No contar vendored
vendor/**        linguist-vendored
third_party/**   linguist-vendored

# Marcar como generado (no cuenta y no se muestra en diff por default)
dist/**          linguist-generated
*.min.js         linguist-generated

# Forzar lenguaje para una ruta ambigua
scripts/*.sh     linguist-language=Shell
*.tf             linguist-language=HCL

# Marcar como documentación (no cuenta)
docs/**          linguist-documentation
```

Es cosmético, pero importa para la credibilidad del repo (y para que `main.py` deje de aparecer como "Shell 90%" porque tenías un `install.sh` enorme).

---

## 5. Ejemplo mínimo

Supón que ya tienes cuenta GitHub y `gh` instalado y autenticado. Vas de cero a repo público en 5 comandos.

```bash
# 1. Preparar
mkdir -p /tmp/hello-gh && cd /tmp/hello-gh
git init -q -b main
git config user.name  "Student"
git config user.email "student@example.com"

echo "# hello-gh" > README.md
git add README.md
git commit -q -m "docs: initial README"

# 2. Crear repo en GitHub Y añadirlo como remote 'origin' en un solo comando
gh repo create hello-gh --public --source=. --remote=origin --push
# → crea en github.com/<tu-user>/hello-gh, hace push de main.

# 3. Ver que existe
gh repo view --web   # abre en navegador
```

Ya tienes repo público, README visible, y `origin` tracking configurado. Equivalente manual:

```bash
# Equivalente sin gh (manual)
# 1. Crea el repo vacío en github.com (UI)
# 2. Añádelo como remote
git remote add origin git@github.com:<tu-user>/hello-gh.git
git push -u origin main
```

---

## 6. Implementación progresiva

### 6.1 README que no da vergüenza

Un README mínimo decente tiene estas secciones. **El 90% de los repos personales las omiten y eso les cuesta estrellas y colaboradores**:

```markdown
# Nombre del proyecto

Oración (literal, una) que diga qué hace y para quién.

## Instalación

Comando(s) copy-pasteable que funcionan.

## Uso

Un ejemplo mínimo. Idealmente con output esperado.

## Desarrollo

Cómo ejecutar tests, build, lint.

## Licencia

MIT (ver `LICENSE`).
```

**Topics** del repo (web UI → Settings → Topics) son el "SEO" de GitHub: `python`, `cli`, `devops`, `terraform-module`, etc. Añádelos: te hacen aparecer en búsquedas y en la página del topic.

### 6.2 Elegir licencia

| Licencia | Qué permite | Qué obliga | Cuándo elegirla |
|----------|-------------|------------|-----------------|
| **MIT** | Casi todo (uso, modificación, sublicenciamiento, uso comercial) | Mantener aviso de copyright | Default para proyectos pequeños/libraries. Simple y permisiva. |
| **Apache-2.0** | Como MIT | Mantener aviso + **grant explícito de patentes** + marcar cambios | Proyectos con potencial de patentes; libraries para empresas (más defensiva). |
| **GPL-3.0** | Uso/modificación/distribución | Las obras derivadas deben ser GPL también (**copyleft**) | Proyectos que quieren forzar que las derivaciones sigan libres. |
| **AGPL-3.0** | Como GPL + extendido a SaaS | SaaS que use el código debe liberar su código también | Para evitar "cloud washing" (ej. librerías de bases de datos). |
| **Unlicense / CC0** | Todo | Nada (dominio público donde aplique) | Snippets, demos, código que quieres regalar sin condiciones. |
| **Sin LICENSE** | **Nada por default** | — | **Nunca**. Sin licencia, legalmente nadie puede usar tu código. |

Añádela con `gh repo create --license mit` o cópiala de [choosealicense.com](https://choosealicense.com/).

### 6.3 Clonar: SSH vs HTTPS

```bash
# SSH (recomendado si tienes key configurada)
git clone git@github.com:user/repo.git

# HTTPS (recomendado si estás detrás de proxy que bloquea 22)
git clone https://github.com/user/repo.git
# → te pedirá PAT como "password" la primera vez,
#   y el credential helper lo cachea.
```

Puedes mezclar: HTTPS para `fetch`, SSH para `push`, con `insteadOf` en `~/.gitconfig`. Para la mayoría es overkill — elige uno y mantelo.

### 6.4 Tags y semver

**SemVer** (Semantic Versioning 2.0.0): `MAJOR.MINOR.PATCH[-PRE][+BUILD]`.

- `MAJOR` — cambios incompatibles (rompes API).
- `MINOR` — features nuevas, compatibles hacia atrás.
- `PATCH` — bug fixes, compatibles.
- Pre-release: `v1.0.0-alpha.1`, `v1.0.0-rc.3`.
- Build metadata: `v1.0.0+build.42`.

Reglas no escritas pero universales:

- **Prefijo `v`**: `v1.2.3`, no `1.2.3`. Convención en Git/GitHub ecosystem (lo asumen muchas tools).
- **Antes de v1.0.0**: puedes romper cosas en MINOR; `0.x` significa "aún inestable".
- **Tag anotado siempre** para releases.

```bash
git tag -a v0.1.0 -m "Release v0.1.0

First public release.
- feature A
- feature B
"
git push origin v0.1.0           # push de un tag específico
# o:
git push --follow-tags           # push de commits + tags anotados alcanzables
```

### 6.5 Release con `gh`

```bash
# Tag + release + asset en un comando
tar -czf hello-gh-0.1.0.tar.gz --exclude='.git' .
gh release create v0.1.0 \
  --title "v0.1.0 — First release" \
  --notes "First release. See README." \
  hello-gh-0.1.0.tar.gz
# → crea el tag si no existe, lo pushea, crea el release, sube el asset.

# Variantes útiles:
gh release create v0.1.0-rc.1 --prerelease ...   # marca como prerelease
gh release create v0.1.0 --draft ...             # borrador invisible al público
gh release create v0.1.0 --notes-file CHANGELOG.md
gh release create v0.1.0 --generate-notes        # auto-genera desde PRs/commits
```

Verifica:

```bash
gh release view v0.1.0
gh release list
gh release download v0.1.0 --dir /tmp/dl       # descarga assets
```

### 6.6 `.gitattributes` para Linguist

Patrón mínimo útil en repos reales:

```gitattributes
# Línea base: normalizar line endings
* text=auto

# Linguist: ignorar generados / vendored
dist/**         linguist-generated
vendor/**       linguist-vendored
*.min.*         linguist-generated

# Linguist: documentar
docs/**         linguist-documentation
examples/**     linguist-documentation
```

Después de commitearlo, GitHub recalcula el badge en el próximo push (puede tardar unos minutos).

---

## 7. Aplicación profesional

### 7.1 Elección de auth por contexto

| Contexto | Recomendado | Por qué |
|----------|-------------|---------|
| Tu laptop personal | **SSH key** (ed25519) por repo clonado + 2FA obligatorio. O **`gh auth login`** si prefieres UX más suave. | Clave en Keychain / `ssh-agent`; no viaja. |
| Workstation compartida (bootcamp, aula) | **`gh auth login` con device flow**, logout al salir. | No deja clave privada en disco. |
| CI de corta vida (GitHub Actions) | **`GITHUB_TOKEN`** autogenerado del workflow + **OIDC** para cloud providers. **Nunca PAT**. | Vida corta, scoped al repo, sin manejo humano. |
| CI de terceros (Jenkins, GitLab CI que necesita tocar GitHub) | **GitHub App** (vida corta, por installation) o **fine-grained PAT** si no es viable App. | Lo mínimo necesario, con expiración. |
| Bot/script en servidor | **GitHub App** o fine-grained PAT con un único repo. | Reducir blast radius. |

Regla general: **menos tokens, con menos permisos, viviendo menos tiempo**.

### 7.2 Higiene de perfil

- **Email privado**: Settings → Emails → "Keep my email addresses private" + usa el `noreply` que GitHub te da. Previene scraping de spam.
- **Firma de commits** (ya en `gh-13`): hace que aparezca "Verified" al lado de tus commits en PRs.
- **README del perfil**: crea un repo con tu propio username (`efloresp06/efloresp06`) y su `README.md` se muestra en tu perfil.
- **2FA obligatorio**: GitHub ya lo exige para contributors. Usa TOTP app o passkey, no SMS.

### 7.3 Convenciones de nombrado y topics

- `kebab-case` para repos. `my_project` da fricción (algunos ecosistemas convierten a `my-project`).
- Nombre descriptivo, no cute (`log-parser-rust` > `logzilla`).
- Topics: 3–10. Mezcla **lenguaje** + **dominio** + **ecosistema**: `python`, `cli`, `aws`, `terraform-module`, `devops`.
- Descripción corta (`<120` chars). Es lo que aparece en búsquedas.

### 7.4 Policy de releases en un equipo

- Siempre **anotado**.
- Prefijo `v` siempre.
- **Nunca re-pushees un tag** (`git tag -f` + `git push --force` sobre un tag ya consumido rompe caches de clientes y pipelines reproducibles). Si equivocaste el commit, saca `v0.1.1`.
- Si pre-release: usar sufijo (`-alpha.N`, `-rc.N`) y marcar `--prerelease`.
- Notas con 3 secciones: **Highlights**, **Breaking changes**, **Changelog completo**. `release-please` o `semantic-release` lo automatizan.

---

## 8. Trade-offs

### 8.1 SSH vs HTTPS+PAT vs `gh auth`

**SSH**:
- + Setup una vez por máquina y olvídate.
- + No depende de tokens que expiran.
- + Mejor UX para pushes frecuentes.
- − Hay que generar y cargar por máquina.
- − Si olvidaste subir la pública, los errores son crípticos ("Permission denied (publickey)").
- − Bloqueado en redes corporativas que cierran 22 (mitigable con `ssh.github.com:443`).

**HTTPS + PAT**:
- + Funciona en cualquier red (443 nunca está bloqueado).
- + Útil para scripts y CI simples.
- − Tokens son credenciales de larga vida que acaban en logs, histórico de shell, archivos de config...
- − Los *classic* dan permisos amplios por default; es fácil "sobre-concederlos".
- − Expiran, hay que rotar.

**`gh auth login`**:
- + Device flow sin pegar tokens.
- + Instala credential helper que resuelve todo HTTPS sin fricción.
- + Encaja con `gh` para issues/PRs/releases.
- − Requiere `gh` instalado.
- − Para CI headless hay que generar un token separado igual.

Mi default: **`gh auth` en laptops**, **SSH key** si eres purista o quieres independencia de `gh`, **GitHub App / OIDC** en CI serio, **fine-grained PAT** solo cuando los dos anteriores no aplican.

### 8.2 Repo público vs privado

**Público**:
- + Portfolio visible, atrae colaboradores y recruiters.
- + Minutos de Actions gratis más generosos.
- − Todo el mundo lo lee: cualquier error (secretos, data) es *leaked*.
- − Issues públicos: puede haber ruido o abuse.

**Privado**:
- + Mientras pulgas, nadie te juzga.
- + Datos sensibles ok (pero sigue: no comitees secretos).
- − Si abandonas el proyecto se vuelve invisible.

Recomendación: **arranca privado, hazlo público cuando esté decente**. Es trivial cambiar (`gh repo edit --visibility public`).

### 8.3 Tag anotado vs ligero

- Ligero: para marcadores locales efímeros ("acabo de probar X aquí").
- Anotado: para releases, firmas, y cualquier cosa que vayas a pushear o compartir.

Si en duda: **anotado**.

### 8.4 Release con assets vs sin assets

- Sin assets (solo tag + notas): suficiente si el "producto" es el código mismo (una library que se instala por `pip`/`npm` desde el registry oficial). El release es un *announcement*.
- Con assets: imprescindible si el usuario descarga binarios directamente (CLI compilada por SO, firmware, instaladores).

Nunca metas los binarios al repo: usa releases.

---

## 9. Errores frecuentes

### 9.1 "`Permission denied (publickey)`" al hacer push por SSH

Causas típicas:
- No subiste la **pública** a GitHub (confundiste con la privada).
- Subiste la privada por accidente (**ROTA LA KEY YA**: borra el par, genera otro, revoca en Settings).
- La key no está cargada en `ssh-agent`: `ssh-add ~/.ssh/id_ed25519`.
- Clonaste por HTTPS en vez de SSH: `git remote -v` para verlo.

Debug:

```bash
ssh -vT git@github.com
# Lee la salida: te dice qué keys ofrece el cliente y cómo responde el server.
```

### 9.2 "Password authentication is not supported for Git operations"

Ya no se puede usar password sobre HTTPS. Soluciones:
- `gh auth login` + `gh auth setup-git`.
- Cambia remoto a SSH: `git remote set-url origin git@github.com:user/repo.git`.
- Si realmente necesitas HTTPS: genera un PAT (fine-grained) y pégalo cuando pida "password".

### 9.3 "Hice push y GitHub no muestra el commit"

Causas:
- Pushaste a una rama distinta (`git push origin feature/foo` pero miras `main`).
- Caché del navegador: hard-reload.
- Pushaste al remote equivocado (fork en vez de upstream).

Debug: `git ls-remote origin` muestra qué refs ve GitHub.

### 9.4 "`gh repo create` falla con 'name already exists'"

El repo ya existe en tu cuenta (o fue archivado). Opciones:
- Elige otro nombre.
- `gh repo delete <name>` (destructivo, pide confirmación).
- Si estaba archivado: `gh repo unarchive <name>` + push.

### 9.5 "Mi release aparece pero no tiene el tag"

Pasó cuando creaste el release en la UI apuntando a un tag que no existe. GitHub creó un tag ligero por su cuenta. Dos opciones:
- Borra el release, crea tag anotado local, push, re-crea release.
- Déjalo así (es consumible), pero tu `git describe` local no lo verá hasta `git fetch --tags`.

### 9.6 "Pushé un tag mal y lo quiero cambiar"

```bash
# NO lo hagas si alguien ya lo consumió. Prefiere sacar v0.1.1.
# Si sí tienes que:
git tag -d v0.1.0
git push origin :refs/tags/v0.1.0     # borra remoto
git tag -a v0.1.0 -m "..." <nuevo-commit>
git push origin v0.1.0
```

Advierte a cualquiera que haya clonado. Pipelines reproducibles basados en ese tag se rompen.

### 9.7 "Mi `.gitignore` no funciona para `secrets.env`"

El archivo ya estaba tracked. `.gitignore` solo afecta a **archivos que Git no conoce todavía**.

```bash
git rm --cached secrets.env
echo "secrets.env" >> .gitignore
git commit -m "chore: stop tracking secrets.env"
# El secreto SIGUE en la historia. Si fue pusheado: asume LEAKED, rota.
```

### 9.8 "GitHub dice que mi repo es 95% HTML y es un repo Python"

Linguist cuenta todo. Añade `.gitattributes`:

```gitattributes
docs/**     linguist-documentation
*.html      linguist-generated
```

commit + push, espera unos minutos.

---

## 10. Buenas prácticas

- **Un repo = un propósito claro.** Si tu "repo monolítico" es "my-experiments", está bien para scratch; pero sepáralo cuando algo madure.
- **README decente desde el commit 1.** 10 líneas útiles > 500 líneas de boilerplate copiadas.
- **LICENSE desde el día 1.** Sin licencia, no es open source.
- **`.gitignore` desde el commit 1.** Añádelo con el `init`, no después de ya haber commiteado `__pycache__/`.
- **2FA obligatorio.** TOTP (Authy, 1Password, Aegis) o passkey. **No SMS.**
- **SSH key `ed25519`**, no RSA de 2048 (débil) ni DSA (muerta).
- **Fine-grained PATs** sobre classic siempre que puedas.
- **Nunca commits de credenciales**, aunque sean dummies de pruebas; otra persona copiará el patrón sin pensar.
- **Tags anotados** siempre para releases. **Nunca sobreescribas un tag pusheado.**
- **Releases para binarios**, no `git add dist/`.
- **Topics y descripción** para que tu repo sea encontrable.
- **Email privado** (`noreply` de GitHub) si no quieres que te escrapeen.
- **Perfil con avatar + bio + link a tu web** si lo usas como portfolio.

---

## 11. Ejercicios recomendados

1. **`examples/01-ssh-setup/`** — genera ed25519 y pruébala contra GitHub (si tienes cuenta).
2. **`activities/01-create-repo-and-push/`** — guided-lab: crea un repo con README + LICENSE + .gitignore y empújalo. Modo `live` o `local`.
3. **`examples/02-first-release/`** — demo de tag anotado + `gh release create` con asset.
4. **`activities/02-publish-first-release/`** — guided-lab: etiqueta `v0.1.0`, genera `tar.gz`, publica el release.

---

## 12. Evaluación

Responde sin consultar.

**P1.** Explica en una frase cada uno:
- SSH key
- Personal Access Token (classic)
- Personal Access Token (fine-grained)
- `gh auth login`
- GitHub App

¿Para qué contexto es cada uno el default correcto?

**P2.** Diferencia operativa entre **tag ligero** y **tag anotado**. Da un comando para cada uno. ¿Cuál se puede firmar?

**P3.** Verdadero / falso, con razón corta:
- [ ] Un release de GitHub es un commit nuevo que empaqueta otros commits.
- [ ] Puedes borrar un release sin borrar el tag al que apunta.
- [ ] `.gitignore` deja de trackear un archivo que ya estaba tracked.
- [ ] GitHub acepta password HTTPS si activas 2FA.
- [ ] Un fine-grained PAT siempre tiene fecha de expiración.
- [ ] Puedes clonar por SSH sin haber subido tu clave pública.

**P4.** Estás en una red corporativa que bloquea el puerto 22. Describe dos formas de seguir pushando a GitHub.

**P5.** Vas a abrir el código de una CLI en Rust. ¿Qué licencia eliges y por qué? ¿Qué pondrías en los Releases vs qué dejarías en el repo?

**P6.** Diseña el `.gitattributes` para un repo que tiene: Python como código principal, un `docs/` grande en Markdown y HTML, un `vendor/` con dependencias copiadas, y un `dist/` con builds. Objetivo: que GitHub muestre "Python 100%" o lo más cerca posible.

**P7.** Equipo pequeño, 3 devs humanos + 1 bot que automatiza issues. ¿Cómo autenticas a cada uno? ¿Qué tipo de token/credencial para el bot?

**P8.** Explica la secuencia **exacta** desde `gh release create v1.0.0 --generate-notes dist/app.tar.gz` hasta que un usuario abre `https://github.com/you/app/releases/tag/v1.0.0` y descarga el `.tar.gz`. ¿Qué hace `gh`, qué hace la API de GitHub, qué hace el navegador?

---

## Referencias

- *Pro Git* cap. 2.5 "Working with Remotes" y 2.6 "Tagging". <https://git-scm.com/book/en/v2>
- GitHub Docs — Authentication. <https://docs.github.com/en/authentication>
- Generating a new SSH key (ed25519). <https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent>
- Managing fine-grained PATs. <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens>
- GitHub CLI manual. <https://cli.github.com/manual/>
- `gh release create`. <https://cli.github.com/manual/gh_release_create>
- About releases. <https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases>
- Semantic Versioning 2.0.0. <https://semver.org/>
- Choose a License. <https://choosealicense.com/>
- GitHub Linguist. <https://github.com/github-linguist/linguist>
- GitHub's SSH key fingerprints. <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints>
