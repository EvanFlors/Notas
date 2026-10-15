# Actividad 01 — Mapa anotado: namespaces, cgroups y pila Docker→runc

## 1. Identificación

- **ID:** `dkr-01-01-draw-namespaces-and-cgroups`
- **Tecnología:** `docker`
- **Módulo:** `dkr-01-mental-model-and-oci`
- **Dificultad:** beginner
- **Duración estimada:** 40–60 min
- **Tipo:** independent

## 2. Contexto

Esta es la actividad **conceptual** del módulo. No requiere Docker instalado ni Linux: se puede completar en cualquier editor de texto.

Se trata de producir un **mapa anotado** que demuestra que entendiste el modelo mental. Si no puedes escribirlo con tus palabras, no lo entiendes todavía.

Es la actividad que valida comprensión real — no si recuerdas los nombres.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Nombrar los 7 namespaces de Linux y qué recurso aisla cada uno.
- Nombrar al menos 4 controladores de cgroups v2 y qué limita cada uno.
- Dibujar la pila `Docker CLI → dockerd → containerd → containerd-shim → runc → kernel`.
- Indicar **en qué nivel** se ejecutan las syscalls `clone`/`unshare`/`setns`/`mount`/`pivot_root`.
- Explicar por qué una imagen construida con Docker la puede ejecutar Podman o nerdctl sin reconstruir.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` completo (al menos §4).
- Haber recorrido `examples/01-processes-vs-containers/`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/dkr-01-mental-model
cd /tmp/dkr-01-mental-model
```

(Puedes usar otro directorio si pasas la ruta a `validate.sh`; el default es `/tmp/dkr-01-mental-model`.)

### 5.2 Entregable: `MAP.md`

Produce un archivo `MAP.md` con **cuatro secciones** explícitas:

#### A. Namespaces de Linux

Tabla con los 7 namespaces. Para cada uno:

| Namespace | Qué aisla | Ejemplo de "antes vs después" |
|-----------|-----------|-------------------------------|
| pid       | ...       | ...                            |
| mnt       | ...       | ...                            |
| net       | ...       | ...                            |
| user      | ...       | ...                            |
| uts       | ...       | ...                            |
| ipc       | ...       | ...                            |
| cgroup    | ...       | ...                            |

El "ejemplo antes vs después" puede ser una frase corta: p. ej. para `uts`, "antes: `hostname` muestra el del host; después: muestra el que yo le ponga, sin afectar al host".

Al final de la sección, añade **una frase** sobre el estado por default de `user namespace` en Docker (está disponible pero NO activado por default y por qué).

#### B. Controladores de cgroups v2

Lista con al menos 4 controladores. Para cada uno:

- Nombre del controlador (ej. `cpu`, `memory`, `pids`, `io`).
- Archivo clave en `/sys/fs/cgroup/.../` (ej. `memory.max`).
- Qué pasa si un proceso del cgroup intenta superar el límite.

#### C. Pila Docker → runc

Dibuja (ASCII o Mermaid) la pila **de arriba hacia abajo** con **al menos**: `docker CLI`, `dockerd`, `containerd`, `containerd-shim`, `runc`, `kernel`. Para **cada eslabón**, una frase describiendo **su responsabilidad**:

```
┌─────────────┐
│ docker CLI  │  ← parsea args, llama al daemon
└─────────────┘
     ...
```

Indica explícitamente en qué eslabón se hacen las syscalls `clone`/`unshare`/`setns`/`mount`/`pivot_root`.

#### D. Por qué OCI permite intercambiar runtimes

En 3–5 frases, responde: si construyo una imagen con `docker build`, ¿por qué puede ejecutarla Podman, nerdctl o Kubernetes sin reconstrucción? Nombra las **tres specs OCI** en tu respuesta.

### 5.3 Preguntas obligatorias (al final de `MAP.md`)

Numera las respuestas **del 1 al 7**:

1. Un contenedor Linux "estándar" (sin `--privileged`) aísla ¿cuáles de los 7 namespaces por default? ¿Cuál NO aísla por default y por qué?
2. ¿Qué pasaría si Docker arrancara un contenedor **sin** aplicar cgroups? Da un escenario concreto.
3. Un proceso dentro de un contenedor se cree PID 1. Desde el host, ese mismo proceso tiene otro PID (ej. 2340). ¿Son el mismo proceso o dos procesos distintos? Justifica.
4. ¿Cuál es la diferencia funcional entre `runc` y `containerd`? Si tuvieras que reemplazar uno sin cambiar el otro, ¿cuál sería más fácil y por qué?
5. ¿Qué parte del stack realiza las syscalls `clone` / `unshare` / `setns` / `pivot_root`? ¿Y las syscalls `mount` para el overlayfs?
6. Un contenedor con `--privileged` tiene todas las capabilities. Si además monta `/var/run/docker.sock`, ¿qué puede hacer? ¿Por qué se considera equivalente a root en el host?
7. Verifica tu diagrama de la pila ejecutando (si tienes Linux + Docker, OPCIONAL): `pstree -p $(pidof dockerd)` y `pstree -p $(pidof containerd)`. Si no tienes acceso, describe qué **esperarías** ver y por qué.

### 5.4 Validar estructura

```bash
bash tests/validate.sh /tmp/dkr-01-mental-model
```

Chequea que `MAP.md` exista y contenga las cuatro secciones mínimas (A, B, C, D), los 7 namespaces nombrados, los controladores de cgroups, los componentes de la pila y las 7 respuestas numeradas. **No valida contenido semántico** — eso lo verificas contra `solution/MAP-reference.md`.

## 6. Resultado esperado

- Archivo `MAP.md` en `/tmp/dkr-01-mental-model/` con secciones A, B, C, D y 7 respuestas numeradas.
- `tests/validate.sh` pasa.
- Autocomparas con `solution/MAP-reference.md` para calibrar.

## 7. Criterios de aceptación

- [ ] Los 7 namespaces (pid, mnt, net, user, uts, ipc, cgroup) aparecen por nombre.
- [ ] Al menos 4 controladores de cgroups mencionados por nombre (`cpu`, `memory`, `pids`, `io`, …).
- [ ] Diagrama de pila incluye `docker`, `dockerd`, `containerd`, `runc`, `kernel`.
- [ ] Se identifica a `runc` como el que hace `clone/unshare/setns`.
- [ ] Las 3 specs OCI mencionadas por nombre en la sección D.
- [ ] Las 7 preguntas respondidas (como `1.`, `2.`, ... al inicio de línea).

## 8. Validación

```bash
bash tests/validate.sh /tmp/dkr-01-mental-model
```

Estructural. **Semántica** la calibras tú con `solution/MAP-reference.md`.

## 9. Preguntas de reflexión

Más allá de las obligatorias:

1. Si Linux no tuviera `user namespace`, ¿sería posible correr "rootless containers"? ¿Por qué?
2. ¿Por qué un contenedor Docker en macOS vive dentro de una VM Linux? Explica en términos del kernel.
3. Si cambias `runc` por `crun`, ¿cambia algo visible para el usuario de `docker run`? ¿Y para un operador que debuggea?

## 10. Extensiones (opcional)

- **E1** — Si estás en Linux, ejecuta `ls -l /proc/$$/ns/` y compara los inodos con `ls -l /proc/1/ns/`. Explica qué significa que algunos coincidan.
- **E2** — Lee `man 7 namespaces` y añade a tu `MAP.md` qué namespace apareció más tarde históricamente (hint: `cgroup namespace`).
- **E3** — Lee los primeros 2 archivos de `/sys/fs/cgroup/` en una máquina Linux (sin Docker) y explica qué controladores están disponibles por default.

## 11. Limpieza

```bash
rm -rf /tmp/dkr-01-mental-model
```
