# REFERENCE — gcp-10-01-wif-pipeline-no-keys-adr

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Estructura

```
/tmp/gcp-10-01-wif/
├── terraform/wif.tf
├── .github/workflows/publish.yml
└── ADR-WIF-PIPELINE.md
```

Los archivos de solución están en este mismo directorio:

- `terraform/wif.tf` — plantilla TF completa.
- `github-workflow-publish.yml` — plantilla GHA (copiar a `.github/workflows/publish.yml`).
- `ADR-WIF-PIPELINE.md` — ADR de referencia.

---

## Resumen de decisiones

1. **Un solo pool `github-pool`** para todos los repos de GitHub de la org, con **un provider por tipo de IdP** (en este caso solo GitHub).
   - Alternativa: un pool por repo. Descartada: multiplica la administración sin beneficio real; los bindings ya aíslan.

2. **`attribute_condition` en el provider** pinnea a `assertion.repository == "acme/checkout"`.
   - Pinnear al repo elimina el riesgo de que un fork malicioso impersone.
   - Si en el futuro se añaden más repos, se usa `||` o se extiende la condición.
   - Alternativa: no pinnear y confiar solo en el binding de la SA. Descartada: defensa en profundidad obliga a dos filtros.

3. **Binding con `principalSet://` filtrado por `attribute.repository`**: segunda defensa.

4. **Permisos mínimos**: `roles/artifactregistry.writer` **solo** sobre el repo `prod-images`, no sobre todo el project.

5. **El workflow no referencia ningún secret** más allá de los que GitHub inyecta (`GITHUB_TOKEN`). No existe `GCP_SA_KEY`.

6. **El provider no incluye `allowed_audiences`**: por defecto, GCP acepta como audience el nombre completo del provider resource, lo cual es seguro. Si se quisiera forzar un audience custom, se pone `oidc.allowed_audiences = ["sts.googleapis.com"]` y el workflow lo pasa en `audience`.

---

## Trampas comunes

- Olvidar `permissions: id-token: write` → GHA no emite el JWT y la auth falla antes del intercambio.
- Olvidar `attribute_condition` → **cualquier** repo del planeta puede intentar impersonar; el binding es la única barrera.
- Dar `roles/editor` o `roles/owner` a la SA → anula el beneficio de WIF (sigue siendo demasiado poder).
- Crear `google_service_account_key` "por si acaso" → anula completamente el pipeline (la key filtrada vuelve a ser el eslabón débil).

---

## Para continuar

Esta actividad produce el **plano** del pipeline WIF. La actividad 02 añade la **admisión por firma** (Binauthz) para que ninguna imagen no firmada por este pipeline pueda ejecutarse en el cluster.
