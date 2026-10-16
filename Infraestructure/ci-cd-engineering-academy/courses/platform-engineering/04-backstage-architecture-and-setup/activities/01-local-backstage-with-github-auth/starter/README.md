# Starter — plat-04-01-local-backstage-with-github-auth

Esta actividad es **independiente** y documental. Tu entregable principal es un documento Markdown. Si tienes Node 20+ puedes además ejecutar `create-app`, pero no es obligatorio.

## Pasos

1. Lee `../README.md`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/plat-04-backstage
   cd /tmp/plat-04-backstage
   ```
3. (Opcional) Si `node --version` reporta `v20.x` o superior:
   ```bash
   npx @backstage/create-app@latest
   # elige nombre: my-backstage
   ```
4. Escribe `BACKSTAGE-SETUP.md` con las 5 secciones A–E descritas en `../README.md`.
5. Verifica que **ningún secreto real** haya quedado en el documento (solo placeholders tipo `ghp_xxxx_placeholder_do_not_use`).
6. Valida:
   ```bash
   bash <ruta-repo>/courses/platform-engineering/04-backstage-architecture-and-setup/activities/01-local-backstage-with-github-auth/tests/validate.sh /tmp/plat-04-backstage
   ```
7. Compara con `../solution/REFERENCE.md`.

> El validador comprueba **estructura** y **ausencia de secretos reales**, no corrección conceptual. La semántica la revisas tú contra la referencia.
