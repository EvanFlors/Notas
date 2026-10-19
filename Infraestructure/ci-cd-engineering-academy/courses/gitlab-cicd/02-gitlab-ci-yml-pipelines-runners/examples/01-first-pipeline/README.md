# Ejemplo 01 — Primer `.gitlab-ci.yml`

## Qué muestra

El `.gitlab-ci.yml` **más corto que GitLab acepta** y produce un pipeline con un único job que imprime `hola GitLab`. Útil para entender la mínima convención.

## Archivo

Mira [`.gitlab-ci.yml`](./.gitlab-ci.yml). Son 2 líneas útiles.

## Lectura línea por línea

```yaml
hello:
  script: echo "hola GitLab"
```

- `hello` — **nombre del job**. No es una key reservada, así que GitLab la trata como job.
- `script:` — en este caso un escalar, pero la convención es lista (ver teoría §2).
- Sin `stage:` → cae en `test` (default del `stages:` implícito).
- Sin `image:` → el runner usa su imagen default (en SaaS Linux small amd64, es `ruby:3.3` histórico, hoy variable; no asumir nada).
- Sin `tags:` → cualquier runner que acepte jobs sin tags lo recoge (en `gitlab.com`, los shared runners lo hacen).

## Cómo "ejecutarlo" (opcional)

1. Crea un repo en `gitlab.com`.
2. Añade este `.gitlab-ci.yml` a la raíz.
3. Push a `main`. En *CI/CD → Pipelines* verás un pipeline con 1 job.

## Validación local (sin GitLab)

```bash
python3 -c "import yaml, sys; yaml.safe_load(open('.gitlab-ci.yml')); print('YAML OK')"
```

## Qué **no** muestra

- Múltiples stages → `examples/02`.
- Executor Docker con `image:` → `examples/03`.
- `rules:` y `workflow:` → `gl-04`.
