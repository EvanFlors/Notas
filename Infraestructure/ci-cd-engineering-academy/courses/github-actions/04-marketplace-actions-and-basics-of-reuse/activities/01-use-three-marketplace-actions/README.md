# Actividad 01 — Usar 3 actions del Marketplace (todas pinneadas a SHA)

## 1. Identificación

- **ID:** `gha-04-01-use-three-marketplace-actions`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-04-marketplace-actions-and-basics-of-reuse`
- **Dificultad:** beginner
- **Duración estimada:** 30–45 min
- **Tipo:** guided-lab

## 2. Contexto

Primer workflow que compones vos mismo eligiendo las dependencias. Vas a construir un CI Python mínimo que use **tres actions del Marketplace** (una para checkout, una para preparar el runtime, una tercera a elección), **todas pinneadas a SHA de 40 chars con comentario `# v<SEMVER>`**.

No necesitas GitHub real: la validación corre sobre el YAML local.

## 3. Objetivos

Al terminar:
- Elegiste 3 actions del Marketplace (al menos 1 oficial `actions/*`, al menos 1 que no sea solo `checkout`).
- Resolviste cada tag a su SHA (o lo tomaste de la propia página del release).
- Escribiste cada `uses:` en el formato canónico `owner/repo@<SHA40>  # v<SEMVER>`.
- El validador pasa en verde.

## 4. Prerrequisitos

- `gha-01` completado (sabes qué es un job, un step, una `uses:`).
- Python ≥ 3.9 con `pyyaml` instalado (`pip install pyyaml`).
- (Opcional) `gh` autenticado para resolver tags cómodamente.

Costo: $0.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/gha-04-01-use-three-marketplace-actions
```

Esto crea:

```
/tmp/gha-04-01-use-three-marketplace-actions/
└── repo/
    └── .github/
        └── workflows/
            └── ci.yml      ← starter con TODOs; esto lo editas tú
```

### 5.2 Elegir tus 3 actions

Elige **exactamente 3** actions (puedes incluir más si quieres, pero el validador exige al menos 3). Sugerencias (del catálogo oficial):

| Action | Para qué sirve |
|--------|----------------|
| `actions/checkout` | Clonar el repo al workspace (siempre va primero) |
| `actions/setup-python` | Instalar Python |
| `actions/setup-node` | Instalar Node.js |
| `actions/cache` | Caché generalista |
| `actions/upload-artifact` | Subir artefactos entre jobs |
| `actions/download-artifact` | Bajar artefactos |
| `actions/setup-go` | Instalar Go |

Reglas:
- Al menos **una** debe ser `actions/checkout` (sin ella no haces nada útil).
- Al menos **tres** actions distintas (owner/repo distintos).

### 5.3 Resolver tags a SHAs

Para cada action elegida, elige una versión semver y resuélvela:

```bash
# Ejemplo: actions/setup-node v4.1.0
gh api repos/actions/setup-node/git/refs/tags/v4.1.0 --jq '.object.sha'
# o sin gh:
git ls-remote https://github.com/actions/setup-node.git refs/tags/v4.1.0
```

> Si estás offline, puedes copiar los SHAs del `solution/` o de `examples/01-setup-python-matrix/files/ci.yml`.

### 5.4 Escribir el workflow

Edita `/tmp/gha-04-01-use-three-marketplace-actions/repo/.github/workflows/ci.yml`. Patrón requerido para cada `uses:`:

```yaml
- uses: <owner>/<repo>@<40-hex-sha>  # v<MAJOR>.<MINOR>.<PATCH>
```

Ejemplos válidos:

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
- uses: actions/setup-python@0b93645e9fea7318ecaed2b359559ac225c90a2b  # v5.3.0
- uses: actions/cache@6849a6489940f00c2f30c0fb92c6274307ccb58a  # v4.1.2
```

Lo que **NO** se acepta:
- `@v4` suelto (tag mayor).
- `@main` o cualquier branch.
- SHA sin comentario (`@abc123... ` sin `# vX.Y.Z` al lado).
- SHA de menos de 40 chars.

### 5.5 Validar

```bash
bash tests/validate.sh /tmp/gha-04-01-use-three-marketplace-actions
```

Debe terminar con `RESULT: N/N checks OK.`

## 6. Resultado esperado

- Archivo `.github/workflows/ci.yml` con al menos 3 `uses:`, todas en formato `owner/repo@<SHA40>  # v<SEMVER>`.
- YAML parseable sin errores.
- Al menos un job con `runs-on:` y `steps:`.

## 7. Criterios de aceptación

- [ ] El YAML carga sin excepción.
- [ ] Hay ≥ 3 líneas `uses:` que apuntan a owner/repo distintos.
- [ ] Cada `uses:` referencia un SHA de **exactamente 40 chars hex** (`[0-9a-f]{40}`).
- [ ] Cada línea de `uses:` lleva un comentario `# vX.Y.Z` (semver con 3 números) en la misma línea.
- [ ] Al menos una de las actions es `actions/checkout`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gha-04-01-use-three-marketplace-actions
```

Lee `tests/validate.sh` para ver el detalle de cada chequeo.

## 9. Preguntas de reflexión

1. ¿Por qué el validador exige el comentario con la versión? ¿Qué pierdes sin él?
2. Si eliges `actions/setup-node@v4.1.0`, ¿cómo le decís a Dependabot "quiero el minor dentro de v4 pero no saltar a v5"?
3. ¿Qué política aplicarías para actions **no oficiales** (fuera de `actions/*`)?
4. ¿Qué pasa si pinneas al SHA del **tag object** anotado en vez del SHA del commit? Prueba con `git ls-remote URL refs/tags/<tag>` vs `URL refs/tags/<tag>^{}`.

## 10. Extensiones (opcional)

- **E1** — Añade un `.github/dependabot.yml` con `package-ecosystem: github-actions` y verifica que YAML carga.
- **E2** — Añade una matriz `strategy.matrix` con 2 o 3 versiones de la runtime (Python o Node).
- **E3** — Añade `permissions: contents: read` a nivel workflow.
- **E4** — Añade un segundo workflow (`release.yml`) con otras 2 actions, también pinneadas, y re-corre el validador.

## 11. Limpieza

```bash
rm -rf /tmp/gha-04-01-use-three-marketplace-actions
```
