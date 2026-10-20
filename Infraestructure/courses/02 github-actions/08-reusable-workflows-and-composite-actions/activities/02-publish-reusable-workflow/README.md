# Actividad 02 — Publicar un reusable workflow (dos repos)

## 1. Identificación

- **ID:** `gha-08-02-publish-reusable-workflow`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-08-reusable-workflows-and-composite-actions`
- **Dificultad:** intermediate
- **Duración estimada:** 60–90 min
- **Tipo:** independent

## 2. Contexto

En producción un reusable workflow vive en un repo "shared" al que apuntan N repos "client". Esta actividad simula ese escenario con **dos directorios en `/tmp/`**: uno es el `shared` y otro es el `client`. Ambos son repos git reales (para que puedas crear un tag `v1` en `shared` y "pinnear" desde `client`), pero no requieren GitHub remoto.

La validación es **estática** sobre los YAML: estructura del `workflow_call`, inputs tipados, secrets declarados, outputs propagados, y que el caller use el formato correcto `uses: owner/repo/.github/workflows/<file>.yml@v1`.

## 3. Objetivos

Al terminar:
- Escribes `shared/.github/workflows/build-and-publish.yml` con `on: workflow_call`, al menos 2 inputs tipados, al menos 1 secret declarado, y 1 output propagado.
- Creas el tag `v1` en el repo `shared` apuntando al commit que contiene el reusable.
- Escribes `client/.github/workflows/ci.yml` que invoca el reusable con el **formato de referencia cross-repo** (`uses: owner/shared/.github/workflows/build-and-publish.yml@v1`) y le pasa el secret explícitamente.
- Pasas `bash tests/validate.sh`.

**No** se te da la solución. Lee la lección (`theory/lesson.md`) y el ejemplo 02 (`examples/02-reusable-deploy-workflow/`) y resuelve.

## 4. Prerrequisitos

- `gha-08-01-extract-composite-action` completada.
- `theory/lesson.md` del módulo.
- `git`, `bash`, `python3` + `PyYAML`.
- No requiere GitHub real.

**Costos**: $0.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/publish-reusable
find /tmp/publish-reusable -not -path '*/.git/*' | sort
```

Se te crean **dos repos git** vacíos (salvo un commit base):

```
/tmp/publish-reusable/
├── shared/          (git repo, rama main, tiene commit base pero NO workflow)
└── client/          (git repo, rama main, tiene commit base pero NO workflow)
```

Y una variable:
- **`OWNER_SLUG`** (ver el output de `bootstrap.sh`): el "owner/repo" simulado para el shared, por ejemplo `my-org/shared-workflows`. Úsalo tal cual en el `uses:` del caller.

### 5.2 Lo que debes construir — repo `shared`

Crea `shared/.github/workflows/build-and-publish.yml`. El contrato mínimo:

- `on.workflow_call` presente.
- **Al menos 2 inputs tipados**: p. ej. `image-name` (`type: string`, `required: true`) y `push` (`type: boolean`, `required: false`, `default: false`). Al menos **uno** debe ser `type: string` y al menos **uno** `type: boolean`. (Esto el validador lo checa.)
- **Al menos 1 secret declarado**: `REGISTRY_TOKEN` con `required: true`.
- **1 output declarado**: `digest`, cuyo `value:` referencie `${{ jobs.<jobname>.outputs.<key> }}`.
- Un `jobs.<jobname>` con `outputs:` a nivel job que a su vez venga de un `steps.<id>.outputs.<key>` escrito a `$GITHUB_OUTPUT`.
- `permissions:` declarado (al menos `contents: read`).

Luego:

```bash
cd /tmp/publish-reusable/shared
git add .github
git commit -m "feat: add build-and-publish reusable workflow"
git tag -a v1.0.0 -m "v1.0.0"
git tag -a v1    -m "latest v1 (1.0.0)"
```

### 5.3 Lo que debes construir — repo `client`

Crea `client/.github/workflows/ci.yml`. Contrato mínimo:

- Al menos un `job` cuyo `uses:` apunte al reusable del shared en formato **cross-repo** con `@v1`:

  ```
  uses: <OWNER_SLUG>/.github/workflows/build-and-publish.yml@v1
  ```

  donde `<OWNER_SLUG>` es la cadena impresa por `bootstrap.sh` (típicamente `my-org/shared-workflows`).

- `with:` pasando los inputs requeridos del reusable (al menos `image-name`).
- `secrets:` **explícitos** (no `inherit`) pasando `REGISTRY_TOKEN` desde un `${{ secrets.* }}` del cliente.
- Un **segundo job** `announce` con `needs:` al job que invoca al reusable y que lea el output `digest` vía `${{ needs.<call-job>.outputs.digest }}`.

Luego:

```bash
cd /tmp/publish-reusable/client
git add .github
git commit -m "ci: adopt shared build-and-publish reusable at v1"
```

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/publish-reusable
```

Debe salir con `RESULT: N/N checks OK.` y exit code 0.

## 6. Resultado esperado

```
/tmp/publish-reusable/
├── shared/
│   ├── .github/workflows/build-and-publish.yml
│   └── (git tags: v1.0.0, v1)
└── client/
    └── .github/workflows/ci.yml
         └── job call-publish:  uses: my-org/shared-workflows/.github/workflows/build-and-publish.yml@v1
             with:    image-name: ...
             secrets: REGISTRY_TOKEN: ${{ secrets.REGISTRY_TOKEN }}
         └── job announce (needs: call-publish): lee needs.call-publish.outputs.digest
```

## 7. Criterios de aceptación

- [ ] `shared/.github/workflows/build-and-publish.yml` existe y es YAML válido.
- [ ] Define `on.workflow_call` con **≥2 inputs tipados** (al menos uno `string` y uno `boolean`).
- [ ] Declara el secret `REGISTRY_TOKEN` con `required: true`.
- [ ] Declara el output `digest` que propaga desde `jobs.<j>.outputs.*` → `steps.<s>.outputs.*`.
- [ ] Shared repo tiene tag `v1` creado.
- [ ] `client/.github/workflows/ci.yml` invoca el reusable con `uses: <OWNER_SLUG>/.github/workflows/build-and-publish.yml@v1`.
- [ ] Caller pasa el secret `REGISTRY_TOKEN` explícitamente (sin `inherit`).
- [ ] Caller tiene un job downstream con `needs:` que consume `needs.<j>.outputs.digest`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/publish-reusable
```

El validador comprueba (resumen):

1. Ambos repos existen y son git repos.
2. `shared` tiene el workflow con la estructura esperada (`workflow_call`, inputs tipados, secret, output).
3. `shared` tiene el tag `v1`.
4. `client` tiene el workflow con la **referencia cross-repo correcta** (regex: `^[\w.-]+/[\w.-]+/\.github/workflows/[\w.-]+\.yml@[\w.-]+$`).
5. El caller pasa el secret explícitamente.
6. El caller consume el output del reusable en un job con `needs:`.

## 9. Preguntas de reflexión

1. Si cambias `@v1` por `@main` en el caller, ¿qué riesgo introduces?
2. Si cambias el secret por `secrets: inherit`, ¿qué cambia en términos de supply-chain?
3. ¿Qué pasa si tu reusable necesita `permissions: packages: write` pero el caller declaró `permissions: contents: read`?
4. ¿Cuánto cuesta en minutos pasar de "composite inline" a este reusable con un solo job? ¿Y con tres jobs?
5. ¿Cómo probarías en vivo (sin merge) que el cambio al reusable no rompe a los consumidores actuales?

## 10. Extensiones (opcional)

- **E1** — Añade un **segundo reusable** (`shared/.github/workflows/scan.yml`) y haz que el caller lo encadene con `needs:` entre ambos.
- **E2** — Promueve `v1.0.0 → v1.0.1` moviendo el tag `v1` con `git tag -fa v1 && git push --force origin v1` (en vivo requiere `--force`; local solo re-crea).
- **E3** — Cambia el pin de `@v1` a `@<SHA>` en el caller y escribe un párrafo justificando cuándo prefieres cada opción.
- **E4** — Documenta en `shared/README.md` el **contract**: tabla con nombre del reusable, inputs, outputs, secrets, permissions requeridos en el caller.

## 11. Limpieza

```bash
rm -rf /tmp/publish-reusable
```
