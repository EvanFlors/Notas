# CMD, ENTRYPOINT y Shell/Exec Form: Guía Completa

> *"The container's PID 1 is the single most important process. Get it right, and everything works. Get it wrong, and nothing shuts down gracefully."*
> — Bret Fisher, Docker Captain

---

## Tabla de Contenidos

### Parte I — CMD y ENTRYPOINT
- [1. CMD](#1-cmd)
  - [1.1 Definición y sintaxis](#11-definición-y-sintaxis)
  - [1.2 Sobreescritura en runtime](#12-sobreescritura-en-runtime)
- [2. ENTRYPOINT](#2-entrypoint)
  - [2.1 Definición y sintaxis](#21-definición-y-sintaxis)
  - [2.2 Sobreescritura en runtime](#22-sobreescritura-en-runtime)
- [3. CMD vs ENTRYPOINT](#3-cmd-vs-entrypoint)
  - [3.1 Diferencias fundamentales](#31-diferencias-fundamentales)
  - [3.2 Tabla de interacción CMD/ENTRYPOINT](#32-tabla-de-interacción-cmdentrypoint)
- [4. ENTRYPOINT + CMD juntos](#4-entrypoint--cmd-juntos)
  - [4.1 Caso 1: Contenedor como CLI tool](#41-caso-1-contenedor-como-cli-tool)
  - [4.2 Caso 2: Startup script + proceso principal](#42-caso-2-startup-script--proceso-principal)
- [5. Cuándo usar cada uno](#5-cuándo-usar-cada-uno)

### Parte II — Shell Form vs Exec Form
- [6. Las dos formas de ejecutar comandos](#6-las-dos-formas-de-ejecutar-comandos)
- [7. Shell form](#7-shell-form)
- [8. Exec form](#8-exec-form)
- [9. Cuándo usar cada forma](#9-cuándo-usar-cada-forma)
- [10. Ejemplos prácticos de interacción](#10-ejemplos-prácticos-de-interacción)

### Parte III — PID 1 y Señales
- [11. ¿Qué es PID 1?](#11-qué-es-pid-1)
- [12. Señales de proceso](#12-señales-de-proceso)
- [13. El problema del shell form con señales](#13-el-problema-del-shell-form-con-señales)
- [14. exec "$@" en scripts de inicio](#14-exec--en-scripts-de-inicio)
- [15. Resumen de buenas prácticas](#15-resumen-de-buenas-prácticas)

---

# Parte I — CMD y ENTRYPOINT

---

# 1. CMD

---

## 1.1 Definición y sintaxis

`CMD` define el comando por defecto que se ejecuta al iniciar un contenedor. Es una instrucción **runtime** (se almacena como metadata, no crea capas) y de tipo **overwrite** (solo el último `CMD` tiene efecto).

### Tres formas

```dockerfile
# Exec form (recomendada):
CMD ["executable", "param1", "param2"]

# Exec form como argumentos de ENTRYPOINT:
CMD ["param1", "param2"]

# Shell form:
CMD command param1 param2
```

### Ejemplo básico

```dockerfile
FROM busybox
CMD ["hostname"]
```

```shell
docker build -t myhost .
docker run myhost          # Ejecuta 'hostname', imprime el container ID
```

---

## 1.2 Sobreescritura en runtime

`CMD` se sobreescribe fácilmente al pasar argumentos después del nombre de imagen:

```shell
# Sintaxis: docker run [OPTIONS] IMAGE [COMMAND] [ARG...]

docker run myhost              # Ejecuta CMD: hostname
docker run myhost date         # Sobreescribe CMD: ejecuta 'date' en vez de 'hostname'
docker run myhost echo "hi"   # Sobreescribe CMD: ejecuta 'echo hi'
```

> **Este es el mecanismo estándar.** La mayoría de imágenes oficiales (nginx, postgres, node) usan `CMD` para su proceso principal.

---

# 2. ENTRYPOINT

---

## 2.1 Definición y sintaxis

`ENTRYPOINT` define el ejecutable principal del contenedor. Al igual que `CMD`, es **runtime** y **overwrite** (solo el último cuenta).

### Dos formas

```dockerfile
# Exec form (recomendada):
ENTRYPOINT ["executable", "param1"]

# Shell form:
ENTRYPOINT command param1
```

---

## 2.2 Sobreescritura en runtime

A diferencia de `CMD`, **los argumentos de `docker run` NO sobreescriben `ENTRYPOINT`** — se añaden como argumentos:

```shell
docker run myimage arg1 arg2    # arg1 y arg2 se pasan como argumentos al ENTRYPOINT
```

Para sobreescribir el ENTRYPOINT se necesita el flag explícito:

```shell
docker run --entrypoint date myimage    # Reemplaza el ENTRYPOINT por 'date'
```

### Demostración

```dockerfile
FROM busybox
ENTRYPOINT ["hostname"]
```

```shell
docker build -t entryhost .
docker run entryhost               # Funciona: ejecuta 'hostname'
docker run entryhost date          # ERROR: 'hostname' recibe 'date' como argumento
docker run --entrypoint date entryhost  # Funciona: sobreescribe ENTRYPOINT
```

---

# 3. CMD vs ENTRYPOINT

---

## 3.1 Diferencias fundamentales

| Aspecto                     | CMD                              | ENTRYPOINT                       |
|----------------------------|----------------------------------|----------------------------------|
| Propósito                  | Comando por defecto              | Ejecutable principal fijo        |
| `docker run image arg`     | `arg` reemplaza CMD              | `arg` se añade como argumento    |
| Sobreescritura             | Automática al pasar argumentos   | Requiere `--entrypoint`          |
| Por sí solo                | ✅ Suficiente para la mayoría     | ⚠️ No ofrece ventajas vs CMD     |
| Combinado con el otro      | Provee argumentos por defecto    | Define el ejecutable base        |

> **ENTRYPOINT por sí solo no ofrece beneficios sobre CMD solo.** Su poder aparece cuando se combinan.

---

## 3.2 Tabla de interacción CMD/ENTRYPOINT

| Configuración                        | No ENTRYPOINT              | `ENTRYPOINT exec p1` (shell)    | `ENTRYPOINT ["exec", "p1"]` (exec) |
|--------------------------------------|----------------------------|---------------------------------|-------------------------------------|
| **No CMD**                           | Error                      | `/bin/sh -c exec p1`            | `exec p1`                           |
| **`CMD ["cmd", "p1"]`** (exec)      | `cmd p1`                   | `/bin/sh -c exec p1`            | `exec p1 cmd p1`                    |
| **`CMD cmd p1`** (shell)            | `/bin/sh -c cmd p1`        | `/bin/sh -c exec p1`            | `exec p1 /bin/sh -c cmd p1`         |

> **Regla crítica:** Si `CMD` se hereda de la imagen base, definir `ENTRYPOINT` resetea `CMD` a vacío. Debes redefinir `CMD` en tu Dockerfile.

---

# 4. ENTRYPOINT + CMD juntos

Cuando ambos están definidos, Docker los combina en un solo comando:

```
Comando final = ENTRYPOINT + " " + CMD
```

Esto habilita dos patrones poderosos:

---

## 4.1 Caso 1: Contenedor como CLI tool

El contenedor se comporta como un comando ejecutable:

```dockerfile
FROM ubuntu
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["curl"]
CMD ["--help"]
```

```shell
docker build -t mycurl .

# Sin argumentos → ejecuta 'curl --help' (CMD por defecto):
docker run mycurl

# Con argumentos → reemplaza CMD, ENTRYPOINT se mantiene:
docker run mycurl https://example.com
docker run mycurl -s -o /dev/null -w "%{http_code}" https://example.com
```

```
CÓMO FUNCIONA:

docker run mycurl                           → curl --help
docker run mycurl https://example.com       → curl https://example.com
docker run mycurl -v https://example.com    → curl -v https://example.com

ENTRYPOINT = ejecutable fijo
CMD = argumentos por defecto (fácilmente sobreescribibles)
```

> **Útil para:** herramientas CLI que no quieres instalar nativamente (curl, ffmpeg, awscli, terraform, etc.).

---

## 4.2 Caso 2: Startup script + proceso principal

El ENTRYPOINT ejecuta un script de inicialización que prepara el entorno, y luego pasa la ejecución al CMD:

```dockerfile
FROM mysql:8
COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mysqld"]
```

```
FLUJO DE EJECUCIÓN:

1. Docker ejecuta: docker-entrypoint.sh mysqld
2. El script configura: usuarios, permisos, base de datos
3. Al final del script: exec "$@"
4. exec reemplaza el shell por: mysqld (PID 1)
5. mysqld recibe señales directamente (SIGTERM, etc.)
```

### El script de inicialización

```bash
#!/bin/bash
set -e

# Configuración previa al inicio del proceso principal
if [ "$1" = 'mysqld' ]; then
    echo "Initializing database..."
    chown -R mysql:mysql /var/lib/mysql
    # ... más configuración
fi

# CRÍTICO: pasar ejecución al CMD (mysqld)
exec "$@"
```

> **`exec "$@"` es la línea más importante.** Reemplaza el proceso shell por el CMD, haciendo que el proceso principal sea PID 1.

### Sobreescritura útil del CMD

```shell
# Inicio normal (ejecuta mysqld):
docker run mysql

# Acceder a utilidades MySQL sin iniciar el servidor:
docker run -it mysql sh

# El ENTRYPOINT script sigue ejecutándose, pero detecta que
# el CMD no es 'mysqld' y puede omitir la configuración pesada
```

---

# 5. Cuándo usar cada uno

```
¿CUÁL NECESITO?

¿El contenedor ejecuta un proceso largo (web server, DB, app)?
  → CMD ["node", "server.js"]
  → No necesitas ENTRYPOINT

¿El contenedor es una herramienta CLI que se ejecuta y sale?
  → ENTRYPOINT ["herramienta"]
  → CMD ["--help"]

¿Necesitas un script de inicialización antes del proceso principal?
  → ENTRYPOINT ["docker-entrypoint.sh"]
  → CMD ["proceso-principal"]

¿Solo quieres un comando simple?
  → CMD ["comando"]
  → Ignora ENTRYPOINT
```

---

# Parte II — Shell Form vs Exec Form

---

# 6. Las dos formas de ejecutar comandos

Las instrucciones `RUN`, `CMD`, y `ENTRYPOINT` soportan dos formas de especificar comandos:

```dockerfile
# Exec form (JSON array):
INSTRUCTION ["executable", "param1", "param2"]

# Shell form (string):
INSTRUCTION command param1 param2
```

Estas formas **no son equivalentes**. Cambian fundamentalmente cómo Docker ejecuta el comando.

---

# 7. Shell form

Docker ejecuta el comando a través de un shell: `/bin/sh -c <comando>`.

```dockerfile
CMD echo "Hello $HOME"
# Docker ejecuta: /bin/sh -c 'echo "Hello $HOME"'
```

### Características

| Aspecto                 | Comportamiento                                 |
|------------------------|------------------------------------------------|
| Shell involucrado      | Sí (`/bin/sh -c` en Linux, `cmd /S /C` en Win) |
| Sustitución de vars    | ✅ `$HOME`, `$PATH`, etc.                       |
| Chaining de comandos   | ✅ `&&`, `||`, `;`                               |
| Pipes                  | ✅ `cmd1 | cmd2`                                  |
| Redirección I/O        | ✅ `>`, `>>`, `<`                                |
| PID 1                  | ❌ El shell es PID 1, no tu proceso             |
| Recibe señales         | ❌ El shell no reenvía señales al subproceso    |

---

# 8. Exec form

Docker ejecuta el comando **directamente**, sin invocar un shell.

```dockerfile
CMD ["echo", "Hello $HOME"]
# Docker ejecuta directamente: echo Hello $HOME
# $HOME NO se sustituye (no hay shell)
```

### Características

| Aspecto                 | Comportamiento                                 |
|------------------------|------------------------------------------------|
| Shell involucrado      | ❌ No                                            |
| Sustitución de vars    | ❌ No (no hay shell para procesarlas)            |
| Features de shell      | ❌ Sin `&&`, pipes, redirección                  |
| PID 1                  | ✅ Tu proceso es PID 1 directamente              |
| Recibe señales         | ✅ SIGTERM, SIGINT llegan al proceso             |
| Sintaxis               | JSON array: `["cmd", "arg1", "arg2"]`           |
| Comillas               | Solo comillas dobles (`"`) — es JSON             |

> **Las variables de `ENV` definidas en el Dockerfile SÍ están disponibles para el proceso** aunque uses exec form. Lo que no funciona es la sustitución inline por el shell.

### Si necesitas sustitución de variables en exec form

```dockerfile
# Invocar un shell explícitamente:
CMD ["sh", "-c", "echo Hello $HOME"]
```

---

# 9. Cuándo usar cada forma

| Instrucción            | Forma recomendada | Razón                                        |
|-----------------------|-------------------|----------------------------------------------|
| `RUN`                 | **Shell form**    | Necesitas `&&`, pipes, variables con frecuencia|
| `ENTRYPOINT`          | **Exec form**     | Shell form impide que CMD funcione correctamente|
| `CMD`                 | **Exec form**     | PID 1 directo, recibe señales                |
| `ENTRYPOINT` + `CMD`  | **Exec form ambos** | Evita edge cases al mezclar formas         |

```
REGLA SIMPLE:

RUN         → Shell form    (necesitas features de shell)
ENTRYPOINT  → SIEMPRE Exec  (o CMD no funciona)
CMD         → Exec form     (excepto si necesitas features de shell sin ENTRYPOINT)
AMBOS       → Exec form     (NUNCA mezclar formas)
```

---

# 10. Ejemplos prácticos de interacción

### Shell form en ENTRYPOINT rompe CMD

```dockerfile
FROM ubuntu
ENTRYPOINT /hello.sh       # Shell form
CMD my friend              # Shell form
```

Docker ejecuta: `/bin/sh -c /hello.sh /bin/sh -c 'my friend'`

El shell ignora todo después de `/hello.sh` → `CMD` nunca se ejecuta.

### Exec form funciona correctamente

```dockerfile
FROM ubuntu
ENTRYPOINT ["/hello.sh"]   # Exec form
CMD ["my", "friend"]       # Exec form
```

Docker ejecuta: `/hello.sh my friend` → El script recibe los argumentos.

### Sin shebang line

Si el script no tiene `#!/bin/bash` al inicio y usas exec form, Docker no sabe con qué intérprete ejecutarlo:

```shell
exec /hello.sh: exec format error
```

**Solución:** Siempre incluir shebang en scripts que se usan como ENTRYPOINT:

```bash
#!/bin/bash
set -e
# tu código aquí
exec "$@"
```

---

# Parte III — PID 1 y Señales

---

# 11. ¿Qué es PID 1?

**PID 1** (Process ID 1) es el primer proceso que se ejecuta en un contenedor. Todo otro proceso es hijo de PID 1.

```
DENTRO DEL CONTENEDOR:

PID 1 = El proceso que Docker inicia (CMD o ENTRYPOINT)
        ↓
      Todos los demás procesos son hijos

CUANDO PID 1 TERMINA → EL CONTENEDOR SE DETIENE
```

PID 1 tiene una responsabilidad especial:
- Recibe señales del sistema (SIGTERM, SIGINT, SIGKILL)
- Es el responsable de iniciar el shutdown graceful
- Docker envía señales a PID 1 cuando ejecutas `docker stop`

---

# 12. Señales de proceso

| Señal     | Descripción                            | Cómo se genera                    | ¿Interceptable? |
|----------|----------------------------------------|-----------------------------------|-----------------|
| `SIGINT`  | Interrumpir proceso                    | `Ctrl+C` en terminal              | ✅ Sí            |
| `SIGTERM` | Solicitar terminación amable           | `docker stop`, `kill`, `killall`   | ✅ Sí            |
| `SIGKILL` | Forzar terminación inmediata           | `docker kill`, tras timeout        | ❌ No            |

### Flujo de docker stop

```
docker stop <container>
    │
    ↓
1. Envía SIGTERM a PID 1
    │
    ↓
2. Espera graceful shutdown (default: 10s)
    │
    ↓
3. Si no responde → envía SIGKILL (forzado)
```

> **Si el shutdown tarda exactamente 10s (o 30s en Kubernetes), es probable que tu proceso no esté recibiendo SIGTERM.**

---

# 13. El problema del shell form con señales

```dockerfile
# Shell form:
CMD top -b
```

Docker ejecuta: `/bin/sh -c top -b`

```
PID 1 = /bin/sh          ← Recibe SIGTERM
  └─ PID 2 = top -b      ← NO recibe SIGTERM

docker stop → envía SIGTERM a PID 1 (shell)
           → el shell NO reenvía la señal a top
           → timeout → SIGKILL forzado
           → shutdown sucio (10s de retraso)
```

```dockerfile
# Exec form:
CMD ["top", "-b"]
```

Docker ejecuta: `top -b` directamente

```
PID 1 = top -b            ← Recibe SIGTERM directamente

docker stop → envía SIGTERM a PID 1 (top)
           → top se detiene limpiamente
           → shutdown inmediato (~0.2s)
```

### Workaround con exec en shell form

Si por alguna razón necesitas shell form en ENTRYPOINT:

```dockerfile
FROM ubuntu
ENTRYPOINT exec top -b    # 'exec' reemplaza el shell por top como PID 1
```

---

# 14. exec "$@" en scripts de inicio

El patrón más importante para scripts de ENTRYPOINT:

```bash
#!/bin/bash
set -e

echo "Initializing..."
# Configuración previa...

# La línea clave:
exec "$@"
```

### Qué hace cada parte

| Parte   | Función                                                    |
|--------|------------------------------------------------------------|
| `exec`  | Reemplaza el proceso shell actual por el siguiente comando |
| `"$@"`  | Expande a todos los argumentos pasados al script (el CMD)  |

### Flujo completo

```
Dockerfile:
  ENTRYPOINT ["docker-entrypoint.sh"]
  CMD ["mysqld"]

Docker ejecuta: docker-entrypoint.sh mysqld

1. bash inicia el script como PID 1
2. El script configura el entorno
3. exec "$@" → exec mysqld
4. bash se reemplaza por mysqld
5. mysqld es ahora PID 1
6. mysqld recibe señales directamente
```

### Ejemplo real: script flexible

```bash
#!/bin/bash
set -e

# Si el CMD es el proceso esperado, configurar:
if [ "$1" = 'postgres' ]; then
    chown -R postgres:postgres /var/lib/postgresql
    exec gosu postgres "$@"   # Cambiar usuario Y pasar ejecución
fi

# Si el CMD es otro (ej: sh, bash), ejecutar directamente:
exec "$@"
```

```shell
docker run mypostgres                # → postgres inicia con configuración
docker run mypostgres sh             # → shell directo (skip configuración)
docker run mypostgres pg_dump mydb   # → ejecuta pg_dump como herramienta
```

---

# 15. Resumen de buenas prácticas

### Reglas de oro

| Regla                                              | Razón                                        |
|---------------------------------------------------|----------------------------------------------|
| Usar exec form en CMD y ENTRYPOINT                | PID 1 directo, señales funcionan              |
| Usar shell form en RUN                            | Necesitas features de shell                   |
| No mezclar shell y exec form entre CMD/ENTRYPOINT | Comportamiento impredecible                   |
| Usar `exec "$@"` al final de scripts ENTRYPOINT   | Pasar PID 1 al proceso principal              |
| Incluir shebang (`#!/bin/bash`) en scripts         | Necesario para exec form                      |
| Un solo proceso por contenedor                     | Docker monitorea PID 1 únicamente             |
| `CMD` para procesos long-running estándar          | Fácil de sobreescribir                        |
| `ENTRYPOINT + CMD` para CLI tools                  | Flexibilidad con argumentos                   |
| `ENTRYPOINT + CMD` para startup scripts            | Configuración previa + proceso principal      |

### Patrón estándar para servicios

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY . .
RUN npm ci --only=production
USER node
EXPOSE 3000
CMD ["node", "server.js"]
```

### Patrón estándar para CLI tools

```dockerfile
FROM alpine
RUN apk add --no-cache curl
ENTRYPOINT ["curl"]
CMD ["--help"]
```

### Patrón estándar para bases de datos

```dockerfile
FROM debian:stable-slim
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mysqld"]
```

### Referencia rápida de comandos

```shell
# Inspeccionar CMD y ENTRYPOINT de una imagen:
docker inspect <image> --format='CMD: {{.Config.Cmd}} | ENTRYPOINT: {{.Config.Entrypoint}}'

# Sobreescribir CMD:
docker run <image> <nuevo-comando>

# Sobreescribir ENTRYPOINT:
docker run --entrypoint <nuevo-ejecutable> <image>

# Ver procesos dentro de un contenedor:
docker top <container>
docker exec <container> ps aux
```

---

> *"In Docker, PID 1 is king. Everything — startup, shutdown, signal handling — revolves around getting PID 1 right."*
> — Docker Community
