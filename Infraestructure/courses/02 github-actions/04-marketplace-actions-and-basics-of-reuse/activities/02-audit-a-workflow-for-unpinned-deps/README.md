# Actividad 02 — Auditar y corregir un workflow con dependencias sin pin

## 1. Identificación

- **ID:** `gha-04-02-audit-a-workflow-for-unpinned-deps`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-04-marketplace-actions-and-basics-of-reuse`
- **Dificultad:** beginner
- **Duración estimada:** 45–60 min
- **Tipo:** independent

## 2. Contexto

Un compañero (o tu "yo" de hace 6 meses) escribió un workflow que funciona pero no cumple la política de supply chain. Tu trabajo es **auditarlo** y **arreglarlo**. El workflow mezcla los antipatrones más comunes: `@main`, `@master`, `@v4` sin SHA, y hasta un SHA sin comentario de versión.

Esto es independiente: no te vamos a decir qué línea arreglar. Debes identificarlas tú y re-escribirlas en el formato canónico.

## 3. Objetivos

Al terminar:
- Produjiste un reporte `AUDIT.md` en `/tmp/.../repo/` listando cada hallazgo y su tipo.
- Reescribiste `.github/workflows/ci.yml` para que **todas** las `uses:` estén en forma `owner/repo@<SHA40>  # v<SEMVER>`.
- El validador pasa en verde.

## 4. Prerrequisitos

- Haber hecho la actividad 01.
- Python ≥ 3.9 con `pyyaml`.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/gha-04-02-audit-a-workflow-for-unpinned-deps
```

Resultado:

```
/tmp/gha-04-02-audit-a-workflow-for-unpinned-deps/
└── repo/
    └── .github/workflows/
        ├── ci.yml       ← lleno de antipatrones; audítalo y arréglalo
        └── release.yml  ← también auditable (más corto)
```

### 5.2 Auditar (sin arreglar aún)

Primero **lee** los dos archivos. Para cada línea `uses:` responde:

- ¿Qué owner/repo es?
- ¿Qué tipo de ref usa? (`SHA40` | `tag mayor` | `tag exacto` | `branch`)
- ¿Lleva comentario de versión?
- ¿Es first-party (`actions/*`), trusted vendor, o tercero desconocido?

Crea un archivo `/tmp/gha-04-02-audit-a-workflow-for-unpinned-deps/repo/AUDIT.md` con una tabla como esta (una fila por `uses:`):

```markdown
| archivo | línea | owner/repo | ref actual | tipo | riesgo | acción |
|---------|-------|------------|-----------|------|--------|--------|
| ci.yml  | 12    | actions/checkout | @main | branch | HIGH — HEAD mutable | pin a SHA v4.2.2 |
| ci.yml  | 15    | actions/setup-python | @v5 | major tag | MED — tag reescribible | pin a SHA v5.3.0 |
| ...     | ...   | ...              | ...   | ...    | ...                 | ...               |
```

Herramientas útiles:

```bash
# Lista todas las `uses:` del repo
grep -rhnE '^\s*-?\s*uses:' /tmp/gha-04-02-audit-a-workflow-for-unpinned-deps/repo/.github/workflows/

# Las que ya están pinneadas a SHA40 (lo sano)
grep -rhnE 'uses:\s+[^@]+@[0-9a-f]{40}' /tmp/gha-04-02-audit-a-workflow-for-unpinned-deps/repo/.github/workflows/
```

### 5.3 Arreglar

Para cada `uses:` que NO esté en forma canónica, reescríbela como:

```yaml
- uses: owner/repo@<SHA40>  # v<MAJOR>.<MINOR>.<PATCH>
```

Resuelve cada SHA con:

```bash
gh api repos/<owner>/<repo>/git/refs/tags/<v> --jq '.object.sha'
# o
git ls-remote https://github.com/<owner>/<repo>.git refs/tags/<v>
```

> Para los `uses:` que apuntan a `actions/*`, puedes reutilizar los SHAs que ya aparecen en `examples/02-pin-to-sha/files/workflow-safe.yml` y en `examples/01-setup-python-matrix/files/ci.yml`.
> Para `actions/upload-artifact v4.4.3` usa: `b4b15b8c7c6ac21ea08fcf65892d2ee8f75cf882`.
> Para `actions/setup-node v4.1.0` usa: `39370e3970a6d050c480ffad4ff0ed4d3fdee5af`.
>
> (Si estás en live-fire con GitHub real, re-verifica estos SHAs antes de pegarlos.)

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/gha-04-02-audit-a-workflow-for-unpinned-deps
```

Debe terminar con `RESULT: N/N checks OK.`

## 6. Resultado esperado

- `AUDIT.md` existe y contiene una tabla con las columnas esperadas.
- Los dos workflows (`ci.yml`, `release.yml`) tienen **todas** sus `uses:` en forma `owner/repo@<SHA40>  # v<SEMVER>`.
- Ningún `uses:` queda apuntando a `@main`, `@master`, `@v<N>` (solo), ni a SHA sin comentario.

## 7. Criterios de aceptación

- [ ] `AUDIT.md` existe y contiene al menos una tabla markdown.
- [ ] Ambos YAML cargan sin error.
- [ ] 100% de las `uses:` apuntan a SHA de 40 chars.
- [ ] 100% de las `uses:` llevan comentario `# vX.Y.Z`.
- [ ] No queda ninguna `uses:` con `@main`, `@master`, ni tag `@v<N>` o `@v<N>.<M>` sin SHA.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gha-04-02-audit-a-workflow-for-unpinned-deps
```

El validador falla ruidoso: te dice exactamente qué línea no cumple y por qué.

## 9. Preguntas de reflexión

1. En la auditoría, ¿qué `uses:` consideraste de **mayor riesgo** y por qué? Da un argumento concreto (no "porque sí").
2. ¿Qué cambios de proceso (no de código) propondrías para que esto no vuelva a aparecer? (Pista: Dependabot, pre-commit hook, PR template, codeowners.)
3. ¿Habría alguna `uses:` para la que tolerarías dejar `@v4` sin SHA? Si sí, cuál y por qué. Si no, justifica.
4. Da un ejemplo concreto (puede ser el de `tj-actions/changed-files` 2025, o uno inventado) de cómo un tag reescrito puede comprometer este workflow específico.

## 10. Extensiones (opcional)

- **E1** — Añade `.github/dependabot.yml` con política para `github-actions` + `groups:` para no ahogarte en PRs.
- **E2** — Escribe un pre-commit hook (bash) que falle el commit si detecta `uses: ...@` sin SHA.
- **E3** — Instala `actionlint` y corre `actionlint .github/workflows/*.yml`.
- **E4** — Compara con `zizmor` o `pinact`: ¿qué más detectan además de tu validador?

## 11. Limpieza

```bash
rm -rf /tmp/gha-04-02-audit-a-workflow-for-unpinned-deps
```
