# dkr-05 — Networking básico en Docker

## Identificación

- **ID:** `dkr-05-networking-basics`
- **Curso:** `docker`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `dkr-02-install-engine-and-first-container`; T-3 Networking básico (direcciones IP, puertos TCP/UDP, NAT, DNS).

## Objetivo

Entender cómo se comunican los **contenedores entre sí** y **con el host**: qué drivers de red ofrece Docker, qué pasa por debajo (bridge Linux `docker0`, reglas `iptables`), qué cambia entre `-p host:container` y `--network host`, por qué `localhost` dentro de un contenedor no es el host, y cómo diagnosticar "no puedo conectar a mi contenedor".

## Alcance

Este módulo cubre:

- Drivers de red disponibles: `bridge` (default), `host`, `none`, `macvlan`, `overlay` (mención).
- El bridge Linux `docker0`: qué es y cómo se materializa en el kernel.
- Reglas `iptables` que Docker inserta (cadena `DOCKER`, `MASQUERADE`, DNAT por `-p`).
- Publicación de puertos: `-p HOST:CONTAINER`, `-p 127.0.0.1:HOST:CONTAINER`, puertos ya ocupados.
- `--network host` y su diferencia radical con `-p` (elimina el net namespace).
- Resolución de DNS entre contenedores en una **user-defined bridge** (la default NO lo habilita).
- Diagnóstico de problemas típicos: `localhost` adentro, puerto ocupado afuera, nombre no resuelve.
- Diferencias prácticas en macOS/Windows (Docker Desktop corre una VM Linux).

Lo que **no** cubre (vendrá después):
- Compose networks y `depends_on` → `dkr-08`.
- `overlay` networks multi-host y Swarm → fuera del scope.
- CNI, Kubernetes networking → curso Kubernetes (D8).
- Hardening (`--cap-drop=NET_RAW`, egress policies) → `dkr-13`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones (3 h de lectura + exploración).
- **`examples/`** — ejemplos reproducibles:
  - `01-user-defined-bridge/` — dos contenedores que se resuelven por nombre vía DNS.
  - `02-port-publishing/` — `-p 8080:80` vs `--network host`, cuándo cada uno.
  - `03-why-cant-i-reach-localhost/` — el pitfall más común explicado y corregido.
- **`activities/`**:
  - `01-two-containers-talking-by-name/` — **guided-lab**: crear una user-defined bridge, levantar `db` y `app`, confirmar que `app` resuelve `db` por nombre.
  - `02-debug-published-port/` — **independent-debug**: setup intencionalmente roto; diagnóstico y arreglo.
- **`resources/links.md`** — documentación oficial y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `localhost` dentro de un contenedor **no** es el host. Diferenciar `bridge` default vs user-defined. Describir qué hace Docker con `iptables` al publicar un puerto. Explicar qué quita `--network host`. |
| Operativa | Crear una user-defined bridge, correr dos contenedores en ella y verificar DNS por nombre. Publicar puertos y diagnosticar colisiones. Inspeccionar la red con `docker network inspect` y `docker inspect <c>`. |
| Arquitectónica | Diseñar la red de una app + DB (una network aislada por entorno, sin publicar puertos innecesarios). Decidir cuándo usar `--network host` (y por qué casi nunca es la respuesta). |

## Criterios de evaluación

- Diagrama de red para `app + db` en una user-defined bridge, con puertos publicados mínimos.
- Respuesta argumentada: *por qué `localhost` dentro del contenedor NO es el host*.
- `tests/validate.sh` de cada actividad pasa (requiere `docker` disponible; omite con `SKIP` si no).

## Docker: requisitos y comportamiento multi-OS

- **Requiere Docker Engine o Docker Desktop**. Si falta, las actividades reportan `SKIP` (no `FAIL`).
- **Linux**: todo lo que describe la lección es literal (bridge `docker0`, `iptables`, net namespaces).
- **macOS / Windows (Docker Desktop)**: el "host" real desde el punto de vista de contenedores es una **VM Linux**; por eso `--network host` **no** expone al Mac/Windows, y `-p` sigue siendo la forma correcta. Los ejemplos lo señalan explícitamente.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin consultar nada externo).
2. Reproduce `examples/01-user-defined-bridge/`, luego `02-port-publishing/`, luego `03-why-cant-i-reach-localhost/`.
3. Haz la actividad `01-two-containers-talking-by-name/` (guided).
4. Haz la actividad `02-debug-published-port/` sin consultar la solución.
5. Responde las preguntas de evaluación de la lección sin re-leer.

## Siguiente

→ `dkr-06-dockerfile-idiomatic-and-caching`: escribir Dockerfiles rápidos y mantenibles aprovechando la caché de BuildKit.
