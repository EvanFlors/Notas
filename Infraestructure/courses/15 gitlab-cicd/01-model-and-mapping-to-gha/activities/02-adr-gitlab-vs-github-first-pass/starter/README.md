# Starter — gl-01-02-adr-gitlab-vs-github-first-pass

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un ADR Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo (sobre todo el contexto de "acme" en §2).
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gl-01-02
   cd /tmp/gl-01-02
   ```
3. Crea `ADR-GITLAB-VS-GITHUB.md` con las 6 secciones requeridas:
   - Estado, Contexto, Decisión, Consecuencias, Alternativas (y el encabezado `# ADR`).
4. Incluye en la Decisión:
   - Una **tabla comparativa** de ejes decisivos (compliance, Self-Managed, Subgroups, Catalog, migración, SSO, costo).
   - La elección explícita (`elegimos ...`) con horizonte temporal.
   - El plan equivalente comparado (`GitHub Team + GHAS` vs `GitLab Ultimate`, o similar — no "Free vs Free").
   - Mención de Europa / `eu-*`.
5. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/gitlab-cicd/01-model-and-mapping-to-gha/activities/02-adr-gitlab-vs-github-first-pass/tests/validate.sh /tmp/gl-01-02
   ```
6. Compara tu ADR con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura, no semántica. La corrección argumentativa la revisas tú contra la referencia.

## Plantilla sugerida (opcional)

Puedes arrancar con esto y rellenar:

```markdown
# ADR 001 — Plataforma CI/CD: GitLab vs GitHub Actions (primera pasada)

## Estado
Propuesto

## Contexto
<org acme, 20 personas, 15 repos en GitHub, SOC 2 en 6 meses, PCI-light en checkout, Europa (eu-*), susto reciente con secreto en logs>

## Decisión

Elegimos ...

### Tabla comparativa

| Eje | GitHub Actions (Team + GHAS + GHE) | GitLab Ultimate (SaaS) | Peso |
|-----|-----------------------------------|------------------------|------|
| Compliance SOC 2 / PCI | ... | ... | ... |
| Self-Managed gratuito | ... | ... | ... |
| Subgroups y gobernanza jerárquica | ... | ... | ... |
| Catalog / reuso | ... | ... | ... |
| Marketplace / ecosistema | ... | ... | ... |
| SSO / SCIM | ... | ... | ... |
| Costo de migración (desde GHA actual) | ... | ... | ... |
| Residencia Europa (eu-*) | ... | ... | ... |

## Consecuencias
### Positivas
- ...
### Negativas
- ...

## Alternativas descartadas
### Alt A: ...
- Por qué no: ...
### Alt B: ...
- Por qué no: ...
```
