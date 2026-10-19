# Ejemplo 02 — Push al Container Registry y cleanup policy

> Objetivo: ver un build rootless con Kaniko que publica a `$CI_REGISTRY_IMAGE` y la **cleanup policy** declarativa que mantiene el registry sin basura.

## 1. El `.gitlab-ci.yml`

Ver `.gitlab-ci.yml`. Puntos clave:

- Build con **Kaniko** (sin DinD, sin `--privileged`).
- Dos tags por push: `:$CI_COMMIT_SHA` (immutable) y `:latest` solo en `main`.
- Variable `IMAGE_DIGEST` capturada del output de Kaniko (`--digest-file`) para uso downstream en firma/attestations.

## 2. Cleanup policy (equivalente API)

GitLab expone la cleanup policy del Container Registry via UI y API. El JSON que se envía al endpoint `PUT /projects/:id/registry/repositories/:repo_id/cleanup_policy` tiene esta forma (ver `cleanup-policy.json`):

```json
{
  "enabled": true,
  "cadence": "7d",
  "keep_n": 10,
  "older_than": "30d",
  "name_regex_delete": "^(pr-\\d+|sha-[0-9a-f]{7,40})$",
  "name_regex_keep": "^(v\\d+\\.\\d+\\.\\d+|main-.*|latest)$"
}
```

Lectura:

- **`keep_n: 10`** — conserva los 10 tags más recientes que matchean `name_regex_delete`.
- **`older_than: 30d`** — borra tags con >30 días de edad entre los que matchean `name_regex_delete`.
- **`name_regex_keep`** — allowlist: `v1.2.3`, `main-*`, `latest` nunca se borran.
- **`cadence: 7d`** — el worker corre semanalmente.

> **Trampa habitual**: olvidar el `name_regex_keep` → cuando sube la cuenta de tags, el cleanup borra el `v1.2.3` de hace meses porque "no está en los 10 más recientes".

## 3. Dependency proxy (bonus)

Si tus runners tiran imágenes de Docker Hub (`alpine`, `node`, `python`), configura el group dependency proxy y reemplaza:

```yaml
image: alpine:3.19
```

por:

```yaml
image: ${CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX}/alpine:3.19
```

Evita el rate limit de Docker Hub (100 pulls/6h anónimo) y reduce latencia.

## 4. Verificación local

```bash
python3 -c 'import yaml,sys; yaml.safe_load(open(".gitlab-ci.yml"))'
jq . cleanup-policy.json
```
