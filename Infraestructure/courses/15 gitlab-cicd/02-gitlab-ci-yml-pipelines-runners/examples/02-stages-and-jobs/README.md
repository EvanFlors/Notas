# Ejemplo 02 — Stages y jobs en paralelo

## Qué muestra

Un pipeline con **3 stages** (`lint`, `test`, `build`) y **4 jobs**. Dos jobs corren en paralelo dentro de `lint`. Ilustra la regla "stage = barrera de sincronización".

## Archivo

Ver [`.gitlab-ci.yml`](./.gitlab-ci.yml).

## Diagrama de ejecución

```
stage: lint        │ stage: test      │ stage: build
───────────────────┼──────────────────┼──────────────
lint-yaml  ──┐     │                  │
             ├──►  │ unit-tests  ──►  │ build-artifact
lint-shell ──┘     │                  │
```

- `lint-yaml` y `lint-shell` arrancan a la vez (ambos en `lint`).
- `unit-tests` espera a que **ambos** lint-* acaben.
- `build-artifact` espera a `unit-tests`.

Si quisieras romper esa barrera y que `build-artifact` arrancara en cuanto `unit-tests` acaba sin importar otros jobs futuros de `test`, usarías `needs:` → `gl-04`.

## Qué fijarse

- `stages:` declara explícitamente el orden (buena práctica, aunque el default lo soporta).
- Cada job tiene `stage:` y `script:` como lista.
- Ningún job tiene `image:` → asume el default del runner. En SaaS funciona; en self-managed tal vez quieras un `default: image:` global.

## Validación local

```bash
python3 -c "import yaml; d = yaml.safe_load(open('.gitlab-ci.yml')); assert d['stages'] == ['lint','test','build']; print('stages OK')"
```

## Variante útil (fuera del ejemplo)

Si quisieras que **ningún job quede sin tag** en self-managed con política estricta:

```yaml
default:
  tags: [docker, linux]
```

Así todos los jobs heredan `tags: [docker, linux]` y solo los runners que los tengan los recogen.
