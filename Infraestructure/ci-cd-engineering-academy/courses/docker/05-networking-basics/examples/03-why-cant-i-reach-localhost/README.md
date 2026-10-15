# Ejemplo 03 — "¿Por qué no puedo llegar a `localhost`?"

## Concepto que demuestra

El pitfall número uno de networking con contenedores: `localhost` **dentro** del contenedor **no** es el host (ni el otro contenedor). Y una app que hace bind a `127.0.0.1` **nunca** será accesible desde `-p`.

## Contexto

Prácticamente todo estudiante choca con esto al menos una vez. Verlo con un experimento controlado ahorra horas futuras.

## Objetivo

- Reproducir el error "connection refused" al asumir que `localhost` cruza namespaces.
- Verificar que la solución correcta es (a) red compartida + nombre, o (b) `host.docker.internal`.
- Reproducir el bug de bind a `127.0.0.1` adentro y por qué `-p` no lo arregla.

## Prerrequisitos

- Docker. Puertos `18081` y `18082` del host libres.

## Archivo del ejemplo

`files/run-demo.sh`.

## Ejecución

```bash
bash courses/docker/05-networking-basics/examples/03-why-cant-i-reach-localhost/files/run-demo.sh
```

El script hace tres experimentos:

1. **Mal**: contenedor `db` publicado con `-p 18081:5432`; desde `client` corres `nc -z localhost 18081` → falla.
2. **Bien (red compartida)**: `db` y `client` en una user-defined bridge; `client` llega a `db` por nombre.
3. **Bind a `127.0.0.1`**: contenedor que escucha en `127.0.0.1:80` publicado con `-p 18082:80`; desde el host, `curl` falla aunque el `-p` parezca correcto.

## Resultado esperado

```
== Exp 1: localhost dentro del contenedor NO es el host ==
FAIL (esperado): nc no pudo conectar.

== Exp 2: user-defined bridge + nombre ==
OK: wget a db:5432 responde (TCP se abre; postgres habla su wire protocol).

== Exp 3: app bindeada a 127.0.0.1 adentro, -p no la salva ==
FAIL (esperado): curl desde el host no puede conectar.
Lección: la app debe escuchar en 0.0.0.0.
```

## Interpretación

- **Exp 1**: `localhost` dentro de `client` es la `lo` del net namespace de `client`. Postgres no corre ahí.
- **Exp 2**: con una red compartida, DNS por nombre apunta a la IP de `db` en esa red. El tráfico va host-less (sin NAT): bridge interno.
- **Exp 3**: `-p` hace DNAT a `172.x.y.z:80` del contenedor, pero el proceso dentro solo acepta en `127.0.0.1:80`. El paquete llega al namespace del contenedor pero no hay socket que lo acepte → RST.

## Errores frecuentes

- Buscar la causa en `iptables` del host. No está ahí: está en que `localhost` no cruza namespaces.
- Añadir más `-p` cuando el problema es el bind interno.

## Nota macOS/Windows

Idéntico. En Docker Desktop, además, `host.docker.internal` resuelve al host del Mac/Windows, lo cual es útil cuando necesitas acceder a servicios **del Mac** desde el contenedor.

## Limpieza

El script limpia solo.
