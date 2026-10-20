# Ejemplo 01 — STRIDE aplicado a un servicio FastAPI

> Lectura y análisis. Sin ejecución. Objetivo: ver cómo las 6 letras de STRIDE se materializan en un servicio web realista y pequeño.

## 1. El servicio bajo análisis

Imagina una API HTTP pequeña:

- **Stack:** FastAPI + Postgres + Redis.
- **Endpoints:**
  - `POST /login` — recibe email + password, devuelve JWT.
  - `GET /me` — requiere JWT, devuelve perfil del usuario.
  - `POST /orders` — requiere JWT, crea una orden (consulta inventario en Redis, inserta en Postgres).
- **Deploy:** container en Kubernetes detrás de un Ingress público (TLS terminado en el ingress).
- **Dependencias:** `fastapi`, `uvicorn`, `sqlalchemy`, `redis`, `pyjwt`, `bcrypt`.

## 2. DFD mínimo

```
            [User (browser)]
                  │  HTTPS
   ─ ─ ─ ─ ─ ─ ─ ─│─ ─ ─ ─ ─ ─ ─ ─  trust boundary: internet ↔ VPC
                  ▼
             ( Ingress / TLS )
                  │  HTTP (VPC)
                  ▼
             ( FastAPI pod )
                  │               \
                  │  SQL (TLS)     \  Redis protocol (TLS?)
                  ▼                 ▼
             [[ Postgres ]]     [[ Redis ]]
   ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
            [GitHub Actions] ──► [Image Registry] ──► Kubernetes
                  (CI builds and pushes the image)
```

Trust boundaries presentes:

1. Internet ↔ VPC (en el Ingress).
2. FastAPI ↔ Postgres (red interna, pero autenticación propia).
3. FastAPI ↔ Redis (ídem; muchas veces *sin* auth, es un bug clásico).
4. CI ↔ Registry (quién puede pushear imágenes).
5. Registry ↔ Cluster (quién puede desplegar).

## 3. Tabla STRIDE anotada

| ID | Letra | Amenaza concreta | Afecta a | Mitigación recomendada |
|----|-------|------------------|----------|------------------------|
| T01 | **S**poofing | JWT firmado con secreto débil → token forjado. | `/me`, `/orders` | Secreto largo, rotación, algoritmo asimétrico (RS256/EdDSA) a largo plazo. |
| T02 | **S**poofing | Phishing/credential stuffing contra `/login`. | Cuentas de usuario | Rate limit por IP y por email, MFA, protección contra credential stuffing (HIBP). |
| T03 | **T**ampering | Modificación del payload JWT (algoritmo `none` o `alg confusion`). | `/me`, `/orders` | Validación estricta de `alg` esperado; usar librería que no acepte `none`. |
| T04 | **T**ampering | Mutación de la imagen en el registry sin firma. | Despliegues | Firma de imágenes (cosign) + admission controller que verifica (`sec-09`, `sec-11`). |
| T05 | **R**epudiation | Falta de audit log de `POST /orders` → usuario niega haber ordenado. | Compliance | Append-only audit log con `user_id`, `order_id`, `trace_id`; retención según regulación. |
| T06 | **I**nformation disclosure | Stack trace con secretos en respuesta HTTP ante error no capturado. | Cualquier endpoint | `debug=False` en prod; middleware de error que loguea detalle y devuelve mensaje genérico. |
| T07 | **I**nformation disclosure | Redis sin auth y expuesto en VPC → cualquier pod lee sesiones. | Sesiones, cache | `requirepass` + NetworkPolicy que solo permita al namespace de la API. |
| T08 | **I**nformation disclosure | Logs con PII (emails, IPs) sin retención ni acceso controlado. | PII | Scrubber de PII en logging pipeline; retención corta; acceso con break-glass. |
| T09 | **D**oS | `/login` sin rate limit → ataque de fuerza bruta satura CPU. | Disponibilidad | Rate limit por IP + por email; backoff; Captcha tras N intentos. |
| T10 | **D**oS | `POST /orders` con payloads enormes (JSON de 100 MB) → OOM del pod. | Disponibilidad | Límite de body size en el Ingress y en FastAPI; validación de longitudes. |
| T11 | **D**oS | ReDoS: expresión regular de validación de email con backtracking exponencial. | CPU | Usar validador de email que no sea regex vulnerable; test con inputs patológicos. |
| T12 | **E**oP | SQL injection en una query de `POST /orders` por f-string. | DB, otros usuarios | ORM parameterizado; code review; SAST (Semgrep rule) — ver `sec-06`. |
| T13 | **E**oP | Container corre como `root` → escape a nodo si hay exploit kernel. | Nodo entero | `runAsNonRoot`, `readOnlyRootFilesystem`, drop ALL capabilities; PSA restricted — `sec-11`. |
| T14 | **E**oP | ServiceAccount del pod con RBAC excesivo (p. ej. `cluster-admin`). | Cluster entero | SA dedicado con permisos mínimos; auditar con `rakkess` / `kubectl who-can`. |

## 4. Lecciones a extraer

- STRIDE no "inventa" amenazas: las **estructura** y evita que te olvides de una categoría.
- Muchas amenazas se **repiten** con pequeñas variantes (hay tres `Information disclosure` en este ejemplo). Agrupar por mitigación común es sano (p. ej. "middleware de error + scrubber de PII" cubre T06 y T08 en gran parte).
- Las amenazas más caras de corregir después (`T04`, `T13`, `T14`) son las más baratas de prevenir desde el día 1.
- **Lo que no está en la tabla también importa**: nada de supply chain (manejado por SLSA/SBOM/cosign — ver §7, §8 de la lección), nada de secretos (ver `sec-02`), nada de scanning (ver `sec-03`). Threat model acotado = threat model útil.

## 5. Para discutir

- ¿Qué amenaza de la tabla priorizarías para "arreglar YA" si tuvieras 1 día?
- ¿Qué mitigaciones son **compartidas** entre varias amenazas (una pieza, muchas defensas)?
- ¿Qué assumptions tácitas has detectado al leer la tabla? (ej.: "existe un Ingress", "existe NetworkPolicy").
