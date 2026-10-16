# Lección: Repositorios, OCI y provenance

> **ID:** `helm-08-repositories-oci-and-provenance` · **Nivel:** avanzado · **Duración:** 3 h
> **Prerrequisitos:** `helm-03-chart-anatomy`.

---

## 1. Introducción intuitiva

Hasta ahora tus charts viven en una carpeta. Para que *otros* (otro cluster, otro equipo, otro humano) los consuman, hay que **publicarlos** a algún lado y luego **confiar** en lo que descargamos. Dos problemas distintos:

- **Distribución**: dónde pongo el `.tgz` para que `helm install` lo encuentre.
- **Integridad y autenticidad**: cómo pruebo que *este* `.tgz` lo publicó quien dice, y no fue manipulado en tránsito, por el proxy de la empresa, por un espejo malicioso o por un maintainer comprometido.

Durante años la respuesta de Helm fue: *distribución* vía un `index.yaml` servido por HTTP (como `apt`/`yum` servían paquetes), *integridad* vía un provenance file `.prov` con firma GPG. Funcionaba pero vivía fuera del ecosistema de contenedores.

Desde 2022 la respuesta recomendada es: **OCI**. El mismo registry que guarda tus imágenes (GHCR, ECR, Harbor, Artifactory) guarda tus charts, con la misma autenticación, los mismos permisos, el mismo tooling de firmas (**cosign**) y las mismas pipelines. Un chart es *un artefacto OCI más*.

Este módulo cubre ambos caminos, pero deja claro: hoy, para un proyecto nuevo, el default moderno es **OCI + cosign (keyless si CI, key pair si no)**.

---

## 2. Fundamentos

### 2.1 Qué es un chart repository (modelo clásico HTTP)

Un repo HTTP tradicional es un **servidor estático** que expone:

- `index.yaml` — índice con la lista de charts, versiones, URLs de descarga, hashes, dependencias, keywords.
- `<chart>-<version>.tgz` — los paquetes.
- Opcional: `<chart>-<version>.tgz.prov` — provenance con firma GPG.

El cliente ejecuta `helm repo add miname https://.../` → descarga `index.yaml`, lo cachea en `~/.cache/helm/repository/`. `helm install miname/mi-chart` lo resuelve contra el índice y descarga el `.tgz`.

Para publicar basta un bucket S3 público, GitHub Pages, cualquier CDN estático y un `helm repo index` que te genera el `index.yaml`. Simple hasta que necesitas autenticación granular, mirror interno, retention policies, cuotas, inventario — ahí sufres.

### 2.2 Qué es un OCI registry (modelo moderno)

Un registry OCI (Distribution Spec) habla el protocolo de distribución de imágenes de contenedor. Fue diseñado para *imágenes*, pero su modelo abstracto es "artefacto": un **manifest** apunta a uno o más **blobs** descritos por **media type**. Un chart simplemente usa media types propios:

- `application/vnd.cncf.helm.config.v1+json` para el config.
- `application/vnd.cncf.helm.chart.content.v1.tar+gzip` para el `.tgz`.
- `application/vnd.cncf.helm.chart.provenance.v1.prov+origin` para el `.prov` cuando se adjunta.

Lo que ganas:

- **Una sola infra** para imágenes y charts (autenticación OAuth2/token, políticas IAM, scanning, retención, replicación).
- **Compatible con cosign** sin pegamento: la firma vive como otro artefacto en el registry asociado por digest.
- **Pull por digest** (`oci://registry/chart@sha256:…`) además de por tag — crítico para reproducibilidad.
- **Mirror / air-gap** con las mismas herramientas que ya usas para imágenes (crane, skopeo, oras).

Lo que pierdes:

- `helm search repo` no funciona contra un OCI (no hay `index.yaml`). Para búsqueda hay que consultar la API del registry o usar **Artifact Hub** como índice público.

### 2.3 Nomenclatura: chart, versión, repo, OCI reference

Un chart tiene dos versiones en `Chart.yaml`:

- `version:` — versión del **chart** (sigue SemVer estricto). Es lo que firma, publica y resuelve el registry.
- `appVersion:` — versión de la **aplicación empaquetada** (puede ser cualquier string: `1.2.3`, `v4.0.0`, `nightly-20261013`). No afecta la resolución de dependencias.

Una referencia OCI de chart tiene forma:

```
oci://<host>/<repo-path>/<chart-name>:<version>
```

Ejemplo:

```
oci://ghcr.io/myorg/charts/fastapi-app:0.3.1
```

Aquí `ghcr.io/myorg/charts/fastapi-app` es el repo OCI y `0.3.1` el tag (tiene que coincidir con `version:` en el `Chart.yaml` empaquetado).

---

## 3. Contexto histórico

- **Helm 1-2 (2015-2018)**: repos HTTP. `index.yaml` + GPG `.prov`. GitHub Pages y Google Cloud Storage eran los hostings más comunes.
- **2019 — Helm 3**: desaparece Tiller. El soporte de OCI empieza como *experimental* detrás de `HELM_EXPERIMENTAL_OCI=1`.
- **2022 — Helm 3.8**: OCI **GA**. `helm push`, `helm pull`, `helm install oci://…` funcionan sin flag experimental.
- **2023+ — Artifact Hub + cosign**: Artifact Hub muestra firmas cosign junto al listado. GHA + OIDC + Fulcio hacen trivial firmar en pipelines sin manejar claves.
- **Hoy (2026)**: proyectos nuevos van directo a OCI. HTTP sobrevive por legacy; muchas organizaciones mantienen *ambos* durante una transición.

---

## 4. OCI registries en detalle

### 4.1 Autenticación

```bash
# GHCR con PAT con scope read:packages / write:packages
echo "$GHCR_TOKEN" | helm registry login ghcr.io -u myuser --password-stdin
```

Las credenciales se guardan en `~/.config/helm/registry/config.json` (formato Docker config). Esto significa que si ya hiciste `docker login ghcr.io`, Helm **las reusa** y `helm registry login` es opcional. En CI se pasa un token efímero (`GITHUB_TOKEN` del runner tiene permisos sobre packages del mismo repo por defecto).

### 4.2 Publicar

```bash
helm package ./fastapi-app                 # genera fastapi-app-0.3.1.tgz
helm push fastapi-app-0.3.1.tgz oci://ghcr.io/myorg/charts
```

El registry recibe `ghcr.io/myorg/charts/fastapi-app:0.3.1`. Nota que `helm push` **no** acepta `--tag`; el tag se toma del `.tgz` nombrado (`<chart>-<version>.tgz`). Para "re-taggear" hay que re-empaquetar con otra `version:` o usar `oras tag`.

Un registry conformante **rechaza** push de un tag que ya existe como *immutable* si la política así lo indica. GHCR por defecto permite overwrite, pero esto es un **anti-pattern**: una versión publicada no se re-publica, se re-numera (SemVer: bump de patch/minor/major).

### 4.3 Consumir

```bash
helm install my-release oci://ghcr.io/myorg/charts/fastapi-app --version 0.3.1
helm pull oci://ghcr.io/myorg/charts/fastapi-app --version 0.3.1   # descarga el .tgz
helm show chart oci://ghcr.io/myorg/charts/fastapi-app --version 0.3.1
```

El flag `--version` es **obligatorio** para OCI: no hay un `index.yaml` que resuelva "la última". Si no lo pasas, Helm pide una versión explícita.

### 4.4 Registry local para desarrollo (`registry:2`)

Para los ejemplos del módulo (y en general para iterar sin tocar GHCR):

```bash
docker run -d --rm --name helm-local-reg -p 5000:5000 registry:2
helm push mi-chart-0.1.0.tgz oci://localhost:5000/charts --plain-http
helm pull oci://localhost:5000/charts/mi-chart --version 0.1.0 --plain-http
```

`--plain-http` es necesario porque `localhost:5000` no sirve TLS. Omitirlo da error `http: server gave HTTP response to HTTPS client`.

---

## 5. SemVer y por qué importa en un chart

Un chart es una **API** que consumen operadores y pipelines. Cambiar la estructura de `values.yaml`, renombrar un helper, o retirar un recurso rompe clientes. SemVer te da el lenguaje:

- **PATCH** (`0.3.1 → 0.3.2`): bug fix, defaults seguros, cambios internos invisibles.
- **MINOR** (`0.3.x → 0.4.0`): features aditivas; `values.yaml` puede ganar keys *opcionales*.
- **MAJOR** (`0.x → 1.0`, `1.x → 2.0`): breaking changes (keys renombradas, defaults distintos, templates que requieren K8s más nuevo, recursos movidos).

El registry solo *tagea*; la **disciplina** es tuya. Dos reglas prácticas:

1. **Pre-1.0**: cualquier bump de minor puede romper. Documéntalo. Muchos charts famosos viven en `0.x` durante años.
2. Nunca "parchees in-place" una versión publicada. Si descubres un bug crítico en `0.3.1`, publicas `0.3.2`. El `.tgz` original queda **tal cual** en el registry porque alguien, en algún pipeline, lo tiene pinneado por digest.

Dependencias de chart (`Chart.yaml` → `dependencies:`) aceptan rangos SemVer (`^1.2.0`, `~1.2`). Como siempre con rangos: funcionan si se respeta SemVer; truenan si no.

---

## 6. Chart signing clásico: `.prov` + GPG

Este fue el camino original. Lo entiendes para leer repos legacy y para saber cuándo *todavía* tiene sentido.

### 6.1 Mecánica

```bash
helm package ./fastapi-app \
  --sign \
  --key "mi-nombre-de-clave" \
  --keyring ~/.gnupg/secring.gpg
# → fastapi-app-0.3.1.tgz
# → fastapi-app-0.3.1.tgz.prov
```

El `.prov` es un archivo de texto con tres partes:

1. YAML con `apiVersion`, `name`, `version`, `appVersion`, `description` del chart.
2. Hashes SHA-256 del `.tgz`.
3. **Firma GPG inline** (clearsign) sobre las dos partes anteriores.

Verificación:

```bash
helm verify fastapi-app-0.3.1.tgz --keyring ~/.gnupg/pubring.gpg
helm install my-release fastapi-app-0.3.1.tgz --verify --keyring ~/.gnupg/pubring.gpg
```

### 6.2 Problemas prácticos

- Requiere **manejar claves GPG**: expiraciones, revocaciones, distribuir las públicas por un canal confiable (los famosos `keybase`, keyservers, `.asc` en el website). Operacionalmente pesado.
- El `.prov` tiene que viajar **junto** al `.tgz`. En HTTP tradicional, el servidor sirve ambos; en OCI *puede* adjuntarse como blob extra, pero no es el flujo nativo.
- GnuPG en CI es doloroso (importar key, `--pinentry-mode loopback`, `GPG_TTY`, etc.).

### 6.3 Cuándo todavía usarlo

- Repos **HTTP legacy** donde ya tienes una PKI GPG consolidada.
- Entornos sin acceso a Rekor/Fulcio (air-gapped) donde cosign *keyless* no es viable y prefieres el formato nativo de Helm.
- Compliance muy conservadora que exige un canal independiente del registry para la firma.

Para todo lo demás: cosign.

---

## 7. Firma moderna: cosign sobre OCI

cosign (parte de Sigstore) firma **artefactos OCI por digest** y publica la firma como *otro artefacto OCI* en el mismo registry, asociado al original por convención de nombre (tag legacy `sha256-<digest>.sig`) o por la **OCI 1.1 referrers API**.

Un chart publicado como OCI es un artefacto como cualquier otro. Lo firmas igual que firmas una imagen.

### 7.1 Keyless con OIDC (CI/CD moderno)

En un workflow GHA:

```yaml
permissions:
  id-token: write    # para OIDC
  packages: write
  contents: read

- uses: sigstore/cosign-installer@v3
- run: |
    helm package ./fastapi-app
    helm push fastapi-app-${VERSION}.tgz oci://ghcr.io/${{ github.repository }}/charts
    DIGEST=$(helm show chart oci://ghcr.io/${{ github.repository }}/charts/fastapi-app \
             --version "$VERSION" | grep '^digest:' | awk '{print $2}')
    cosign sign --yes "ghcr.io/${{ github.repository }}/charts/fastapi-app@${DIGEST}"
```

Internamente cosign:

1. Pide un token OIDC al runner (`id-token: write` lo habilita).
2. Lo envía a **Fulcio**, que emite un **certificado efímero** (válido ~10 min) que ata la identidad OIDC (`https://github.com/myorg/myrepo/.github/workflows/release.yml@refs/tags/v0.3.1`) a una clave pública generada en memoria.
3. Firma el digest, publica la firma + certificado en el registry.
4. Sube la entrada a **Rekor** (transparency log público e inmutable) para que cualquiera pueda auditar que la firma existió.

El verificador no necesita conocer una clave pública; necesita saber **qué identidad OIDC es legítima**:

```bash
cosign verify ghcr.io/myorg/charts/fastapi-app@sha256:... \
  --certificate-identity-regexp 'https://github\.com/myorg/myrepo/\.github/workflows/release\.yml@.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com'
```

Beneficio: **no hay claves que rotar**. La "clave" es la identidad del workflow en GitHub. Si el workflow se mueve a otro repo, la verificación falla, y eso es exactamente lo que quieres.

### 7.2 Con key pair local (sin Rekor)

Para desarrollo local, air-gap o si no quieres depender de Sigstore pública:

```bash
cosign generate-key-pair           # genera cosign.key / cosign.pub (password protegido)
cosign sign --key cosign.key --tlog-upload=false --yes "localhost:5000/charts/mi-chart@sha256:..."
cosign verify --key cosign.pub --insecure-ignore-tlog "localhost:5000/charts/mi-chart@sha256:..."
```

`--tlog-upload=false` evita subir a Rekor; `--insecure-ignore-tlog` dice al verificador que no exija la entrada Rekor. Ambos son necesarios juntos.

### 7.3 Attestations (bonus)

cosign también adjunta **attestations** (predicados firmados en formato in-toto): SBOM, SLSA provenance, resultados de escaneo. Para un chart tiene menos valor que para una imagen, pero mentalmente es la misma primitiva (`cosign attest`).

---

## 8. `.prov` + GPG vs cosign + OCI — comparación

| Dimensión | `.prov` + GPG | cosign + OCI |
|-----------|---------------|---------------|
| Formato de firma | Archivo paralelo al `.tgz` (clearsign GPG) | Artefacto OCI asociado por digest |
| Dónde vive | Mismo HTTP server que el `.tgz` | Mismo registry que el chart |
| Verificación | `helm verify` / `--verify` | `cosign verify` |
| Gestión de claves | Keyring GPG, distribuir `.asc` | Keyless (OIDC) o key pair |
| CI friendly | Doloroso (GPG agent, pinentry) | Nativo (acción oficial GHA) |
| Transparency log | No | **Rekor** (público, inmutable) |
| Rotación de claves | Manual, revocación GPG | No aplica en keyless |
| Soporta OCI nativamente | Parcial (puede adjuntarse como blob) | Sí, por diseño |
| Herramientas | `gpg`, `helm` | `cosign`, cualquier cliente OCI |
| Madurez | Veterana, estable, poco movimiento | Activa, estándar emergente |

**Regla práctica**:

- Proyecto nuevo, OSS o interno con CI/CD: **cosign keyless**.
- Entorno air-gapped sin Rekor accesible: **cosign con key pair** o `.prov` + GPG si ya tienes PKI.
- Legacy donde los consumidores *ya* corren `helm verify`: mantén `.prov` + GPG.

---

## 9. Artifact Hub, visibility y pull limits

### 9.1 Artifact Hub

[artifacthub.io](https://artifacthub.io) es el **índice público** post-deprecación de `helm/charts`. No hospeda: indexa charts publicados en registries HTTP u OCI que registras. Muestra:

- Versiones, keywords, README, dependencias.
- **Firmas cosign** cuando existen (verifica contra Rekor y marca el chart como "Signed").
- Vulnerabilities (via trivy integration) y métricas de popularidad.

Publicar un chart y *añadirlo* a Artifact Hub son pasos distintos: hay que subir un `artifacthub-repo.yml` al root del repo o del namespace OCI, con metadata del publisher.

### 9.2 Visibility

En GHCR cada paquete tiene su propia visibility (independiente del repo de código):

- **Public**: cualquiera puede pull sin auth.
- **Private**: solo con token con scope `read:packages` y permiso sobre el package.
- **Internal** (orgs enterprise): miembros de la org.

Es *fácil* publicar sin querer un chart privado como public o viceversa — revisa la UI del package tras el primer push.

### 9.3 Pull limits y rate limiting

- **Docker Hub**: límites estrictos para anonymous (100 pulls/6h/IP) y autenticados free (200/6h). Afectan si *dependes* de charts/imágenes de Docker Hub en pipelines.
- **GHCR**: sin pull limits documentados actualmente, pero rate limits de API (~5000 req/h autenticado).
- **ECR / Artifactory / Harbor**: límites propios de cuota y almacenamiento.

Mitigaciones: **mirror** (pull-through cache como `registry:2 + proxy`, Harbor, Artifactory), *o* `helm pull` + guardar el `.tgz` en S3/filesystem interno.

---

## 10. `helm pull` y operación air-gapped

En un entorno **sin internet** (sin acceso al registry, por política de red o por diseño), el flujo es:

### 10.1 En el entorno con red

```bash
helm pull oci://ghcr.io/myorg/charts/fastapi-app --version 0.3.1
# → fastapi-app-0.3.1.tgz en el directorio actual

# Opcional: pull de la firma cosign también
cosign save ghcr.io/myorg/charts/fastapi-app@sha256:... --dir ./air-gap-bundle
```

Se transportan los artefactos (`.tgz`, firma, clave pública si no es keyless) por el canal que corresponda: USB, S3 interno, pipeline cross-boundary.

### 10.2 En el entorno air-gapped

```bash
# Verificar firma offline
cosign verify --key cosign.pub --insecure-ignore-tlog --local-image \
  ./air-gap-bundle

# Instalar desde el .tgz, sin red
helm install my-release ./fastapi-app-0.3.1.tgz
# o render puro
helm template my-release ./fastapi-app-0.3.1.tgz > manifests.yaml
```

Nota: dependencias de chart (`Chart.yaml` → `dependencies:`) **se resuelven en `helm dependency update`**, no en `install`. Para air-gap haz `helm dependency update` **antes** de empaquetar; el `.tgz` resultante incluye todos los sub-charts en `charts/`. No necesitas red en destino.

Un patrón adicional: espejar el *registry entero* (chart + imágenes referidas en el chart) con `oras cp`, `crane cp` o Harbor replication. Para charts internos es sobrado; para air-gap serio probablemente quieres mirror.

---

## 11. Errores comunes y debugging

- **`Error: push access denied`** → `helm registry login` olvidado o PAT sin scope `write:packages`.
- **`http: server gave HTTP response to HTTPS client`** → falta `--plain-http` apuntando a un registry local sin TLS.
- **`chart version in Chart.yaml must match tag`** → publicaste con un nombre `.tgz` que no coincide con el `version:` interno. Re-empaqueta.
- **`Error: cannot overwrite digest`** → política de inmutabilidad activa en el registry (Harbor/Artifactory). Bump de versión obligatorio.
- **`cosign verify` falla con firma válida** → casi siempre `--insecure-ignore-tlog` olvidado cuando firmaste con `--tlog-upload=false`; o `--certificate-identity-regexp` mal escrito (recordar escapar los puntos: `github\.com`).
- **`helm install oci://…` ignora `latest`** → OCI *no* resuelve `latest`; pide `--version` explícito.
- **`helm verify` no encuentra `.prov`** → el `.prov` tiene que estar junto al `.tgz` en el mismo directorio.
- **Firma cosign con digest incorrecto** → siempre firma por `@sha256:...`, nunca por tag. Un re-push cambia el digest y la firma anterior deja de aplicar.

### Nota operativa: `grep -q` + `pipefail`

Los scripts de este módulo (y de todo el curso) **no usan `set -o pipefail`** cuando pipean a `grep -q`. Razón: `grep -q` cierra stdin al primer match, lo que puede provocar `SIGPIPE` (exit 141) en el productor del pipe (típicamente `helm`, `git`, `oras`), y `pipefail` convertiría ese 141 en un fallo espurio. Preferimos `set -eu` y comprobar los códigos de salida explícitamente.

---

## 12. Resumen y evaluación

### Resumen

- Hay dos modelos de distribución: **HTTP + `index.yaml`** (legacy, simple, limitado) y **OCI** (moderno, unificado con imágenes, soportado por todas las herramientas del ecosistema).
- Hay dos modelos de firma: **`.prov` + GPG** (nativo de Helm, pesado operacionalmente) y **cosign + OCI** (moderno, keyless-ready, estándar emergente).
- `helm pull` + verificación offline hacen viable el **air-gap** sin reinventar nada.
- Un registry es una fuente de **integridad y disciplina** (SemVer, inmutabilidad, visibility), no solo un servidor de archivos.
- Un chart publicado y firmado es un **producto** con contrato versionado y provenance verificable; eso es lo que te permite consumirlo con confianza en pipelines y clusters que no controlas.

### Preguntas de evaluación

Respóndelas sin consultar.

1. ¿Por qué `helm install oci://…` requiere `--version` mientras que `helm install miname/chart` (HTTP) no?
2. ¿Qué pasa si firmas con cosign un chart por tag en vez de por digest, y luego alguien re-publica el mismo tag?
3. ¿Cuándo elegirías `.prov` + GPG sobre cosign + OCI? Da un escenario concreto.
4. En un workflow GHA que publica un chart firmado keyless, ¿qué permisos de `GITHUB_TOKEN` necesitas y por qué (`id-token`, `packages`, `contents`)?
5. ¿Por qué `helm dependency update` debe correrse *antes* del `helm package` para operación air-gapped?
6. Un consumidor hace `cosign verify --certificate-identity-regexp '...' ...` y falla aunque la firma es correcta. Lista tres causas probables.
7. ¿Qué es un **transparency log** y qué garantía adicional da sobre una firma criptográficamente correcta?
8. Diferencia entre `version:` y `appVersion:` en `Chart.yaml`. ¿Cuál afecta la resolución de dependencias?
