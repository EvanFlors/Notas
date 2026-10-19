# Actividad 02 — Chain de 3 roles: `common` → `webserver` → `fastapi-app`

## 1. Identificación

- **ID:** `ans-04-02-role-dependency-chain`
- **Tecnología:** `ansible`
- **Módulo:** `ans-04-roles-structure-and-reuse`
- **Dificultad:** intermediate
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

El equipo quiere empaquetar el despliegue de una app FastAPI simple como una cadena de 3 roles:

1. **`common`** — baseline del host: timezone, usuario de servicio `appuser`, directorios base.
2. **`webserver`** — nginx como reverse proxy, con config que ya apunta a la app.
3. **`fastapi-app`** — paquete Python + unidad systemd + health endpoint; servido via nginx del role anterior.

Tienes dos formas de encadenarlos:

- **A — dependencies**: declarar en `meta/main.yml` de `fastapi-app` que depende de `webserver` que depende de `common`. Ansible resuelve y aplica el orden.
- **B — composición explícita**: declarar los 3 roles en `site.yml`, en el orden deseado, sin dependencies en meta.

Ambas son defendibles. Elige **una**, impleméntala, y **justifícala por escrito** en `README-INTENT.md`.

Trabajas en `/tmp/ans-04-chain/`.

## 3. Objetivos

Al terminar deberías poder:

- Diseñar 3 roles por responsabilidad clara, sin solapes.
- Decidir si usas `meta/main.yml:dependencies` o composición explícita; justificarlo.
- Encadenarlos de forma que `ansible-playbook site.yml --syntax-check` pase.
- Documentar cada role (README) y la decisión global (`README-INTENT.md`).

## 4. Prerrequisitos

- Terminada la actividad `01` (sabes extraer un role).
- Herramientas: `bash`, `python3`. `ansible-core` opcional.

## 5. Instrucciones

### 5.1 Preparar directorio

```bash
mkdir -p /tmp/ans-04-chain
cd /tmp/ans-04-chain
```

### 5.2 Estructura mínima esperada

```
/tmp/ans-04-chain/
├── site.yml
├── README-INTENT.md
└── roles/
    ├── common/
    │   ├── README.md
    │   ├── defaults/main.yml
    │   ├── tasks/main.yml
    │   └── meta/main.yml
    ├── webserver/
    │   ├── README.md
    │   ├── defaults/main.yml
    │   ├── tasks/main.yml
    │   ├── handlers/main.yml
    │   ├── templates/nginx.conf.j2
    │   └── meta/main.yml
    └── fastapi-app/
        ├── README.md
        ├── defaults/main.yml
        ├── tasks/main.yml
        ├── handlers/main.yml
        ├── templates/
        │   └── fastapi-app.service.j2
        └── meta/main.yml
```

### 5.3 Requisitos por role

#### `common`

- `defaults/main.yml` define al menos `common_timezone`, `common_appuser`.
- `tasks/main.yml` crea el usuario `appuser` (módulo `user:`) y asegura timezone (puedes usar `community.general.timezone` o escribir `/etc/timezone`).
- `meta/main.yml` con `galaxy_info` mínimo y `dependencies: []`.

#### `webserver`

- `defaults/main.yml` define al menos `webserver_port`, `webserver_upstream_port`.
- `tasks/main.yml` instala nginx (`package:`), despliega template con `template:`, notifica handler.
- `handlers/main.yml` con `reload nginx`.
- `templates/nginx.conf.j2` que haga `proxy_pass http://127.0.0.1:{{ webserver_upstream_port }};`.
- `meta/main.yml` — **si eliges opción A**, `dependencies: [common]`. **Si eliges opción B**, `dependencies: []`.

#### `fastapi-app`

- `defaults/main.yml` define al menos `fastapi_app_name`, `fastapi_app_port`, `fastapi_app_user`.
- `tasks/main.yml` instala Python + pip + paquete simulado (puedes usar `package: name=python3`), despliega una unidad systemd desde template.
- `handlers/main.yml` con `restart fastapi-app`.
- `templates/fastapi-app.service.j2` con un `[Unit]`, `[Service]` (ExecStart dummy acepta), `[Install]`.
- `meta/main.yml` — **si eliges opción A**, `dependencies: [webserver]`. **Si eliges B**, `dependencies: []`.

#### `site.yml`

- `hosts: localhost` + `connection: local`.
- **Opción A**: `roles: [fastapi-app]` (las deps arrastran a `webserver` y `common` en orden).
- **Opción B**: `roles: [common, webserver, fastapi-app]` (explícito).

### 5.4 `README-INTENT.md`

Secciones **obligatorias** (el validador las busca):

- `## Decision` — cuál opción elegiste (A o B).
- `## common` — qué hace, por qué va primero.
- `## webserver` — qué hace, por qué va después de common.
- `## fastapi-app` — qué hace, por qué va al final.
- `## Trade-offs` — qué perdiste al elegir A o B.

Debes mencionar explícitamente las palabras `meta/main.yml` **y** `dependencies` **y** `composicion` (o `composición`) para que el validador vea que razonaste ambas.

## 6. Resultado esperado

- Los 3 roles existen con la estructura mínima.
- Todos los YAML parsean.
- `site.yml` invoca el role correcto según la opción elegida.
- `README-INTENT.md` cubre las 5 secciones y menciona ambas opciones.
- Validador: `RESULT: 0 issue(s).`

## 7. Criterios de aceptación

- **Estructura**: 3 roles con `defaults/`, `tasks/`, `meta/` + README cada uno.
- **Encadenado funcional**: `--syntax-check` pasa (si ansible instalado).
- **Decisión documentada**: `README-INTENT.md` no es un placeholder.
- **Coherencia**: si eliges A, `meta/main.yml` tiene dependencies no vacías. Si eliges B, `site.yml` lista los 3 roles.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-04-chain
```

El validador acepta ambas opciones (A y B) y comprueba internamente la coherencia entre `site.yml` y los `meta/main.yml`.

## 9. Preguntas de reflexión

1. Si `webserver` declara `dependencies: [common]` y `fastapi-app` también declara `dependencies: [common]`, ¿se corre `common` dos veces? ¿Por qué?
2. ¿Qué pasa si `common` tiene vars (`common_timezone: UTC`) y `fastapi-app` las sobreescribe en `meta/main.yml`? ¿A qué precedence equivale?
3. Si en el futuro quieres reemplazar `webserver` (nginx) por `caddy`, ¿la opción A o la B te facilita el cambio?

## 10. Extensiones

- Añade un `common_hardening` role (ssh config, fail2ban) y encadénalo antes de `common`.
- Añade un segundo `site-dev.yml` que corra `common + fastapi-app` **sin** `webserver` (dev local). ¿Cómo lo haces si elegiste opción A?

## 11. Limpieza

```bash
rm -rf /tmp/ans-04-chain
```
