# dkr-13 — Runtime security y hardening

## Identificación

- **ID:** `dkr-13-runtime-security-and-hardening`
- **Curso:** `docker`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `dkr-10-internals-namespaces-cgroups-overlayfs`, `dkr-11-image-optimization-and-base-image-strategy`. Linux básico (T-2). Haber construido imágenes multi-stage (`dkr-07`).

## Objetivo

Desplegar contenedores siguiendo el **principio de mínimo privilegio** y **defensa en profundidad**: una imagen productiva que no sea root por default, un filesystem de raíz de solo lectura, capabilities reducidas al mínimo necesario, prohibición de elevación de privilegios, límites de recursos cuantificados y una auditoría automatizada de vulnerabilidades y mala configuración. Al terminar, debes poder leer un `docker run` arbitrario y producir una auditoría escrita señalando los riesgos presentes y las mitigaciones concretas.

## Alcance

Este módulo cubre:

- `USER` no-root en Dockerfile y por qué `--user` en runtime no basta.
- `--read-only` + `--tmpfs` para rutas que la app necesita escribir.
- Modelo de **capabilities** Linux: `--cap-drop=ALL --cap-add=<minimal>`.
- `--security-opt no-new-privileges` y cómo cierra la vía de setuid/setgid.
- **seccomp**: perfil por default de Docker, cómo auditarlo y cómo escribir uno custom.
- Nociones de **AppArmor** / **SELinux** (MAC) y cuándo entran en juego.
- **Rootless Docker** y **Podman rootless**: qué resuelven y qué no (puertos privilegiados, overlay, fuse-overlayfs).
- Límites de recursos: `--memory`, `--memory-swap`, `--cpus`, `--pids-limit`, `--ulimit`.
- Por qué **nunca** se monta `/var/run/docker.sock` dentro de un contenedor no confiable.
- Auditoría de imágenes: `docker scan` deprecado → **Trivy** / **grype** para vulnerabilidades y misconfig.
- Referencia operacional: **CIS Docker Benchmark**.

Lo que **no** cubre (vendrá después):

- Firma, SBOM, attestations, verificación con cosign → `dkr-14`.
- Políticas de admisión en Kubernetes (Kyverno, OPA/Gatekeeper, policy-controller) → cursos D8/D9.
- Secrets managers (Vault, cloud KMS) → curso DevSecOps D9.
- Runtime detection (Falco, Tracee) → mencionado, no profundizado.

## Materiales

- **`theory/lesson.md`** — lección profunda, 12 secciones. Lee de principio a fin antes de los ejemplos.
- **`examples/`** — tres ejemplos reproducibles:
  - `01-least-privilege-container/` — Dockerfile `USER` no-root + `docker run` con todos los switches (`--cap-drop ALL`, `--read-only`, `--security-opt no-new-privileges`, `--pids-limit`, `--memory`, `--cpus`). Walkthrough de qué comprueba cada flag.
  - `02-trivy-scan/` — escaneo con **Trivy** de vulnerabilidades (CVE) y misconfig del Dockerfile. Interpretación de severidad y de `--exit-code`.
  - `03-why-not-mount-docker-sock/` — demostración controlada de por qué `docker.sock` dentro del contenedor es equivalente a root en el host.
- **`activities/`** — dos actividades:
  - `01-harden-fastapi-container/` — **guided-lab**. Dockerfile para una app FastAPI mínima + `docker run` endurecido; el validador inspecciona la configuración runtime del contenedor con `docker inspect` y verifica los seis controles exigidos.
  - `02-container-escape-reasoning/` — **independent**. Análisis escrito de vectores comunes de escape (docker.sock, `--privileged`, `CAP_SYS_ADMIN`, montar `/`, kernel exploits) sin ejecutarlos. El validador comprueba la estructura de `ANALYSIS.md`.
- **`resources/links.md`** — documentación oficial, CIS Benchmark, Trivy/grype, Sigstore.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué es una capability y por qué `--privileged` no equivale a "root común". Diferenciar seccomp de capabilities y de AppArmor/SELinux. Explicar por qué el daemon de Docker rootful corre como root y qué cambia en rootless. |
| Operativa | Escribir un Dockerfile con `USER` no-root y un `docker run` con los seis controles principales. Correr Trivy sobre una imagen e interpretar su reporte. Diagnosticar por qué un contenedor con `--read-only` crashea al escribir en `/tmp` y arreglarlo con `--tmpfs`. |
| Arquitectónica | Leer un `docker run` dado y producir una auditoría escrita (riesgos, por qué, mitigación concreta). Decidir cuándo rootless Docker es suficiente y cuándo requieres Podman rootless o un orquestador con PodSecurityStandards. |

## Criterios de evaluación

- Imagen FastAPI que arranca con **UID no-root**, root FS `read-only`, `ALL` capabilities dropped (sólo las mínimas añadidas, si cualquiera), `no-new-privileges=true`, `--memory` y `--pids-limit` establecidos. El contenedor responde HTTP sin ningún error de "permission denied".
- `tests/validate.sh` de la Actividad 01 pasa (verifica los seis controles vía `docker inspect`).
- `ANALYSIS.md` de la Actividad 02 explica correctamente al menos **cuatro** vectores de escape, con mecanismo técnico, cómo detectarlo en un `docker run` y mitigación.
- Auditoría escrita de un `docker run` dado por el instructor (ejemplos en `theory/lesson.md` §12) señalando riesgos con precisión técnica, no genérica.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (1 h 30 min; es denso).
2. Reproduce `examples/01-least-privilege-container/`. Rompe cosas a propósito (quita `--read-only`, agrega `--privileged`, observa).
3. Si tienes Trivy instalado, reproduce `examples/02-trivy-scan/`. Si no, lee el ejemplo — es útil incluso sin ejecutarlo.
4. Lee `examples/03-why-not-mount-docker-sock/` **antes** de ejecutarlo. Luego ejecútalo en `/tmp/` y limpia.
5. Haz la Actividad 01 en modo guiado. Valida.
6. Haz la Actividad 02 sin consultar la lección a medida que escribes — es la que valida comprensión real.

## Siguiente

→ `dkr-14-supply-chain-sbom-signing-provenance`: SBOM con syft, firma keyless con cosign, attestations SLSA, verificación en entornos de admisión.

## Notas sobre entorno

- Requiere **docker** instalado y funcional (daemon rootful es suficiente para todas las actividades; donde rootless cambia el resultado se indica en la lección).
- **Trivy** es opcional en el Ejemplo 02 y en el escaneo bonus de la Actividad 01 — si no está instalado, el validador imprime `SKIP` y continúa.
- Todos los artefactos de ejecución viven en `/tmp/dkr-13-*/` para no ensuciar el repo. Cada actividad incluye su sección de limpieza.
