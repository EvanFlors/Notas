# Starter — plat-07-01-add-techdocs-to-capstone

Plantilla mínima para arrancar. **Copia** estos stubs a `/tmp/plat-07-techdocs/` y complétalos. No edites este starter — es el punto de partida compartido.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/plat-07-techdocs
   cd /tmp/plat-07-techdocs
   ```
3. Copia los stubs de este starter como semilla:
   ```bash
   cp -R <ruta-repo>/courses/platform-engineering/07-techdocs-docs-as-code/activities/01-add-techdocs-to-capstone/starter/skeleton/* /tmp/plat-07-techdocs/
   ```
4. Completa:
   - `mkdocs.yml` — añade `plugins: [techdocs-core]` y el `nav` con las 4 páginas.
   - `catalog-info.yaml` — añade la anotación `backstage.io/techdocs-ref: dir:.`.
   - `docs/index.md`, `docs/adr/0001-adopt-techdocs.md`, `docs/runbook/deploy-and-rollback.md`, `docs/api/reference.md` — rellena con contenido real (ver requisitos en el README).
   - `.github/workflows/techdocs.yml` — pipeline CI con `techdocs-cli publish --publisher-type awsS3` y OIDC.
5. (Opcional) Instala MkDocs y valida localmente:
   ```bash
   pip install mkdocs mkdocs-techdocs-core
   cd /tmp/plat-07-techdocs
   mkdocs build --strict
   ```
6. Corre el validador:
   ```bash
   bash <ruta-repo>/courses/platform-engineering/07-techdocs-docs-as-code/activities/01-add-techdocs-to-capstone/tests/validate.sh /tmp/plat-07-techdocs
   ```

> Si no tienes `pip`/MkDocs, el validador salta el strict build con un SKIP y solo revisa estructura. Igualmente debería pasar.
