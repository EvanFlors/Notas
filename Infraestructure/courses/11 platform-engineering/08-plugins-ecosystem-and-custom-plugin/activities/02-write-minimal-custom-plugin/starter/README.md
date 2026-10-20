# Starter — plat-08-02-write-minimal-custom-plugin

Esta actividad es **independiente**: construyes la estructura de un plugin propio en `/tmp/plat-08-plugin/`.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/plat-08-plugin/src/components/ServiceHealthCard
   cd /tmp/plat-08-plugin
   ```
3. (Opcional) Si tienes Node + Yarn + un workspace Backstage, corre `yarn new --select plugin` y copia `plugins/service-health/*` a `/tmp/plat-08-plugin/`.
4. (Siempre) Asegúrate de tener los archivos mínimos listados en la sección 5.3 del README.
5. Escribe `TEMPLATE.md` con el enganche en `App.tsx` y la decisión sobre backend vs proxy.
6. Valida:
   ```bash
   bash <ruta-repo>/courses/platform-engineering/08-plugins-ecosystem-and-custom-plugin/activities/02-write-minimal-custom-plugin/tests/validate.sh /tmp/plat-08-plugin
   ```
7. Compara tus archivos con `../solution/` para autoevaluarte.

> **Importante:** el validador comprueba estructura, no ejecución. Si falta `node`/`yarn`, los checks que requieran tooling se marcan `SKIP`.
