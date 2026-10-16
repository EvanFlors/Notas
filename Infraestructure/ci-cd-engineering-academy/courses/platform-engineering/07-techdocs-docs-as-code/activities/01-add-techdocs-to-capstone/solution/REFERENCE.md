# Solution — plat-07-01-add-techdocs-to-capstone

Esta carpeta contiene una **implementación de referencia** completa, pensada para autoevaluarte después de haber hecho la tuya. **No la copies tal cual**: léela, compara, y refuerza tu versión donde haga falta.

## Qué hay aquí

- `REFERENCE.md` — este archivo: discute decisiones no obvias.
- `reference/` — árbol copiable que pasa el validador:
  - `mkdocs.yml`
  - `catalog-info.yaml`
  - `docs/index.md`
  - `docs/adr/0001-adopt-techdocs.md`
  - `docs/runbook/deploy-and-rollback.md`
  - `docs/api/reference.md`
  - `.github/workflows/techdocs.yml`

## Para probar

```bash
rm -rf /tmp/plat-07-techdocs
mkdir -p /tmp/plat-07-techdocs
cp -R reference/. /tmp/plat-07-techdocs/
bash ../tests/validate.sh /tmp/plat-07-techdocs
```

Si tienes MkDocs instalado:

```bash
cd /tmp/plat-07-techdocs && mkdocs build --strict
```

## Decisiones no obvias

1. **`backstage.io/techdocs-ref: dir:.`** (y no `url:...`). El contrato "docs owned by services" es más fuerte cuando las docs viven en el mismo repo que el código; `url:` se reserva para casos excepcionales (p. ej. un repo de "arquitectura global" compartido).
2. **`nav` explícito**. Dejar que MkDocs autogenere `nav` desde el filesystem funciona para 5 páginas, pero cuando el `docs/` crece el orden se vuelve imprevisible. Mantener `nav` explícito es un *forcing function* para pensar el índice.
3. **Pipeline con `paths:` filter**. Sin filter, cada push `src/` lanza build+publish (minutos de CI por nada). Con filter, solo re-publica cuando algo doc-relevante cambia.
4. **OIDC federado hacia AWS**. `id-token: write` en `permissions` + `aws-actions/configure-aws-credentials` → cero secretos rotables, trust limitado a `repo:org/repo:ref:refs/heads/main`. Esto es lo que se enseñó en el curso de GitHub Actions.
5. **`--no-docker` en `techdocs-cli generate`**. Dentro de un runner Ubuntu con Python instalado, invocar Docker-in-Docker añade complejidad sin beneficio.
6. **Dos pasadas `mkdocs build --strict` → `techdocs-cli generate`**. La primera falla rápido con links rotos; la segunda produce el bundle que `publish` sube. Se puede consolidar en optimización final.
7. **`concurrency` group en el pipeline**. Dos merges rápidos a main no se pisan en el bucket (el segundo cancela el primero).
8. **El runbook en el starter incluye "Rollback"** porque "mitigación" para un servicio es casi siempre "rollback" — es la mitigación por defecto en Argo CD. Nombrarlo explícitamente ahorra tiempo en la crisis.

## Qué NO hace esta solución (y por qué)

- No sube realmente a S3. Fuera del scope del módulo (y violaría la regla "no cloud cost"). El pipeline queda como walkthrough.
- No instala MkDocs. Si lo tienes, el validador aprovecha; si no, lo saltea.
- No cubre versioning por rama/SHA. Es decisión org-wide y aparece en `plat-12`.
- No cubre el plugin `search` del Backstage backend. Es una pieza del propio Backstage (`plat-04` nivel avanzado).

## Lectura recomendada después

- `../../../examples/02-techdocs-centralized-s3/README.md` — el pipeline completo con IAM policies.
- `../../02-docs-minimum-standard-adr/` — la actividad hermana que institucionaliza este estándar como ADR de plataforma.
