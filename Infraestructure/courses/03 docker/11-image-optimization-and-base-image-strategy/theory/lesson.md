# dkr-11 — Optimización de imagen y estrategia de base image

> Lección profunda, 12 secciones. ~3 h de lectura activa.

---

## 1. Por qué el tamaño importa (más de lo que parece)

Una imagen "pesada" cuesta en tres planos que la gente suele mezclar:

1. **Red** — cada `docker pull` baja los bytes de las capas que no estén cacheadas en el nodo. En un cluster con autoscaling (K8s, ECS), un nodo nuevo que levanta tu Pod paga el pull completo. 500 MB vs 80 MB es la diferencia entre "listo en 2 s" y "listo en 20 s" en una red típica de datacenter, y mucho peor en edge.
2. **Disco** — overlayfs comparte capas entre contenedores, pero el **registry** cobra storage por capa única. Más capas, más duplicación en el registry.
3. **Superficie de ataque** — cada binario que empacas es un `apt-get install` potencial de un CVE mañana. `curl`, `wget`, `bash`, `apt`, `openssl` son herramientas magníficas... para un atacante que ya está dentro.

Lo que **no** mejora con una imagen pequeña:
- El consumo de RAM en runtime (eso lo decide tu proceso).
- La CPU (idem).
- La latencia de red *de tu app* una vez levantada.

```
┌────────────────────────────────────────────────┐
│  Costo real por cada MB extra en una imagen    │
├────────────────────────────────────────────────┤
│  pull en nodo frío ...... bytes * latencia     │
│  storage en registry .... bytes * nodos * $   │
│  CVE surface ............ paquetes extra       │
│  cold-start a app lista . pull + extract + run │
└────────────────────────────────────────────────┘
```

Regla operativa: **mide antes de optimizar**. `docker images`, `docker history`, `dive`.

---

## 2. Anatomía: qué pesa realmente en una imagen

Una imagen OCI es un árbol de **capas tar comprimidas** (gzip o zstd) + un `config.json` + un `manifest.json`. `docker images` muestra tamaño *descomprimido* en disco; el registry transfiere el *comprimido*. Las dos cifras no coinciden.

Dentro de una capa típica de app Python encuentras:

- El binario del intérprete (`/usr/local/bin/python3`).
- La standard library (~30 MB).
- Las dependencias instaladas por `pip` en `site-packages`.
- Caches: `__pycache__`, `~/.cache/pip`, `/var/cache/apt`.
- Datos accidentales: `.git` del repo, `node_modules` de un frontend que colaste.

El culpable más común de "mi imagen pesa 1.2 GB" **no** es el intérprete: es el `.cache/pip` que pip deja por default y que *se copia en una capa posterior* si no lo limpias en la misma `RUN`.

```
RUN pip install -r requirements.txt     # <-- deja ~/.cache/pip, pesa X
RUN rm -rf /root/.cache                 # <-- NO reduce la capa anterior
```

Las capas son **inmutables**. Borrar un archivo en una capa posterior lo marca como "whiteout" en overlayfs: sigue viajando en la capa inferior. La única forma de que no pese es que **nunca haya existido en una capa que ships**. De ahí la práctica `pip install --no-cache-dir`.

---

## 3. El árbol de decisión de base images

```
                     ¿tu binario es estático?
                            /         \
                          sí           no
                          /             \
                     scratch       ¿necesitas glibc?
                                    /          \
                                  sí            no
                                  /              \
                           debian-slim          alpine
                           / distroless       (musl, cuidado
                           / chainguard        con libs C)
```

Las cinco familias relevantes:

| Base | Tamaño típico base | libc | Package manager en runtime | Shell |
|------|-------------------|------|----------------------------|-------|
| `debian:bookworm-slim` | ~75 MB | glibc | `apt` | sí |
| `alpine:3.19` | ~7 MB | **musl** | `apk` | sí (`ash`) |
| `gcr.io/distroless/python3-debian12` | ~50 MB | glibc | **no** | **no** |
| `cgr.dev/chainguard/python` | ~55 MB | glibc | **no** | **no** |
| `scratch` | 0 bytes | ninguna | no | no |

Punto clave: **tamaño no es la métrica única**. Alpine es la más pequeña pero es la que más dolores da en Python por musl. Distroless es más pequeña que slim y además no trae shell → ni tamaño ni superficie te pueden chantajear.

---

## 4. `debian:bookworm-slim` — el "default seguro"

`slim` es la variante de Debian con el conjunto mínimo útil: `apt`, `bash`, `coreutils`, certificados CA, glibc, poco más. No incluye documentación, man pages, locales no esenciales, ni herramientas de build.

Pros:
- **glibc** — compatibilidad total con wheels manylinux de PyPI, con drivers propietarios (NVIDIA), con bibliotecas que asumen glibc (que son casi todas).
- Package manager (`apt`) para añadir lo que falte sin salir del ecosistema Debian.
- Ciclo de release predecible, patches de seguridad del equipo de Debian.

Contras:
- 70–80 MB base: no es "pequeña" para los estándares de 2024+.
- Trae shell y `apt`: si un atacante consigue RCE, tiene herramientas.

Cuándo elegirla: cuando no puedes pagar el coste de debug de distroless y tu equipo todavía necesita `docker exec sh` ocasional. Es el *baseline razonable*.

---

## 5. `alpine` — pequeña, pero con asterisco gigante

Alpine mide ~7 MB porque usa **musl libc** (no glibc) y **BusyBox** (no GNU coreutils). Está diseñada para ser mínima.

El problema para Python (y Node, y Ruby, y Rust con ciertas crates): **las wheels precompiladas de PyPI (manylinux) asumen glibc**. En Alpine, `pip install cryptography` o `pip install numpy` *no encuentra wheel compatible* y cae a **compilar desde fuente**. Eso significa:

- Necesitas `gcc`, `musl-dev`, `libffi-dev`, `openssl-dev`, headers de Python, Rust toolchain para `cryptography` moderno...
- El build pasa de 10 s a 10 min.
- La imagen final (si no haces multi-stage) se infla por el toolchain.
- Hay bugs sutiles por diferencias musl vs glibc: resolución DNS, threading, `getaddrinfo`, memoria.

Existe el proyecto `musllinux` (PEP 656) y cada vez más wheels están disponibles, pero la cobertura **no** es completa.

Casos donde Alpine sí tiene sentido:
- Imágenes de **Go / Rust estáticos**: no te importa libc porque no la usas.
- Herramientas de línea de comandos simples (shell scripts, `curl`, utilidades).
- Imágenes de nginx, redis, etc., donde la propia upstream mantiene variantes alpine testeadas.

Casos donde Alpine es trampa:
- **Apps Python con extensiones C** (ML, cripto, drivers de DB). La "ganancia" en tamaño se la come la pesadilla de mantenimiento.

Regla: si vas a Alpine por el tamaño, revisa primero `distroless`.

---

## 6. Distroless — "sin distribución"

Distroless (Google) es una familia de imágenes que contiene **sólo** lo necesario para ejecutar la app: glibc, certificados CA, `/etc/passwd` con un usuario `nonroot`, el runtime del lenguaje (Python, Node, Java, estática, ...). **No tiene shell, ni `apt`, ni `ls`, ni nada**.

Variantes:
- `gcr.io/distroless/static-debian12` — para binarios estáticos (Go, Rust).
- `gcr.io/distroless/base-debian12` — glibc + libssl + libcrypto, sin runtime de lenguaje.
- `gcr.io/distroless/python3-debian12` — Python 3 + glibc.
- `gcr.io/distroless/nodejs20-debian12` — Node 20.
- Tag `:debug` — variante **con** BusyBox, para troubleshooting; **no** usar en prod.

Pros:
- Superficie mínima: no hay shell que spawn-ear, no hay `curl` para exfiltrar.
- Pesa menos que slim.
- Mantenida por Google, se reconstruye con cada CVE de Debian.
- `USER nonroot:nonroot` ya configurado.

Contras:
- **No puedes `docker exec -it <id> sh`** — no hay shell. Para debug necesitas:
  - usar la variante `:debug` en entornos de QA,
  - o adjuntar un contenedor efímero (`kubectl debug`, `docker run --pid=container:X ...`),
  - o loguear bien desde el principio.
- El `ENTRYPOINT` del *base* es el intérprete (ej. `python3`). Tu `CMD` son los args. Esto cambia el patrón mental si venías de "siempre `CMD ["python", "app.py"]`".
- No puedes instalar nada en runtime. Todo lo que necesites debe venir del builder stage de un multi-stage.

Cuándo elegirla: **producción Python, Node, Java, Go**. Es el default moderno.

---

## 7. Chainguard images — la variante "zero-known-CVE"

Chainguard mantiene una familia de imágenes construidas sobre **Wolfi** (una distro "undistro" diseñada específicamente para contenedores, con glibc y rolling release). Objetivo declarado: **cero CVEs conocidas al momento de release**, firma Sigstore nativa, SBOM nativa.

Comparación práctica vs distroless:
- Mismo espíritu "mínimo", a menudo con glibc, sin shell en variantes "prod".
- Variantes `-dev` con shell y toolchain para builder stages.
- Más agresivas con el ciclo de patch (rolling), lo que a su vez implica que **no puedes pinnear tags "estables" por meses** sin re-escanear.
- La mayoría de imágenes son free; las "FIPS", "LTS" y algunas específicas son pagas.

Elegir Chainguard sobre distroless si tu política de supply chain exige firma y SBOM en el `FROM` desde el día cero, o si tu auditor te pide "zero known CVE" por escrito.

---

## 8. `scratch` + binario estático

`FROM scratch` arranca con una imagen literalmente **vacía**: 0 bytes, 0 archivos, 0 libc. Sólo tiene sentido si lo que vas a correr es un binario **estáticamente enlazado** (todo compilado adentro).

Ecosistemas que esto permite:
- **Go** (`CGO_ENABLED=0 go build`) — binario único, portátil.
- **Rust** con target `*-unknown-linux-musl`.
- **C/C++** con `-static` (con cuidado por glibc / NSS).

Qué te falta y hay que copiar a mano si lo necesitas:
- Certificados CA: `COPY --from=alpine /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/`.
- Timezone data: `COPY --from=alpine /usr/share/zoneinfo /usr/share/zoneinfo`.
- Un `/etc/passwd` mínimo si tu binario resuelve `getpwuid`.
- `nsswitch.conf` si tu binario hace resolución DNS no-trivial.

Tamaño típico: un hello-world Go pesa **~2 MB**. Un servicio real Go pesa ~15–30 MB.

**No** uses `scratch` para Python / Node / Java: su runtime no es estático.

---

## 9. Medir: `docker history` y `dive`

`docker history IMAGE` muestra, por capa, el comando que la creó y los bytes que añadió.

```
docker history --no-trunc --format "table {{.Size}}\t{{.CreatedBy}}" app:slim
```

Qué buscar:
- Capas grandes creadas por `apt-get install` o `pip install` sin limpieza.
- Capas creadas por `COPY . .` que meten `.git/`, `node_modules/`, `__pycache__`.
- Capas de "limpieza" (`rm -rf`) que **no** reducen tamaño porque van después.

`dive` (herramienta externa, `wagoodman/dive`) va más allá: muestra el filesystem de cada capa y resalta ineficiencias (archivos sobrescritos, archivos añadidos y luego borrados en otra capa). Es la mejor herramienta para diagnosticar.

Instalación rápida:
```
# macOS
brew install dive
# Linux (binario estático)
curl -L -o dive.tar.gz https://github.com/wagoodman/dive/releases/latest/download/...
```

Si no quieres instalarla, el ejemplo `02-dive-walkthrough/` describe qué verías.

---

## 10. Patrón multi-stage para apps Python

El patrón canónico para una app Python moderna que apunta a < 100 MB:

```dockerfile
# syntax=docker/dockerfile:1

# ---- builder: tiene toolchain, pip, compiladores ----
FROM python:3.12-slim AS builder
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /build
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt
COPY src/ ./src/

# ---- runtime: distroless, sin shell, sin pip ----
FROM gcr.io/distroless/python3-debian12:nonroot
WORKDIR /app
COPY --from=builder /install /usr/local
COPY --from=builder /build/src /app/src
USER nonroot
ENTRYPOINT ["python3", "-m", "src.main"]
```

Observaciones:
- `--prefix=/install` instala en un árbol aislado que se copia completo al runtime.
- `PIP_NO_CACHE_DIR=1` evita que pip deje ~100 MB de wheels cacheadas que nunca más usarás.
- El runtime no tiene `pip`: no puedes instalar nada en el contenedor en producción. Es intencional.
- `USER nonroot` ya está en la base distroless.
- `ENTRYPOINT` es `python3` en la base; nosotros lo sobre-escribimos con nuestro módulo.

Alternativas modernas:
- Usar **`uv`** en el builder (mucho más rápido que pip, misma salida).
- Usar `pip wheel` para pre-compilar y luego `pip install --find-links=./wheels/` en runtime (útil cuando el runtime es distroless y no puede compilar).

---

## 11. Cold-start y pull-time en clusters

En un orquestador (K8s, ECS, Nomad), el tiempo que tarda un Pod en estar `Ready` tiene esta descomposición grosera:

```
Ready = schedule + pull + extract + start_container + readiness_probe_passes
```

- **`pull`**: proporcional al tamaño comprimido no cacheado en el nodo. Un `FROM python:3.12` (~140 MB comprimidos) vs `distroless` (~25 MB) son segundos de diferencia.
- **`extract`**: descompresión + overlay merge. Proporcional al número y tamaño de capas.
- **`start_container`**: creación de namespaces, cgroups, mounts. Decenas de ms.
- **`readiness_probe_passes`**: tu app arranca; si es un intérprete (Python, Node, JVM), aquí vive el verdadero cold-start.

Reducir la imagen ataca el `pull + extract`, no el startup del intérprete. Para atacar el intérprete necesitas:
- Precargar módulos.
- JIT caches (JVM) o AOT compilation.
- `python -O`, pyc precompilados.

Pero en autoscaling y en edge, **el pull domina**. Una imagen 5x más pequeña se nota.

---

## 12. CVEs: pequeño no es sinónimo de seguro

Dos verdades incómodas:

1. **Una imagen pequeña con una CVE crítica es insegura.** `alpine` ha tenido CVEs en `musl` y `busybox`.
2. **Una imagen grande sin CVEs conocidas es más segura que una pequeña con 20 CVEs.** El tamaño es una *proxy* de la superficie, no la medida directa.

Herramientas para medir CVEs (se profundizan en `dkr-14`):
- **Trivy** (`aquasec/trivy`): `trivy image app:slim`.
- **Grype** (`anchore/grype`): `grype app:slim`.
- Reporte: cuenta de Critical / High / Medium / Low por imagen.

Metodología para la ADR del módulo:
1. Construye la misma app sobre `slim`, `alpine`, `distroless`.
2. Mide: tamaño (comprimido y descomprimido), tiempo de pull desde registry limpio, cold-start (`time docker run --rm img python -c 'print(1)'`), CVEs Critical/High.
3. Decide con los números, no con la vibra.

Preguntas de evaluación (sin consultar):

- ¿Por qué pip install deja caché por default y por qué eso infla las imágenes?
- ¿Qué pasa si haces `RUN rm -rf /var/cache/apt` en una capa separada del `apt-get install`?
- ¿Por qué `alpine` rompe `pip install cryptography` sin toolchain extra?
- ¿Cómo abres una shell en una imagen distroless sin shell? (Pista: no la abres; usas `kubectl debug` o la variante `:debug`.)
- ¿En qué escenario `scratch` es la elección correcta? ¿En cuál es un error?
- ¿Qué información te da `dive` que `docker history` no te da?
- ¿Por qué el `COPY --from=builder /install /usr/local` del patrón multi-stage es seguro aunque `/install` haya tenido toolchain?
