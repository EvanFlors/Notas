# Lección: Networking básico en Docker

> **ID:** `dkr-05-networking-basics` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** `dkr-02` + T-3 Networking básico (IP, TCP/UDP, NAT, DNS).

---

## 1. Introducción intuitiva

Levantaste un contenedor:

```bash
docker run -d --name web nginx
```

`docker ps` dice que está corriendo. Abres `http://localhost` en el navegador. **Nada.** ¿Por qué?

Porque el contenedor vive en **su propio net namespace**: tiene su propia `lo`, sus propias interfaces, sus propias tablas de rutas. Es, para efectos prácticos, otra máquina en otra red. El puerto `80` del contenedor no es el puerto `80` del host; son dos puertos distintos en dos pilas TCP/IP distintas.

Para que puedas llegarle hace falta algo que **traduzca** una conexión al host en una conexión al contenedor. Y para que dos contenedores se hablen por nombre, hace falta una **red común** y un **resolver DNS** que entienda nombres de contenedor.

Esta lección explica, de abajo hacia arriba, qué es "la red de Docker":

- Qué es un **net namespace** y qué significa que cada contenedor tenga uno.
- Qué es `docker0` y por qué es un **bridge Linux** convencional.
- Cómo `docker run -p 8080:80 nginx` termina siendo una regla **DNAT** en `iptables`.
- Por qué una **user-defined bridge** te da DNS por nombre y la default no.
- Qué pasa cuando usas `--network host` (y por qué casi nunca es la respuesta).
- Qué cambia en macOS/Windows (Docker Desktop corre una VM Linux intermedia).

Si tienes claros estos puntos, el 90% de los problemas de red con contenedores se resuelven en minutos.

---

## 2. Fundamentos

Hay cinco primitivas detrás de todo lo que verás.

### 2.1 Net namespace

Un **net namespace** (`CLONE_NEWNET`) es un aislamiento del kernel Linux: cada net namespace tiene su propio conjunto de interfaces, tablas de rutas, `iptables`, puertos ocupados, sockets, cache ARP, etc. Dos procesos en net namespaces distintos **no comparten nada** de red.

Cada contenedor arranca en un net namespace nuevo. Dentro ve una `lo` (loopback) y, si está conectado a alguna red Docker, una `eth0` virtual.

### 2.2 Bridge Linux

Un **bridge** es un switch de capa 2 implementado por el kernel. Agrupas varias interfaces en un bridge y los paquetes se reenvían entre ellas como en un switch físico. `docker0` es un bridge Linux creado por `dockerd` al arrancar.

### 2.3 veth pair

Una **veth pair** es "un cable virtual": dos interfaces conectadas espalda contra espalda. Lo que entra por un extremo sale por el otro. Docker crea una veth pair por contenedor:
- Un extremo (`vethXXXX`) queda en el host, conectado al bridge `docker0`.
- El otro extremo (`eth0`) queda **dentro del net namespace** del contenedor.

Resultado: el contenedor "está conectado a `docker0`" como si fuera un cable físico al switch.

### 2.4 iptables / nftables

Docker inserta reglas en `iptables` (en kernels modernos realmente usa el backend nf_tables, pero la CLI sigue siendo `iptables`). Dos cadenas clave:

- **`DOCKER`** en `nat` — reglas DNAT: *"paquete que llega al host en puerto 8080 → reescribe destino a 172.17.0.2:80"*.
- **`DOCKER-USER`** en `filter` — gancho reservado al operador para añadir reglas sin que Docker las sobrescriba.

También aparece una regla `MASQUERADE` (SNAT) para el tráfico de salida: el contenedor usa su IP privada, pero al salir al mundo se enmascara con la IP del host.

### 2.5 Embedded DNS resolver

Cuando creas una **user-defined bridge** (`docker network create mired`), Docker ejecuta un pequeño resolver DNS **dentro de cada contenedor** de esa red, escuchando en `127.0.0.11:53`. Ese resolver conoce los nombres de los contenedores conectados a esa red. En la red **default** `bridge` ese resolver **no** está habilitado para resolver por nombre (comportamiento legacy).

---

## 3. Arquitectura: cómo encajan las piezas

Vista alta de un host Linux con dos contenedores en la bridge default:

```
┌──────────────────────────── HOST (net ns raíz) ─────────────────────────────┐
│                                                                             │
│   eth0 (IP pública/LAN)                                                     │
│     │                                                                       │
│     │  iptables: NAT (MASQUERADE out, DNAT in para -p)                      │
│     │                                                                       │
│   ┌──────────── docker0 (bridge Linux, 172.17.0.1/16) ────────────┐         │
│   │                                                               │         │
│   │  veth-A                     veth-B                            │         │
│   └────┬─────────────────────────┬────────────────────────────────┘         │
│        │                         │                                          │
│   ┌────┴────── net ns A ────┐   ┌┴──────── net ns B ────┐                   │
│   │  eth0  172.17.0.2       │   │ eth0  172.17.0.3      │                   │
│   │  lo    127.0.0.1        │   │ lo    127.0.0.1       │                   │
│   │  (procesos del contain) │   │ (procesos del contain)│                   │
│   └─────────────────────────┘   └───────────────────────┘                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

Dos observaciones clave de este diagrama:

1. Cada contenedor tiene **su propia** `lo`. "`localhost` dentro del contenedor" **es** el contenedor; no es el host, ni el otro contenedor.
2. El contenedor A puede hablarle a B por IP (`172.17.0.3`) porque están conectados al mismo bridge. En la bridge **default** esto funciona por IP pero **no** por nombre.

---

## 4. Drivers de red

Docker expone varios drivers. Los que importan en Nivel 1:

| Driver     | Qué hace                                                                                           | Cuándo usar                                                                         |
|------------|----------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|
| `bridge`   | Red privada en un bridge Linux. Default. **User-defined** habilita DNS por nombre.                 | Casi todo el desarrollo local y multi-contenedor en un host.                        |
| `host`     | Elimina el net namespace: el contenedor **comparte** la pila de red del host.                      | Herramientas de red, benchmarking, servidores que necesitan puertos < 1024 fácil.   |
| `none`     | Contenedor sin ninguna interfaz (solo `lo`).                                                       | Sandbox hermético, jobs batch que no deben tocar la red.                            |
| `macvlan`  | Al contenedor se le asigna una MAC propia y aparece como "otro host más" en la LAN física.         | Integrar contenedores con equipos legacy que esperan hosts tradicionales.           |
| `overlay`  | Red L2 virtual multi-host (Swarm, raramente a mano).                                               | Clúster Swarm. Fuera del scope de este módulo.                                      |

Listarlos:

```bash
docker network ls
```

Verás por default `bridge`, `host`, `none`.

---

## 5. La bridge default vs una user-defined bridge

Son **dos cosas distintas** aunque ambas usan el driver `bridge`:

| Aspecto                       | Default `bridge`                            | User-defined bridge (`docker network create X`) |
|-------------------------------|---------------------------------------------|--------------------------------------------------|
| DNS por nombre de contenedor  | **NO** (solo IP, o `--link` legacy)         | **SÍ** (resolver embebido en `127.0.0.11:53`)    |
| Alias (`--network-alias`)     | NO                                          | SÍ                                               |
| Aislamiento                   | Compartida por todo lo que no diga red      | Aislada: solo contenedores conectados se ven     |
| Recomendación                 | Legacy; evitar                              | **Siempre preferir**                             |

Regla práctica: **nunca** uses la bridge default para apps multi-contenedor. Una línea extra te da DNS y aislamiento:

```bash
docker network create miapp
docker run -d --name db  --network miapp postgres:16
docker run -d --name app --network miapp miapp:latest
# dentro de 'app', 'db' resuelve a la IP de 'db' en 'miapp'.
```

---

## 6. Publicación de puertos: `-p` por dentro

```bash
docker run -d -p 8080:80 --name web nginx
```

Lo que pasa debajo:

1. Docker crea el contenedor y le asigna IP en `docker0` (p. ej. `172.17.0.2`).
2. Docker inserta en `iptables` (tabla `nat`, cadena `DOCKER`) una regla **DNAT**:
   > "paquete con destino `HOST:8080` → reescribe destino a `172.17.0.2:80`".
3. Docker inserta una regla `MASQUERADE` para que las respuestas vuelvan correctamente.
4. `dockerd` ocupa `8080` en el host (el **port binding**). Dos contenedores no pueden publicar el mismo puerto del host simultáneamente.

Variantes:

```bash
-p 8080:80                 # bind a 0.0.0.0:8080 (TODAS las interfaces del host).
-p 127.0.0.1:8080:80       # bind SOLO a loopback del host (no accesible desde fuera).
-p 8080:80/udp             # UDP en vez de TCP.
-p 8080                    # mismo puerto en host (poco usado; da puerto aleatorio en algunos modos).
-P                         # publica cada EXPOSE a un puerto aleatorio del host.
```

Ver qué está publicado:

```bash
docker port web
# 80/tcp -> 0.0.0.0:8080
```

Puerto ocupado:

```bash
docker run -d -p 8080:80 nginx
docker run -d -p 8080:80 nginx
# Error: bind for 0.0.0.0:8080 failed: port is already allocated
```

**No es** que Linux no pueda; es que ya hay un socket en `8080` en el host. Soluciones: liberar el puerto (`docker ps`, `lsof -i :8080`) o publicar en otro puerto.

---

## 7. `-p` vs `--network host`

Son dos modelos opuestos.

### `-p host:container` (publishing / port forwarding)

- El contenedor **mantiene** su net namespace propio.
- Hay NAT: el host traduce `HOST:X → CONTAINER:Y`.
- Puedes elegir en qué interfaz/puerto del host se expone.
- Dos contenedores pueden tener el mismo puerto interno sin colisionar; cada uno publica en un puerto distinto del host.

### `--network host` (host network)

- El contenedor **comparte** el net namespace del host: su `eth0` es el `eth0` del host.
- No hay NAT, no hay puerto a publicar. Si `nginx` escucha en `80`, es el `80` del host directamente.
- No puedes correr dos contenedores en `--network host` que escuchen en el mismo puerto.
- `--publish` se **ignora** con `--network host`.

Cuándo usar `host`:

- Herramientas de red (`iperf3`, `nmap` desde el host, agents de monitoring).
- Casos de performance donde el salto de NAT importa (muy raro en app típica).
- Servicios que necesitan puertos privilegiados sin pelear con `net.ipv4.ip_unprivileged_port_start`.

Cuándo **no**:

- Casi todo lo demás. Pierdes aislamiento y portabilidad.

**macOS / Windows (Docker Desktop)**: `--network host` **no te expone al Mac/Windows**: te expone a la VM Linux interna. Por eso en Docker Desktop se recomienda `-p` incluso para scripts rápidos. Soporte experimental de `host.docker.internal` y de `--network host` en Docker Desktop ha ido cambiando; verifica contra tu versión.

---

## 8. DNS entre contenedores

### En la bridge default

No hay resolución por nombre. Opciones (todas malas):
- Hardcodear IPs (frágil: cambian al recrear).
- `--link` (legacy, deprecated).

### En una user-defined bridge

Cada contenedor conectado recibe `127.0.0.11` como DNS en `/etc/resolv.conf`. Ese resolver conoce:
- Los **nombres** de contenedores conectados a la red (`--name`).
- Los **alias** declarados con `--network-alias`.
- Y hace **forward** al DNS upstream (del host) para todo lo demás.

```bash
docker network create miapp
docker run -d --name db  --network miapp postgres:16
docker run -it --rm --network miapp alpine sh
# dentro:
#   nslookup db       -> 172.x.y.z
#   ping -c 1 db      -> OK
#   cat /etc/resolv.conf  -> nameserver 127.0.0.11
```

Múltiples redes: un contenedor puede estar en varias networks (`docker network connect`). Solo se resuelven los nombres **dentro de cada red** respectivamente.

---

## 9. El pitfall número uno: `localhost` dentro del contenedor

Caso típico:

```bash
docker run -d -p 5432:5432 --name db postgres:16
docker run -it --rm alpine sh
# dentro:
apk add postgresql-client
psql -h localhost -U postgres   # <-- FALLA: connection refused
```

¿Por qué? Porque `localhost` **dentro** del contenedor `alpine` es la `lo` de **ese** net namespace. Postgres no corre ahí; corre en el net namespace del contenedor `db`. "Localhost" nunca cruza namespaces.

Opciones correctas:

1. **Red compartida + nombre** (lo canónico):
   ```bash
   docker network create miapp
   docker run -d --name db --network miapp postgres:16
   docker run -it --rm --network miapp alpine sh
   # dentro: psql -h db -U postgres
   ```

2. **IP del host** (si el servicio está publicado):
   - En **Docker Desktop (macOS/Windows)** y en Docker 20.10+ en Linux: `host.docker.internal` apunta al host.
   - En Linux puro, requiere `--add-host=host.docker.internal:host-gateway`.

3. **`--network host`** (solo Linux, acepta la pérdida de aislamiento): `localhost` sí es el host.

Variante dolorosa: tu app en el contenedor hace bind a `127.0.0.1:PUERTO`. **Nunca llegará nadie**, porque ese `127.0.0.1` es la `lo` del contenedor. Para que `-p` funcione, la app tiene que escuchar en `0.0.0.0:PUERTO` (o en la IP de `eth0` del contenedor).

---

## 10. Operación: comandos que vas a usar todos los días

Listar redes:

```bash
docker network ls
```

Crear / eliminar:

```bash
docker network create miapp
docker network rm miapp
docker network prune        # elimina redes no usadas
```

Inspeccionar una red (ver subnet, gateway, containers conectados):

```bash
docker network inspect miapp
```

Ver la red/IP/puertos de un contenedor:

```bash
docker inspect -f '{{json .NetworkSettings}}' web | jq
docker port web
```

Conectar / desconectar un contenedor en caliente:

```bash
docker network connect miapp web
docker network disconnect miapp web
```

Entrar al namespace para debug (sin tener `ip`/`ss` dentro):

```bash
docker run --rm --network container:web nicolaka/netshoot ss -ltn
# container:web -> comparte el net ns de 'web'
```

Trucos útiles:

- `nicolaka/netshoot` es la caja de herramientas de red (`ip`, `ss`, `tcpdump`, `dig`, `curl`, `iptables`).
- `docker exec web wget -qO- http://db:5432` para comprobar DNS/conectividad desde el contenedor que te importa.
- `curl -v http://localhost:8080` **desde el host** para verificar publicación.

---

## 11. Casos de uso y antipatterns

### Buenos patrones

- **Una user-defined bridge por app**. Aisla y da DNS gratis.
- **Publicar solo lo necesario**. Base de datos: no publicar al host en dev (otros contenedores le hablan por red interna). Si publicas, usa `-p 127.0.0.1:5432:5432` para no exponer a la LAN.
- **Nombres estables**. `--name db`, `--name app`. Si recreas el contenedor con el mismo nombre, los otros siguen resolviéndolo.
- **Health checks + reintentos** para absorber la ventana en que la DB aún no está lista (se profundiza en `dkr-08`).

### Antipatterns comunes

- **Usar la bridge default** para apps multi-contenedor. No tienes DNS; terminas hardcodeando IPs.
- **`-p 0.0.0.0:5432:5432`** para la DB en una laptop con WiFi pública. Acabas de exponer Postgres a la red del café.
- **`--network host`** "porque no me funciona el DNS". El DNS funciona si usas user-defined bridge; `host` renuncia a aislamiento sin arreglar la causa.
- **Hacer bind a `127.0.0.1`** dentro del contenedor y pretender que `-p` lo publique. Nunca lo hará.
- **Montar `/var/run/docker.sock`** "para que el contenedor levante otros contenedores en la misma red". Es equivalente a dar root al host (se cubre en `dkr-13`).

---

## 12. Verificación de comprensión

Responde sin consultar la lección:

1. ¿Por qué `curl http://localhost:80` **dentro** de un contenedor que corre `nginx` en otro contenedor **no** funciona?
2. ¿Qué diferencia hay entre la red default `bridge` y una red creada con `docker network create`?
3. ¿Qué hace exactamente `-p 8080:80` por debajo? Enumera los pasos.
4. ¿En qué situación `--network host` es la elección correcta? ¿Qué pierdes al usarlo?
5. Tu app Python dentro de un contenedor hace `app.run(host="127.0.0.1", port=8000)`. Publicas con `-p 8000:8000`. No puedes conectarte desde el host. ¿Por qué y cómo lo arreglas?
6. Dos contenedores en la **misma** user-defined bridge: uno se llama `db`, otro `cache`. Desde `cache`, ¿`ping db` funciona? ¿Y desde el host?
7. Levantas dos contenedores con `-p 8080:80` cada uno. ¿Qué pasa?
8. Si borras `docker0` con `ip link del docker0`, ¿qué pasa con tus contenedores actuales y los próximos?
9. En Docker Desktop (macOS), ¿qué significa realmente `--network host`?
10. ¿Qué contiene `/etc/resolv.conf` dentro de un contenedor conectado a una user-defined bridge? ¿Por qué?

---

**Siguiente:** `dkr-06-dockerfile-idiomatic-and-caching`.
