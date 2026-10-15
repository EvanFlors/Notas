# Ejemplo 01 — Required reusable workflow via org ruleset

Este ejemplo muestra el patrón **"platform contract via ruleset"**: un workflow reutilizable publicado en `org/.github` que **todos los repos** cubiertos por el ruleset deben pasar antes de mergear a `main`.

## Qué hay aquí

```
.
├── README.md                      ← este archivo
├── ruleset.json                   ← payload para POST /orgs/{org}/rulesets
├── security-scan.yml              ← el reusable workflow (vive en org/.github)
└── consumer-ci.yml                ← lo que escribe un repo cliente
```

> **No ejecutes este ejemplo contra tu org real sin leerlo entero.** Un ruleset
> con `enforcement: active` bloquea los PRs del scope cubierto. Para probar
> seguro: aplícalo a un repo de sandbox con `conditions.repository_name` filtrando
> por nombre, o usa `enforcement: evaluate` (modo "shadow", no bloquea).

## Pasos

### 1. Publicar el reusable workflow

En un repo `ACME/.github` (repo especial de org):

```
.github/workflows/security-scan.yml   ← contenido de este dir
```

Taggearlo:

```bash
git tag v1.0.0
git tag -f v1          # mutable, mueve con cada release de la major 1
git push --tags --force
```

### 2. Averiguar el `repository_id` del repo del reusable

```bash
gh api /repos/ACME/.github --jq .id
# -> p. ej. 1234567
```

Pégalo en `ruleset.json` donde dice `"repository_id": 1234567`.

### 3. Aplicar el ruleset a la org

```bash
gh api -X POST /orgs/ACME/rulesets \
  --input ruleset.json
```

Verificar:

```bash
gh api /orgs/ACME/rulesets --jq '.[] | {id, name, enforcement}'
```

### 4. Lado consumidor

Cualquier repo de la org añade `.github/workflows/ci.yml` con el contenido de `consumer-ci.yml`. En su próximo PR a `main`:

- Debe aparecer el check `security-scan / scan`.
- Si el workflow falla, el PR no puede mergear.
- Si el workflow **no corre** (p. ej. filtro `paths-ignore` lo saltó), el ruleset reporta el check como **requerido pero ausente** y bloquea.

### 5. Modo evaluate (shadow)

Antes de hacerlo obligatorio, prueba con:

```json
"enforcement": "evaluate"
```

Genera "would-have-blocked" en la UI de rulesets sin romper nada.

## Observaciones de diseño

- **Pin del `ref` del workflow**: en el ruleset usamos `"ref": "refs/heads/main"` por simplicidad. En producción pinnea a un tag inmutable (`refs/tags/v1.0.0`) para que un cambio al repo platform no mueva el contrato sin PR explícito.
- **Bypass**: añade `bypass_actors` con el team platform para permitir que platform mergee fixes al propio reusable sin quedar bloqueado por su propio check roto.
- **Observabilidad del contrato**: cada ruleset tiene un *insights* en la UI (PRs evaluados, bloqueos). Es el "SLO del contrato".
