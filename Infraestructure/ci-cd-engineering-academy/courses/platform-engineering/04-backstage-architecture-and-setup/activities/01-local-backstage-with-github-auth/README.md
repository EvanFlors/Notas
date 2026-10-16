# Actividad 01 — Backstage local con auth GitHub + Postgres (documentado)

## 1. Identificación

- **ID:** `plat-04-01-local-backstage-with-github-auth`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-04-backstage-architecture-and-setup`
- **Dificultad:** intermediate
- **Duración estimada:** 80–100 min
- **Tipo:** independent

## 2. Contexto

Esta actividad consolida la arquitectura y el setup inicial de Backstage. El entregable **principal** es un documento `BACKSTAGE-SETUP.md` que debe poder leerse como un manual: alguien que lo siga en limpio debería poder levantar Backstage, configurar auth GitHub y preparar el switch a Postgres sin consultar nada más.

> **Nota sobre tooling:** `npx @backstage/create-app` requiere **Node 20+** y descarga ~1.5 GB de dependencias. Si no tienes Node 20+ o la red disponible, trata la ejecución como *walkthrough* — el validador detecta la ausencia de Node 20+ y hace **SKIP** limpio de los checks que requieren el repo ejecutado. El Markdown sigue siendo obligatorio.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Explicar por qué Backstage es un framework y no una app descargable.
- Enumerar los paquetes del monorepo generado por `create-app`.
- Describir el merge por capas de `app-config.yaml` → `app-config.<env>.yaml` → `app-config.local.yaml` → variables de entorno.
- Configurar el provider GitHub con **placeholders** de secretos (jamás reales).
- Describir el switch de SQLite a Postgres y qué cambia en prod.
- Dibujar el diagrama de componentes (frontend, backend, DB, auth, catálogo).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` y los 3 ejemplos.
- `bash` y un editor Markdown. **Opcional:** `node >= 20` para ejecutar `create-app`.

**Costos:** cero.

## 5. Instrucciones

### 5.1 Preparar directorio

```bash
mkdir -p /tmp/plat-04-backstage
cd /tmp/plat-04-backstage
```

### 5.2 (Opcional) Ejecutar `create-app`

Si tienes `node >= 20`:

```bash
cd /tmp/plat-04-backstage
# El wizard preguntara un nombre; usa 'my-backstage'
npx @backstage/create-app@latest
# No arranques `yarn dev` para esta actividad — solo verificamos la estructura
```

Si no, salta este paso. El validador lo marcará como SKIP.

### 5.3 Producir `BACKSTAGE-SETUP.md`

Crea `/tmp/plat-04-backstage/BACKSTAGE-SETUP.md` con las **cinco secciones** siguientes. Cada heading debe empezar con `## Seccion <letra>` para que el validador lo encuentre.

#### Sección A — create-app y estructura del repo

- Comando ejecutado (`npx @backstage/create-app@latest`).
- Prerrequisitos (Node 20+).
- Árbol de directorios resultante (al menos: `packages/app/`, `packages/backend/`, `plugins/`, `app-config.yaml`).
- Qué hace cada uno.

#### Sección B — Merge por capas de `app-config`

- Orden exacto de merge (1 → 4) incluyendo `${VAR}` resolution.
- Qué va en cada capa (base commiteado vs overrides vs secretos).
- Al menos un ejemplo real de override (p. ej. `backend.database.client`).

#### Sección C — Auth GitHub

- Pasos a nivel GitHub (OAuth App, callback URL `http://localhost:7007/api/auth/github/handler/frame`).
- Bloque `auth.providers.github` con **placeholders** (`${AUTH_GITHUB_CLIENT_ID}`, etc.).
- Variables de entorno necesarias.
- **Nota explícita:** los valores de ejemplo deben ser literales placeholders del tipo `ghp_xxxx_placeholder_do_not_use` o `Iv1.xxxx_placeholder`. **Prohibido** pegar un token real.

#### Sección D — Postgres en producción

- Qué cambia en `app-config.production.yaml` (`backend.database.client: pg`).
- Env vars (`POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`).
- Por qué SQLite no sobrevive a multi-replica.
- Dónde corren las migraciones (automáticas al `start`).

#### Sección E — Diagrama de componentes (ASCII)

Debe mostrar al menos:

- Frontend (`packages/app`, puerto 3000).
- Backend (`packages/backend`, puerto 7007).
- Base de datos (SQLite dev / Postgres prod).
- Flujo auth (Browser → GitHub OAuth → Backend callback → session).

### 5.4 Entregable

```
/tmp/plat-04-backstage/BACKSTAGE-SETUP.md
```

Si corriste `create-app`, también:

```
/tmp/plat-04-backstage/my-backstage/
```

### 5.5 Limpieza

```bash
rm -rf /tmp/plat-04-backstage
```

## 6. Resultado esperado

- `BACKSTAGE-SETUP.md` existe y tiene las 5 secciones.
- Menciona `app-config`, `packages/app`, `packages/backend`, Postgres y GitHub OAuth.
- Diagrama ASCII incluido.
- **Ningún secreto real**; solo placeholders del tipo `ghp_xxxx_placeholder`.
- `bash tests/validate.sh /tmp/plat-04-backstage` sale en verde (los chequeos de create-app pueden salir como SKIP si no hay Node 20+ — eso cuenta como éxito).

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa (o SKIP limpio en los pasos sin herramientas).
- **Calidad**: cada decisión está defendida en 1–3 líneas.
- **Seguridad**: cero secretos reales. Todos los placeholders llevan el string `placeholder`.
- **Reproducibilidad**: alguien ajeno puede seguir el documento y llegar al mismo estado.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-04-backstage
```

El validador:

- Verifica estructura del Markdown.
- Verifica ausencia de patrones de secretos reales.
- Si detecta `node >= 20` y existe `/tmp/plat-04-backstage/my-backstage/package.json`, hace checks adicionales. Si no, los omite con mensaje `SKIP`.

## 9. Preguntas de reflexión

1. ¿Por qué `create-app` genera un repo nuevo en vez de bajar un contenedor con la UI final?
2. Si commiteas `app-config.local.yaml` por error, ¿qué deberías hacer *antes* de hacer push?
3. ¿Qué pasa si tu `app.baseUrl` es HTTP pero el callback de OAuth lo configuraste en HTTPS?
4. ¿Por qué SQLite in-memory basta para dev pero rompe en multi-replica?
5. ¿Cuándo preferirías CNOE (`idpbuilder`) a hacer `create-app` tú mismo?

## 10. Extensiones

- Añade una Sección F documentando cómo migrarías a Google OIDC en lugar de GitHub.
- Añade un bloque de ejemplo de **External Secrets Operator** mapeando los env vars a secretos de K8s.
- Añade un ADR corto justificando "Postgres managed (RDS) vs operator en cluster".

## 11. Autoevaluación

Compara tu `BACKSTAGE-SETUP.md` con `solution/REFERENCE.md`.
