# Lección: Storage en Docker — volúmenes, bind mounts y tmpfs

> **ID:** `dkr-04-storage-volumes-bind-mounts-tmpfs` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** `dkr-02`.

---

## 1. Introducción intuitiva

Imagina que levantas una base de datos Postgres en un contenedor, insertas un cliente nuevo, haces `docker rm` y vuelves a lanzar el contenedor. La fila desapareció. ¿Dónde fue? A ninguna parte: nunca estuvo escrita en un lugar durable. Postgres escribió sus archivos en `/var/lib/postgresql/data` *dentro del contenedor*, que vive sobre un filesystem **copy-on-write** cuyo "piso superior" se destruye con el propio contenedor.

El problema que resuelve este módulo es simple de enunciar y fácil de hacer mal: **separar el ciclo de vida de los datos del ciclo de vida del contenedor**. Un contenedor es ganado, no mascota — debe poder morir y renacer sin perder nada que importe. Los datos viven *fuera*: en un volumen gestionado por Docker, en un directorio del host, o explícitamente en memoria si son temporales.

Docker ofrece tres primitivas para esto:

- **Volume** — gestionado por Docker, portable, el default correcto para datos de aplicación.
- **Bind mount** — un directorio del host "pegado" en una ruta del contenedor. Útil en desarrollo, peligroso en producción.
- **tmpfs** — un filesystem en RAM, nunca tocado por disco. Útil para secretos efímeros o scratch rápido.

Elegir mal (o no elegir) termina en pérdida de datos, bugs de permisos, o builds no reproducibles. Vamos por partes.

---

## 2. Fundamentos

### 2.1 Por qué el filesystem del contenedor es efímero

Una imagen OCI es un conjunto de **capas** apiladas, cada una un tarball comprimido de diferencias. Cuando `docker run` crea un contenedor, el runtime pone una capa adicional **escribible** encima de las capas de la imagen y las fusiona con un filesystem copy-on-write (en Linux moderno, `overlayfs`):

```
                 ┌───────────────────────────────┐
   container     │ container upperdir (writable) │   <- se descarta al rm
                 ├───────────────────────────────┤
   image         │ layer N (ro)                  │
                 │ ...                           │
                 │ layer 0 (ro)                  │
                 └───────────────────────────────┘
                            = merged view
```

Cualquier `write` *dentro* del contenedor va al **upperdir**, que es un directorio efímero en `/var/lib/docker/overlay2/<id>/diff/`. Al hacer `docker rm`, ese upperdir se borra. Datos escritos en `/var/lib/postgresql/data`, `/app/uploads`, `/tmp` *dentro del contenedor* desaparecen con él.

Hay una segunda razón, independiente del borrado: **cada contenedor nuevo arranca con su propio upperdir vacío**, derivado solo de las capas de la imagen. Dos contenedores de la misma imagen no comparten estado por default.

### 2.2 Las tres primitivas de mount

El runtime permite, en el momento de crear el contenedor, decirle: "en vez de usar el upperdir para esta ruta, monta aquí otra cosa". Hay tres "otras cosas":

| Primitiva | Dónde vive la data | Gestionada por | Caso típico |
|-----------|--------------------|----------------|-------------|
| **volume** | `/var/lib/docker/volumes/<name>/_data/` (en el host, pero propiedad de Docker) | Docker | Datos de aplicación persistentes (DB, uploads). |
| **bind mount** | cualquier ruta del host, elegida por ti | el host (Docker solo "la pega") | Hot-reload de código en dev; config inyectada. |
| **tmpfs** | RAM (no toca disco) | el kernel | Secretos efímeros, scratch de alta velocidad. |

Las tres se ven, desde dentro del contenedor, como un directorio cualquiera. La diferencia es *qué hay realmente detrás* y *quién manda sobre su ciclo de vida*.

### 2.3 Dos sintaxis: `-v` y `--mount`

Docker expone dos formas de declarar mounts:

- **`-v` (short)** — compacta: `-v <src>:<dst>[:opts]`. `<src>` interpretado como volumen si es un nombre, como ruta si empieza con `/` o `.`. Puede *crear volúmenes implícitamente* si el nombre no existe (fuente clásica de "volúmenes huérfanos").
- **`--mount` (long)** — explícita: `--mount type=volume,source=<name>,target=<path>,readonly`. Más verbosa, menos ambigua, **no crea volúmenes implícitos** y falla ruidosamente si algo no cuadra.

Preferir `--mount` en scripts y producción; `-v` está bien en la línea de comandos interactiva.

---

## 3. Volúmenes nombrados

Un **volumen nombrado** es un directorio gestionado por Docker:

```bash
docker volume create app_data
docker volume ls
docker volume inspect app_data
```

`inspect` muestra algo así:

```json
[
  {
    "Name": "app_data",
    "Driver": "local",
    "Mountpoint": "/var/lib/docker/volumes/app_data/_data",
    "Scope": "local"
  }
]
```

Ese `Mountpoint` es la ruta real en el host (en Linux). Dentro del contenedor es irrelevante: montas donde quieras:

```bash
docker run -d --name db \
  --mount type=volume,source=app_data,target=/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret postgres:16
```

Ventajas:

- **Portable**: el mismo nombre funciona en cualquier host; no hace falta coordinar rutas absolutas.
- **Pre-poblado**: si la imagen trae datos en el destino (`VOLUME` instruction), al crear un volumen *vacío* Docker **copia** esos datos al volumen la primera vez (solo si está vacío).
- **Permisos "normales"**: el daemon suele ajustar ownership al UID que la imagen declara.
- **Gestionable**: `docker volume ls / prune / rm` como primera clase.

Un volumen **sobrevive** al `docker rm` del contenedor que lo usó. Se destruye solo si:

- Lo borras explícitamente: `docker volume rm app_data`.
- Lo borras pasando `-v` a `docker rm`: `docker rm -v db` (pero solo elimina volúmenes *anónimos* del contenedor, no los nombrados).
- Lo arrasa `docker volume prune` (dangerous — borra todos los que no estén en uso).

### 3.1 Drivers de volumen

El `Driver: local` es el default. Hay otros: `nfs`, `cifs`, plugins propietarios (AWS EBS, GCE PD, vendor-specific). En Kubernetes el equivalente moderno son los **CSI drivers**. Para Docker standalone, `local` cubre el 95% de los casos y los otros son dominio de orquestadores.

### 3.2 Volúmenes anónimos

Si corres `docker run -v /data image`, Docker crea un volumen **anónimo** con un nombre tipo `3f2a9b...`. Son horribles para operar porque nadie los reclama. Usar siempre nombres explícitos.

---

## 4. Bind mounts

Un **bind mount** monta directamente una ruta del host en el contenedor:

```bash
docker run --rm -it \
  --mount type=bind,source="$(pwd)",target=/app \
  python:3.12-slim bash -c "ls /app"
```

A diferencia del volumen, aquí **tú** decides dónde está la fuente. Pros y contras simétricos:

**Pros**:

- Editas en el host, el contenedor ve el cambio *inmediatamente*. Ideal para hot-reload en dev.
- Sin indirección: `cat /path/en/host` y `docker exec cat /app/mismo-archivo` ven lo mismo.
- Útil para inyectar config (`-v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro`).

**Contras**:

- **No portable**: la ruta solo existe en tu máquina.
- **Permisos crudos**: el contenedor ve UIDs/GIDs tal cual; si el UID del proceso dentro no puede leer esos archivos en el host, no puede leerlos aquí tampoco.
- **Peligroso**: `-v /:/host` da acceso total al host.
- En Docker Desktop (macOS/Windows) hay una **VM intermedia**: los bind mounts cruzan un filesystem compartido (gRPC-FUSE / virtiofs) y son **sensiblemente más lentos** que los volúmenes nativos. Esto importa para apps con muchos archivos pequeños (p. ej. `node_modules`).

### 4.1 Modificadores útiles

- **`:ro`** — read-only. El contenedor puede leer pero no escribir. Default para config inyectada.
- **`:z` / `:Z`** — relabel SELinux (solo en hosts con SELinux: RHEL, Fedora, CentOS). `:z` comparte el label entre contenedores; `:Z` lo hace privado. Sin esto, SELinux bloquea el acceso con un `Permission denied` que *no* se explica por los permisos POSIX.

### 4.2 Cuándo usar bind mount vs volumen

Regla práctica:

- **Datos de app persistentes** (DB, estado) → **volumen** nombrado.
- **Código fuente para hot-reload en dev** → **bind** del repo.
- **Config files inyectados** → **bind read-only** del archivo o directorio.
- **Secretos de dev** → **tmpfs** o bind read-only de un `.env` ignorado por git. Nunca en la imagen.

---

## 5. tmpfs

Un `tmpfs` monta un filesystem **en memoria**. Nada se escribe a disco. Se descarta con el contenedor.

```bash
docker run --rm \
  --mount type=tmpfs,destination=/scratch,tmpfs-size=64m \
  alpine sh -c "echo foo > /scratch/a; mount | grep scratch"
```

Casos de uso:

- Scratch rápido donde no quieres tocar el filesystem del contenedor (ni su upperdir).
- Secretos de corta vida que no deben persistir ni siquiera en overlayfs.
- Reducir desgaste en SSDs embebidos en CI de alto volumen.

Limitaciones:

- Solo Linux (en Docker Desktop corre dentro de la VM, no en tu macOS directamente).
- Consume RAM contada contra el límite del contenedor.
- No puede compartirse entre contenedores.

---

## 6. Permisos: UID/GID dentro vs fuera

Esta es la fuente #1 de bugs operativos con bind mounts. El principio es simple: **el UID numérico dentro del contenedor es el mismo UID numérico en el host**. No hay traducción (salvo con user namespaces, no habilitado por default). Si el proceso dentro del contenedor corre como UID 1000 e intenta escribir en un bind mount cuyo directorio en el host es propiedad de UID 0 con `rwx r-x ---`, obtiene `Permission denied` — porque el kernel aplica permisos POSIX al UID real, y 1000 ≠ 0.

El nombre `root` dentro del contenedor también es el mismo `root` del host (UID 0). Un `docker run --user 0` con bind mount a `/etc/passwd` del host puede **escribirlo** si tienes permiso de daemon.

### 6.1 Estrategias

Cuando hay desalineación entre el UID que la imagen usa y el ownership del bind mount:

1. **Alinear host → contenedor**: `chown <uid-del-container>:<gid> <ruta-host>`.
2. **Alinear contenedor → host**: `docker run --user "$(id -u):$(id -g)"` para que el contenedor adopte tu UID. Funciona si la app no necesita UIDs específicos.
3. **Rebuild de la imagen** con `USER` y `ARG UID`/`ARG GID` configurables.
4. **Volumen nombrado** en lugar de bind: Docker suele ajustar el ownership del volumen al UID que la imagen declara.

El anti-patrón es `chmod 777`: hace que "funcione" pero rompe la auditoría de permisos y es un smell que persiste.

### 6.2 User namespaces (mención)

Docker soporta `userns-remap` donde el UID 0 del contenedor se mapea a un UID alto del host (ej. 100000). Mejora el aislamiento pero rompe bind mounts porque los archivos del host no están owned por 100000. No está activado por default. Se cubre a fondo en `dkr-10`.

---

## 7. SELinux: `:z` y `:Z`

En distros con SELinux (RHEL, Fedora, CentOS, Rocky, Oracle Linux), el kernel aplica **etiquetas** además de permisos POSIX. Un bind mount sin la etiqueta correcta falla con `Permission denied` aunque los UIDs sean correctos — y `ls -l` muestra permisos "válidos", lo que confunde.

- **`:z`** (minúscula) — relabel compartido: el archivo recibe una etiqueta que varios contenedores pueden usar. Para datos que varios contenedores leen.
- **`:Z`** (mayúscula) — relabel privado: solo el contenedor que hizo el mount puede usarlo. Más seguro, pero no para compartir.

Ejemplo:

```bash
docker run --rm -v "$(pwd)":/app:Z fedora ls /app
```

Si no estás en SELinux (Ubuntu, Debian, macOS, Windows), estos flags son no-ops y pueden omitirse.

---

## 8. Backup y restore de volúmenes

Un volumen no se "copia" como un directorio normal: su `Mountpoint` requiere root y acopla al host. El patrón idiomático es montar el volumen en un contenedor efímero y hacer `tar`:

### 8.1 Backup

```bash
# tar del volumen 'app_data' a un archivo en el host
docker run --rm \
  -v app_data:/data:ro \
  -v "$(pwd)":/backup \
  busybox tar czf /backup/app_data.tar.gz -C /data .
```

### 8.2 Restore

```bash
docker volume create app_data_restored
docker run --rm \
  -v app_data_restored:/data \
  -v "$(pwd)":/backup \
  busybox sh -c "cd /data && tar xzf /backup/app_data.tar.gz"
```

Patrones a notar:

- Dos mounts: uno al volumen Docker, otro bind al host para dejar el `.tar.gz`.
- `:ro` en el backup para no corromper el volumen con una escritura accidental.
- Contenedor efímero (`--rm`) + `busybox` por minimalismo.
- Reemplaza `busybox` por `postgres:16` y usa `pg_dump` cuando la DB está corriendo (backup lógico, más seguro para DBs).

---

## 9. Anti-patrones

### 9.1 Persistir datos de aplicación en el filesystem de la imagen

```dockerfile
# MAL
RUN mkdir /data && touch /data/db.sqlite
CMD ["python", "app.py"]  # app escribe en /data/db.sqlite
```

`/data` vive en una capa de la imagen y en el upperdir del contenedor. Al borrar el contenedor, los datos se van. Al actualizar la imagen, el `/data` nuevo *reemplaza* al viejo. La solución: montar `/data` como volumen o bind.

### 9.2 Bind mount a rutas sensibles del host

`-v /:/host`, `-v /etc:/host-etc`, `-v /var/run/docker.sock:/var/run/docker.sock`. El último es equivalente a dar root al host — se cubre en `dkr-13`.

### 9.3 `chmod 777` como fix

Oculta el problema de UIDs y queda para siempre. Preferir alinear UIDs explícitamente.

### 9.4 Volúmenes anónimos sin control

`-v /data image` genera un volumen con hash como nombre. Nadie los encuentra, acumulan GB. Siempre nombrar o usar bind.

### 9.5 Confiar en el orden de `-v`

Si dos mounts se solapan, el último "gana" dentro de ese subpath. Nunca montes algo encima de otro mount a propósito; es un bug esperando a pasar.

---

## 10. Comandos clave

```bash
# Ciclo de vida
docker volume create <name>
docker volume ls
docker volume inspect <name>
docker volume rm <name>
docker volume prune               # borra TODO lo no usado -- peligroso

# Montar
docker run -v <name>:/path image                                 # volume
docker run -v "$(pwd)":/path image                               # bind (ruta absoluta)
docker run --mount type=volume,source=<name>,target=/path image  # explícito
docker run --mount type=bind,source="$(pwd)",target=/path,readonly image
docker run --mount type=tmpfs,destination=/path,tmpfs-size=32m image

# Ver mounts de un contenedor existente
docker inspect <container> --format '{{json .Mounts}}' | jq
```

Trabajar siempre con `--mount` cuando el comando se automatiza; `-v` cuando se tipea a mano.

---

## 11. Mapa mental final

```
                        ¿Dónde escribo?
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
     persistente          temporal              compartido
     entre runs           pero rápido           con el host
          │                    │                    │
          ▼                    ▼                    ▼
       VOLUME               TMPFS               BIND MOUNT
     (default               (RAM,            (ruta exacta
      correcto)             sin disco)        del host)
          │                                        │
   portable, gestionado                   no portable, acoplado
   por Docker, sobrevive al rm             al filesystem del host
```

Regla operativa en una línea: **data en volumen, código en bind (solo dev), secretos efímeros en tmpfs, nunca datos en la imagen**.

---

## 12. Preguntas de evaluación

Responde sin consultar docs. Si no puedes, vuelve a la sección correspondiente.

1. ¿Por qué una fila insertada en Postgres se pierde al hacer `docker rm` si no usas volumen?
2. Diferencia operativa concreta entre `-v` y `--mount`. ¿Cuál usarías en un script?
3. Dado un bind mount cuyo directorio en el host es `root:root 755` y un contenedor que corre como UID 1000, ¿qué pasa al intentar escribir? Da tres fixes posibles.
4. ¿Para qué sirven `:z` y `:Z`? ¿En qué distros aplican?
5. Escribe el comando para hacer backup del volumen `pg_data` a `/tmp/pg_data.tar.gz` sin montarlo en un contenedor con tu DB corriendo.
6. ¿Qué pasa si usas la instrucción `VOLUME /data` en el Dockerfile y luego `docker run` sin especificar un volumen explícito?
7. ¿Por qué `chmod 777` resuelve síntomas pero no causas en un bug de permisos de bind mount?
8. Dado un contenedor con `--mount type=tmpfs,destination=/scratch,tmpfs-size=64m`, ¿los datos sobreviven a `docker restart`? ¿Por qué?

---

## Siguiente

→ `dkr-05-networking-basics`: cómo se hablan los contenedores entre sí y con el host.
