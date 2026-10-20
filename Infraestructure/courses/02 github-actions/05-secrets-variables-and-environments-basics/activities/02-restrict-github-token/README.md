# Actividad 02 — Auditar y restringir el `GITHUB_TOKEN`

## 1. Identificación

- **ID:** `gha-05-02-restrict-github-token`
- **Tecnología:** `github-actions`
- **Módulo:** `05-secrets-variables-and-environments-basics`
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Alguien del equipo escribió este workflow para "que funcione sin pelearse con permisos":

```yaml
permissions: write-all
```

Y a partir de ahí todo el workflow corre con permisos de admin del repo: puede empujar a cualquier branch, abrir y cerrar issues, publicar releases, modificar labels, borrar packages. Si cualquiera de las actions que invoca es comprometida (ya ha pasado: `tj-actions/changed-files` en 2025), el atacante consigue todo eso automáticamente.

Tu trabajo: **auditar y reescribirlo** siguiendo el patrón "read-only por default + escalada mínima por job con comentario de justificación". El validador comprueba, sobre el YAML resultante, que el modelo está bien aplicado.

## 3. Objetivos

- Identificar en un workflow dado cada operación que requiere escribir en GitHub (comentar PRs, crear releases, etc.).
- Mapear cada operación a la **key mínima** de `permissions:` que la habilita.
- Reescribir el workflow a `permissions: contents: read` top-level + escalada por job comentada.
- Pasar un validador que rechaza `write-all`, `contents: write` sin comentario de justificación, y la ausencia de `permissions:`.

## 4. Prerrequisitos

- Lectura de `theory/lesson.md` (secciones 2.3 y 7).
- Referencia GitHub Docs → "Permissions for the `GITHUB_TOKEN`" (listada en `resources/links.md`).

## 5. Instrucciones

### 5.1 Preparar

```bash
MODE=local bash starter/bootstrap.sh /tmp/gha-05-restrict-github-token
```

Esto crea `/tmp/gha-05-restrict-github-token/local/.github/workflows/vulnerable.yml` — un workflow con **tres jobs**:

1. `lint` — solo lee código. No necesita escribir nada.
2. `comment-pr` — deja un comentario con el resumen de lint en el PR.
3. `publish-draft-release` — en push a `main`, crea un release draft.

Y arriba de todo: `permissions: write-all` (el problema).

### 5.2 Auditar (hazlo con lápiz antes de tocar YAML)

Para cada job respondé:

- ¿Lee código del repo? → necesita `contents: read`.
- ¿Comenta en un PR? → necesita `pull-requests: write`.
- ¿Crea / edita releases o pushea commits? → necesita `contents: write`.
- ¿Edita issues? → `issues: write`.
- ¿Publica packages a GHCR? → `packages: write`.
- ¿Usa OIDC a cloud? → `id-token: write` (`gha-11`).

### 5.3 Reescribir

Editá `vulnerable.yml` (o renombralo a `hardened.yml` — mantenerlo con el mismo nombre está bien) para:

1. Eliminar `permissions: write-all`.
2. Agregar top-level:

   ```yaml
   permissions:
     contents: read
   ```

3. En cada job que **sí** escribe, declarar un bloque `permissions:` propio con las keys mínimas, y agregar un **comentario** justificando (una línea `#` que incluya la palabra clave "justif", es decir "JUSTIFICATION" o "Justificación", en la misma línea del permiso elevado o en la línea inmediatamente anterior).

Ejemplo de forma esperada:

```yaml
  comment-pr:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write   # JUSTIFICATION: post lint summary comment on PR
    steps:
      - ...
```

### 5.4 Validar

```bash
MODE=local bash tests/validate.sh /tmp/gha-05-restrict-github-token
```

Debe terminar en `RESULT (local): N/N checks OK.`.

## 6. Resultado esperado

Workflow con:

- Top-level `permissions: contents: read`.
- `lint`: sin bloque `permissions:` propio (hereda del top-level).
- `comment-pr`: `permissions:` con `contents: read` + `pull-requests: write` + comentario de justificación.
- `publish-draft-release`: `permissions:` con `contents: write` + comentario de justificación.
- Cero `permissions: write-all`.
- Cero `contents: write` *sin* un comentario con "justif" cerca.

## 7. Criterios de aceptación

- [ ] No existe `permissions: write-all` en ninguna parte del YAML.
- [ ] Hay un bloque `permissions:` top-level con `contents: read` (y nada más).
- [ ] Al menos un job declara `permissions:` propias que incluyen `pull-requests: write`, con justificación.
- [ ] Al menos un job declara `permissions:` propias que incluyen `contents: write`, con justificación.
- [ ] `tests/validate.sh` termina con exit 0.

## 8. Validación

Checks que corre `tests/validate.sh` (MODE=local):

1. El YAML parsea.
2. Grep de `permissions:[[:space:]]*write-all` → **debe fallar** (no debe aparecer).
3. Presencia de `permissions:` top-level con `contents: read`.
4. Cualquier `contents:[[:space:]]*write` tiene un comentario con `justif` en esa línea o la inmediatamente anterior.
5. Cualquier `pull-requests:[[:space:]]*write` idem.
6. Al menos un job sin bloque `permissions:` propio (confirmando que la herencia top-level se está usando, en vez de duplicar en cada job).

## 9. Preguntas de reflexión

1. ¿Por qué `permissions:` por job **reemplaza** al top-level en vez de merge-earse? ¿Qué fallo se evita con esa semántica?
2. ¿Qué pasa si una action que invoca `publish-draft-release` es comprometida? ¿Qué puede hacer, y qué no puede hacer, con el `GITHUB_TOKEN` del job?
3. ¿En qué se diferencia tu modelo final del original (`write-all`) si el workflow nunca llegó a ejecutarse en condiciones reales? (Pista: pensá en lectura humana y en auditoría futura.)
4. ¿Qué beneficio concreto da el comentario de justificación, frente a tenerlo "obvio" por el nombre del job?
5. ¿Qué harías si un job *legítimamente* necesita escribir a varios recursos (p. ej. `contents: write` + `packages: write` + `id-token: write`)? ¿Lo dejás en un solo job o lo partís?

## 10. Extensiones

- **E1** — Partí `publish-draft-release` en dos: uno que *solo* genera notas (sin escribir) y otro que crea el release. Comprobá que podés dejar el primero con `contents: read`.
- **E2** — Agregá un job que use OIDC (`id-token: write`) con un comentario que apunte a `gha-11`.
- **E3** — Simulá una org donde el default es `write-all`. Agregá un comentario al tope del workflow explicando por qué el bloque `permissions:` top-level es **obligatorio** independientemente del default.
- **E4** — Documentá qué controles organizacionales (branch protection, CODEOWNERS para `.github/workflows/`, required reviewers) complementan a `permissions:`. (Se profundiza en `gha-13`.)

## 11. Limpieza

```bash
rm -rf /tmp/gha-05-restrict-github-token
```
