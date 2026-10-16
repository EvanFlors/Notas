# Actividad 02 — Escribir un plugin propio mínimo

## 1. Identificación

- **ID:** `plat-08-02-write-minimal-custom-plugin`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-08-plugins-ecosystem-and-custom-plugin`
- **Dificultad:** advanced
- **Duración estimada:** 75–100 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Los plugins oficiales no cubren el 100 % del contexto que tu organización quiere mostrar en Backstage. Antes o después vas a necesitar un **plugin propio** aunque sea mínimo (una card de "health" interna, un badge de un sistema que solo existe en tu empresa, una vista de licensing custom).

Esta actividad te lleva por el **esqueleto estructural** real de un plugin frontend como lo genera `backstage-cli create` (`yarn new --select plugin`). Si tienes `node + yarn + Backstage workspace` localmente, puedes correr el CLI y usar su output. Si no, reprodu­ces manualmente los archivos mínimos (el validador comprueba **estructura**, no ejecución).

El plugin de ejemplo se llama `service-health` y muestra una Card estática. En producción conectarías esa Card a un backend o a `proxy.endpoints`; aquí solo construyes el esqueleto.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Enumerar los archivos **imprescindibles** de un plugin frontend.
- Escribir un `package.json` con `backstage.role`, `peerDependencies`, scripts.
- Escribir `src/plugin.ts` con `createPlugin` + `createRoutableExtension`.
- Escribir un componente React tipado con `Page / Header / Content` de `@backstage/core-components`.
- Documentar en un `TEMPLATE.md` cómo se engancha el plugin en `packages/app/src/App.tsx`.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (en particular §5–§8).
- Haber recorrido `examples/03-custom-plugin-boilerplate/`.
- Prerrequisitos del módulo: `plat-04`, `plat-05`.
- **Opcional**: `node >= 18`, `yarn` y un workspace Backstage creado con `npx @backstage/create-app`. Si los tienes, el walkthrough puede ejecutarse en vivo. Si no, los archivos se escriben a mano.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-08-plugin
cd /tmp/plat-08-plugin
```

### 5.2 Walkthrough opcional con `backstage-cli` (si tienes tooling)

Si tienes Node + Yarn + un workspace Backstage:

```bash
cd <ruta-a-tu-workspace-backstage>
yarn new --select plugin
# Enter plugin ID: service-health
# Copiar plugins/service-health/ a /tmp/plat-08-plugin/
cp -r plugins/service-health/* /tmp/plat-08-plugin/
```

Si **no** los tienes, crea los archivos a mano con el contenido mínimo indicado en 5.3 (es exactamente lo que `yarn new` produce con nombres cambiados).

### 5.3 Reproduce el esqueleto mínimo

Al final, `/tmp/plat-08-plugin/` debe contener **al menos**:

```
/tmp/plat-08-plugin/
├── package.json
├── README.md
├── TEMPLATE.md
└── src/
    ├── index.ts
    ├── plugin.ts
    ├── routes.ts
    └── components/
        └── ServiceHealthCard/
            ├── ServiceHealthCard.tsx
            └── index.ts
```

Reglas de contenido:

- **`package.json`** incluye:
  - `"name"` del tipo `@internal/plugin-service-health` (o similar).
  - `"backstage"` object con `"role": "frontend-plugin"`.
  - `"peerDependencies"` con `"react"`.
  - `"scripts"` con al menos `start`, `build`, `test`.
- **`src/plugin.ts`** usa `createPlugin` y `createRoutableExtension` importados desde `@backstage/core-plugin-api`.
- **`src/routes.ts`** exporta un `rootRouteRef` creado con `createRouteRef`.
- **`src/index.ts`** reexporta los símbolos públicos del plugin.
- **`src/components/ServiceHealthCard/ServiceHealthCard.tsx`** es un componente React tipado que importa `Page`, `Header`, `Content` desde `@backstage/core-components`.
- **`TEMPLATE.md`** (no `ANALYSIS.md`) documenta: cómo enganchar el plugin en `App.tsx`, y si decides que necesita backend propio o `proxy.endpoints`.

### 5.4 Entregable

El directorio `/tmp/plat-08-plugin/` con la estructura anterior.

## 6. Resultado esperado

- Todos los archivos listados existen.
- `package.json` es JSON válido.
- `src/plugin.ts` importa de `@backstage/core-plugin-api` y usa `createPlugin`.
- `ServiceHealthCard.tsx` importa de `@backstage/core-components`.
- `TEMPLATE.md` menciona `App.tsx` y la palabra `proxy` o `discoveryApi`.
- `bash tests/validate.sh /tmp/plat-08-plugin` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: nombres de package consistentes; tipos React explícitos.
- **Reproducibilidad**: alguien con un workspace Backstage puede copiar `/tmp/plat-08-plugin/` dentro de `plugins/` y hacer `yarn install` sin romper (modulo pequeños ajustes de versión).
- **Mantenibilidad**: `react` en `peerDependencies`, no en `dependencies`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-08-plugin
```

El validador comprueba **estructura**: existencia de archivos, JSON válido, patrones de código esperados (nombres de API, imports). **No** ejecuta `yarn install`, `tsc` ni `jest`: si no tienes `node`/`yarn`/`backstage-cli`, el validador **salta** graciosamente los checks que requieran tooling y los marca como `SKIP`.

## 9. Preguntas de reflexión

1. ¿Por qué `react` va en `peerDependencies` y no en `dependencies`?
2. ¿Cuándo decidirías promover tu plugin de "frontend-only" a "frontend + backend"?
3. ¿Qué pierdes si hardcodeas `http://localhost:7007/api/service-health` en el frontend en lugar de usar `discoveryApi`?
4. Si el plugin solo necesita hacer `GET` a una API interna con un token, ¿qué patrón usas antes de escribir un plugin backend?
5. ¿Cómo cambiarías el esqueleto para que el plugin aparezca como **tab** dentro de `EntityPage` en lugar de página standalone?

## 10. Extensiones

- Añade `src/api/types.ts` + `src/api/ServiceHealthClient.ts` con el patrón `discoveryApi + fetchApi`.
- Añade un `createApiFactory` en el `TEMPLATE.md` mostrando cómo registrarlo en `App.tsx`.
- Añade un segundo componente `EntityServiceHealthContent` para enganchar como tab en `EntityPage`.
- Añade `peerDependencies` para `@backstage/core-plugin-api` y `@backstage/core-components` (evita duplicación en runtime).

## 11. Limpieza

```bash
rm -rf /tmp/plat-08-plugin
```

No hay procesos ni contenedores que detener.
