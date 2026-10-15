# Actividad 02 — CODEOWNERS y required reviewers para un repo multi-equipo

## 1. Identificación

- **ID:** `gh-07-02-codeowners-and-required-reviews`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-07-collaboration-prs-and-review`
- **Dificultad:** intermediate
- **Duración estimada:** 45–60 min
- **Tipo:** guided-lab

## 2. Contexto

Se te entrega el esqueleto de un repo multi-equipo (`api`, `web`, `docs`, `infra`). Tu tarea es declarar quién revisa qué (`CODEOWNERS`), con qué criterios (`PULL_REQUEST_TEMPLATE.md`), y qué política mínima de aprobaciones aplica (`review-policy.yaml`). El validador verifica sintaxis, cobertura (que cada subsistema tenga owner distinto del default) y simula asignación de reviewers para 5 PRs hipotéticos.

## 3. Objetivos

Al terminar:
- Diseñas `CODEOWNERS` con 3 niveles: default (`*`), glob (`*.ext`), path (`/dir/`).
- Validas que cada regla sigue sintaxis `<pattern> @owner[ @owner...]`.
- Redactas un `PULL_REQUEST_TEMPLATE.md` con las secciones obligatorias.
- Documentas la política de reviewers en `.github/review-policy.yaml`.

## 4. Prerrequisitos

- Git ≥ 2.30.
- `bash`, `python3`, `awk`, `grep`.
- Opcional (`MODE=live`): `gh` autenticado y permisos de admin en el repo.

**Costos**: ninguno en `MODE=local`.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-repo.sh /tmp/codeowners-lab
cd /tmp/codeowners-lab
tree -L 2 .          # (si no tienes 'tree', usa 'find . -maxdepth 2')
```

El starter crea un repo con esta estructura:

```
/tmp/codeowners-lab/
├── README.md
├── src/
│   ├── api/handlers.py
│   ├── api/__init__.py
│   ├── web/app.ts
│   └── web/index.html
├── docs/architecture.md
├── docs/runbook.md
├── infra/main.tf
├── tests/test_handlers.py
├── .github/
│   └── workflows/ci.yml
└── .pr/issues/*.md   # issues simulados
```

Pero **no** incluye `CODEOWNERS`, ni PR template, ni política. Esos los redactas tú.

### 5.2 Diseño pedido

**Equipos disponibles** (nombres a usar literalmente):

```
@acme/maintainers        # fallback para cualquier archivo
@acme/api-team           # dueños de /src/api/
@acme/frontend-team      # dueños de /src/web/
@acme/docs-team          # dueños de /docs/ y de *.md
@acme/platform-team      # dueños de /infra/ y de *.tf
@acme/python-maintainers # expertos transversales *.py
@acme/devops             # dueños de /.github/workflows/
@acme/security           # dueños de SECURITY.md y de cualquier cambio en /.github/CODEOWNERS
```

### 5.3 Archivos a producir

1. **`.github/CODEOWNERS`** con reglas que:
   - Tengan **default** (`*`) apuntando a `@acme/maintainers`.
   - Tengan al menos **2 globs** por extensión (`*.py`, `*.tf`, `*.md`, etc.).
   - Tengan al menos **3 paths** específicos (acabando en `/`).
   - Protejan `/.github/workflows/` y `/.github/CODEOWNERS` con doble owner.
   - Cumplan sintaxis: línea = `<pattern> @owner[ @owner...]`.
   - La **última regla que matchea gana** (ordena los más específicos **al final**).

2. **`.github/PULL_REQUEST_TEMPLATE.md`** con las secciones:
   `## Summary`, `## Changes`, `## Linked issues` (con línea literal `Fixes #`), `## Test plan`, `## Risk / rollback`.

3. **`.github/review-policy.yaml`** con esta estructura mínima:
   ```yaml
   required_approvals: <int, >=1>
   require_codeowner_review: true | false
   dismiss_stale_reviews_on_push: true | false
   require_up_to_date_before_merge: true | false
   restrict_who_can_push_to_main: [team1, team2]  # al menos uno
   ```

   Elige valores **razonados** y defendibles.

4. Commitea todo (`feat(.github): add governance files`) y pushea si trabajas con remoto.

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/codeowners-lab
```

El validador comprueba:
- Existencia y sintaxis de `.github/CODEOWNERS`.
- Default, ≥ 2 globs, ≥ 3 paths específicos.
- Doble owner en `/.github/workflows/` y en `/.github/CODEOWNERS`.
- Simulación: para 5 archivos de prueba, el owner efectivo coincide con lo esperado.
- Existencia y secciones de `.github/PULL_REQUEST_TEMPLATE.md`.
- Existencia y claves mínimas de `.github/review-policy.yaml`.

## 6. Resultado esperado

- Working tree limpio.
- Los 3 archivos existen con contenido válido.
- Validador imprime `OK: actividad completada correctamente.`

## 7. Criterios de aceptación

- [ ] `.github/CODEOWNERS` existe, sintaxis correcta, ≥ 3 paths específicos, ≥ 2 globs, 1 default.
- [ ] `/.github/workflows/` y `/.github/CODEOWNERS` tienen **≥ 2 owners**.
- [ ] `.github/PULL_REQUEST_TEMPLATE.md` tiene las 5 secciones listadas.
- [ ] `.github/review-policy.yaml` tiene las 5 claves listadas con valores coherentes.
- [ ] Tests simulados de "quién es owner" pasan (ver `tests/validate.sh`).

## 8. Validación

```bash
bash tests/validate.sh /tmp/codeowners-lab
```

En **MODE=live** adicionalmente consulta `gh api repos/$GH_REPO/codeowners/errors` para asegurar que GitHub no reporta owners inválidos:

```bash
MODE=live GH_REPO="<owner>/<repo>" bash tests/validate.sh /tmp/codeowners-lab
```

## 9. Preguntas de reflexión

1. Si inviertes el orden de `*` y `/src/api/`, ¿quién sería owner de `src/api/handlers.py`? ¿Por qué CODEOWNERS funciona "última regla gana"?
2. ¿Por qué recomendamos **teams** (`@acme/api-team`) en vez de personas (`@alice`)?
3. En tu `review-policy.yaml` elegiste `required_approvals: N`. Justifica N en 2 frases.
4. Si el repo tiene auto-merge activado y falta la review de un CODEOWNER, ¿qué pasa? ¿Y si se pushean cambios tras la aprobación con `dismiss_stale_reviews_on_push: true`?

## 10. Extensiones (opcional)

- **E1** — Añade un `.github/CODEOWNERS` adicional en una subcarpeta (`/src/api/CODEOWNERS`) y comprueba cómo GitHub resuelve. (Pista: no se soporta anidado; solo las 3 ubicaciones canónicas.)
- **E2** — Añade reglas para `.ipynb`, `Dockerfile`, `docker-compose.*.yml`.
- **E3** — Escribe un script `simulate-reviewer.sh <ruta>` que lea tu `CODEOWNERS` y responda qué owners serían asignados.

## 11. Limpieza

```bash
rm -rf /tmp/codeowners-lab
```
