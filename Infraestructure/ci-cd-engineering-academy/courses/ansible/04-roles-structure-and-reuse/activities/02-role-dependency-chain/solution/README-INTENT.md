# README-INTENT — Chain de 3 roles

## Decision

Elegimos **Opción A: dependencies declaradas en `meta/main.yml`**. `fastapi-app` depende de `webserver`, y `webserver` depende de `common`. `site.yml` sólo invoca `fastapi-app`; Ansible resuelve la cadena y aplica `common` → `webserver` → `fastapi-app` en ese orden.

Rechazamos la **composicion** explícita (opción B) para este escenario porque el acoplamiento es técnico y obligatorio: `fastapi-app` sin `webserver` no sirve tráfico HTTP, y `webserver` sin el usuario `appuser` creado por `common` no tiene a quién delegar. Un consumidor del role no debería tener que recordar la cadena.

## common

Baseline del host: crea el usuario de servicio `appuser` y fija la timezone. No depende de nada; es la raíz. Va primero porque los roles siguientes necesitan el usuario y el entorno base.

## webserver

Instala nginx y lo configura como reverse proxy hacia `127.0.0.1:{{ webserver_upstream_port }}`. Declara `dependencies: [common]` en `meta/main.yml` porque el servicio nginx se ejecuta bajo el usuario `appuser` creado por `common`.

## fastapi-app

Instala Python y despliega la unidad systemd de la app. Declara `dependencies: [webserver]` en `meta/main.yml` porque el reverse proxy debe estar listo para delegarle tráfico. La transitividad arrastra `common` sin tener que declararlo aquí.

## Trade-offs

- **Lo que ganamos con A (`dependencies` en `meta/main.yml`)**: `site.yml` es minimal; añadir un host nuevo basta con `roles: [fastapi-app]`; la cadena no se puede olvidar.
- **Lo que perdemos con A**: acoplamiento oculto. Alguien que lee `site.yml` no ve que se corren tres roles. Para un `site-dev.yml` sin nginx (dev local con uvicorn directo), con A tendríamos que romper la dependency; con **composicion** bastaría otro playbook listando `[common, fastapi-app]`.
- **Si el proyecto creciera** con 10 variantes de despliegue (dev, staging, prod, multi-tenant, etc.), probablemente migraríamos a **composicion** explícita y mantendríamos las dependencies vacías: la claridad del `site*.yml` compensa el verbosity.
